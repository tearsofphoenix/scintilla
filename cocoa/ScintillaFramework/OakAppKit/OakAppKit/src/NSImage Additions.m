#import "NSImage Additions.h"

@implementation NSImage (ImageFromBundle)

static NSMutableDictionary* cache = nil;

+ (NSImage*)imageNamed: (NSString*)aName
   inSameBundleAsClass: (id)aClass
{
	if(!aName)
		return nil;

	NSBundle* bundle = [NSBundle bundleForClass:aClass];
	NSString* name   = [NSString stringWithFormat:@"%@.%@", [bundle bundleIdentifier], aName];

    if (!cache)
    {
        cache = [NSMutableDictionary new];
    }
	
    NSImage* res = [cache objectForKey:name];
	if(res)
    {
		return res;
    }

    NSImage* image = [[NSBundle bundleForClass:aClass] imageForResource: aName];
    
	if(image)
	{
		[cache setObject: image
                  forKey: name];
        
		return image;
	}

	return nil;
}

// ===================================================
// = Gracefully draw in potentially flipped contexts =
// ===================================================

- (void)drawAdjustedAtPoint:(NSPoint)aPoint fromRect:(NSRect)srcRect operation:(NSCompositingOperation)op fraction:(CGFloat)delta
{
	[self drawAdjustedInRect:(NSRect){ aPoint, [self size] } fromRect:srcRect operation:op fraction:delta];
}

- (void)drawAdjustedInRect:(NSRect)dstRect fromRect:(NSRect)srcRect operation:(NSCompositingOperation)op fraction:(CGFloat)delta
{
	NSGraphicsContext* context = [NSGraphicsContext currentContext];
	if([context isFlipped])
	{
		[context saveGraphicsState];

		NSAffineTransform* transform = [NSAffineTransform transform];
		[transform translateXBy:0 yBy:NSMaxY(dstRect)];
		[transform scaleXBy:1 yBy:-1];
		[transform concat];

		dstRect.origin.y = 0.0; // The transform above places the y-origin right where the image should be drawn.
		[self drawInRect:dstRect fromRect:srcRect operation:op fraction:delta];

		[context restoreGraphicsState];
	}
	else
	{
		[self drawInRect:dstRect fromRect:srcRect operation:op fraction:delta];
	}
}
@end
