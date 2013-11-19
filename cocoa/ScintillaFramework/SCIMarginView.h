//
//  SCIMarginView.h
//  ScintillaFramework
//
//  Created by Lei on 11/19/13.
//
//

#import <Cocoa/Cocoa.h>

@class ScintillaView;
/**
 * SCIMarginView draws line numbers and other margins next to the text view.
 */
@interface SCIMarginView : NSRulerView
{
@private
    NSMutableArray *_currentCursors;
}

@property (assign) int marginWidth;
@property (assign) ScintillaView *owner;

- (id)initWithScrollView: (NSScrollView *)aScrollView;

@end

