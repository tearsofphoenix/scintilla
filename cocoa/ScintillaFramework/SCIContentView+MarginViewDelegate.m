//
//  SCIContentView+MarginViewDelegate.m
//  Scintilla
//
//  Created by Mac003 on 13-11-21.
//
//

#import "SCIContentView+MarginViewDelegate.h"
#import "SCIContentView.h"

@implementation SCIContentView (MarginViewDelegate)

- (BOOL)rulerView: (NSRulerView *)ruler
 shouldMoveMarker: (NSRulerMarker *)marker
{
    return YES;
}
// This is sent when a drag operation is just beginning for a ruler marker already on the ruler.  If the ruler object should be allowed to either move or remove, return YES.  If you return NO, all tracking is abandoned and nothing happens.

- (CGFloat)rulerView: (NSRulerView *)ruler
      willMoveMarker: (NSRulerMarker *)marker
          toLocation: (CGFloat)location
{
    return location;
}

// This is sent continuously while the mouse is being dragged.  The client can constrian the movement by returning a different location.  Receipt of one or more of these messages does not guarantee that the corresponding "did" method will be called.  Only movable objects will send this message.

- (void)rulerView: (NSRulerView *)ruler
    didMoveMarker: (NSRulerMarker *)marker
{
    
}

// This is called if the NSRulerMarker actually ended up with a different location than it started with after the drag completes.  It is not called if the object gets removed, or if the object gets dragged around and dropped right where it was.  Only movable objects will send this message.

- (BOOL)rulerView: (NSRulerView *)ruler
shouldRemoveMarker: (NSRulerMarker *)marker
{
    return YES;
}
// This is sent each time the object is dragged off the baseline enough that if it were dropped, it would be removed.  It can be sent multiple times in the course of a drag.  Return YES if it's OK to remove the object, NO if not.  Receipt of this message does not guarantee that the corresponding "did" method will be called.  Only removable objects will send this message.

- (void)rulerView: (NSRulerView *)ruler
  didRemoveMarker: (NSRulerMarker *)marker
{
    
}
// This is sent if the object is actually removed.  The object has been removed from the ruler when this message is sent.

- (BOOL)rulerView: (NSRulerView *)ruler
  shouldAddMarker: (NSRulerMarker *)marker
{
    return YES;
}
// This is sent when a drag operation is just beginning for a ruler marker that is being added.  If the ruler object should be allowed to add, return YES.  If you return NO, all tracking is abandoned and nothing happens.

- (CGFloat)rulerView: (NSRulerView *)ruler
       willAddMarker: (NSRulerMarker *)marker
          atLocation: (CGFloat)location
{
    return location;
}
// This is sent continuously while the mouse is being dragged during an add operation and the new object is stuck on the baseline.  The client can constrian the movement by returning a different location.  Receipt of one or more of these messages does not guarantee that the corresponding "did" method will be called.  Any object sending these messages is not yet added to the ruler it is being dragged on.

- (void)rulerView: (NSRulerView *)ruler
     didAddMarker: (NSRulerMarker *)marker
{
    
}
// This is sent after the object has been added to the ruler.

- (void)rulerView:(NSRulerView *)ruler
  handleMouseDown: (NSEvent *)event
{
    
}
// This is sent when the user clicks in the rule area of the ruler.  The "rule" area is the area below the baseline where the hash marks and labels are drawn.  A common use for this method would be to make clicking in the rule be a shortcut for adding the most common type of ruler object for a particuar client.  NSTextView will use this to insert a new left tab (as a short cut to dragging one out of the well in the accessory view).

- (void)rulerView: (NSRulerView *)ruler
willSetClientView: (NSView *)newClient
{
    
}
// This is sent to the existing client before it is replaced by the new client.  The existing client can catch this to clean up any cached state it keeps while it is the client of a ruler.

// This additional mapping allows mapping between location and point for clients with rotated coordinate system (i.e. vertical text view)
//- (CGFloat)rulerView: (NSRulerView *)ruler
//    locationForPoint: (NSPoint)aPoint
//{
//    
//}
//
//- (NSPoint)rulerView: (NSRulerView *)ruler
//    pointForLocation: (CGFloat)aPoint
//{
//    
//}

@end
