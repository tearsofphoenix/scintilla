//
//  SCIMarginView.m
//  ScintillaFramework
//
//  Created by Lei on 11/19/13.
//
//

#import "SCIMarginView.h"
#import "ScintillaPrivate.h"
#import "ScintillaView.h"
#import "SCIController.h"

#import <DevToolsFoundation/DevToolsFoundation.h>

@interface SCIMarginView ()
{
@private
    NSMutableArray *_currentCursors;
}
@end

@implementation SCIMarginView

- (id)initWithScrollView:(NSScrollView *)aScrollView
{
    self = [super initWithScrollView: aScrollView
                         orientation: NSVerticalRuler];
    if (self != nil)
    {
        _owner = nil;
        _marginWidth = 20;
        _currentCursors = [[NSMutableArray alloc] init];
        
        for (size_t i=0; i<5; i++)
        {
            [_currentCursors addObject: NSCursorFromEnum(Scintilla::Window::Cursor::cursorReverseArrow)];
        }
        
        [self setClientView: [aScrollView documentView]];
    }
    return self;
}

- (void) dealloc
{
    [_currentCursors release];
    [super dealloc];
}

- (void) setFrame: (NSRect) frame
{
    [super setFrame: frame];
    
    [[self window] invalidateCursorRectsForView: self];
}

- (CGFloat)requiredThickness
{
    return _marginWidth;
}

- (void)drawHashMarksAndLabelsInRect:(NSRect)aRect
{
    if (_owner)
    {
        NSRect contentRect = [[[self scrollView] contentView] bounds];
        NSRect marginRect = [self bounds];
        // Ensure paint to bottom of view to avoid glitches
        if (marginRect.size.height > contentRect.size.height)
        {
            // Legacy scroll bar mode leaves a poorly painted corner
            aRect = marginRect;
        }
        
        _owner.backend->PaintMargin(aRect);
    }
}

- (void) mouseDown: (NSEvent *) theEvent
{
    _owner.backend->MouseDown(theEvent);
    
    dispatch_async(dispatch_get_main_queue(),
                   (^
                    {
                        [self setNeedsDisplay: YES];
                    }));
}

- (void) mouseDragged: (NSEvent *) theEvent
{
    _owner.backend->MouseMove(theEvent);
}

- (void) mouseMoved: (NSEvent *) theEvent
{
    _owner.backend->MouseMove(theEvent);
}

- (void) mouseUp: (NSEvent *) theEvent
{
    _owner.backend->MouseUp(theEvent);
}

/**
 * This method is called to give us the opportunity to define our mouse sensitive rectangle.
 */
- (void) resetCursorRects
{
    [super resetCursorRects];
    
    int x = 0;
    NSRect marginRect = [self bounds];
    NSInteger co = [_currentCursors count];
    
    for (NSInteger i=0; i<co; i++)
    {
        int cursType = _owner.backend->WndProc(SCI_GETMARGINCURSORN, i, 0);
        int width =_owner.backend->WndProc(SCI_GETMARGINWIDTHN, i, 0);
        
        NSCursor *cc = NSCursorFromEnum(static_cast<Scintilla::Window::Cursor>(cursType));
        
        [_currentCursors replaceObjectAtIndex: i
                                   withObject: cc];
        marginRect.origin.x = x;
        marginRect.size.width = width;
        
        [self addCursorRect: marginRect
                     cursor: cc];
        
        [cc setOnMouseEntered: YES];
        
        x += width;
    }
}

- (void)addBreakpoint: (PBXBreakpoint *)breakpoint
         atLineNumber: (int)lineNumber
{    
    PBXTextBookmark *marker = [[PBXTextBookmark alloc] initWithRulerView: self
                                                          markerLocation: lineNumber];
    [marker setRemovable: YES];
    [marker setMovable: YES];
    
    [marker setDelegate: breakpoint];
    [breakpoint setTextMark: marker];
    
    [self addMarker: marker];
    
    [marker release];
    
    printf("%d\n", lineNumber);
}

@end

