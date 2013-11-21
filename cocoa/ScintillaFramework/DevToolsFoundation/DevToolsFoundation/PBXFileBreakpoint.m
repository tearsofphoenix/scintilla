//
//  PBXFileBreakpoint.m
//  DevToolsFoundation
//
//  Created by Mac003 on 13-11-21.
//  Copyright (c) 2013年 Mac003. All rights reserved.
//

#import "PBXFileBreakpoint.h"

@implementation PBXFileBreakpoint


- (id)copyWithZone: (NSZone *)zone
{
    PBXFileBreakpoint *copy = [[[self class] alloc] initWithFileReference: _fileReference
                                                               lineNumber: [self lineNumber]];
    return copy;
}

- (void)purify
{
    
}

- (NSInteger)compareUsingLineNumber: (id)breakpoint
{
    return [self compareToBreakpoint: breakpoint];
}

- (NSInteger)compareToBreakpoint: (id)arg1
{
    return [super compareToBreakpoint: arg1];
}

- (id)initWithFileReference: (id)fileReference
                 lineNumber: (NSUInteger)lineNumber
{
    if ((self = [super init]))
    {
        
    }
    
    return self;
}

@end