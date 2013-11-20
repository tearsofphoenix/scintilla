//
//  SCIContentView.m
//  ScintillaFramework
//
//  Created by Lei on 11/19/13.
//
//

#import "SCIContentView.h"

#import "Scintilla.h"
#import "SciLexer.h"

#import "InfoBarCommunicator.h"
#import "Platform.h"
#import "ScintillaView.h"
#import "ScintillaCocoa.h"
#import "ScintillaPrivate.h"

using namespace Scintilla;

@interface SCIContentView ()
{
@private
    NSCursor* mCurrentCursor;
    NSTrackingRectTag mCurrentTrackingRect;
    
    // Set when we are in composition mode and partial input is displayed.
    NSRange mMarkedTextRange;
    BOOL undoCollectionWasActive;
}
@end

@implementation SCIContentView

- (id)initWithFrame: (NSRect) frame
{
    self = [super initWithFrame: frame];
    
    if (self != nil)
    {
        // Some initialization for our view.
        mCurrentCursor = [[NSCursor arrowCursor] retain];
        mCurrentTrackingRect = 0;
        mMarkedTextRange = NSMakeRange(NSNotFound, 0);
        
        [self registerForDraggedTypes: (@[NSStringPboardType,
                                          ScintillaRecPboardType,
                                          NSFilenamesPboardType
                                          ])];
    }
    
    return self;
}



/**
 * When the view is resized we need to update our tracking rectangle and let the backend know.
 */
- (void) setFrame: (NSRect) frame
{
    [super setFrame: frame];
    
    // Make the content also a tracking rectangle for mouse events.
    if (mCurrentTrackingRect != 0)
    {
        [self removeTrackingRect: mCurrentTrackingRect];
    }
    
	mCurrentTrackingRect = [self addTrackingRect: [self bounds]
                                           owner: self
                                        userData: nil
                                    assumeInside: YES];
    _owner.backend->Resize();
}



/**
 * Called by the backend if a new cursor must be set for the view.
 */
- (void) setCursor: (int) cursor
{
    Window::Cursor eCursor = (Window::Cursor)cursor;
    [mCurrentCursor autorelease];
    mCurrentCursor = NSCursorFromEnum(eCursor);
    [mCurrentCursor retain];
    
    // Trigger recreation of the cursor rectangle(s).
    [[self window] invalidateCursorRectsForView: self];
}



/**
 * This method is called to give us the opportunity to define our mouse sensitive rectangle.
 */
- (void) resetCursorRects
{
    [super resetCursorRects];
    
    // We only have one cursor rect: our bounds.
    [self addCursorRect: [self bounds] cursor: mCurrentCursor];
    [mCurrentCursor setOnMouseEntered: YES];
}



/**
 * Gets called by the runtime when the view needs repainting.
 */
- (void) drawRect: (NSRect) rect
{
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
    
    if (!_owner.backend->Draw(rect, context))
    {
        dispatch_async(dispatch_get_main_queue(),
                       (^
                        {
                            [self setNeedsDisplay:YES];
                        }));
    }
}



/**
 * Windows uses a client coordinate system where the upper left corner is the origin in a window
 * (and so does Scintilla). We have to adjust for that. However by returning YES here, we are
 * already done with that.
 * Note that because of returning YES here most coordinates we use now (e.g. for painting,
 * invalidating rectangles etc.) are given with +Y pointing down!
 */
- (BOOL) isFlipped
{
    return YES;
}



- (BOOL) isOpaque
{
    return YES;
}



/**
 * Implement the "click through" behavior by telling the caller we accept the first mouse event too.
 */
- (BOOL) acceptsFirstMouse: (NSEvent *) theEvent
{
#pragma unused(theEvent)
    return YES;
}



/**
 * Make this view accepting events as first responder.
 */
- (BOOL) acceptsFirstResponder
{
    return YES;
}



/**
 * Called by the framework if it wants to show a context menu for the editor.
 */
- (NSMenu*) menuForEvent: (NSEvent*) theEvent
{
    if (![_owner respondsToSelector: @selector(menuForEvent:)])
        return _owner.backend->CreateContextMenu(theEvent);
    else
        return [_owner menuForEvent: theEvent];
}



// Adoption of NSTextInputClient protocol.

- (NSAttributedString *)attributedSubstringForProposedRange: (NSRange)aRange
                                                actualRange: (NSRangePointer)actualRange
{
    return nil;
}



- (NSUInteger) characterIndexForPoint: (NSPoint) point
{
    return NSNotFound;
}



- (void) doCommandBySelector: (SEL) selector
{
    if ([self respondsToSelector: @selector(selector)])
        [self performSelector: selector withObject: nil];
}



- (NSRect) firstRectForCharacterRange: (NSRange) aRange actualRange: (NSRangePointer) actualRange
{
    NSRect rect;
    rect.origin.x = [ScintillaView directCall: _owner
                                      message: SCI_POINTXFROMPOSITION
                                       wParam: 0
                                       lParam: aRange.location];
    rect.origin.y = [ScintillaView directCall: _owner
                                      message: SCI_POINTYFROMPOSITION
                                       wParam: 0
                                       lParam: aRange.location];
    int rangeEnd = aRange.location + aRange.length;
    rect.size.width = [ScintillaView directCall: _owner
                                        message: SCI_POINTXFROMPOSITION
                                         wParam: 0
                                         lParam: rangeEnd] - rect.origin.x;
    rect.size.height = [ScintillaView directCall: _owner
                                         message: SCI_POINTYFROMPOSITION
                                          wParam: 0
                                          lParam: rangeEnd] - rect.origin.y;
    rect.size.height += [ScintillaView directCall: _owner
                                          message: SCI_TEXTHEIGHT
                                           wParam: 0
                                           lParam: 0];
    rect = [[[self superview] superview] convertRect:rect toView:nil];
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_6
    if ([self.window respondsToSelector:@selector(convertRectToScreen:)])
        rect = [self.window convertRectToScreen:rect];
    else // convertRectToScreen not available on 10.6
        rect.origin = [self.window convertBaseToScreen:rect.origin];
#else
    rect.origin = [self.window convertBaseToScreen:rect.origin];
#endif
    
    return rect;
}



- (BOOL) hasMarkedText
{
    return mMarkedTextRange.length > 0;
}



/**
 * General text input. Used to insert new text at the current input position, replacing the current
 * selection if there is any.
 * First removes the replacementRange.
 */
- (void) insertText: (id) aString replacementRange: (NSRange) replacementRange
{
	// Remove any previously marked text first.
	[self removeMarkedText];
    
	if (replacementRange.location == (NSNotFound-1))
		// This occurs when the accent popup is visible and menu selected.
		// Its replacing a non-existent position so do nothing.
		return;
    
	if (replacementRange.length > 0)
	{
		[ScintillaView directCall: _owner
                          message: SCI_DELETERANGE
                           wParam: replacementRange.location
                           lParam: replacementRange.length];
	}
    
	NSString* newText = @"";
	if ([aString isKindOfClass:[NSString class]])
		newText = (NSString*) aString;
	else if ([aString isKindOfClass:[NSAttributedString class]])
		newText = (NSString*) [aString string];
	
	_owner.backend->InsertText(newText);
}



- (NSRange) markedRange
{
    return mMarkedTextRange;
}



- (NSRange) selectedRange
{
    long begin = [_owner getGeneralProperty: SCI_GETSELECTIONSTART parameter: 0];
    long end = [_owner getGeneralProperty: SCI_GETSELECTIONEND parameter: 0];
    return NSMakeRange(begin, end - begin);
}



/**
 * Called by the input manager to set text which might be combined with further input to form
 * the final text (e.g. composition of ^ and a to â).
 *
 * @param aString The text to insert, either what has been marked already or what is selected already
 *                or simply added at the current insertion point. Depending on what is available.
 * @param range The range of the new text to select (given relative to the insertion point of the new text).
 * @param replacementRange The range to remove before insertion.
 */
- (void) setMarkedText: (id) aString selectedRange: (NSRange)range replacementRange: (NSRange)replacementRange
{
    NSString* newText = @"";
    if ([aString isKindOfClass:[NSString class]])
        newText = (NSString*) aString;
    else
        if ([aString isKindOfClass:[NSAttributedString class]])
            newText = (NSString*) [aString string];
    
    long currentPosition = [_owner getGeneralProperty: SCI_GETCURRENTPOS parameter: 0];
    
    // Replace marked text if there is one.
    if (mMarkedTextRange.length > 0)
    {
        [_owner setGeneralProperty: SCI_SETSELECTIONSTART
                             value: mMarkedTextRange.location];
        [_owner setGeneralProperty: SCI_SETSELECTIONEND
                             value: mMarkedTextRange.location + mMarkedTextRange.length];
        currentPosition = mMarkedTextRange.location;
    }
    else
    {
        // Switching into composition so remember if collecting undo.
        undoCollectionWasActive = [_owner getGeneralProperty: SCI_GETUNDOCOLLECTION] != 0;
        
        // Keep Scintilla from collecting undo actions for the composition task.
        [_owner setGeneralProperty: SCI_SETUNDOCOLLECTION value: 0];
        
        // Ensure only a single selection
        _owner.backend->SelectOnlyMainSelection();
    }
    
    if (replacementRange.length > 0)
    {
        [ScintillaView directCall: _owner
                          message: SCI_DELETERANGE
                           wParam: replacementRange.location
                           lParam: replacementRange.length];
    }
    
    // Note: Scintilla internally works almost always with bytes instead chars, so we need to take
    //       this into account when determining selection ranges and such.
    std::string raw_text = [newText UTF8String];
    int lengthInserted = _owner.backend->InsertText(newText);
    
    mMarkedTextRange.location = currentPosition;
    mMarkedTextRange.length = lengthInserted;
    
    if (lengthInserted > 0)
    {
        // Mark the just inserted text. Keep the marked range for later reset.
        [_owner setGeneralProperty: SCI_SETINDICATORCURRENT value: INPUT_INDICATOR];
        [_owner setGeneralProperty: SCI_INDICATORFILLRANGE
                         parameter: mMarkedTextRange.location
                             value: mMarkedTextRange.length];
    }
    else
    {
        // Re-enable undo action collection if composition ended (indicated by an empty mark string).
        if (undoCollectionWasActive)
            [_owner setGeneralProperty: SCI_SETUNDOCOLLECTION value: range.length == 0];
    }
    
    // Select the part which is indicated in the given range. It does not scroll the caret into view.
    if (range.length > 0)
    {
        // range is in characters so convert to bytes for selection.
        int rangeStart = currentPosition;
        for (size_t characterInComposition=0; characterInComposition<range.location; characterInComposition++)
            rangeStart = [_owner getGeneralProperty: SCI_POSITIONAFTER parameter: rangeStart];
        int rangeEnd = rangeStart;
        for (size_t characterInRange=0; characterInRange<range.length; characterInRange++)
            rangeEnd = [_owner getGeneralProperty: SCI_POSITIONAFTER parameter: rangeEnd];
        [_owner setGeneralProperty: SCI_SETSELECTION parameter: rangeEnd value: rangeStart];
    }
}



- (void) unmarkText
{
    if (mMarkedTextRange.length > 0)
    {
        [_owner setGeneralProperty: SCI_SETINDICATORCURRENT value: INPUT_INDICATOR];
        [_owner setGeneralProperty: SCI_INDICATORCLEARRANGE
                         parameter: mMarkedTextRange.location
                             value: mMarkedTextRange.length];
        mMarkedTextRange = NSMakeRange(NSNotFound, 0);
        
        // Reenable undo action collection, after we are done with text composition.
        if (undoCollectionWasActive)
            [_owner setGeneralProperty: SCI_SETUNDOCOLLECTION value: 1];
    }
}



/**
 * Removes any currently marked text.
 */
- (void) removeMarkedText
{
    if (mMarkedTextRange.length > 0)
    {
        // We have already marked text. Replace that.
        [_owner setGeneralProperty: SCI_SETSELECTIONSTART
                             value: mMarkedTextRange.location];
        [_owner setGeneralProperty: SCI_SETSELECTIONEND
                             value: mMarkedTextRange.location + mMarkedTextRange.length];
        _owner.backend->InsertText(@"");
        mMarkedTextRange = NSMakeRange(NSNotFound, 0);
        
        // Reenable undo action collection, after we are done with text composition.
        if (undoCollectionWasActive)
            [_owner setGeneralProperty: SCI_SETUNDOCOLLECTION value: 1];
    }
}



- (NSArray*) validAttributesForMarkedText
{
    return nil;
}

// End of the NSTextInputClient protocol adoption.



/**
 * Generic input method. It is used to pass on keyboard input to Scintilla. The control itself only
 * handles shortcuts. The input is then forwarded to the Cocoa text input system, which in turn does
 * its own input handling (character composition via NSTextInputClient protocol):
 */
- (void) keyDown: (NSEvent *) theEvent
{
    if (mMarkedTextRange.length == 0)
    {
        _owner.backend->KeyboardInput(theEvent);
    }
    
    [self interpretKeyEvents: @[theEvent]];
}



- (void) mouseDown: (NSEvent *) theEvent
{
    _owner.backend->MouseDown(theEvent);
}



- (void) mouseDragged: (NSEvent *) theEvent
{
    _owner.backend->MouseMove(theEvent);
}



- (void) mouseUp: (NSEvent *) theEvent
{
    _owner.backend->MouseUp(theEvent);
}



- (void) mouseMoved: (NSEvent *) theEvent
{
    _owner.backend->MouseMove(theEvent);
}



- (void) mouseEntered: (NSEvent *) theEvent
{
    _owner.backend->MouseEntered(theEvent);
}



- (void) mouseExited: (NSEvent *) theEvent
{
    _owner.backend->MouseExited(theEvent);
}



/**
 * Mouse wheel with command key magnifies text.
 */
- (void) scrollWheel: (NSEvent *) theEvent
{
    if (([theEvent modifierFlags] & NSCommandKeyMask) != 0)
    {
        _owner.backend->MouseWheel(theEvent);
    } else
    {
        [super scrollWheel: theEvent];
    }
}



/**
 * Ensure scrolling is aligned to whole lines instead of starting part-way through a line
 */
- (NSRect)adjustScroll:(NSRect)proposedVisibleRect
{
    NSRect rc = proposedVisibleRect;
    // Snap to lines
    NSRect contentRect = [self bounds];
    if ((rc.origin.y > 0) && (NSMaxY(rc) < contentRect.size.height)) {
        // Only snap for positions inside the document - allow outside
        // for overshoot.
        int lineHeight = _owner.backend->WndProc(SCI_TEXTHEIGHT, 0, 0);
        rc.origin.y = roundf(rc.origin.y / lineHeight) * lineHeight;
    }
    return rc;
}



/**
 * The editor is getting the foreground control (the one getting the input focus).
 */
- (BOOL) becomeFirstResponder
{
    _owner.backend->WndProc(SCI_SETFOCUS, 1, 0);
    return YES;
}



/**
 * The editor is losing the input focus.
 */
- (BOOL) resignFirstResponder
{
    _owner.backend->WndProc(SCI_SETFOCUS, 0, 0);
    return YES;
}



/**
 * Called when an external drag operation enters the view.
 */
- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>) sender
{
    return _owner.backend->DraggingEntered(sender);
}



/**
 * Called frequently during an external drag operation if we are the target.
 */
- (NSDragOperation) draggingUpdated: (id <NSDraggingInfo>) sender
{
    return _owner.backend->DraggingUpdated(sender);
}



/**
 * Drag image left the view. Clean up if necessary.
 */
- (void) draggingExited: (id <NSDraggingInfo>) sender
{
    _owner.backend->DraggingExited(sender);
}



- (BOOL) prepareForDragOperation: (id <NSDraggingInfo>) sender
{
#pragma unused(sender)
    return YES;
}



- (BOOL) performDragOperation: (id <NSDraggingInfo>) sender
{
    return _owner.backend->PerformDragOperation(sender);
}



/**
 * Returns operations we allow as drag source.
 */
- (NSDragOperation) draggingSourceOperationMaskForLocal: (BOOL) flag
{
    return NSDragOperationCopy | NSDragOperationMove | NSDragOperationDelete;
}



/**
 * Finished a drag: may need to delete selection.
 */

- (void)draggedImage:(NSImage *)image endedAt:(NSPoint)screenPoint operation:(NSDragOperation)operation {
    if (operation == NSDragOperationDelete) {
        _owner.backend->WndProc(SCI_CLEAR, 0, 0);
    }
}



/**
 * Drag operation is done. Notify editor.
 */
- (void) concludeDragOperation: (id <NSDraggingInfo>) sender
{
    // Clean up is the same as if we are no longer the drag target.
    _owner.backend->DraggingExited(sender);
}



// NSResponder actions.

- (void) selectAll: (id) sender
{
#pragma unused(sender)
    _owner.backend->SelectAll();
}

- (void) deleteBackward: (id) sender
{
#pragma unused(sender)
    _owner.backend->DeleteBackward();
}

- (void) cut: (id) sender
{
#pragma unused(sender)
    _owner.backend->Cut();
}

- (void) copy: (id) sender
{
#pragma unused(sender)
    _owner.backend->Copy();
}

- (void) paste: (id) sender
{
#pragma unused(sender)
    _owner.backend->Paste();
}

- (void) undo: (id) sender
{
#pragma unused(sender)
    _owner.backend->Undo();
}

- (void) redo: (id) sender
{
#pragma unused(sender)
    _owner.backend->Redo();
}

- (BOOL) canUndo
{
    return _owner.backend->CanUndo();
}

- (BOOL) canRedo
{
    return _owner.backend->CanRedo();
}

- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>) anItem
{
    SEL action = [anItem action];
    
    if (action==@selector(undo:))
    {
        return [self canUndo];
        
    }else if (action==@selector(redo:))
    {
        return [self canRedo];
        
    }else if (action==@selector(cut:)
              || action==@selector(copy:)
              || action==@selector(clear:))
    {
        return _owner.backend->HasSelection();
        
    }else if (action==@selector(paste:))
    {
        return _owner.backend->CanPaste();
    }
    
    return YES;
}

- (void) clear: (id) sender
{
    [self deleteBackward:sender];
}

- (BOOL) isEditable
{
    return _owner.backend->WndProc(SCI_GETREADONLY, 0, 0) == 0;
}



- (void) dealloc
{
    [mCurrentCursor release];
    [super dealloc];
}

@end
