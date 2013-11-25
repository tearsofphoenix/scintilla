//
//  Socket.c
//  LuaRemoteDebug
//
//  Created by Mac003 on 13-11-22.
//  Copyright (c) 2013年 Mac003. All rights reserved.
//

#import "Socket.h"

static int LRDSocketSendString(SOCKET s, const char *str)
{
    return LRDSocketSendData(s, str, strlen(str));
}

SOCKET LRDSocketCreate(const char * addrStr, unsigned short port)
{
    SOCKET s;
    struct sockaddr_in addr;
    assert(addrStr);
    
    s = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (s == INVALID_SOCKET)
    {
        return INVALID_SOCKET;
    }
    
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = inet_addr(addrStr);
    addr.sin_port = htons(port);
    
    if (connect(s, (struct sockaddr *)&addr, sizeof(addr)) == SOCKET_ERROR)
    {
        closesocket(s);
        return INVALID_SOCKET;
    }
    return s;
}

int LRDSocketSendData(SOCKET s, const void * buf, size_t len)
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

int LRDSocketSendErrorMessage(SOCKET s, NSString *message)
{
    return LRDSocketSendObject(s, (@{
                                     @(LRDMessageTypeKey) : @(LRDMessageTypeError),
                                     @(LRDMessageContentKey) : message
                                     }));
}

int LRDSocketSendObject(SOCKET s, id object)
{
    NSError *error = nil;
    NSString *jsonString = [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject: object
                                                                                           options: NSJSONWritingPrettyPrinted
                                                                                             error: &error]
                                                 encoding: NSUTF8StringEncoding];
    if (error)
    {
        NSLog(@"%@", error);
        return (int)[error code];
    }else
    {
        return LRDSocketSendString(s, [jsonString UTF8String]);
    }
}