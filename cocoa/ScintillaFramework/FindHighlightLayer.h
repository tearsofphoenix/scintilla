//
//  FindHighlightLayer.h
//  Scintilla
//
//  Created by Mac003 on 13-11-20.
//
//

#import <QuartzCore/QuartzCore.h>

// Only implement FindHighlightLayer on OS X 10.6+

/**
 * Class to display the animated gold roundrect used on OS X for matches.
 */
@interface FindHighlightLayer : CAGradientLayer
{
@private
	NSString *sFind;
	NSString *sFont;
}

@property (copy) NSString *sFind;
@property (assign) int positionFind;
@property (assign) BOOL retaining;
@property (assign) CGFloat widthText;
@property (assign) CGFloat heightLine;
@property (copy) NSString *sFont;
@property (assign) CGFloat fontSize;

- (void) animateMatch: (CGPoint)ptText
               bounce:(BOOL)bounce;

- (void) hideMatch;

@end
