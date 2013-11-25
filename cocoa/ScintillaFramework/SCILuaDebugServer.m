//
//  SCILuaDebugServer.m
//  Scintilla
//
//  Created by Mac003 on 13-11-22.
//
//

#import "SCILuaDebugServer.h"
#import <LuaRemoteDebug/LuaRemoteDebug.h>

@interface SCILuaDebugServer ()
{
    lua_State *_luaState;
    LRDServer *_server;
    NSThread *_debugServerThread;
    NSThread *_clientThread;
}

@property (nonatomic, copy) dispatch_block_t clientBlock;

@end

@implementation SCILuaDebugServer

static id gsSharedServer = nil;

+ (id)sharedServer
{
    if (!gsSharedServer)
    {
        gsSharedServer = [[self alloc] init];
    }
    
    return gsSharedServer;
}

- (id)init
{
    if (gsSharedServer)
    {
        [self release];
        return gsSharedServer;
    }else
    {
        if ((self = [super init]))
        {
            _luaState = luaL_newstate();

            _debugServerThread = [[NSThread alloc] initWithTarget: self
                                                         selector: @selector(_debugServerMain)
                                                           object: nil];
            
            [_debugServerThread setName: @"com.veritas.thread.lua.debug-server"];
            
            _clientThread = [[NSThread alloc] initWithTarget: self
                                                    selector: @selector(_clientMain)
                                                      object: nil];
            
            [_clientThread setName: @"com.veritas.thread.lua.debug-client"];
        }
        
        return self;
    }
}

- (void)_debugServerMain
{
    @autoreleasepool
    {
        NSLog(@"2");
//        _server = [[LRDServer alloc] initWithHotName: @(LRDDefaultServerAddress)
//                                                port: LRDDefaultServerPort];
        LRDStartDebugServer(LRDDefaultServerAddress, LRDDefaultServerPort);
    }
}

- (void)_clientMain
{
    @autoreleasepool
    {
        if (_clientBlock)
        {
            _clientBlock();
        }
    }
}

- (void)startDebugSource: (NSString *)sourceCode
{
    [self setClientBlock: (^(void)
                           {
                               NSLog(@"1");
                               luaopen_RLdb(_luaState);
                               luaL_dostring(_luaState, [sourceCode UTF8String]);
                           })];
    
    //start server on other thread if possible
    //
    if (![_debugServerThread isExecuting])
    {
        [_debugServerThread start];
    }
    
    if (![_clientThread isExecuting])
    {
        [_clientThread start];
    }
}

@end
