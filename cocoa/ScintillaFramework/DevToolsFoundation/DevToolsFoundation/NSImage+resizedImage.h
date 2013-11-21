//
//  NSImage+resizedImage.h
//  DevToolsFoundation
//
//  Created by Lei on 11/21/13.
//  Copyright (c) 2013 Mac003. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (resizedImage)

+ (NSImage *) image: (NSImage *)image
    resizedWithSize: (NSSize)newSize;

- (NSImage *)resizedWithSize: (NSSize)newSize;

+ (NSImage *)image: (NSImage *)image
      leftCapWidth: (CGFloat)leftWidth
       middleWidth: (CGFloat)middleWidth
     rightCapWidth: (CGFloat)rightWidth;

@end
