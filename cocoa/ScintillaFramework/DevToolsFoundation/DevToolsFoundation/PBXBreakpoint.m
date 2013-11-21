//
//  PBXBreakpoint.c
//  VeritasIDE
//
//  Created by tearsofphoenix on 12-10-30.
//
//

#import "PBXBreakpoint.h"
#import "PBXTextBookmark.h"

@implementation PBXBreakpoint

- (void)dealloc
{
    [_comments release];
    [_name release];
    [_textMark release];
    
    [super dealloc];
}

@synthesize lineNumber = _lineNumber;

- (NSComparisonResult)compareToBreakpoint: (id)breakpoint
{
    NSUInteger otherLineNumber = [breakpoint lineNumber];
    
    if (_lineNumber > otherLineNumber)
    {
        return NSOrderedAscending;
        
    }else if(_lineNumber < otherLineNumber)
    {
        return NSOrderedDescending;
    }
    
    return NSOrderedSame;
}

- (int)state
{
    return _state;
}

- (BOOL)isEnabled
{
    return _enabled;
}

- (void)markChanged
{
    
}

- (void)setTextMark: (PBXTextBookmark *)textMark
{
    if (_textMark)
    {
        [_textMark setDelegate: nil];
    }
    
    [_textMark release];
    
    _textMark = [textMark retain];
    
    if (_textMark)
    {
        [_textMark setDelegate: self];
    }
}

@end
