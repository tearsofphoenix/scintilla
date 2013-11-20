/*
 *  VTLStyle.h
 *
 *  Created by Evan Jones on Wed Oct 02 2002.
 *
 */

#ifndef _QUARTZ_TEXT_STYLE_H
#define _QUARTZ_TEXT_STYLE_H

#import <Foundation/Foundation.h>

@interface VTLStyle : NSObject<NSCopying>

- (NSDictionary *)getCTStyle;

- (void)setCTStyleColor: (CGColorRef)inColor;

- (float)getAscent;

- (float)getDescent;

- (float)getLeading;

- (void)setFontRef: (CTFontRef)inRef
      characterSet: (int)characterSet;

- (NSFont *)getFontRef;

- (int)getCharacterSet;

@end

#endif

