/*
 *  QuartzTextLayout.h
 *
 *  Original Code by Evan Jones on Wed Oct 02 2002.
 *  Contributors:
 *  Shane Caraveo, ActiveState
 *  Bernd Paradies, Adobe
 *
 */

#ifndef _QUARTZ_TEXT_LAYOUT_H
#define _QUARTZ_TEXT_LAYOUT_H

#include <Cocoa/Cocoa.h>

@interface VTLayout : NSObject

@property (nonatomic, assign) CGContextRef context;
@property (nonatomic, assign) CFIndex stringLength;

- (id)initWithContext: (CGContextRef)context;

- (void)setText: (const void*)buffer
         length: (size_t)byteLength
       encoding: (CFStringEncoding)encoding
          style: (NSDictionary *)attributes;

- (void)drawAt: (float)x
             y: (float)y;

- (float)MeasureStringWidth;

- (CTLineRef)getCTLine;

@end

#endif
