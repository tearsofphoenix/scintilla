//
//  VTLWindow.mm
//  Scintilla
//
//  Created by Lei on 11/19/13.
//
//

#include "Platform.h"
#include "Scintilla.h"
#include "ScintillaView.h"
#include "SCIController.h"
#include "PlatCocoa.h"
#import "SCIContentView.h"

#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <assert.h>
#include <sys/time.h>
#include <stdexcept>
#include <vector>
#include <map>

#import "XPM.h"

#import <Foundation/Foundation.h>

using namespace Scintilla;

//----------------- Window -------------------------------------------------------------------------

// Cocoa uses different types for windows and views, so a Window may
// be either an NSWindow or NSView and the code will check the type
// before performing an action.

Window::~Window()
{
}



void Window::Destroy()
{
    if (wid)
    {
        id idWin = reinterpret_cast<id>(wid);
        if ([idWin isKindOfClass: [NSWindow class]])
        {
            NSWindow* win = reinterpret_cast<NSWindow*>(idWin);
            [win release];
        }
    }
    wid = 0;
}



bool Window::HasFocus()
{
    NSView* container = reinterpret_cast<NSView*>(wid);
    return [[container window] firstResponder] == container;
}



static int ScreenMax(NSWindow* win)
{
    NSScreen* screen = [win screen];
    NSRect frame = [screen frame];
    return frame.origin.y + frame.size.height;
}

PRectangle Window::GetPosition()
{
    if (wid)
    {
        NSRect rect;
        id idWin = reinterpret_cast<id>(wid);
        NSWindow* win;
        if ([idWin isKindOfClass: [NSView class]])
        {
            // NSView
            NSView* view = reinterpret_cast<NSView*>(idWin);
            win = [view window];
            rect = [view convertRect: [view bounds] toView: nil];
            rect.origin = [win convertBaseToScreen:rect.origin];
        }
        else
        {
            // NSWindow
            win = reinterpret_cast<NSWindow*>(idWin);
            rect = [win frame];
        }
        int screenHeight = ScreenMax(win);
        // Invert screen positions to match Scintilla
        return PRectangle(
                          NSMinX(rect), screenHeight - NSMaxY(rect),
                          NSMaxX(rect), screenHeight - NSMinY(rect));
    }
    else
    {
        return PRectangle(0, 0, 1, 1);
    }
}



void Window::SetPosition(PRectangle rc)
{
    if (wid)
    {
        id idWin = reinterpret_cast<id>(wid);
        if ([idWin isKindOfClass: [NSView class]])
        {
            // NSView
            // Moves this view inside the parent view
            NSRect nsrc = NSMakeRect(rc.left, rc.bottom, rc.Width(), rc.Height());
            NSView* view = reinterpret_cast<NSView*>(idWin);
            nsrc.origin = [[view window] convertScreenToBase:nsrc.origin];
            [view setFrame: nsrc];
        }
        else
        {
            // NSWindow
            NSWindow* win = reinterpret_cast<NSWindow*>(idWin);
            int screenHeight = ScreenMax(win);
            NSRect nsrc = NSMakeRect(rc.left, screenHeight - rc.bottom,
                                     rc.Width(), rc.Height());
            [win setFrame: nsrc display:YES];
        }
    }
}



void Window::SetPositionRelative(PRectangle rc, Window window)
{
    PRectangle rcOther = window.GetPosition();
    rc.left += rcOther.left;
    rc.right += rcOther.left;
    rc.top += rcOther.top;
    rc.bottom += rcOther.top;
    SetPosition(rc);
}



PRectangle Window::GetClientPosition()
{
    // This means, in MacOS X terms, get the "frame bounds". Call GetPosition, just like on Win32.
    return GetPosition();
}



void Window::Show(bool show)
{
    if (wid)
    {
        id idWin = reinterpret_cast<id>(wid);
        if ([idWin isKindOfClass: [NSWindow class]])
        {
            NSWindow* win = reinterpret_cast<NSWindow*>(idWin);
            
            if (show)
            {
                [win orderFront: nil];
                
            }else
            {
                [win orderOut: nil];
            }
        }
    }
}



/**
 * Invalidates the entire window or view so it is completely redrawn.
 */
void Window::InvalidateAll()
{
    if (wid)
    {
        id idWin = reinterpret_cast<id>(wid);
        NSView* container;
        if ([idWin isKindOfClass: [NSView class]])
        {
            container = reinterpret_cast<NSView*>(idWin);
        }
        else
        {
            // NSWindow
            NSWindow* win = reinterpret_cast<NSWindow*>(idWin);
            container = reinterpret_cast<NSView*>([win contentView]);
            container.needsDisplay = YES;
        }
        container.needsDisplay = YES;
    }
}



/**
 * Invalidates part of the window or view so only this part redrawn.
 */
void Window::InvalidateRectangle(PRectangle rc)
{
    if (wid)
    {
        id idWin = reinterpret_cast<id>(wid);
        NSView* container;
        if ([idWin isKindOfClass: [NSView class]])
        {
            container = reinterpret_cast<NSView*>(idWin);
        }
        else
        {
            // NSWindow
            NSWindow* win = reinterpret_cast<NSWindow*>(idWin);
            container = reinterpret_cast<NSView*>([win contentView]);
        }
        [container setNeedsDisplayInRect: PRectangleToNSRect(rc)];
    }
}



void Window::SetFont(Font&)
{
    // Implemented on list subclass on Cocoa.
}



/**
 * Converts the Scintilla cursor enum into an NSCursor and stores it in the associated NSView,
 * which then will take care to set up a new mouse tracking rectangle.
 */
void Window::SetCursor(Cursor curs)
{
    if (wid)
    {
        id idWin = reinterpret_cast<id>(wid);
        if ([idWin isMemberOfClass: [SCIContentView class]])
        {
            SCIContentView* container = reinterpret_cast<SCIContentView*>(idWin);
            [container setCursor: curs];
        }
    }
}



void Window::SetTitle(const char* s)
{
    if (wid)
    {
        id idWin = reinterpret_cast<id>(wid);
        if ([idWin isKindOfClass: [NSWindow class]])
        {
            NSWindow* win = reinterpret_cast<NSWindow*>(idWin);
            [win setTitle: @(s)];
        }
    }
}



PRectangle Window::GetMonitorRect(Point)
{
    if (wid)
    {
        id idWin = reinterpret_cast<id>(wid);
        if ([idWin isKindOfClass: [NSWindow class]])
        {
            NSWindow* win = reinterpret_cast<NSWindow*>(idWin);
            NSScreen* screen = [win screen];
            NSRect rect = [screen frame];

            int screenHeight = rect.origin.y + rect.size.height;
            // Invert screen positions to match Scintilla
            //
            return PRectangle(NSMinX(rect), screenHeight - NSMaxY(rect),
                              NSMaxX(rect), screenHeight - NSMinY(rect));
        }
    }
    return PRectangle();
}
