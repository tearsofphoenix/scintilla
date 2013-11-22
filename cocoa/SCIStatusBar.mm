
/**
 * Scintilla source code edit control
 * SCIStatusBar.mm - Implements special info bar with zoom info, caret position etc. to be used with
 *              ScintillaView.
 *
 * Mike Lischke <mlischke@sun.com>
 *
 * Copyright 2009 Sun Microsystems, Inc. All rights reserved.
 * This file is dual licensed under LGPL v2.1 and the Scintilla license (http://www.scintilla.org/License.txt).
 */

#import "SCIStatusBar.h"


/**
 * Extended text cell for vertically aligned text.
 */
@interface VerticallyCenteredTextFieldCell : NSTextFieldCell
{
	BOOL _isEditingOrSelecting;
}

@end



@implementation VerticallyCenteredTextFieldCell

// Inspired by code from Daniel Jalkut, Red Sweater Software.

- (NSRect) drawingRectForBounds: (NSRect) theRect
{
	// Get the parent's idea of where we should draw
	NSRect newRect = [super drawingRectForBounds: theRect];
    
	// When the text field is being edited or selected, we have to turn off the magic because it
    // screws up the configuration of the field editor. We sneak around this by intercepting
    // selectWithFrame and editWithFrame and sneaking a reduced, centered rect in at the last minute.
	if (_isEditingOrSelecting == NO)
	{
		// Get our ideal size for current text
		NSSize textSize = [self cellSizeForBounds: theRect];
        
		// Center that in the proposed rect
		float heightDelta = newRect.size.height - textSize.height;
		if (heightDelta > 0)
		{
			newRect.size.height -= heightDelta;
			newRect.origin.y += ceil(heightDelta / 2);
		}
	}
	
	return newRect;
}



- (void) selectWithFrame: (NSRect) aRect inView: (NSView*) controlView editor: (NSText*) textObj
                delegate:(id) anObject start: (NSInteger) selStart length: (NSInteger) selLength
{
	aRect = [self drawingRectForBounds: aRect];
	_isEditingOrSelecting = YES;
	[super selectWithFrame: aRect
                    inView: controlView
                    editor: textObj
                  delegate: anObject
                     start: selStart
                    length: selLength];
	_isEditingOrSelecting = NO;
}



- (void) editWithFrame: (NSRect) aRect inView: (NSView*) controlView editor: (NSText*) textObj
              delegate: (id) anObject event: (NSEvent*) theEvent
{
	aRect = [self drawingRectForBounds: aRect];
	_isEditingOrSelecting = YES;
	[super editWithFrame: aRect
                  inView: controlView
                  editor: textObj
                delegate: anObject
                   event: theEvent];
	_isEditingOrSelecting = NO;
}

@end



@implementation SCIStatusBar

@synthesize callback = _callback;

- (id) initWithFrame: (NSRect) frame
{
    NSGradient *startGradient = [[NSGradient alloc] initWithColorsAndLocations: [NSColor colorWithCalibratedWhite: 1.000
                                                                                                            alpha: 0.68],
                                                                                0.0,
                                                                                [NSColor colorWithCalibratedWhite: 1.000
                                                                                                            alpha: 0.5],
                                                                                0.0416,
                                                                                [NSColor colorWithCalibratedWhite: 1.000
                                                                                                            alpha: 0.0],
                                                                                1.0, nil];
    
    NSGradient *endGradient = [[NSGradient alloc] initWithColorsAndLocations: [NSColor colorWithCalibratedWhite: 1.000
                                                                                                          alpha: 0.68],
                               0.0,
                               [NSColor colorWithCalibratedWhite: 1.000
                                                           alpha: 0.5],
                               0.0416,
                               [NSColor colorWithCalibratedWhite: 1.000
                                                           alpha: 0.0],
                               1.0, nil];

	if(self = [super initWithGradient: startGradient
                     inactiveGradient: endGradient])
    {
        mScaleFactor = 1.0;
        mCurrentCaretX = 0;
        mCurrentCaretY = 0;
        
        [self createItems];
    }
    return self;
}



/**
 * Called by a connected component (usually the info bar) if something changed there.
 *
 * @param type The type of the notification.
 * @param message Carries the new status message if the type is a status message change.
 * @param location Carries the new location (e.g. caret) if the type is a caret change or similar type.
 * @param location Carries the new zoom value if the type is a zoom change.
 */
- (void) notify: (NotificationType) type message: (NSString*) message location: (NSPoint) location
          value: (float) value
{
    switch (type)
    {
        case IBNZoomChanged:
            [self setScaleFactor: value adjustPopup: YES];
            break;
        case IBNCaretChanged:
            [self setCaretPosition: location];
            break;
        case IBNStatusChanged:
            [mStatusTextLabel setStringValue: message];
            break;
    }
}



static float BarFontSize = 10.0;

- (void) createItems
{
    // 2) The caret position label.
    Class oldCellClass = [NSTextField cellClass];
    [NSTextField setCellClass: [VerticallyCenteredTextFieldCell class]];
    
    mCaretPositionLabel = [[NSTextField alloc] initWithFrame: NSMakeRect(0.0, 0.0, 50.0, 1.0)];
    [mCaretPositionLabel setBezeled: NO];
    [mCaretPositionLabel setBordered: NO];
    [mCaretPositionLabel setEditable: NO];
    [mCaretPositionLabel setSelectable: NO];
    [mCaretPositionLabel setDrawsBackground: NO];
    [mCaretPositionLabel setFont: [NSFont menuBarFontOfSize: BarFontSize]];
    
    NSTextFieldCell* cell = [mCaretPositionLabel cell];
    [cell setPlaceholderString: @"0:0"];
    [cell setAlignment: NSCenterTextAlignment];
    
    [self addSubview: mCaretPositionLabel];
    
    // 3) The status text.
    mStatusTextLabel = [[NSTextField alloc] initWithFrame: NSMakeRect(0.0, 0.0, 1.0, 1.0)];
    [mStatusTextLabel setBezeled: NO];
    [mStatusTextLabel setBordered: NO];
    [mStatusTextLabel setEditable: NO];
    [mStatusTextLabel setSelectable: NO];
    [mStatusTextLabel setDrawsBackground: NO];
    [mStatusTextLabel setFont: [NSFont menuBarFontOfSize: BarFontSize]];
    
    cell = [mStatusTextLabel cell];
    [cell setPlaceholderString: @""];
    
    [self addSubview: mStatusTextLabel];
    
    // Restore original cell class so that everything else doesn't get broken
    [NSTextField setCellClass: oldCellClass];
}



- (void) dealloc
{
    [mCaretPositionLabel release];
    [mStatusTextLabel release];

    [super dealloc];
}


/**
 * Used to reposition our content depending on the size of the view.
 */
- (void) setFrame: (NSRect) newFrame
{
    [super setFrame: newFrame];
    [self positionSubViews];
}



- (void) positionSubViews
{
    NSRect currentBounds = {0, 0, 0, [self frame].size.height};
    
    if (mDisplayMask & IBShowCaretPosition)
    {
        [mCaretPositionLabel setHidden: NO];
        currentBounds.size.width = [mCaretPositionLabel frame].size.width;
        [mCaretPositionLabel setFrame: currentBounds];
        currentBounds.origin.x += currentBounds.size.width + 1;
    }
    else
        [mCaretPositionLabel setHidden: YES];
    
    if (mDisplayMask & IBShowStatusText)
    {
        // The status text always takes the rest of the available space.
        [mStatusTextLabel setHidden: NO];
        currentBounds.size.width = [self frame].size.width - currentBounds.origin.x;
        [mStatusTextLabel setFrame: currentBounds];
    }
    else
        [mStatusTextLabel setHidden: YES];
}



/**
 * Used to switch the visible parts of the info bar.
 *
 * @param display Bitwise ORed IBDisplay values which determine what to show on the bar.
 */
- (void) setDisplay: (IBDisplay) display
{
    if (mDisplayMask != display)
    {
        mDisplayMask = display;
        [self positionSubViews];
        [self needsDisplay];
    }
}



/**
 * Handler for selection changes in the zoom menu.
 */
- (void) zoomItemAction: (id) sender
{
    NSNumber* selectedFactorObject = [[sender selectedCell] representedObject];
    
    if (selectedFactorObject == nil)
    {
        NSLog(@"Scale popup action: setting arbitrary zoom factors is not yet supported.");
        return;
        
    }else
    {
        [self setScaleFactor: [selectedFactorObject floatValue] adjustPopup: NO];
    }
}



- (void) setScaleFactor: (float) newScaleFactor adjustPopup: (BOOL) flag
{
    if (mScaleFactor != newScaleFactor)
    {
        mScaleFactor = newScaleFactor;
        
        // Internally set. Notify owner.
        [_callback notify: IBNZoomChanged
                  message: nil
                 location: NSZeroPoint
                    value: newScaleFactor];
    }
}



/**
 * Called from the notification method to update the caret position display.
 */
- (void) setCaretPosition: (NSPoint) position
{
    // Make the position one-based.
    int newX = (int) position.x + 1;
    int newY = (int) position.y + 1;
    
    if (mCurrentCaretX != newX || mCurrentCaretY != newY)
    {
        mCurrentCaretX = newX;
        mCurrentCaretY = newY;
        
        [mCaretPositionLabel setStringValue: [NSString stringWithFormat: @"%d:%d", newX, newY]];
    }
}



/**
 * Makes the bar resize to the smallest width that can accommodate the currently enabled items.
 */
- (void) sizeToFit
{
    NSRect frame = [self frame];
    frame.size.width = 0;
    
    if (mDisplayMask & IBShowCaretPosition)
        frame.size.width += [mCaretPositionLabel frame].size.width;
    
    if (mDisplayMask & IBShowStatusText)
        frame.size.width += [mStatusTextLabel frame].size.width;
    
    [self setFrame: frame];
}

@end
