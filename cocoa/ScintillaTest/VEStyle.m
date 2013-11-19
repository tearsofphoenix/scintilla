//
//  VESettings.m
//  ScintillaTest
//
//  Created by Lei on 11/19/13.
//
//

#import "VEStyle.h"

@interface VEStyle ()
{
    NSMutableDictionary *_foregroundStyle;
}
@end

@implementation VEStyle

- (id)init
{
    if ((self = [super init]))
    {
        _foregroundStyle = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (NSDictionary *)foregroundStyle
{
    return _foregroundStyle;
}

- (void)setForegroundValue: (id)value
                    forKey: (id<NSCopying>)key
{
    [_foregroundStyle setObject: value
                         forKey: key];
}

@end
