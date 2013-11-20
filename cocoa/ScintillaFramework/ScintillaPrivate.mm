//
//  ScintillaPrivate.m
//  Scintilla
//
//  Created by Mac003 on 13-11-20.
//
//

#import "ScintillaPrivate.h"

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
