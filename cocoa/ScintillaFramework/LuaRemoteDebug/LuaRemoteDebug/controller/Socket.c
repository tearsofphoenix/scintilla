//
//  Socket.c
//  LuaRemoteDebug
//
//  Created by Mac003 on 13-11-22.
//  Copyright (c) 2013年 Mac003. All rights reserved.
//

#include "Socket.h"

int SendData(SOCKET s, const void * buf, size_t len)
{
    while (len > 0)
    {
        size_t sent = send(s, buf, len, 0);
        
        if (sent == SOCKET_ERROR)
        {
            return -1;
        }
        
        len -= sent;
        buf += sent;
    }
    
    return 0;
}
