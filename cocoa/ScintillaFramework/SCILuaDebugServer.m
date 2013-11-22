//
//  SCILuaDebugServer.m
//  Scintilla
//
//  Created by Mac003 on 13-11-22.
//
//

#import "SCILuaDebugServer.h"
#import <LuaRemoteDebug/LuaRemoteDebug.h>
#import <LuaKit/LuaKit.h>

@interface SCILuaDebugServer ()
{
    lua_State *_luaState;
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
        }
        
        return self;
    }
}

- (void)startDebugSource: (NSString *)sourceCode
{
    LRDStartDebugServer(0, NULL);
}

@end
