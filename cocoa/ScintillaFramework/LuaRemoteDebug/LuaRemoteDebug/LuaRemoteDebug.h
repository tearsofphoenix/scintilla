//
//  LuaRemoteDebug.h
//  LuaRemoteDebug
//
//  Created by Mac003 on 13-11-22.
//  Copyright (c) 2013年 Mac003. All rights reserved.
//

#ifndef LUAREMOTEDEBUG_H_
#define LUAREMOTEDEBUG_H_ 1

#ifdef __cplusplus
extern "C" {
#endif

#include <LuaKit/LuaKit.h>
#include <LuaRemoteDebug/Dump.h>
#include <LuaRemoteDebug/Socket.h>
#include <LuaRemoteDebug/LRDServerSocketBuffer.h>
#include <LuaRemoteDebug/SocketBuffer.h>
#include <LuaRemoteDebug/Protocol.h>
    
    extern int LRDStartDebugServer(const char *addrStr, int port);
    
#ifdef OS_WIN
    __declspec(dllexport)
#endif
    int luaopen_RLdb(lua_State * L);
    
#ifdef __cplusplus
}
#endif

#endif