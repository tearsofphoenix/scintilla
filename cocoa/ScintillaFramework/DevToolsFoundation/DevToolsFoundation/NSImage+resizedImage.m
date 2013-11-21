//
//  NSImage+resizedImage.m
//  DevToolsFoundation
//
//  Created by Lei on 11/21/13.
//  Copyright (c) 2013 Mac003. All rights reserved.
//

#import "NSImage+resizedImage.h"

@implementation NSImage (resizedImage)

+ (NSImage *) image: (NSImage *)image
    resizedWithSize: (NSSize)newSize
{
    NSImage *sourceImage = image;
    [sourceImage setScalesWhenResized: YES];
    
    // Report an error if the source isn't a valid image
    if (![sourceImage isValid])
    {
        NSLog(@"Invalid Image");
    } else
    {
        NSImage *smallImage = [[NSImage alloc] initWithSize: newSize];
        
        [smallImage lockFocus];
        
        [sourceImage setSize: newSize];
        [[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
        [sourceImage compositeToPoint: NSZeroPoint
                            operation: NSCompositeCopy];
        
        [smallImage unlockFocus];
        
        return [smallImage autorelease];
    }
    return nil;
}

- (NSImage *)resizedWithSize: (NSSize)newSize
{
    return [NSImage image: self
          resizedWithSize: newSize];
}

+ (NSImage *)image: (NSImage *)image
      leftCapWidth: (CGFloat)leftWidth
       middleWidth: (CGFloat)middleWidth
     rightCapWidth: (CGFloat)rightWidth
{
    
    // Calculate the new images dimensions
    float imageWidth = leftWidth + middleWidth + rightWidth;
    float imageHeight = image.size.height;
    
    // Generate the left image
    NSRect rectLeft = NSMakeRect(0, 0, leftWidth, imageHeight);
    NSImage *imageLeft = [[NSImage alloc] initWithSize:rectLeft.size];
    if (imageLeft.size.width > 0)
    {
        [imageLeft lockFocus];
        [image drawInRect:rectLeft fromRect:rectLeft operation:NSCompositeCopy fraction:1.0];
        [imageLeft unlockFocus];
    }
    
    // Generate the middle image
    NSRect rectMiddle = NSMakeRect(0, 0, image.size.width - (rightWidth + leftWidth), imageHeight);
    NSImage *imageMiddle = [[NSImage alloc] initWithSize:rectMiddle.size];
    if (imageMiddle.size.width > 0)
    {
        [imageMiddle lockFocus];
        [image drawInRect:rectMiddle fromRect:NSMakeRect(leftWidth, 0, rectMiddle.size.width, imageHeight) operation:NSCompositeCopy fraction:1.0];
        [imageMiddle unlockFocus];
    }
    
    // Generate the right image
    NSRect rectRight = NSMakeRect(0, 0, rightWidth, imageHeight);
    NSImage *imageRight = [[NSImage alloc] initWithSize:rectRight.size];
    if (imageRight.size.width > 0)
    {
        [imageRight lockFocus];
        [image drawInRect:rectRight fromRect:NSMakeRect(image.size.width - rightWidth, 0, rightWidth, imageHeight) operation:NSCompositeCopy fraction:1.0];
        [imageRight unlockFocus];
    }
    
    // Combine the images
    NSImage *newImage = [[[NSImage alloc] initWithSize:NSMakeSize(imageWidth,  imageHeight)] autorelease];
    if (newImage.size.width > 0)
    {
        [newImage lockFocus];
        NSDrawThreePartImage(NSMakeRect(0, 0, imageWidth, imageHeight), imageLeft, imageMiddle, imageRight, NO, NSCompositeSourceOver, 1, NO);
        [newImage unlockFocus];
    }
    
    // Release the images and return the new image
    [imageLeft release];
    [imageMiddle release];
    [imageRight release];
    
    return newImage;
}

@end