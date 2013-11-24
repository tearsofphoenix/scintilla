//
//  VTLayout.mm
//  Scintilla
//
//  Created by Mac003 on 13-11-20.
//
//

#import "VTLayout.h"

@interface VTLayout ()
{
    NSAttributedString *mString;
    CTLineRef mLine;
}
@end

@implementation VTLayout

/** Create a text layout for drawing on the specified context. */
- (id)initWithContext: (CGContextRef)context
{
    if ((self = [super init]))
    {
        mString = NULL;
        mLine = NULL;
        _stringLength = 0;
        [self setContext: context];
    }
    
    return self;
}

- (void)dealloc
{
    [mString release];
    
    if ( mLine != NULL )
    {
        CFRelease(mLine);
        mLine = NULL;
    }
    
    [super dealloc];
}

- (void)setText: (const void*)buffer
         length: (size_t)byteLength
       encoding: (CFStringEncoding)encoding
          style: (NSDictionary *)attributes
{
    NSString *str = [[NSString alloc] initWithBytes: buffer
                                             length: byteLength
                                           encoding: CFStringConvertEncodingToNSStringEncoding(encoding)];
    if (!str)
        return;
    
    _stringLength = [str length];
    
    [mString release];
    mString = [[NSAttributedString alloc] initWithString: str
                                              attributes: attributes];
    
    if (mLine != NULL)
        CFRelease(mLine);
    mLine = CTLineCreateWithAttributedString((CFAttributedStringRef)mString);
    
    [str release];
}

/** Draw the text layout into the current CGContext at the specified position.
 * @param x The x axis position to draw the baseline in the current CGContext.
 * @param y The y axis position to draw the baseline in the current CGContext. */
- (void)drawAt: (float)x
             y: (float)y
{
    if (mLine == NULL)
        return;
    
    CGContextSetTextMatrix(_context, CGAffineTransformMakeScale(1.0, -1.0));

    // Set the text drawing position.
    CGContextSetTextPosition(_context, x, y);

    // And finally, draw string here!
    //
    CTLineDraw(mLine, _context);    
}

- (float)MeasureStringWidth
{
    if (mLine == NULL)
        return 0.0f;
    
    return CTLineGetTypographicBounds(mLine, NULL, NULL, NULL);
}

- (CTLineRef)getCTLine
{
    return mLine;
}

@end