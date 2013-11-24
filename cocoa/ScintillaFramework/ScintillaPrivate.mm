//
//  ScintillaPrivate.m
//  Scintilla
//
//  Created by Mac003 on 13-11-20.
//
//

#import "ScintillaPrivate.h"
#import "Scintilla.h"

static void ProviderReleaseData(void *, const void *data, size_t)
{
	const unsigned char *pixels = reinterpret_cast<const unsigned char *>(data);
	delete []pixels;
}

CGImageRef ImageCreateFromRGBA(int width, int height, const unsigned char *pixelsImage, bool invert)
{
	CGImageRef image = 0;
    
	// Create an RGB color space.
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	if (colorSpace) {
		const int bitmapBytesPerRow = ((int) width * 4);
		const int bitmapByteCount = (bitmapBytesPerRow * (int) height);
		
		// Create a data provider.
		CGDataProviderRef dataProvider = 0;
		if (invert) {
			unsigned char *pixelsUpsideDown = new unsigned char[bitmapByteCount];
            
			for (int y=0; y<height; y++) {
				int yInverse = height - y - 1;
				memcpy(pixelsUpsideDown + y * bitmapBytesPerRow,
				       pixelsImage + yInverse * bitmapBytesPerRow,
				       bitmapBytesPerRow);
			}
			
			dataProvider = CGDataProviderCreateWithData(NULL, pixelsUpsideDown, bitmapByteCount, ProviderReleaseData);
		} else
        {
			dataProvider = CGDataProviderCreateWithData(
                                                        NULL, pixelsImage, bitmapByteCount, NULL);
			
		}
		
        if (dataProvider)
        {
			// Create the CGImage.
			image = CGImageCreate(width,
                                  height,
                                  8,
                                  8 * 4,
                                  bitmapBytesPerRow,
                                  colorSpace,
                                  kCGImageAlphaLast,
                                  dataProvider,
                                  NULL,
                                  0,
                                  kCGRenderingIntentDefault);
            
			CGDataProviderRelease(dataProvider);
		}
		
		// The image retains the color space, so we can release it.
		CGColorSpaceRelease(colorSpace);
	}
	return image;
}


CFStringEncoding EncodingFromCharacterSet(bool unicode, int characterSet)
{
    if (unicode)
        return kCFStringEncodingUTF8;
    
    // Unsupported -> Latin1 as reasonably safe
    enum { notSupported = kCFStringEncodingISOLatin1};
    
    switch (characterSet)
    {
        case SC_CHARSET_ANSI:
            return kCFStringEncodingISOLatin1;
        case SC_CHARSET_DEFAULT:
            return kCFStringEncodingISOLatin1;
        case SC_CHARSET_BALTIC:
            return kCFStringEncodingWindowsBalticRim;
        case SC_CHARSET_CHINESEBIG5:
            return kCFStringEncodingBig5;
        case SC_CHARSET_EASTEUROPE:
            return kCFStringEncodingWindowsLatin2;
        case SC_CHARSET_GB2312:
            return kCFStringEncodingGB_18030_2000;
        case SC_CHARSET_GREEK:
            return kCFStringEncodingWindowsGreek;
        case SC_CHARSET_HANGUL:
            return kCFStringEncodingEUC_KR;
        case SC_CHARSET_MAC:
            return kCFStringEncodingMacRoman;
        case SC_CHARSET_OEM:
            return kCFStringEncodingISOLatin1;
        case SC_CHARSET_RUSSIAN:
            return kCFStringEncodingKOI8_R;
        case SC_CHARSET_CYRILLIC:
            return kCFStringEncodingWindowsCyrillic;
        case SC_CHARSET_SHIFTJIS:
            return kCFStringEncodingShiftJIS;
        case SC_CHARSET_SYMBOL:
            return kCFStringEncodingMacSymbol;
        case SC_CHARSET_TURKISH:
            return kCFStringEncodingWindowsLatin5;
        case SC_CHARSET_JOHAB:
            return kCFStringEncodingWindowsKoreanJohab;
        case SC_CHARSET_HEBREW:
            return kCFStringEncodingWindowsHebrew;
        case SC_CHARSET_ARABIC:
            return kCFStringEncodingWindowsArabic;
        case SC_CHARSET_VIETNAMESE:
            return kCFStringEncodingWindowsVietnamese;
        case SC_CHARSET_THAI:
            return kCFStringEncodingISOLatinThai;
        case SC_CHARSET_8859_15:
            return kCFStringEncodingISOLatin1;
        default:
            return notSupported;
    }
}
