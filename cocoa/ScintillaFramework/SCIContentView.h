//
//  SCIContentView.h
//  ScintillaFramework
//
//  Created by Lei on 11/19/13.
//
//

#import <Cocoa/Cocoa.h>

@class ScintillaView;
/**
 * SCIContentView is the Cocoa interface to the Scintilla backend. It handles text input and
 * provides a canvas for painting the output.
 */
@interface SCIContentView : NSView <NSTextInputClient, NSUserInterfaceValidations>
{
@private
    NSCursor* mCurrentCursor;
    NSTrackingRectTag mCurrentTrackingRect;
    
    // Set when we are in composition mode and partial input is displayed.
    NSRange mMarkedTextRange;
    BOOL undoCollectionWasActive;
}

@property (nonatomic, assign) ScintillaView* owner;

- (void) removeMarkedText;
- (void) setCursor: (int) cursor;

- (BOOL) canUndo;
- (BOOL) canRedo;

@end