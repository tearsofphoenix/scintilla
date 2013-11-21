//
//  PBXTextBookmark.m
//  DevToolsFoundation
//
//  Created by Mac003 on 13-11-21.
//  Copyright (c) 2013年 Mac003. All rights reserved.
//

#import "PBXTextBookmark.h"

@implementation PBXTextBookmark

- (id)initWithRulerView: (NSRulerView *)ruler
         markerLocation: (CGFloat)location
{
    NSString *path = [[NSBundle bundleForClass: [self class]] pathForResource: @"TB_Breakpoints-Glyph"
                                                                       ofType: @"pdf"];
    NSImage *image = [[NSImage alloc] initWithContentsOfFile: path];
    [image setTemplate: YES];
    
    self = [super initWithRulerView: ruler
                     markerLocation: location
                              image: image
                        imageOrigin: NSZeroPoint];
    [image release];
    
    return self;
}

@end
