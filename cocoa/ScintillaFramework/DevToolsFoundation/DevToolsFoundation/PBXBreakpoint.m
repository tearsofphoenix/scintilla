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

- (id)init
{
    if ((self = [super init]))
    {
        _enabled = YES;
    }
    
    return self;
}

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

@synthesize enabled = _enabled;

- (void)setEnabled: (BOOL)enabled
{
    if (_enabled != enabled)
    {
        _enabled = enabled;
        [_textMark setNeedsDisplay];
    }
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
