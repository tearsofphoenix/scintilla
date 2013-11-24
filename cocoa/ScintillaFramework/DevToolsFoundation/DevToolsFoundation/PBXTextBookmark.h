//
//  PBXTextBookmark.h
//  DevToolsFoundation
//
//  Created by Mac003 on 13-11-21.
//  Copyright (c) 2013年 Mac003. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DevToolsFoundation/PBXMarkerDelegateProtocol.h>

@interface PBXTextBookmark : NSRulerMarker

@property (nonatomic, assign) id<PBXMarkerDelegateProtocol> delegate;

- (id)initWithRulerView: (NSRulerView *)ruler
         markerLocation: (CGFloat)location;

@end
