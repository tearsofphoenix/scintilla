//
//  SCIDebugServer.h
//  Scintilla
//
//  Created by Mac003 on 13-11-21.
//
//

#ifndef __Scintilla__SCIDebugServer__
#define __Scintilla__SCIDebugServer__

#import <Foundation/Foundation.h>
@class PBXBreakpoint;

@interface SCIDebugServer : NSObject

//breakpoint management
//
- (PBXBreakpoint *)breakpointAtLineNumber: (NSInteger)lineNumber;
- (void)addBreakpoint: (PBXBreakpoint *)breakpoint;
- (void)removeBreakpoint: (PBXBreakpoint *)breakpoint;

- (void)disableBreakpointAtLine: (NSInteger)lineNumber;
- (void)moveBreakpointFromLine: (NSInteger)sourceLineNumber
                        toLine: (NSInteger)targetLineNumber;

- (void)removeAllBreakpoints;

@end

#endif /* defined(__Scintilla__SCIDebugServer__) */
