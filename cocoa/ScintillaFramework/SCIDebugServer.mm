//
//  SCIDebugServer.cpp
//  Scintilla
//
//  Created by Mac003 on 13-11-21.
//
//

#import "SCIDebugServer.h"
#import <DevToolsFoundation/DevToolsFoundation.h>

@interface SCIDebugServer ()
{
    NSMutableDictionary *_breakpoints;
}
@end

@implementation SCIDebugServer

- (id)init
{
    if ((self = [super init]))
    {
        _breakpoints = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (PBXBreakpoint *)breakpointAtLineNumber: (NSInteger)lineNumber
{
    return _breakpoints[@(lineNumber)];
}

- (void)addBreakpoint: (PBXBreakpoint *)breakpoint
{
    [_breakpoints setObject: breakpoint
                     forKey: @([breakpoint lineNumber])];
}

- (void)removeBreakpoint: (PBXBreakpoint *)breakpoint
{
    [_breakpoints removeObjectForKey: @([breakpoint lineNumber])];
}

- (void)disableBreakpointAtLine: (NSInteger)lineNumber
{
    PBXBreakpoint *breakpoint = _breakpoints[@(lineNumber)];
    [breakpoint setEnabled: NO];
}

- (void)moveBreakpointFromLine: (NSInteger)sourceLineNumber
                        toLine: (NSInteger)targetLineNumber
{
    NSNumber *target = @(targetLineNumber);
    
    [_breakpoints removeObjectForKey: target];
    
    PBXBreakpoint *sourceBreakpoint = _breakpoints[@(sourceLineNumber)];
    
    if (sourceBreakpoint)
    {
        [sourceBreakpoint setLineNumber: targetLineNumber];
        
        [_breakpoints setObject: sourceBreakpoint
                         forKey: target];
    }
}

- (void)removeAllBreakpoints
{
    [_breakpoints removeAllObjects];
}

@end