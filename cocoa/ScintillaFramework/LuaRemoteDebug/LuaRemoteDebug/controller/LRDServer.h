//
//  LRDServer.h
//  LuaRemoteDebug
//
//  Created by Mac003 on 13-11-25.
//  Copyright (c) 2013年 Mac003. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LRDServer : NSObject

- (id)initWithHotName: (NSString *)name
                 port: (UInt32)port;

@end
