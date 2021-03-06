/**
 * Scintilla source code edit control
 * PlatCocoa.mm - implementation of platform facilities on MacOS X/Cocoa
 *
 * Written by Mike Lischke
 * Based on PlatMacOSX.cxx
 * Based on work by Evan Jones (c) 2002 <ejones@uwaterloo.ca>
 * Based on PlatGTK.cxx Copyright 1998-2002 by Neil Hodgson <neilh@scintilla.org>
 * The License.txt file describes the conditions under which this software may be distributed.
 *
 * Copyright 2009 Sun Microsystems, Inc. All rights reserved.
 * This file is dual licensed under LGPL v2.1 and the Scintilla license (http://www.scintilla.org/License.txt).
 */

#import "Platform.h"
#import "ScintillaView.h"
#import "SCIController.h"
#import "PlatCocoa.h"

#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <assert.h>
#include <sys/time.h>
#include <stdexcept>
#include <vector>
#include <map>

#include "XPM.h"
#import "ScintillaContextMenu.h"
#import "ScintillaPrivate.h"
#import "VTLayout.h"
#import "VTLStyle.h"

#import <Foundation/NSGeometry.h>

using namespace Scintilla;

extern sptr_t scintilla_send_message(void* sci, unsigned int iMessage, uptr_t wParam, sptr_t lParam);



/**
 * Converts a PRectangle as used by Scintilla to standard Obj-C NSRect structure .
 */
NSRect PRectangleToNSRect(PRectangle& rc)
{
    return NSMakeRect(rc.left, rc.top, rc.Width(), rc.Height());
}



/**
 * Converts an NSRect as used by the system to a native Scintilla rectangle.
 */
PRectangle NSRectToPRectangle(NSRect& rc)
{
    return PRectangle(rc.origin.x, rc.origin.y, rc.size.width + rc.origin.x, rc.size.height + rc.origin.y);
}



/**
 * Converts a PRectangle as used by Scintilla to a Quartz-style rectangle.
 */
inline CGRect PRectangleToCGRect(PRectangle& rc)
{
    return CGRectMake(rc.left, rc.top, rc.Width(), rc.Height());
}



/**
 * Converts a Quartz-style rectangle to a PRectangle structure as used by Scintilla.
 */
inline PRectangle CGRectToPRectangle(const CGRect& rect)
{
    PRectangle rc;
    rc.left = (int)(rect.origin.x + 0.5);
    rc.top = (int)(rect.origin.y + 0.5);
    rc.right = (int)(rect.origin.x + rect.size.width + 0.5);
    rc.bottom = (int)(rect.origin.y + rect.size.height + 0.5);
    return rc;
}

//----------------- Point --------------------------------------------------------------------------

/**
 * Converts a point given as a long into a native Point structure.
 */
Scintilla::Point Scintilla::Point::FromLong(long lpoint)
{
    return Scintilla::Point(
                            Platform::LowShortFromLong(lpoint),
                            Platform::HighShortFromLong(lpoint)
                            );
}



//----------------- SurfaceImpl --------------------------------------------------------------------

SurfaceImpl::SurfaceImpl()
{
    unicodeMode = true;
    x = 0;
    y = 0;
    gc = NULL;
    
    _textLayout = [[VTLayout alloc] initWithContext: NULL];
    codePage = 0;
    verticalDeviceResolution = 0;
    
    bitmapData = NULL; // Release will try and delete bitmapData if != NULL
    bitmapWidth = 0;
    bitmapHeight = 0;
    
    Release();
}



SurfaceImpl::~SurfaceImpl()
{
    Release();
    [_textLayout release];
}



void SurfaceImpl::Release()
{
    [_textLayout setContext: NULL];
    if ( bitmapData != NULL )
    {
        delete[] bitmapData;
        // We only "own" the graphics context if we are a bitmap context
        if (gc != NULL)
            CGContextRelease(gc);
    }
    bitmapData = NULL;
    gc = NULL;
    
    bitmapWidth = 0;
    bitmapHeight = 0;
    x = 0;
    y = 0;
}



bool SurfaceImpl::Initialised()
{
    // We are initalised if the graphics context is not null
    return gc != NULL;// || port != NULL;
}



void SurfaceImpl::Init(WindowID)
{
    // To be able to draw, the surface must get a CGContext handle.  We save the graphics port,
    // then acquire/release the context on an as-need basis (see above).
    // XXX Docs on QDBeginCGContext are light, a better way to do this would be good.
    // AFAIK we should not hold onto a context retrieved this way, thus the need for
    // acquire/release of the context.
    
    Release();
}



void SurfaceImpl::Init(SurfaceID sid, WindowID)
{
    Release();
    gc = reinterpret_cast<CGContextRef>(sid);
    CGContextSetLineWidth(gc, 1.0);
    [_textLayout setContext: gc];
}



void SurfaceImpl::InitPixMap(int width, int height, Surface* /* surface_ */, WindowID /* wid */)
{
    Release();
    
    // Create a new bitmap context, along with the RAM for the bitmap itself
    bitmapWidth = width;
    bitmapHeight = height;
    
    const int bitmapBytesPerRow = (width * BYTES_PER_PIXEL);
    const int bitmapByteCount = (bitmapBytesPerRow * height);
    
    // Create an RGB color space.
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL)
        return;
    
    // Create the bitmap.
    bitmapData = new uint8_t[bitmapByteCount];
    // create the context
    gc = CGBitmapContextCreate(bitmapData,
                               width,
                               height,
                               BITS_PER_COMPONENT,
                               bitmapBytesPerRow,
                               colorSpace,
                               kCGImageAlphaPremultipliedLast);
    
    if (gc == NULL)
    {
        // the context couldn't be created for some reason,
        // and we have no use for the bitmap without the context
        delete[] bitmapData;
        bitmapData = NULL;
    }
    
    [_textLayout setContext: gc];
    
    // the context retains the color space, so we can release it
    CGColorSpaceRelease(colorSpace);
    
    if (gc != NULL && bitmapData != NULL)
    {
        // "Erase" to white.
        CGContextClearRect( gc, CGRectMake( 0, 0, width, height ) );
        CGContextSetRGBFillColor( gc, 1.0, 1.0, 1.0, 1.0 );
        CGContextFillRect( gc, CGRectMake( 0, 0, width, height ) );
    }
}



void SurfaceImpl::PenColour(ColourDesired fore)
{
    if (gc)
    {
        ColourDesired colour(fore.AsLong());
        
        // Set the Stroke color to match
        CGContextSetRGBStrokeColor(gc, colour.GetRed() / 255.0, colour.GetGreen() / 255.0,
                                   colour.GetBlue() / 255.0, 1.0 );
    }
}



void SurfaceImpl::FillColour(const ColourDesired& back)
{
    if (gc)
    {
        ColourDesired colour(back.AsLong());
        
        // Set the Fill color to match
        CGContextSetRGBFillColor(gc, colour.GetRed() / 255.0, colour.GetGreen() / 255.0,
                                 colour.GetBlue() / 255.0, 1.0 );
    }
}



CGImageRef SurfaceImpl::GetImage()
{
    // For now, assume that GetImage can only be called on PixMap surfaces.
    if (bitmapData == NULL)
        return NULL;
    
    CGContextFlush(gc);
    
    // Create an RGB color space.
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if( colorSpace == NULL )
        return NULL;
    
    const int bitmapBytesPerRow = ((int) bitmapWidth * BYTES_PER_PIXEL);
    const int bitmapByteCount = (bitmapBytesPerRow * (int) bitmapHeight);
    
    // Make a copy of the bitmap data for the image creation and divorce it
    // From the SurfaceImpl lifetime
    CFDataRef dataRef = CFDataCreate(kCFAllocatorDefault, bitmapData, bitmapByteCount);
    
    // Create a data provider.
    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData(dataRef);
    
    CGImageRef image = NULL;
    if (dataProvider != NULL)
    {
        // Create the CGImage.
        image = CGImageCreate(bitmapWidth,
                              bitmapHeight,
                              BITS_PER_COMPONENT,
                              BITS_PER_PIXEL,
                              bitmapBytesPerRow,
                              colorSpace,
                              kCGImageAlphaPremultipliedLast,
                              dataProvider,
                              NULL,
                              0,
                              kCGRenderingIntentDefault);
    }
    
    // The image retains the color space, so we can release it.
    CGColorSpaceRelease(colorSpace);
    colorSpace = NULL;
    
    // Done with the data provider.
    CGDataProviderRelease(dataProvider);
    dataProvider = NULL;
    
    // Done with the data provider.
    CFRelease(dataRef);
    
    return image;
}



/**
 * Returns the vertical logical device resolution of the main monitor.
 * This is no longer called.
 * For Cocoa, all screens are treated as 72 DPI, even retina displays.
 */
int SurfaceImpl::LogPixelsY()
{
    return 72;
}



/**
 * Converts the logical font height in points into a device height.
 * For Cocoa, points are always used for the result even on retina displays.
 */
int SurfaceImpl::DeviceHeightFont(int points)
{
    return points;
}



void SurfaceImpl::MoveTo(int x_, int y_)
{
    x = x_;
    y = y_;
}



void SurfaceImpl::LineTo(int x_, int y_)
{
    CGContextBeginPath( gc );
    
    // Because Quartz is based on floating point, lines are drawn with half their colour
    // on each side of the line. Integer coordinates specify the INTERSECTION of the pixel
    // division lines. If you specify exact pixel values, you get a line that
    // is twice as thick but half as intense. To get pixel aligned rendering,
    // we render the "middle" of the pixels by adding 0.5 to the coordinates.
    CGContextMoveToPoint( gc, x + 0.5, y + 0.5 );
    CGContextAddLineToPoint( gc, x_ + 0.5, y_ + 0.5 );
    CGContextStrokePath( gc );
    x = x_;
    y = y_;
}



void SurfaceImpl::Polygon(Scintilla::Point *pts, int npts, ColourDesired fore,
                          ColourDesired back)
{
    // Allocate memory for the array of points.
    std::vector<CGPoint> points(npts);
    
    for (int i = 0;i < npts;i++)
    {
        // Quartz floating point issues: plot the MIDDLE of the pixels
        points[i].x = pts[i].x + 0.5;
        points[i].y = pts[i].y + 0.5;
    }
    
    CGContextBeginPath(gc);
    
    // Set colours
    FillColour(back);
    PenColour(fore);
    
    // Draw the polygon
    CGContextAddLines(gc, points.data(), npts);
    
    // Explicitly close the path, so it is closed for stroking AND filling (implicit close = filling only)
    CGContextClosePath( gc );
    CGContextDrawPath( gc, kCGPathFillStroke );
}



void SurfaceImpl::RectangleDraw(PRectangle rc, ColourDesired fore, ColourDesired back)
{
    if (gc)
    {
        CGContextBeginPath( gc );
        FillColour(back);
        PenColour(fore);
        
        // Quartz integer -> float point conversion fun (see comment in SurfaceImpl::LineTo)
        // We subtract 1 from the Width() and Height() so that all our drawing is within the area defined
        // by the PRectangle. Otherwise, we draw one pixel too far to the right and bottom.
        CGContextAddRect( gc, CGRectMake( rc.left + 0.5, rc.top + 0.5, rc.Width() - 1, rc.Height() - 1 ) );
        CGContextDrawPath( gc, kCGPathFillStroke );
    }
}



void SurfaceImpl::FillRectangle(PRectangle rc, ColourDesired back)
{
    if (gc)
    {
        FillColour(back);
        // Snap rectangle boundaries to nearest int
        rc.left = lround(rc.left);
        rc.right = lround(rc.right);
        CGRect rect = PRectangleToCGRect(rc);
        CGContextFillRect(gc, rect);
    }
}



void drawImageRefCallback(CGImageRef pattern, CGContextRef gc)
{
    CGContextDrawImage(gc, CGRectMake(0, 0, CGImageGetWidth(pattern), CGImageGetHeight(pattern)), pattern);
}



void releaseImageRefCallback(CGImageRef pattern)
{
    CGImageRelease(pattern);
}



void SurfaceImpl::FillRectangle(PRectangle rc, Surface &surfacePattern)
{
    SurfaceImpl& patternSurface = static_cast<SurfaceImpl &>(surfacePattern);
    
    // For now, assume that copy can only be called on PixMap surfaces. Shows up black.
    CGImageRef image = patternSurface.GetImage();
    if (image == NULL)
    {
        FillRectangle(rc, ColourDesired(0));
        return;
    }
    
    const CGPatternCallbacks drawImageCallbacks = { 0,
        reinterpret_cast<CGPatternDrawPatternCallback>(drawImageRefCallback),
        reinterpret_cast<CGPatternReleaseInfoCallback>(releaseImageRefCallback) };
    
    CGPatternRef pattern = CGPatternCreate(image,
                                           CGRectMake(0, 0, patternSurface.bitmapWidth, patternSurface.bitmapHeight),
                                           CGAffineTransformIdentity,
                                           patternSurface.bitmapWidth,
                                           patternSurface.bitmapHeight,
                                           kCGPatternTilingNoDistortion,
                                           true,
                                           &drawImageCallbacks
                                           );
    if (pattern != NULL)
    {
        // Create a pattern color space
        CGColorSpaceRef colorSpace = CGColorSpaceCreatePattern( NULL );
        if( colorSpace != NULL ) {
            
            CGContextSaveGState( gc );
            CGContextSetFillColorSpace( gc, colorSpace );
            
            // Unlike the documentation, you MUST pass in a "components" parameter:
            // For coloured patterns it is the alpha value.
            const CGFloat alpha = 1.0;
            CGContextSetFillPattern( gc, pattern, &alpha );
            CGContextFillRect( gc, PRectangleToCGRect( rc ) );
            CGContextRestoreGState( gc );
            // Free the color space, the pattern and image
            CGColorSpaceRelease( colorSpace );
        } /* colorSpace != NULL */
        colorSpace = NULL;
        CGPatternRelease( pattern );
        pattern = NULL;
    } /* pattern != NULL */
}

void SurfaceImpl::RoundedRectangle(PRectangle rc, ColourDesired fore, ColourDesired back) {
    // This is only called from the margin marker drawing code for SC_MARK_ROUNDRECT
    // The Win32 version does
    //  ::RoundRect(hdc, rc.left + 1, rc.top, rc.right - 1, rc.bottom, 8, 8 );
    // which is a rectangle with rounded corners each having a radius of 4 pixels.
    // It would be almost as good just cutting off the corners with lines at
    // 45 degrees as is done on GTK+.
    
    // Create a rectangle with semicircles at the corners
    const int MAX_RADIUS = 4;
    int radius = Platform::Minimum( MAX_RADIUS, rc.Height()/2 );
    radius = Platform::Minimum( radius, rc.Width()/2 );
    
    // Points go clockwise, starting from just below the top left
    // Corners are kept together, so we can easily create arcs to connect them
    CGPoint corners[4][3] =
    {
        {
            { rc.left, rc.top + radius },
            { rc.left, rc.top },
            { rc.left + radius, rc.top },
        },
        {
            { rc.right - radius - 1, rc.top },
            { rc.right - 1, rc.top },
            { rc.right - 1, rc.top + radius },
        },
        {
            { rc.right - 1, rc.bottom - radius - 1 },
            { rc.right - 1, rc.bottom - 1 },
            { rc.right - radius - 1, rc.bottom - 1 },
        },
        {
            { rc.left + radius, rc.bottom - 1 },
            { rc.left, rc.bottom - 1 },
            { rc.left, rc.bottom - radius - 1 },
        },
    };
    
    // Align the points in the middle of the pixels
    for( int i = 0; i < 4; ++ i )
    {
        for( int j = 0; j < 3; ++ j )
        {
            corners[i][j].x += 0.5;
            corners[i][j].y += 0.5;
        }
    }
    
    PenColour( fore );
    FillColour( back );
    
    // Move to the last point to begin the path
    CGContextBeginPath( gc );
    CGContextMoveToPoint( gc, corners[3][2].x, corners[3][2].y );
    
    for ( int i = 0; i < 4; ++ i )
    {
        CGContextAddLineToPoint( gc, corners[i][0].x, corners[i][0].y );
        CGContextAddArcToPoint( gc, corners[i][1].x, corners[i][1].y, corners[i][2].x, corners[i][2].y, radius );
    }
    
    // Close the path to enclose it for stroking and for filling, then draw it
    CGContextClosePath( gc );
    CGContextDrawPath( gc, kCGPathFillStroke );
}

// DrawChamferedRectangle is a helper function for AlphaRectangle that either fills or strokes a
// rectangle with its corners chamfered at 45 degrees.
static void DrawChamferedRectangle(CGContextRef gc, PRectangle rc, int cornerSize, CGPathDrawingMode mode) {
    // Points go clockwise, starting from just below the top left
    CGPoint corners[4][2] =
    {
        {
            { rc.left, rc.top + cornerSize },
            { rc.left + cornerSize, rc.top },
        },
        {
            { rc.right - cornerSize - 1, rc.top },
            { rc.right - 1, rc.top + cornerSize },
        },
        {
            { rc.right - 1, rc.bottom - cornerSize - 1 },
            { rc.right - cornerSize - 1, rc.bottom - 1 },
        },
        {
            { rc.left + cornerSize, rc.bottom - 1 },
            { rc.left, rc.bottom - cornerSize - 1 },
        },
    };
    
    // Align the points in the middle of the pixels
    for( int i = 0; i < 4; ++ i )
    {
        for( int j = 0; j < 2; ++ j )
        {
            corners[i][j].x += 0.5;
            corners[i][j].y += 0.5;
        }
    }
    
    // Move to the last point to begin the path
    CGContextBeginPath( gc );
    CGContextMoveToPoint( gc, corners[3][1].x, corners[3][1].y );
    
    for ( int i = 0; i < 4; ++ i )
    {
        CGContextAddLineToPoint( gc, corners[i][0].x, corners[i][0].y );
        CGContextAddLineToPoint( gc, corners[i][1].x, corners[i][1].y );
    }
    
    // Close the path to enclose it for stroking and for filling, then draw it
    CGContextClosePath( gc );
    CGContextDrawPath( gc, mode );
}

void Scintilla::SurfaceImpl::AlphaRectangle(PRectangle rc, int cornerSize, ColourDesired fill, int alphaFill,
                                            ColourDesired outline, int alphaOutline, int /*flags*/)
{
    if ( gc ) {
        // Snap rectangle boundaries to nearest int
        rc.left = lround(rc.left);
        rc.right = lround(rc.right);
        // Set the Fill color to match
        CGContextSetRGBFillColor( gc, fill.GetRed() / 255.0, fill.GetGreen() / 255.0, fill.GetBlue() / 255.0, alphaFill / 255.0 );
        CGContextSetRGBStrokeColor( gc, outline.GetRed() / 255.0, outline.GetGreen() / 255.0, outline.GetBlue() / 255.0, alphaOutline / 255.0 );
        PRectangle rcFill = rc;
        if (cornerSize == 0) {
            // A simple rectangle, no rounded corners
            if ((fill == outline) && (alphaFill == alphaOutline)) {
                // Optimization for simple case
                CGRect rect = PRectangleToCGRect( rcFill );
                CGContextFillRect( gc, rect );
            } else {
                rcFill.left += 1.0;
                rcFill.top += 1.0;
                rcFill.right -= 1.0;
                rcFill.bottom -= 1.0;
                CGRect rect = PRectangleToCGRect( rcFill );
                CGContextFillRect( gc, rect );
                CGContextAddRect( gc, CGRectMake( rc.left + 0.5, rc.top + 0.5, rc.Width() - 1, rc.Height() - 1 ) );
                CGContextStrokePath( gc );
            }
        } else {
            // Approximate rounded corners with 45 degree chamfers.
            // Drawing real circular arcs often leaves some over- or under-drawn pixels.
            if ((fill == outline) && (alphaFill == alphaOutline)) {
                // Specializing this case avoids a few stray light/dark pixels in corners.
                rcFill.left -= 0.5;
                rcFill.top -= 0.5;
                rcFill.right += 0.5;
                rcFill.bottom += 0.5;
                DrawChamferedRectangle( gc, rcFill, cornerSize, kCGPathFill );
            } else {
                rcFill.left += 0.5;
                rcFill.top += 0.5;
                rcFill.right -= 0.5;
                rcFill.bottom -= 0.5;
                DrawChamferedRectangle( gc, rcFill, cornerSize-1, kCGPathFill );
                DrawChamferedRectangle( gc, rc, cornerSize, kCGPathStroke );
            }
        }
    }
}



void SurfaceImpl::DrawRGBAImage(PRectangle rc, int width, int height, const unsigned char *pixelsImage) {
	CGImageRef image = ImageCreateFromRGBA(width, height, pixelsImage, true);
	if (image) {
		CGRect drawRect = CGRectMake(rc.left, rc.top, rc.Width(), rc.Height());
		CGContextDrawImage(gc, drawRect, image);
		CGImageRelease(image);
	}
}

void SurfaceImpl::Ellipse(PRectangle rc, ColourDesired fore, ColourDesired back) {
    // Drawing an ellipse with bezier curves. Code modified from:
    // http://www.codeguru.com/gdi/ellipse.shtml
    // MAGICAL CONSTANT to map ellipse to beziers 2/3*(sqrt(2)-1)
    const double EToBConst = 0.2761423749154;
    
    CGSize offset = CGSizeMake((int)(rc.Width() * EToBConst), (int)(rc.Height() * EToBConst));
    CGPoint centre = CGPointMake((rc.left + rc.right) / 2, (rc.top + rc.bottom) / 2);
    
    // The control point array
    CGPoint cCtlPt[13];
    
    // Assign values to all the control points
    cCtlPt[0].x  =
    cCtlPt[1].x  =
    cCtlPt[11].x =
    cCtlPt[12].x = rc.left + 0.5;
    cCtlPt[5].x  =
    cCtlPt[6].x  =
    cCtlPt[7].x  = rc.right - 0.5;
    cCtlPt[2].x  =
    cCtlPt[10].x = centre.x - offset.width + 0.5;
    cCtlPt[4].x  =
    cCtlPt[8].x  = centre.x + offset.width + 0.5;
    cCtlPt[3].x  =
    cCtlPt[9].x  = centre.x + 0.5;
    
    cCtlPt[2].y  =
    cCtlPt[3].y  =
    cCtlPt[4].y  = rc.top + 0.5;
    cCtlPt[8].y  =
    cCtlPt[9].y  =
    cCtlPt[10].y = rc.bottom - 0.5;
    cCtlPt[7].y  =
    cCtlPt[11].y = centre.y + offset.height + 0.5;
    cCtlPt[1].y =
    cCtlPt[5].y  = centre.y - offset.height + 0.5;
    cCtlPt[0].y =
    cCtlPt[12].y =
    cCtlPt[6].y  = centre.y + 0.5;
    
    FillColour(back);
    PenColour(fore);
    
    CGContextBeginPath( gc );
    CGContextMoveToPoint( gc, cCtlPt[0].x, cCtlPt[0].y );
    
    for ( int i = 1; i < 13; i += 3 )
    {
        CGContextAddCurveToPoint( gc, cCtlPt[i].x, cCtlPt[i].y, cCtlPt[i+1].x, cCtlPt[i+1].y, cCtlPt[i+2].x, cCtlPt[i+2].y );
    }
    
    // Close the path to enclose it for stroking and for filling, then draw it
    CGContextClosePath( gc );
    CGContextDrawPath( gc, kCGPathFillStroke );
}

void SurfaceImpl::CopyImageRectangle(Surface &surfaceSource, PRectangle srcRect, PRectangle dstRect)
{
    SurfaceImpl& source = static_cast<SurfaceImpl &>(surfaceSource);
    CGImageRef image = source.GetImage();
    
    CGRect src = PRectangleToCGRect(srcRect);
    CGRect dst = PRectangleToCGRect(dstRect);
    
    /* source from QuickDrawToQuartz2D.pdf on developer.apple.com */
    float w = (float) CGImageGetWidth(image);
    float h = (float) CGImageGetHeight(image);
    CGRect drawRect = CGRectMake (0, 0, w, h);
    if (!CGRectEqualToRect (src, dst))
    {
        float sx = CGRectGetWidth(dst) / CGRectGetWidth(src);
        float sy = CGRectGetHeight(dst) / CGRectGetHeight(src);
        float dx = CGRectGetMinX(dst) - (CGRectGetMinX(src) * sx);
        float dy = CGRectGetMinY(dst) - (CGRectGetMinY(src) * sy);
        drawRect = CGRectMake (dx, dy, w*sx, h*sy);
    }
    CGContextSaveGState (gc);
    CGContextClipToRect (gc, dst);
    CGContextDrawImage (gc, drawRect, image);
    CGContextRestoreGState (gc);
    CGImageRelease(image);
}

void SurfaceImpl::Copy(PRectangle rc, Scintilla::Point from, Surface &surfaceSource) {
    // Maybe we have to make the Surface two contexts:
    // a bitmap context which we do all the drawing on, and then a "real" context
    // which we copy the output to when we call "Synchronize". Ugh! Gross and slow!
    
    // For now, assume that copy can only be called on PixMap surfaces
    SurfaceImpl& source = static_cast<SurfaceImpl &>(surfaceSource);
    
    // Get the CGImageRef
    CGImageRef image = source.GetImage();
    // If we could not get an image reference, fill the rectangle black
    if ( image == NULL )
    {
        FillRectangle( rc, ColourDesired( 0 ) );
        return;
    }
    
    // Now draw the image on the surface
    
    // Some fancy clipping work is required here: draw only inside of rc
    CGContextSaveGState( gc );
    CGContextClipToRect( gc, PRectangleToCGRect( rc ) );
    
    //Platform::DebugPrintf(stderr, "Copy: CGContextDrawImage: (%d, %d) - (%d X %d)\n", rc.left - from.x, rc.top - from.y, source.bitmapWidth, source.bitmapHeight );
    CGContextDrawImage( gc, CGRectMake( rc.left - from.x, rc.top - from.y, source.bitmapWidth, source.bitmapHeight ), image );
    
    // Undo the clipping fun
    CGContextRestoreGState( gc );
    
    // Done with the image
    CGImageRelease( image );
    image = NULL;
}



void SurfaceImpl::DrawTextNoClip(PRectangle rc, Font &font_, XYPOSITION ybase, const char *s, int len,
                                 ColourDesired fore, ColourDesired back)
{
    FillRectangle(rc, back);
    DrawTextTransparent(rc, font_, ybase, s, len, fore);
}



void SurfaceImpl::DrawTextClipped(PRectangle rc, Font &font_, XYPOSITION ybase, const char *s, int len,
                                  ColourDesired fore, ColourDesired back)
{
    CGContextSaveGState(gc);
    CGContextClipToRect(gc, PRectangleToCGRect(rc));
    DrawTextNoClip(rc, font_, ybase, s, len, fore, back);
    CGContextRestoreGState(gc);
}


static int FontCharacterSet(Font &f)
{
	return [reinterpret_cast<VTLStyle *>(f.GetID()) getCharacterSet];
}

void SurfaceImpl::DrawTextTransparent(PRectangle rc, Font &font_, XYPOSITION ybase, const char *s, int len,
                                      ColourDesired fore)
{
	CFStringEncoding encoding = EncodingFromCharacterSet(unicodeMode, FontCharacterSet(font_));
	ColourDesired colour(fore.AsLong());
	CGColorRef color = CGColorCreateGenericRGB(colour.GetRed()/255.0,colour.GetGreen()/255.0,colour.GetBlue()/255.0,1.0);
    
	VTLStyle *style = reinterpret_cast<VTLStyle *>(font_.GetID());
	[style setCTStyleColor: color];
	
	CGColorRelease(color);
    
	[_textLayout setText: s
                 length: len
               encoding: encoding
                  style:  [reinterpret_cast<VTLStyle *>(font_.GetID()) getCTStyle]];
    
	[_textLayout drawAt: rc.left
                     y: ybase];;
}

static size_t utf8LengthFromLead(unsigned char uch)
{
	if (uch >= (0x80 + 0x40 + 0x20 + 0x10))
    {
		return 4;
	} else if (uch >= (0x80 + 0x40 + 0x20))
    {
		return 3;
	} else if (uch >= (0x80))
    {
		return 2;
	} else
    {
		return 1;
	}
}



void SurfaceImpl::MeasureWidths(Font &font_, const char *s, int len, XYPOSITION *positions)
{
	CFStringEncoding encoding = EncodingFromCharacterSet(unicodeMode, FontCharacterSet(font_));
    
	[_textLayout setText: s
                 length: len
               encoding: encoding
                  style: [reinterpret_cast<VTLStyle *>(font_.GetID()) getCTStyle]];
	
	CTLineRef mLine = [_textLayout getCTLine];
	assert(mLine != NULL);
	
	if (unicodeMode)
    {
		// Map the widths given for UTF-16 characters back onto the UTF-8 input string
		CFIndex fit = [_textLayout stringLength];
		int ui=0;
		const unsigned char *us = reinterpret_cast<const unsigned char *>(s);
		int i=0;
		while (ui<fit) {
			size_t lenChar = utf8LengthFromLead(us[i]);
			size_t codeUnits = (lenChar < 4) ? 1 : 2;
			CGFloat xPosition = CTLineGetOffsetForStringIndex(mLine, ui+1, NULL);
			for (unsigned int bytePos=0; (bytePos<lenChar) && (i<len); bytePos++) {
				positions[i++] = xPosition;
			}
			ui += codeUnits;
		}
		int lastPos = 0;
		if (i > 0)
			lastPos = positions[i-1];
		while (i<len) {
			positions[i++] = lastPos;
		}
	} else if (codePage) {
		int ui = 0;
		for (int i=0;i<len;) {
			size_t lenChar = Platform::IsDBCSLeadByte(codePage, s[i]) ? 2 : 1;
			CGFloat xPosition = CTLineGetOffsetForStringIndex(mLine, ui+1, NULL);
			for (unsigned int bytePos=0; (bytePos<lenChar) && (i<len); bytePos++) {
				positions[i++] = xPosition;
			}
			ui++;
		}
	} else {	// Single byte encoding
		for (int i=0;i<len;i++) {
			CGFloat xPosition = CTLineGetOffsetForStringIndex(mLine, i+1, NULL);
			positions[i] = xPosition;
		}
	}
    
}

XYPOSITION SurfaceImpl::WidthText(Font &font_, const char *s, int len) {
    if (font_.GetID())
    {
        CFStringEncoding encoding = EncodingFromCharacterSet(unicodeMode, FontCharacterSet(font_));
        
        [_textLayout setText: s
                     length: len
                   encoding: encoding
                      style: [reinterpret_cast<VTLStyle *>(font_.GetID()) getCTStyle]];
        
        return [_textLayout MeasureStringWidth];
    }
    return 1;
}

XYPOSITION SurfaceImpl::WidthChar(Font &font_, char ch)
{
    char str[2] = { ch, '\0' };
    
    if (font_.GetID())
    {
        CFStringEncoding encoding = EncodingFromCharacterSet(unicodeMode, FontCharacterSet(font_));

        [_textLayout setText: str
                     length: 1
                   encoding: encoding
                      style: [reinterpret_cast<VTLStyle *>(font_.GetID()) getCTStyle]];
        
        return [_textLayout MeasureStringWidth];
    }
    else
        return 1;
}

// This string contains a good range of characters to test for size.
const char sizeString[] = "`~!@#$%^&*()-_=+\\|[]{};:\"\'<,>.?/1234567890"
"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

XYPOSITION SurfaceImpl::Ascent(Font &font_) {
    if (!font_.GetID())
        return 1;
    
	float ascent = [reinterpret_cast<VTLStyle *>( font_.GetID() ) getAscent];
	return ascent + 0.5;
    
}

XYPOSITION SurfaceImpl::Descent(Font &font_) {
    if (!font_.GetID())
        return 1;
    
	float descent = [reinterpret_cast<VTLStyle *>( font_.GetID() ) getDescent];
	return descent + 0.5;
    
}

XYPOSITION SurfaceImpl::InternalLeading(Font &) {
    return 0;
}

XYPOSITION SurfaceImpl::ExternalLeading(Font &font_) {
    if (!font_.GetID())
        return 1;
    
	float leading = [reinterpret_cast<VTLStyle *>( font_.GetID() ) getLeading];
	return leading + 0.5;
    
}

XYPOSITION SurfaceImpl::Height(Font &font_) {
    
	int ht = Ascent(font_) + Descent(font_);
	return ht;
}

XYPOSITION SurfaceImpl::AverageCharWidth(Font &font_) {
    
    if (!font_.GetID())
        return 1;
    
    const int sizeStringLength = (sizeof( sizeString ) / sizeof( sizeString[0] ) - 1);
    int width = WidthText( font_, sizeString, sizeStringLength  );
    
    return (int) ((width / (float) sizeStringLength) + 0.5);
}

void SurfaceImpl::SetClip(PRectangle rc) {
    CGContextClipToRect( gc, PRectangleToCGRect( rc ) );
}

void SurfaceImpl::FlushCachedState() {
    CGContextSynchronize( gc );
}

void SurfaceImpl::SetUnicodeMode(bool unicodeMode_) {
    unicodeMode = unicodeMode_;
}

void SurfaceImpl::SetDBCSMode(int codePage_) {
    if (codePage_ && (codePage_ != SC_CP_UTF8))
        codePage = codePage_;
}

Surface *Surface::Allocate(int)
{
    return new SurfaceImpl();
}






//----------------- ElapsedTime --------------------------------------------------------------------

// ElapsedTime is used for precise performance measurements during development
// and not for anything a user sees.

ElapsedTime::ElapsedTime() {
    struct timeval curTime;
    gettimeofday( &curTime, NULL );
    
    bigBit = curTime.tv_sec;
    littleBit = curTime.tv_usec;
}

double ElapsedTime::Duration(bool reset) {
    struct timeval curTime;
    gettimeofday( &curTime, NULL );
    long endBigBit = curTime.tv_sec;
    long endLittleBit = curTime.tv_usec;
    double result = 1000000.0 * (endBigBit - bigBit);
    result += endLittleBit - littleBit;
    result /= 1000000.0;
    if (reset) {
        bigBit = endBigBit;
        littleBit = endLittleBit;
    }
    return result;
}

//----------------- DynamicLibrary -----------------------------------------------------------------

/**
 * Implements the platform specific part of library loading.
 * 
 * @param modulePath The path to the module to load.
 * @return A library instance or NULL if the module could not be found or another problem occurred.
 */
DynamicLibrary* DynamicLibrary::Load(const char* /* modulePath */)
{
    // Not implemented.
    return NULL;
}



