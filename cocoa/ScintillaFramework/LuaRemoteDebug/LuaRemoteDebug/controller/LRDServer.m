//
//  LRDServer.m
//  LuaRemoteDebug
//
//  Created by Mac003 on 13-11-25.
//  Copyright (c) 2013年 Mac003. All rights reserved.
//

#import "LRDServer.h"
#import "Socket.h"
#import "EchoConnection.h"

#import <CFNetwork/CFNetwork.h>

@interface LRDServer ()<NSStreamDelegate>
{
    CFSocketRef _ipv4socket;
    CFSocketRef _ipv6socket;
    
    NSMutableArray *_connections;
}

@property (nonatomic) UInt32 port;

@end



@implementation LRDServer

// This function is called by CFSocket when a new connection comes in.
// We gather the data we need, and then convert the function call to a method
// invocation on EchoServer.
static void EchoServerAcceptCallBack(CFSocketRef socket,
                                     CFSocketCallBackType type,
                                     CFDataRef address,
                                     const void *data, void *info)
{
    assert(type == kCFSocketAcceptCallBack);
#pragma unused(type)
#pragma unused(address)
    
    LRDServer *server = (LRDServer *)info;
    assert(socket == server->_ipv4socket || socket == server->_ipv6socket);
#pragma unused(socket)
    
    // For an accept callback, the data parameter is a pointer to a CFSocketNativeHandle.
    [server acceptConnection: *(CFSocketNativeHandle *)data];
}

- (id)init
{
    [self doesNotRecognizeSelector: _cmd];
    return nil;
}

- (BOOL)start
{
    assert(_ipv4socket == NULL && _ipv6socket == NULL);       // don't call -start twice!
    
    CFSocketContext socketCtxt = {0, (__bridge void *) self, NULL, NULL, NULL};
    _ipv4socket = CFSocketCreate(kCFAllocatorDefault, AF_INET,  SOCK_STREAM, 0, kCFSocketAcceptCallBack, &EchoServerAcceptCallBack, &socketCtxt);
    _ipv6socket = CFSocketCreate(kCFAllocatorDefault, AF_INET6, SOCK_STREAM, 0, kCFSocketAcceptCallBack, &EchoServerAcceptCallBack, &socketCtxt);
    
    if (NULL == _ipv4socket || NULL == _ipv6socket)
    {
        [self stop];
        return NO;
    }
    
    static const int yes = 1;
    (void) setsockopt(CFSocketGetNative(_ipv4socket), SOL_SOCKET, SO_REUSEADDR, (const void *) &yes, sizeof(yes));
    (void) setsockopt(CFSocketGetNative(_ipv6socket), SOL_SOCKET, SO_REUSEADDR, (const void *) &yes, sizeof(yes));
    
    // Set up the IPv4 listening socket; port is 0, which will cause the kernel to choose a port for us.
    struct sockaddr_in addr4;
    memset(&addr4, 0, sizeof(addr4));
    addr4.sin_len = sizeof(addr4);
    addr4.sin_family = AF_INET;
    addr4.sin_port = htons(_port);
    addr4.sin_addr.s_addr = htonl(INADDR_ANY);
    
    if (kCFSocketSuccess != CFSocketSetAddress(_ipv4socket, (__bridge CFDataRef) [NSData dataWithBytes:&addr4 length:sizeof(addr4)]))
    {
        [self stop];
        return NO;
    }
    
    // Now that the IPv4 binding was successful, we get the port number
    // -- we will need it for the IPv6 listening socket and for the NSNetService.
    NSData *addr = (NSData *)CFSocketCopyAddress(_ipv4socket);
    assert([addr length] == sizeof(struct sockaddr_in));
    UInt32 sin_port = ntohs(((const struct sockaddr_in *)[addr bytes])->sin_port);
    
    // Set up the IPv6 listening socket.
    struct sockaddr_in6 addr6;
    memset(&addr6, 0, sizeof(addr6));
    addr6.sin6_len = sizeof(addr6);
    addr6.sin6_family = AF_INET6;
    addr6.sin6_port = htons(sin_port);
    memcpy(&(addr6.sin6_addr), &in6addr_any, sizeof(addr6.sin6_addr));
    
    if (kCFSocketSuccess != CFSocketSetAddress(_ipv6socket, (CFDataRef)[NSData dataWithBytes: &addr6
                                                                                      length: sizeof(addr6)]))
    {
        [self stop];
        return NO;
    }
    
    // Set up the run loop sources for the sockets.
    CFRunLoopSourceRef source4 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _ipv4socket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source4, kCFRunLoopCommonModes);
    CFRelease(source4);
    
    CFRunLoopSourceRef source6 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _ipv6socket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source6, kCFRunLoopCommonModes);
    CFRelease(source6);
        
    return YES;
}

- (id)initWithHotName: (NSString *)name
                 port: (UInt32)port
{
    if ((self = [super init]))
    {
        _connections = [[NSMutableArray alloc] init];
        
        [self setPort: port];
        [self start];
//        
//        CFReadStreamRef readStream = NULL;
//        CFWriteStreamRef writeStream = NULL;
//
//#if 1
//        CFSocketNativeHandle nativeSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
//        
//        if (nativeSocket == INVALID_SOCKET)
//        {
//            NSLog(@"Socket error!\n");
//            return nil;
//        }
//        
//        int on = 1;
//        
//        int status = setsockopt(nativeSocket, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));
//        if (status != 0)
//        {
//            NSLog(@"can't make server socket reusable.\n");
//        }
//        
//        struct sockaddr_in addr;
//
//        addr.sin_family = AF_INET;
//        addr.sin_addr.s_addr = htonl(INADDR_ANY);
//        addr.sin_port = htons(port);
//        
//        status = bind(nativeSocket, (struct sockaddr *)&addr, sizeof(addr));
//        if (status == SOCKET_ERROR
//            || listen(nativeSocket, 1) == SOCKET_ERROR)
//        {
//            NSLog(@"Socket error!\nIP %@ Port %d\n", name, port);
//            close(nativeSocket);
//            return nil;
//        }
//        
//        CFStreamCreatePairWithSocket(NULL, nativeSocket, &readStream, &writeStream);
//#else
//        CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)(@"localhost"), port, &readStream, &writeStream);
//#endif
//        _inputStream = (NSInputStream *)readStream;
//        _outputStream = (NSOutputStream *)writeStream;
//        
//        [_inputStream setDelegate: self];
//        [_outputStream setDelegate: self];
//        
//        [_inputStream scheduleInRunLoop: [NSRunLoop currentRunLoop]
//                                forMode: NSDefaultRunLoopMode];
//        [_outputStream scheduleInRunLoop: [NSRunLoop currentRunLoop]
//                                 forMode: NSDefaultRunLoopMode];
//        
//        [_inputStream open];
//        [_outputStream open];

    }
    
    return self;
}

- (void)dealloc
{
    
    [super dealloc];
}

- (void)stop
{
    [_connections makeObjectsPerformSelector: @selector(close)];

    if (_ipv4socket != NULL)
    {
        CFSocketInvalidate(_ipv4socket);
        CFRelease(_ipv4socket);
        _ipv4socket = NULL;
    }
    
    if (_ipv6socket != NULL)
    {
        CFSocketInvalidate(_ipv6socket);
        CFRelease(_ipv6socket);
        _ipv6socket = NULL;
    }
}

- (void)acceptConnection:(CFSocketNativeHandle)nativeSocketHandle
{
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &readStream, &writeStream);
    if (readStream && writeStream)
    {
        CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
        CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
        
        EchoConnection * connection = [[EchoConnection alloc] initWithInputStream:(__bridge NSInputStream *)readStream outputStream:(__bridge NSOutputStream *)writeStream];
        [_connections addObject: connection];
        [connection open];
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(echoConnectionDidCloseNotification:)
                                                     name: EchoConnectionDidCloseNotification
                                                   object: connection];

    } else
    {
        // On any failure, we need to destroy the CFSocketNativeHandle
        // since we are not going to use it any more.
        (void) close(nativeSocketHandle);
    }
    
    if (readStream)
    {
        CFRelease(readStream);
    }
    
    if (writeStream)
    {
        CFRelease(writeStream);
    }
}

- (void)echoConnectionDidCloseNotification:(NSNotification *)note
{
    EchoConnection *connection = [note object];
    assert([connection isKindOfClass: [EchoConnection class]]);
    
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: EchoConnectionDidCloseNotification
                                                  object: connection];
    [_connections removeObject: connection];
    
    NSLog(@"Connection closed.");
}

@end
