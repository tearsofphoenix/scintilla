/******************************************************************************
* Copyright (C) 2009 Zhang Lei.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
******************************************************************************/

#ifndef __SOCKET_H__
#define __SOCKET_H__

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h> //sockaddr_in
#include <arpa/inet.h>  //inet_addr
#include <unistd.h>     //close
#import <Foundation/Foundation.h>

typedef int SOCKET;

#define INVALID_SOCKET -1
#define SOCKET_ERROR -1

#define closesocket(s) close(s)

#define LRDDefaultServerAddress  "127.0.0.1"
#define LRDDefaultServerPort     8211

/*
 ** Connect to a remote controller.
 */
extern SOCKET LRDSocketCreate(const char * addr, unsigned short port);

extern int LRDSocketSendData(SOCKET s, const void * buf, size_t len);

extern int LRDSocketSendErrorMessage(SOCKET s, NSString *message);

extern int LRDSocketSendObject(SOCKET s, id object);

#define LRDPrefix               "com.veritas.lua.remote-debugger"

#define LRDMessageTypeKey       LRDPrefix ".message-type"
#define LRDMessageTypeNormal    "normal"
#define LRDMessageTypeError     "error"
#define LRDMessageTypeCommand   "command"

#define LRDMessageContentKey    LRDPrefix ".content"

#define LRDStatusKey            LRDPrefix ".status"

#define LRDStatusOK             "ok"
#define LRDStatusError          "error"

#define LRDReasonKey            LRDPrefix ".reason"


#endif
