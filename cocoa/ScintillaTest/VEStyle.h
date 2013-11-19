//
//  VESettings.h
//  ScintillaTest
//
//  Created by Lei on 11/19/13.
//
//

#import <Foundation/Foundation.h>

@interface VEStyle : NSObject

- (NSDictionary *)foregroundStyle;

- (void)setForegroundValue: (id)value
                    forKey: (id<NSCopying>)key;

@end
