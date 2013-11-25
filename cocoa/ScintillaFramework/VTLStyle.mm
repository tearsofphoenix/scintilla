//
//  VTLStyle.mm
//  Scintilla
//
//  Created by Mac003 on 13-11-20.
//
//

#import "VTLStyle.h"

@interface VTLStyle ()
{
    NSMutableDictionary *_styleDict;
    NSFont *_font;
    int characterSet;
}
@end

@implementation VTLStyle

- (id)init
{
    if ((self = [super init]))
    {
        _font = nil;
        _styleDict = [[NSMutableDictionary alloc] init];
        
        [_styleDict setObject: [NSColor colorWithCalibratedRed: 0.13f
                                                         green: 0.13f
                                                          blue: 0.13f
                                                         alpha: 1.00f]
                       forKey: NSBackgroundColorAttributeName];
        
        characterSet = 0;
    }
    
    return self;
}

- (id)copyWithZone: (NSZone *)zone
{
    VTLStyle *copy = [[self class] allocWithZone: zone];
    copy->_font = [_font retain];
    
    // Does not copy font colour attribute
    //
    copy->_styleDict =[[NSMutableDictionary alloc] init];
    [copy->_styleDict setObject: _font
                         forKey: NSFontAttributeName];
    
    copy->characterSet = characterSet;
    
    return copy;
}

- (void)dealloc
{
    [_styleDict release];
    [_font release];
    
    [super dealloc];
}

- (NSDictionary *)getCTStyle
{
    return _styleDict;
}

- (void)setCTStyleColor: (CGColorRef)inColor
{
    [_styleDict setObject: (id)inColor
                   forKey: NSForegroundColorAttributeName];
}

- (float)getAscent
{
    return CTFontGetAscent((CTFontRef)_font);
}

- (float)getDescent
{
    return CTFontGetDescent((CTFontRef)_font);
}

- (float)getLeading
{
    return CTFontGetLeading((CTFontRef)_font);
}

- (void)setFontRef: (CTFontRef)inRef
      characterSet: (int)characterSet_
{
    [_font release];
    _font = (id)CFRetain(inRef);
    
    characterSet = characterSet_;
    
    //[_styleDict removeAllObjects];
    [_styleDict setObject: _font
                   forKey: NSFontAttributeName];
}

- (NSFont *)getFontRef
{
    return _font;
}

- (int)getCharacterSet
{
    return characterSet;
}

@end
