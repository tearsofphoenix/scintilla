//
//  SCIMarginView.h
//  ScintillaFramework
//
//  Created by Lei on 11/19/13.
//
//

#import <Cocoa/Cocoa.h>

@class ScintillaView;
@class PBXBreakpoint;
/**
 * SCIMarginView draws line numbers and other margins next to the text view.
 */
@interface SCIMarginView : NSRulerView

@property (assign) int marginWidth;
@property (assign) ScintillaView *owner;

- (id)initWithScrollView: (NSScrollView *)aScrollView;

- (void)addBreakpoint: (PBXBreakpoint *)breakpoint
         atLineNumber: (int)lineNumber;

@end

