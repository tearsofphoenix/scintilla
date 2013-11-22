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
    NSThread *_debugServerThread;
}
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
        }
        
        return self;
    }
}

- (void)_debugServerMain
{
    @autoreleasepool
    {
        LRDStartDebugServer(LRDDefaultServerAddress, LRDDefaultServerPort);
    }
}

- (void)startDebugSource: (NSString *)sourceCode
{
    //start server on other thread if possible
    //
    if (![_debugServerThread isExecuting])
    {
        [_debugServerThread start];
    }
    
    //
    double delayInSeconds = 0.3;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    
    dispatch_after(popTime, dispatch_get_main_queue(),
                   (^(void)
                    {
                        luaopen_RLdb(_luaState);
                        //luaL_requiref(_luaState, "remotedebugger", luaopen_RLdb, 0);
                        luaL_dostring(_luaState, [sourceCode UTF8String]);
                    }));
    
}

@end
