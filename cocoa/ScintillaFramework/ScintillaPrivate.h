//
//  ScintillaPrivate.h
//  ScintillaFramework
//
//  Created by Lei on 11/19/13.
//
//

#import "Platform.h"
#import <Cocoa/Cocoa.h>

extern NSCursor *NSCursorFromEnum(Scintilla::Window::Cursor cursor);

extern CGImageRef ImageCreateFromRGBA(int width, int height, const unsigned char *pixelsImage, bool invert);