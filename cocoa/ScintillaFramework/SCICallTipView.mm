//
//  SCICallTipView.m
//  Scintilla
//
//  Created by Mac003 on 13-11-20.
//
//

#import "SCICallTipView.h"
#import "Platform.h"
#import "Scintilla.h"
#import "SCIController.h"

using namespace Scintilla;

@implementation SCICallTipView

- (NSView*) initWithFrame: (NSRect) frame
{
	self = [super initWithFrame: frame];
    
	if (self)
    {
        _scintillaController = NULL;
	}
	
	return self;
}

- (BOOL) isFlipped
{
	return YES;
}

- (void) drawRect: (NSRect) needsDisplayInRect
{
    SCIController *controller = (SCIController *)_scintillaController;
    
    if (controller)
    {
        CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
        controller->CTPaint(context, needsDisplayInRect);
    }
}

- (void) mouseDown: (NSEvent *) event
{
    SCIController *controller = (SCIController *)_scintillaController;

    if (controller)
    {
        controller->CallTipMouseDown([event locationInWindow]);
    }
}

// On OS X, only the key view should modify the cursor so the calltip can't.
// This view does not become key so resetCursorRects never called.
- (void) resetCursorRects
{
    //[super resetCursorRects];
    //[self addCursorRect: [self bounds] cursor: [NSCursor arrowCursor]];
}

@end
