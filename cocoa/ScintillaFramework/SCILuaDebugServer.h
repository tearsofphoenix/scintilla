//
//  SCILuaDebugServer.h
//  Scintilla
//
//  Created by Mac003 on 13-11-22.
//
//

#import <Foundation/Foundation.h>

@interface SCILuaDebugServer : NSObject

+ (id)sharedServer;

- (void)startDebugSource: (NSString *)sourceCode;

@end
