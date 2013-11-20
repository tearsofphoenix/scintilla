//
//  FindHighlightLayer.m
//  Scintilla
//
//  Created by Mac003 on 13-11-20.
//
//

#import "FindHighlightLayer.h"
#import "Scintilla.h"

@implementation FindHighlightLayer

@synthesize sFind, sFont;

-(id) init
{
	if (self = [super init])
    {
		[self setNeedsDisplayOnBoundsChange: YES];
		// A gold to slightly redder gradient to match other applications
		CGColorRef colGold = CGColorCreateGenericRGB(1.0, 1.0, 0, 1.0);
		CGColorRef colGoldRed = CGColorCreateGenericRGB(1.0, 0.8, 0, 1.0);
		self.colors = @[(id)colGoldRed, (id)colGold];
		CGColorRelease(colGoldRed);
		CGColorRelease(colGold);
        
		CGColorRef colGreyBorder = CGColorCreateGenericGray(0.756f, 0.5f);
		self.borderColor = colGreyBorder;
		CGColorRelease(colGreyBorder);
        
		self.borderWidth = 1.0;
		self.cornerRadius = 5.0f;
		self.shadowRadius = 1.0f;
		self.shadowOpacity = 0.9f;
		self.shadowOffset = CGSizeMake(0.0f, -2.0f);
		self.anchorPoint = CGPointMake(0.5, 0.5);
	}
	return self;
	
}

const CGFloat paddingHighlightX = 4;
const CGFloat paddingHighlightY = 2;

- (void)drawInContext: (CGContextRef)context
{
	if (!sFind || !sFont)
		return;
		
    NSDictionary *styleDict = (@{
                                 NSForegroundColorAttributeName : [NSColor blackColor],
                                 NSFontAttributeName : [NSFont fontWithName: sFont
                                                                       size: _fontSize],
                                 });
    
    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString: sFind
                                                                     attributes: styleDict];
    
	CTLineRef textLine = CTLineCreateWithAttributedString((CFAttributedStringRef)attrString);
	// Indent from corner of bounds
	CGContextSetTextPosition(context, paddingHighlightX, 3 + paddingHighlightY);
	CTLineDraw(textLine, context);
	
	CFRelease(textLine);
    
	[attrString release];
}

- (void) animateMatch: (CGPoint)ptText
               bounce: (BOOL)bounce
{
	if (!self.sFind || ![self.sFind length])
    {
		[self hideMatch];
		return;
	}
    
	CGFloat width = self.widthText + paddingHighlightX * 2;
	CGFloat height = self.heightLine + paddingHighlightY * 2;
    
	CGFloat flipper = self.geometryFlipped ? -1.0 : 1.0;
    
	// Adjust for padding
	ptText.x -= paddingHighlightX;
	ptText.y += flipper * paddingHighlightY;
    
	// Shift point to centre as expanding about centre
	ptText.x += width / 2.0;
	ptText.y -= flipper * height / 2.0;
    
	[CATransaction begin];
	[CATransaction setValue: @0.0
                     forKey: kCATransactionAnimationDuration];
    
	self.bounds = CGRectMake(0,0, width, height);
	self.position = ptText;
	if (bounce) {
		// Do not reset visibility when just moving
		self.hidden = NO;
		self.opacity = 1.0;
	}
	[self setNeedsDisplay];
	[CATransaction commit];
	
	if (bounce)
    {
		CABasicAnimation *animBounce = [CABasicAnimation animationWithKeyPath: @"transform.scale"];
		animBounce.duration = 0.15;
		animBounce.autoreverses = YES;
		animBounce.removedOnCompletion = NO;
		animBounce.fromValue = @1.0;
		animBounce.toValue = @1.25;
		
		if (self.retaining)
        {
			
			[self addAnimation: animBounce forKey:@"animateFound"];
			
		} else
        {			
			CABasicAnimation *animFade = [CABasicAnimation animationWithKeyPath:@"opacity"];
			animFade.duration = 0.1;
			animFade.beginTime = 0.4;
			animFade.removedOnCompletion = NO;
			animFade.fromValue = @1.0;
			animFade.toValue = @0.0;
			
			CAAnimationGroup *group = [CAAnimationGroup animation];
			[group setDuration:0.5];
			group.removedOnCompletion = NO;
			group.fillMode = kCAFillModeForwards;
			[group setAnimations: @[animBounce, animFade]];
			
			[self addAnimation:group forKey:@"animateFound"];
		}
	}
}

- (void)hideMatch
{
	self.sFind = @"";
	self.positionFind = INVALID_POSITION;
	self.hidden = YES;
}

@end
