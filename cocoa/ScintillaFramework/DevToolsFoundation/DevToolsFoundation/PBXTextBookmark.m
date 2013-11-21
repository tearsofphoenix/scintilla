//
//  PBXTextBookmark.m
//  DevToolsFoundation
//
//  Created by Mac003 on 13-11-21.
//  Copyright (c) 2013年 Mac003. All rights reserved.
//

#import "PBXTextBookmark.h"
#import "NSImage+resizedImage.h"

static NSColor *gsBreackpointEnabledColor = nil;
static NSColor *gsBreackpointDisabledColor = nil;

@implementation PBXTextBookmark

+ (void)initialize
{
    gsBreackpointEnabledColor = [[NSColor colorWithCalibratedRed: 0.32f
                                                           green: 0.53f
                                                            blue: 0.75f
                                                           alpha: 1.0f] retain];
    
    gsBreackpointDisabledColor = [[NSColor colorWithCalibratedRed: 0.76f
                                                            green: 0.83f
                                                             blue: 0.90f
                                                            alpha: 1.00f] retain];
    
}

- (id)initWithRulerView: (NSRulerView *)ruler
         markerLocation: (CGFloat)location
{
    NSString *path = [[NSBundle bundleForClass: [self class]] pathForResource: @"TB_Breakpoints-Glyph"
                                                                       ofType: @"pdf"];
    NSImage *image = [[NSImage alloc] initWithContentsOfFile: path];
    
    self = [super initWithRulerView: ruler
                     markerLocation: location
                              image: image
                        imageOrigin: NSZeroPoint];
    [image release];
    
    return self;
}

- (void)drawRect: (NSRect)rect
{
    //[super drawRect: rect];
    NSRulerView *rulerView = [self ruler];
    NSRect imageRect =  [self imageRectInRuler];
    
    imageRect.origin.x = 0;
    imageRect.size.width = [rulerView requiredThickness];
    imageRect.size.height = 16;
    
    [self _drawImage: [NSImage image: [self image]
                        leftCapWidth: 2
                         middleWidth: imageRect.size.width - 14
                       rightCapWidth: 14]
        etchedInRect: imageRect];
}

- (void)_drawImage: (NSImage *)image
      etchedInRect: (NSRect)rect
{
    CGContextRef c = [[NSGraphicsContext currentContext] graphicsPort];
    
    //save the current graphics state
    CGContextSaveGState(c);
    
    //Create mask image:
    NSRect maskRect = rect;
    CGImageRef maskImage = [image CGImageForProposedRect: &maskRect
                                                 context: [NSGraphicsContext currentContext]
                                                   hints: nil];
    
    [image drawInRect: maskRect
             fromRect: NSMakeRect(0, 0, image.size.width, image.size.height)
            operation: NSCompositeSourceOver
             fraction: 1.0];
    
    //Clip drawing to mask:
    CGContextClipToMask(c, NSRectToCGRect(maskRect), maskImage);
    
    //Draw gradient:
    NSColor *color = nil;
    
    if ([_delegate isEnabled])
    {
        color = gsBreackpointEnabledColor;
    }else
    {
        color = gsBreackpointDisabledColor;
    }
    
    
    NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor: color
                                                          endingColor: color] autorelease];
    
    [gradient drawInRect: maskRect
                   angle: 90.0];
    
    //Draw inner shadow with inverted mask:
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef maskContext = CGBitmapContextCreate(NULL,
                                                     CGImageGetWidth(maskImage),
                                                     CGImageGetHeight(maskImage),
                                                     8,
                                                     CGImageGetWidth(maskImage) * 4,
                                                     colorSpace,
                                                     kCGImageAlphaPremultipliedLast
                                                     | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    CGContextSetBlendMode(maskContext, kCGBlendModeXOR);
    CGContextDrawImage(maskContext, maskRect, maskImage);
    CGContextSetRGBFillColor(maskContext, 1.0, 1.0, 1.0, 1.0);
    CGContextFillRect(maskContext, maskRect);
    CGImageRef invertedMaskImage = CGBitmapContextCreateImage(maskContext);
    CGContextDrawImage(c, maskRect, invertedMaskImage);
    CGImageRelease(invertedMaskImage);
    CGContextRelease(maskContext);
    
    //restore the graphics state
    CGContextRestoreGState(c);
}

- (void)setNeedsDisplay
{
    [[self ruler] setNeedsDisplay: YES];
}

- (BOOL)trackMouse: (NSEvent *)mouseDownEvent
            adding: (BOOL)isAdding
{
    BOOL flag = [super trackMouse: mouseDownEvent
                           adding: isAdding];
    
    return flag;
}

@end
