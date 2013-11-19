//
//  VTLFont.m
//  Scintilla
//
//  Created by Lei on 11/19/13.
//
//

#import "Scintilla.h"
#import "VTLFont.h"

CTFontRef VTLFontCreate(const char* name,
                        size_t length,
                        float size,
                        int weight,
                        bool italic)
{
    assert( name != NULL && length > 0 && name[length] == '\0' );
    
    CTFontRef _fontRef;
    
    CFStringRef fontName = CFStringCreateWithCString(kCFAllocatorDefault,
                                                     name,
                                                     kCFStringEncodingMacRoman);
    assert(fontName != NULL);
    
    bool bold = weight > SC_WEIGHT_NORMAL;
    
    if (bold || italic)
    {
        CTFontSymbolicTraits desiredTrait = 0;
        CTFontSymbolicTraits traitMask = 0;
        
        // if bold was specified, add the trait
        if (bold)
        {
            desiredTrait |= kCTFontBoldTrait;
            traitMask |= kCTFontBoldTrait;
        }
        
        // if italic was specified, add the trait
        if (italic)
        {
            desiredTrait |= kCTFontItalicTrait;
            traitMask |= kCTFontItalicTrait;
        }
        
        // create a font and then a copy of it with the sym traits
        CTFontRef iFont = CTFontCreateWithName(fontName, size, NULL);
        _fontRef = CTFontCreateCopyWithSymbolicTraits(iFont, size, NULL, desiredTrait, traitMask);

        if (_fontRef)
        {
            CFRelease(iFont);
            
        }else
        {
            // Traits failed so use base font
            _fontRef = iFont;
        }
    }
    else
    {
        // create the font, no traits
        _fontRef = CTFontCreateWithName(fontName, size, NULL);
    }
    
    if (!_fontRef)
    {
        // Failed to create requested font so use font always present
        _fontRef = CTFontCreateWithName((CFStringRef)@"Monaco", size, NULL);
    }
    
    CFRelease(fontName);
    
    return _fontRef;
}
