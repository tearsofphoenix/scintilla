//
//  VTLPlatform.cpp
//  Scintilla
//
//  Created by Lei on 11/19/13.
//
//

#include "Platform.h"
#include "Scintilla.h"

#import <Foundation/Foundation.h>

using namespace Scintilla;

extern sptr_t scintilla_send_message(void* sci, unsigned int iMessage, uptr_t wParam, sptr_t lParam);

//----------------- Platform -----------------------------------------------------------------------

ColourDesired Platform::Chrome()
{
    return ColourDesired(0xE0, 0xE0, 0xE0);
}

//--------------------------------------------------------------------------------------------------

ColourDesired Platform::ChromeHighlight()
{
    return ColourDesired(0xFF, 0xFF, 0xFF);
}

//--------------------------------------------------------------------------------------------------

/**
 * Returns the currently set system font for the user.
 */
const char *Platform::DefaultFont()
{
    NSString* name = [[NSUserDefaults standardUserDefaults] stringForKey: @"NSFixedPitchFont"];
    return [name UTF8String];
}

//--------------------------------------------------------------------------------------------------

/**
 * Returns the currently set system font size for the user.
 */
int Platform::DefaultFontSize()
{
    return static_cast<int>([[NSUserDefaults standardUserDefaults]
                             integerForKey: @"NSFixedPitchFontSize"]);
}

//--------------------------------------------------------------------------------------------------

/**
 * Returns the time span in which two consecutive mouse clicks must occur to be considered as
 * double click.
 *
 * @return
 */
unsigned int Platform::DoubleClickTime()
{
    float threshold = [[NSUserDefaults standardUserDefaults] floatForKey:
                       @"com.apple.mouse.doubleClickThreshold"];
    if (threshold == 0)
        threshold = 0.5;
    return static_cast<unsigned int>(threshold * 1000.0);
}

//--------------------------------------------------------------------------------------------------

bool Platform::MouseButtonBounce()
{
    return false;
}

//--------------------------------------------------------------------------------------------------

/**
 * Helper method for the backend to reach through to the scintilla window.
 */
long Platform::SendScintilla(WindowID w, unsigned int msg, unsigned long wParam, long lParam)
{
    return scintilla_send_message(w, msg, wParam, lParam);
}

//--------------------------------------------------------------------------------------------------

/**
 * Helper method for the backend to reach through to the scintilla window.
 */
long Platform::SendScintillaPointer(WindowID w, unsigned int msg, unsigned long wParam, void *lParam)
{
    return scintilla_send_message(w, msg, wParam, (long) lParam);
}

//--------------------------------------------------------------------------------------------------

bool Platform::IsDBCSLeadByte(int codePage, char ch)
{
    // Byte ranges found in Wikipedia articles with relevant search strings in each case
    unsigned char uch = static_cast<unsigned char>(ch);
    switch (codePage)
    {
        case 932:
            // Shift_jis
            return ((uch >= 0x81) && (uch <= 0x9F)) ||
            ((uch >= 0xE0) && (uch <= 0xFC));
            // Lead bytes F0 to FC may be a Microsoft addition.
        case 936:
            // GBK
            return (uch >= 0x81) && (uch <= 0xFE);
        case 949:
            // Korean Wansung KS C-5601-1987
            return (uch >= 0x81) && (uch <= 0xFE);
        case 950:
            // Big5
            return (uch >= 0x81) && (uch <= 0xFE);
        case 1361:
            // Korean Johab KS C-5601-1992
            return
            ((uch >= 0x84) && (uch <= 0xD3)) ||
            ((uch >= 0xD8) && (uch <= 0xDE)) ||
            ((uch >= 0xE0) && (uch <= 0xF9));
    }
    return false;
}

//--------------------------------------------------------------------------------------------------

int Platform::DBCSCharLength(int /* codePage */, const char* /* s */)
{
    // DBCS no longer uses this.
    return 1;
}

//--------------------------------------------------------------------------------------------------

int Platform::DBCSCharMaxLength()
{
    return 2;
}

//--------------------------------------------------------------------------------------------------

int Platform::Minimum(int a, int b)
{
    return (a < b) ? a : b;
}

//--------------------------------------------------------------------------------------------------

int Platform::Maximum(int a, int b)
{
    return (a > b) ? a : b;
}

//--------------------------------------------------------------------------------------------------

//#define TRACE
#ifdef TRACE

void Platform::DebugDisplay(const char *s)
{
    fprintf( stderr, "%s", s );
}

//--------------------------------------------------------------------------------------------------

void Platform::DebugPrintf(const char *format, ...)
{
    const int BUF_SIZE = 2000;
    char buffer[BUF_SIZE];
    
    va_list pArguments;
    va_start(pArguments, format);
    vsnprintf(buffer, BUF_SIZE, format, pArguments);
    va_end(pArguments);
    Platform::DebugDisplay(buffer);
}

#else

void Platform::DebugDisplay(const char *) {}

void Platform::DebugPrintf(const char *, ...) {}

#endif

//--------------------------------------------------------------------------------------------------

static bool assertionPopUps = true;

bool Platform::ShowAssertionPopUps(bool assertionPopUps_)
{
    bool ret = assertionPopUps;
    assertionPopUps = assertionPopUps_;
    return ret;
}

//--------------------------------------------------------------------------------------------------

void Platform::Assert(const char *c, const char *file, int line)
{
    char buffer[2000];
    sprintf(buffer, "Assertion [%s] failed at %s %d", c, file, line);
    strcat(buffer, "\r\n");
    Platform::DebugDisplay(buffer);
#ifdef DEBUG
    // Jump into debugger in assert on Mac (CL269835)
    ::Debugger();
#endif
}

//--------------------------------------------------------------------------------------------------

int Platform::Clamp(int val, int minVal, int maxVal)
{
    if (val > maxVal)
        val = maxVal;
    if (val < minVal)
        val = minVal;
    return val;
}
