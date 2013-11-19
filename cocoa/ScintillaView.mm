
/**
 * Implementation of the native Cocoa View that serves as container for the scintilla parts.
 *
 * Created by Mike Lischke.
 *
 * Copyright 2011, 2013, Oracle and/or its affiliates. All rights reserved.
 * Copyright 2009, 2011 Sun Microsystems, Inc. All rights reserved.
 * This file is dual licensed under LGPL v2.1 and the Scintilla license (http://www.scintilla.org/License.txt).
 */

#import "Platform.h"
#import "ScintillaView.h"
#import "ScintillaCocoa.h"
#import "SCIContentView.h"
#import "SCIMarginView.h"

using namespace Scintilla;

// Two additional cursors we need, which aren't provided by Cocoa.
static NSCursor* reverseArrowCursor;
static NSCursor* waitCursor;

NSString *const SCIUpdateUINotification = @"SCIUpdateUI";

/**
 * Provide an NSCursor object that matches the Window::Cursor enumeration.
 */
NSCursor *NSCursorFromEnum(Window::Cursor cursor)
{
    switch (cursor)
    {
        case Window::cursorText:
            return [NSCursor IBeamCursor];
        case Window::cursorArrow:
            return [NSCursor arrowCursor];
        case Window::cursorWait:
            return waitCursor;
        case Window::cursorHoriz:
            return [NSCursor resizeLeftRightCursor];
        case Window::cursorVert:
            return [NSCursor resizeUpDownCursor];
        case Window::cursorReverseArrow:
            return reverseArrowCursor;
        case Window::cursorUp:
        default:
            return [NSCursor arrowCursor];
    }
}


//--------------------------------------------------------------------------------------------------

@implementation ScintillaView

@synthesize scrollView = _scrollView;

/**
 * ScintillaView is a composite control made from an NSView and an embedded NSView that is
 * used as canvas for the output (by the backend, using its CGContext), plus other elements
 * (scrollers, info bar).
 */

//--------------------------------------------------------------------------------------------------

/**
 * Initialize custom cursor.
 */
+ (void) initialize
{
    if (self == [ScintillaView class])
    {
        NSBundle* bundle = [NSBundle bundleForClass: [ScintillaView class]];
        
        NSString* path = [bundle pathForResource: @"mac_cursor_busy" ofType: @"png" inDirectory: nil];
        NSImage* image = [[[NSImage alloc] initWithContentsOfFile: path] autorelease];
        waitCursor = [[NSCursor alloc] initWithImage: image hotSpot: NSMakePoint(2, 2)];
        
        path = [bundle pathForResource: @"mac_cursor_flipped" ofType: @"png" inDirectory: nil];
        image = [[[NSImage alloc] initWithContentsOfFile: path] autorelease];
        reverseArrowCursor = [[NSCursor alloc] initWithImage: image hotSpot: NSMakePoint(12, 2)];
    }
}

//--------------------------------------------------------------------------------------------------

/**
 * Specify the SCIContentView class. Can be overridden in a subclass to provide an SCIContentView subclass.
 */

+ (Class) contentViewClass
{
    return [SCIContentView class];
}

//--------------------------------------------------------------------------------------------------

/**
 * Receives zoom messages, for example when a "pinch zoom" is performed on the trackpad.
 */
- (void) magnifyWithEvent: (NSEvent *) event
{
    zoomDelta += event.magnification * 10.0;
    
    if (fabsf(zoomDelta)>=1.0) {
        long zoomFactor = [self getGeneralProperty: SCI_GETZOOM] + zoomDelta;
        [self setGeneralProperty: SCI_SETZOOM parameter: zoomFactor value:0];
        zoomDelta = 0.0;
    }
}

- (void) beginGestureWithEvent: (NSEvent *) event
{
    zoomDelta = 0.0;
}

//--------------------------------------------------------------------------------------------------

/**
 * Sends a new notification of the given type to the default notification center.
 */
- (void) sendNotification: (NSString*) notificationName
{
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center postNotificationName: notificationName object: self];
}

//--------------------------------------------------------------------------------------------------

/**
 * Called by a connected component (usually the info bar) if something changed there.
 *
 * @param type The type of the notification.
 * @param message Carries the new status message if the type is a status message change.
 * @param location Carries the new location (e.g. caret) if the type is a caret change or similar type.
 * @param location Carries the new zoom value if the type is a zoom change.
 */
- (void) notify: (NotificationType) type message: (NSString*) message location: (NSPoint) location
          value: (float) value
{
    switch (type)
    {
        case IBNZoomChanged:
        {
            // Compute point increase/decrease based on default font size.
            long fontSize = [self getGeneralProperty: SCI_STYLEGETSIZE parameter: STYLE_DEFAULT];
            int zoom = (int) (fontSize * (value - 1));
            [self setGeneralProperty: SCI_SETZOOM value: zoom];
            break;
        }
        default:
            break;
    };
}

//--------------------------------------------------------------------------------------------------

/**
 * Prevents drawing of the inner view to avoid flickering when doing many visual updates
 * (like clearing all marks and setting new ones etc.).
 */
- (void) suspendDrawing: (BOOL) suspend
{
    if (suspend)
        [[self window] disableFlushWindow];
    else
        [[self window] enableFlushWindow];
}

//--------------------------------------------------------------------------------------------------

/**
 * Method receives notifications from Scintilla (e.g. for handling clicks on the
 * folder margin or changes in the editor).
 * A delegate can be set to receive all notifications. If set no handling takes place here, except
 * for action pertaining to internal stuff (like the info bar).
 */
- (void) notification: (Scintilla::SCNotification*)scn
{
    // Parent notification. Details are passed as SCNotification structure.
    
    if (_delegate != nil)
    {
        [_delegate notification: scn];
        
        if (scn->nmhdr.code != SCN_ZOOM
            && scn->nmhdr.code != SCN_UPDATEUI)
        {
            return;
        }
    }
    
    switch (scn->nmhdr.code)
    {
        case SCN_MARGINCLICK:
        {
            if (scn->margin == 2)
            {
                // Click on the folder margin. Toggle the current line if possible.
                long line = [self getGeneralProperty: SCI_LINEFROMPOSITION parameter: scn->position];
                [self setGeneralProperty: SCI_TOGGLEFOLD value: line];
            }
            break;
        };
        case SCN_MODIFIED:
        {
            // Decide depending on the modification type what to do.
            // There can be more than one modification carried by one notification.
            if (scn->modificationType & (SC_MOD_INSERTTEXT | SC_MOD_DELETETEXT))
                [self sendNotification: NSTextDidChangeNotification];
            break;
        }
        case SCN_ZOOM:
        {
            // A zoom change happened. Notify info bar if there is one.
            float zoom = [self getGeneralProperty: SCI_GETZOOM parameter: 0];
            long fontSize = [self getGeneralProperty: SCI_STYLEGETSIZE parameter: STYLE_DEFAULT];
            float factor = (zoom / fontSize) + 1;
            [mInfoBar notify: IBNZoomChanged message: nil location: NSZeroPoint value: factor];
            break;
        }
        case SCN_UPDATEUI:
        {
            // Triggered whenever changes in the UI state need to be reflected.
            // These can be: caret changes, selection changes etc.
            NSPoint caretPosition = _backend->GetCaretPosition();
            [mInfoBar notify: IBNCaretChanged message: nil location: caretPosition value: 0];
            [self sendNotification: SCIUpdateUINotification];
            if (scn->updated & (SC_UPDATE_SELECTION | SC_UPDATE_CONTENT))
            {
                [self sendNotification: NSTextViewDidChangeSelectionNotification];
            }
            break;
        }
        case SCN_FOCUSOUT:
            [self sendNotification: NSTextDidEndEditingNotification];
            break;
        case SCN_FOCUSIN: // Nothing to do for now.
            break;
    }
}

//--------------------------------------------------------------------------------------------------

/**
 * Initialization of the view. Used to setup a few other things we need.
 */
- (id) initWithFrame: (NSRect) frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        mContent = [[[[[self class] contentViewClass] alloc] initWithFrame:NSZeroRect] autorelease];
        mContent.owner = self;
        
        // Initialize the scrollers but don't show them yet.
        // Pick an arbitrary size, just to make NSScroller selecting the proper scroller direction
        // (horizontal or vertical).
        NSRect scrollerRect = NSMakeRect(0, 0, 100, 10);
        
        _scrollView = [[[NSScrollView alloc] initWithFrame: scrollerRect] autorelease];
        [_scrollView setDocumentView: mContent];
        [_scrollView setHasVerticalScroller:YES];
        [_scrollView setHasHorizontalScroller:YES];
        [_scrollView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

        [self addSubview: _scrollView];
        
        marginView = [[SCIMarginView alloc] initWithScrollView: _scrollView];
        marginView.owner = self;
        
        [marginView setRuleThickness:[marginView requiredThickness]];
        
        [_scrollView setVerticalRulerView:marginView];
        [_scrollView setHasHorizontalRuler:NO];
        [_scrollView setHasVerticalRuler:YES];
        [_scrollView setRulersVisible:YES];
        
        _backend = new ScintillaCocoa(mContent, marginView);
        
        // Establish a connection from the back end to this container so we can handle situations
        // which require our attention.
        _backend->SetDelegate(self);
        
        // Setup a special indicator used in the editor to provide visual feedback for
        // input composition, depending on language, keyboard etc.
        [self setColorProperty: SCI_INDICSETFORE parameter: INPUT_INDICATOR fromHTML: @"#FF0000"];
        [self setGeneralProperty: SCI_INDICSETUNDER parameter: INPUT_INDICATOR value: 1];
        [self setGeneralProperty: SCI_INDICSETSTYLE parameter: INPUT_INDICATOR value: INDIC_PLAIN];
        [self setGeneralProperty: SCI_INDICSETALPHA parameter: INPUT_INDICATOR value: 100];
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver: self
                   selector: @selector(applicationDidResignActive:)
                       name: NSApplicationDidResignActiveNotification
                     object: nil];
        
        [center addObserver: self
                   selector: @selector(applicationDidBecomeActive:)
                       name: NSApplicationDidBecomeActiveNotification
                     object: nil];
        
        [[_scrollView contentView] setPostsBoundsChangedNotifications: YES];
        
        [center addObserver: self
                   selector: @selector(scrollerAction:)
                       name: NSViewBoundsDidChangeNotification
                     object: [_scrollView contentView]];
    }
    return self;
}

//--------------------------------------------------------------------------------------------------

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    delete _backend;
    [marginView release];
    [super dealloc];
}

//--------------------------------------------------------------------------------------------------

- (void) applicationDidResignActive: (NSNotification *)note
{
    _backend->ActiveStateChanged(false);
}

//--------------------------------------------------------------------------------------------------

- (void) applicationDidBecomeActive: (NSNotification *)note
{
    _backend->ActiveStateChanged(true);
}

//--------------------------------------------------------------------------------------------------

- (void) viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    
    [self positionSubViews];
    
    // Enable also mouse move events for our window (and so this view).
    [[self window] setAcceptsMouseMovedEvents: YES];
}

//--------------------------------------------------------------------------------------------------

/**
 * Used to position and size the parts of the editor (content, scrollers, info bar).
 */
- (void) positionSubViews
{
    int scrollerWidth = [NSScroller scrollerWidth];
    
    NSSize size = [self frame].size;
    NSRect barFrame = {0, size.height - scrollerWidth, size.width, static_cast<CGFloat>(scrollerWidth)};
    BOOL infoBarVisible = mInfoBar != nil && ![mInfoBar isHidden];
    
    // Horizontal offset of the content. Almost always 0 unless the vertical scroller
    // is on the left side.
    CGFloat contentX = 0;
    NSRect scrollRect = {contentX, 0, size.width, size.height};
    
    // Info bar frame.
    if (infoBarVisible)
    {
        scrollRect.size.height -= scrollerWidth;
        // Initial value already is as if the bar is at top.
        if (!mInfoBarAtTop)
        {
            scrollRect.origin.y += scrollerWidth;
            barFrame.origin.y = 0;
        }
    }
    
    if (!NSEqualRects([_scrollView frame], scrollRect))
    {
        [_scrollView setFrame: scrollRect];
    }
    
    if (infoBarVisible)
        [mInfoBar setFrame: barFrame];
}

//--------------------------------------------------------------------------------------------------

/**
 * Set the width of the margin.
 */
- (void) setMarginWidth: (int) width
{
    if (marginView.ruleThickness != width)
    {
        marginView.marginWidth = width;
        [marginView setRuleThickness:[marginView requiredThickness]];
    }
}

//--------------------------------------------------------------------------------------------------

/**
 * Triggered by one of the scrollers when it gets manipulated by the user. Notify the backend
 * about the change.
 */
- (void) scrollerAction: (id) sender
{
    _backend->UpdateForScroll();
}

//--------------------------------------------------------------------------------------------------

/**
 * Used to reposition our content depending on the size of the view.
 */
- (void) setFrame: (NSRect) newFrame
{
    NSRect previousFrame = [self frame];
    [super setFrame: newFrame];
    [self positionSubViews];
    if (!NSEqualRects(previousFrame, newFrame)) {
        _backend->Resize();
    }
}

//--------------------------------------------------------------------------------------------------

/**
 * Getter for the currently selected text in raw form (no formatting information included).
 * If there is no text available an empty string is returned.
 */
- (NSString*) selectedString
{
    NSString *result = @"";
    
    const long length = _backend->WndProc(SCI_GETSELTEXT, 0, 0);
    if (length > 0)
    {
        std::string buffer(length + 1, '\0');
        try
        {
            _backend->WndProc(SCI_GETSELTEXT, length + 1, (sptr_t) &buffer[0]);
            
            result = [NSString stringWithUTF8String: buffer.c_str()];
        }
        catch (...)
        {
        }
    }
    
    return result;
}

//--------------------------------------------------------------------------------------------------

/**
 * Getter for the current text in raw form (no formatting information included).
 * If there is no text available an empty string is returned.
 */
- (NSString*) string
{
    NSString *result = @"";
    
    const long length = _backend->WndProc(SCI_GETLENGTH, 0, 0);
    if (length > 0)
    {
        std::string buffer(length + 1, '\0');
        try
        {
            _backend->WndProc(SCI_GETTEXT, length + 1, (sptr_t) &buffer[0]);
            
            result = [NSString stringWithUTF8String: buffer.c_str()];
        }
        catch (...)
        {
        }
    }
    
    return result;
}

//--------------------------------------------------------------------------------------------------

/**
 * Setter for the current text (no formatting included).
 */
- (void) setString: (NSString*) aString
{
    const char* text = [aString UTF8String];
    _backend->WndProc(SCI_SETTEXT, 0, (long) text);
}

//--------------------------------------------------------------------------------------------------

- (void) insertString: (NSString*) aString atOffset: (int)offset
{
    const char* text = [aString UTF8String];
    _backend->WndProc(SCI_ADDTEXT, offset, (long) text);
}

//--------------------------------------------------------------------------------------------------

- (void) setEditable: (BOOL) editable
{
    _backend->WndProc(SCI_SETREADONLY, editable ? 0 : 1, 0);
}

//--------------------------------------------------------------------------------------------------

- (BOOL) isEditable
{
    return _backend->WndProc(SCI_GETREADONLY, 0, 0) == 0;
}

//--------------------------------------------------------------------------------------------------

- (SCIContentView*) content
{
    return mContent;
}

//--------------------------------------------------------------------------------------------------

/**
 * Direct call into the backend to allow uninterpreted access to it. The values to be passed in and
 * the result heavily depend on the message that is used for the call. Refer to the Scintilla
 * documentation to learn what can be used here.
 */
+ (sptr_t) directCall: (ScintillaView*) sender message: (unsigned int) message wParam: (uptr_t) wParam
               lParam: (sptr_t) lParam
{
    return ScintillaCocoa::DirectFunction(sender->_backend, message, wParam, lParam);
}

- (sptr_t) message: (unsigned int) message wParam: (uptr_t) wParam lParam: (sptr_t) lParam
{
    return _backend->WndProc(message, wParam, lParam);
}

- (sptr_t) message: (unsigned int) message wParam: (uptr_t) wParam
{
    return _backend->WndProc(message, wParam, 0);
}

- (sptr_t) message: (unsigned int) message
{
    return _backend->WndProc(message, 0, 0);
}

//--------------------------------------------------------------------------------------------------

/**
 * This is a helper method to set properties in the backend, with native parameters.
 *
 * @param property Main property like SCI_STYLESETFORE for which a value is to be set.
 * @param parameter Additional info for this property like a parameter or index.
 * @param value The actual value. It depends on the property what this parameter means.
 */
- (void) setGeneralProperty: (int) property parameter: (long) parameter value: (long) value
{
    _backend->WndProc(property, parameter, value);
}

//--------------------------------------------------------------------------------------------------

/**
 * A simplified version for setting properties which only require one parameter.
 *
 * @param property Main property like SCI_STYLESETFORE for which a value is to be set.
 * @param value The actual value. It depends on the property what this parameter means.
 */
- (void) setGeneralProperty: (int) property value: (long) value
{
    _backend->WndProc(property, value, 0);
}

//--------------------------------------------------------------------------------------------------

/**
 * This is a helper method to get a property in the backend, with native parameters.
 *
 * @param property Main property like SCI_STYLESETFORE for which a value is to get.
 * @param parameter Additional info for this property like a parameter or index.
 * @param extra Yet another parameter if needed.
 * @result A generic value which must be interpreted depending on the property queried.
 */
- (long) getGeneralProperty: (int) property parameter: (long) parameter extra: (long) extra
{
    return _backend->WndProc(property, parameter, extra);
}

//--------------------------------------------------------------------------------------------------

/**
 * Convenience function to avoid unneeded extra parameter.
 */
- (long) getGeneralProperty: (int) property parameter: (long) parameter
{
    return _backend->WndProc(property, parameter, 0);
}

//--------------------------------------------------------------------------------------------------

/**
 * Convenience function to avoid unneeded parameters.
 */
- (long) getGeneralProperty: (int) property
{
    return _backend->WndProc(property, 0, 0);
}

//--------------------------------------------------------------------------------------------------

/**
 * Use this variant if you have to pass in a reference to something (e.g. a text range).
 */
- (long) getGeneralProperty: (int) property ref: (const void*) ref
{
    return _backend->WndProc(property, 0, (sptr_t) ref);
}

//--------------------------------------------------------------------------------------------------

/**
 * Specialized property setter for colors.
 */
- (void) setColorProperty: (int) property parameter: (long) parameter value: (NSColor*) value
{
    if ([value colorSpaceName] != NSDeviceRGBColorSpace)
        value = [value colorUsingColorSpaceName: NSDeviceRGBColorSpace];
    long red = [value redComponent] * 255;
    long green = [value greenComponent] * 255;
    long blue = [value blueComponent] * 255;
    
    long color = (blue << 16) + (green << 8) + red;
    _backend->WndProc(property, parameter, color);
}

//--------------------------------------------------------------------------------------------------

/**
 * Another color property setting, which allows to specify the color as string like in HTML
 * documents (i.e. with leading # and either 3 hex digits or 6).
 */
- (void) setColorProperty: (int) property parameter: (long) parameter fromHTML: (NSString*) fromHTML
{
    if ([fromHTML length] > 3 && [fromHTML characterAtIndex: 0] == '#')
    {
        bool longVersion = [fromHTML length] > 6;
        int index = 1;
        
        char value[3] = {0, 0, 0};
        value[0] = [fromHTML characterAtIndex: index++];
        if (longVersion)
            value[1] = [fromHTML characterAtIndex: index++];
        else
            value[1] = value[0];
        
        unsigned rawRed;
        [[NSScanner scannerWithString: [NSString stringWithUTF8String: value]] scanHexInt: &rawRed];
        
        value[0] = [fromHTML characterAtIndex: index++];
        if (longVersion)
            value[1] = [fromHTML characterAtIndex: index++];
        else
            value[1] = value[0];
        
        unsigned rawGreen;
        [[NSScanner scannerWithString: [NSString stringWithUTF8String: value]] scanHexInt: &rawGreen];
        
        value[0] = [fromHTML characterAtIndex: index++];
        if (longVersion)
            value[1] = [fromHTML characterAtIndex: index++];
        else
            value[1] = value[0];
        
        unsigned rawBlue;
        [[NSScanner scannerWithString: [NSString stringWithUTF8String: value]] scanHexInt: &rawBlue];
        
        long color = (rawBlue << 16) + (rawGreen << 8) + rawRed;
        _backend->WndProc(property, parameter, color);
    }
}

//--------------------------------------------------------------------------------------------------

/**
 * Specialized property getter for colors.
 */
- (NSColor*) getColorProperty: (int) property parameter: (long) parameter
{
    long color = _backend->WndProc(property, parameter, 0);
    float red = (color & 0xFF) / 255.0;
    float green = ((color >> 8) & 0xFF) / 255.0;
    float blue = ((color >> 16) & 0xFF) / 255.0;
    NSColor* result = [NSColor colorWithDeviceRed: red green: green blue: blue alpha: 1];
    return result;
}

//--------------------------------------------------------------------------------------------------

/**
 * Specialized property setter for references (pointers, addresses).
 */
- (void) setReferenceProperty: (int) property
                    parameter: (long) parameter
                        value: (const void*) value
{
    _backend->WndProc(property, parameter, (sptr_t) value);
}

//--------------------------------------------------------------------------------------------------

/**
 * Specialized property getter for references (pointers, addresses).
 */
- (const void*) getReferenceProperty: (int) property parameter: (long) parameter
{
    return (const void*) _backend->WndProc(property, parameter, 0);
}

//--------------------------------------------------------------------------------------------------

/**
 * Specialized property setter for string values.
 */
- (void) setStringProperty: (int)property
                 parameter: (long)parameter
                     value: (NSString*)value
{
    const char* rawValue = [value UTF8String];
    _backend->WndProc(property, parameter, (sptr_t) rawValue);
}


//--------------------------------------------------------------------------------------------------

/**
 * Specialized property getter for string values.
 */
- (NSString*) getStringProperty: (int) property parameter: (long) parameter
{
    const char* rawValue = (const char*) _backend->WndProc(property, parameter, 0);
    return [NSString stringWithUTF8String: rawValue];
}

//--------------------------------------------------------------------------------------------------

/**
 * Specialized property setter for lexer properties, which are commonly passed as strings.
 */
- (void) setLexerProperty: (NSString*) name value: (NSString*) value
{
    const char* rawName = [name UTF8String];
    const char* rawValue = [value UTF8String];
    _backend->WndProc(SCI_SETPROPERTY, (sptr_t) rawName, (sptr_t) rawValue);
}

//--------------------------------------------------------------------------------------------------

/**
 * Specialized property getter for references (pointers, addresses).
 */
- (NSString*) getLexerProperty: (NSString*) name
{
    const char* rawName = [name UTF8String];
    const char* result = (const char*) _backend->WndProc(SCI_SETPROPERTY, (sptr_t) rawName, 0);
    return [NSString stringWithUTF8String: result];
}

//--------------------------------------------------------------------------------------------------

/**
 * Sets the notification callback
 */
- (void) registerNotifyCallback: (intptr_t) windowid value: (Scintilla::SciNotifyFunc) callback
{
	_backend->RegisterNotifyCallback(windowid, callback);
}


//--------------------------------------------------------------------------------------------------

/**
 * Sets the new control which is displayed as info bar at the top or bottom of the editor.
 * Set newBar to nil if you want to hide the bar again.
 * The info bar's height is set to the height of the scrollbar.
 */
- (void) setInfoBar: (NSView <InfoBarCommunicator>*) newBar top: (BOOL) top
{
    if (mInfoBar != newBar)
    {
        [mInfoBar removeFromSuperview];
        
        mInfoBar = newBar;
        mInfoBarAtTop = top;
        if (mInfoBar != nil)
        {
            [self addSubview: mInfoBar];
            [mInfoBar setCallback: self];
        }
        
        [self positionSubViews];
    }
}

//--------------------------------------------------------------------------------------------------

/**
 * Sets the edit's info bar status message. This call only has an effect if there is an info bar.
 */
- (void) setStatusText: (NSString*) text
{
    if (mInfoBar != nil)
        [mInfoBar notify: IBNStatusChanged message: text location: NSZeroPoint value: 0];
}

//--------------------------------------------------------------------------------------------------

- (NSRange) selectedRange
{
    return [mContent selectedRange];
}

//--------------------------------------------------------------------------------------------------

- (void)insertText: (NSString*)text
{
    _backend->InsertText(text);
}

//--------------------------------------------------------------------------------------------------

/**
 * For backwards compatibility.
 */
- (BOOL) findAndHighlightText: (NSString*) searchText
                    matchCase: (BOOL) matchCase
                    wholeWord: (BOOL) wholeWord
                     scrollTo: (BOOL) scrollTo
                         wrap: (BOOL) wrap
{
    return [self findAndHighlightText: searchText
                            matchCase: matchCase
                            wholeWord: wholeWord
                             scrollTo: scrollTo
                                 wrap: wrap
                            backwards: NO];
}

//--------------------------------------------------------------------------------------------------

/**
 * Searches and marks the first occurrence of the given text and optionally scrolls it into view.
 *
 * @result YES if something was found, NO otherwise.
 */
- (BOOL) findAndHighlightText: (NSString*) searchText
                    matchCase: (BOOL) matchCase
                    wholeWord: (BOOL) wholeWord
                     scrollTo: (BOOL) scrollTo
                         wrap: (BOOL) wrap
                    backwards: (BOOL) backwards
{
    int searchFlags= 0;
    if (matchCase)
        searchFlags |= SCFIND_MATCHCASE;
    if (wholeWord)
        searchFlags |= SCFIND_WHOLEWORD;
    
    int selectionStart = [self getGeneralProperty: SCI_GETSELECTIONSTART parameter: 0];
    int selectionEnd = [self getGeneralProperty: SCI_GETSELECTIONEND parameter: 0];
    
    // Sets the start point for the coming search to the beginning of the current selection.
    // For forward searches we have therefore to set the selection start to the current selection end
    // for proper incremental search. This does not harm as we either get a new selection if something
    // is found or the previous selection is restored.
    if (!backwards)
        [self getGeneralProperty: SCI_SETSELECTIONSTART parameter: selectionEnd];
    [self setGeneralProperty: SCI_SEARCHANCHOR value: 0];
    sptr_t result;
    const char* textToSearch = [searchText UTF8String];
    
    // The following call will also set the selection if something was found.
    if (backwards)
    {
        result = [ScintillaView directCall: self
                                   message: SCI_SEARCHPREV
                                    wParam: searchFlags
                                    lParam: (sptr_t) textToSearch];
        if (result < 0 && wrap)
        {
            // Try again from the end of the document if nothing could be found so far and
            // wrapped search is set.
            [self getGeneralProperty: SCI_SETSELECTIONSTART parameter: [self getGeneralProperty: SCI_GETTEXTLENGTH parameter: 0]];
            [self setGeneralProperty: SCI_SEARCHANCHOR value: 0];
            result = [ScintillaView directCall: self
                                       message: SCI_SEARCHNEXT
                                        wParam: searchFlags
                                        lParam: (sptr_t) textToSearch];
        }
    }
    else
    {
        result = [ScintillaView directCall: self
                                   message: SCI_SEARCHNEXT
                                    wParam: searchFlags
                                    lParam: (sptr_t) textToSearch];
        if (result < 0 && wrap)
        {
            // Try again from the start of the document if nothing could be found so far and
            // wrapped search is set.
            [self getGeneralProperty: SCI_SETSELECTIONSTART parameter: 0];
            [self setGeneralProperty: SCI_SEARCHANCHOR value: 0];
            result = [ScintillaView directCall: self
                                       message: SCI_SEARCHNEXT
                                        wParam: searchFlags
                                        lParam: (sptr_t) textToSearch];
        }
    }
    
    if (result >= 0)
    {
        if (scrollTo)
            [self setGeneralProperty: SCI_SCROLLCARET value: 0];
    }
    else
    {
        // Restore the former selection if we did not find anything.
        [self setGeneralProperty: SCI_SETSELECTIONSTART value: selectionStart];
        [self setGeneralProperty: SCI_SETSELECTIONEND value: selectionEnd];
    }
    return (result >= 0) ? YES : NO;
}

//--------------------------------------------------------------------------------------------------

/**
 * Searches the given text and replaces
 *
 * @result Number of entries replaced, 0 if none.
 */
- (int) findAndReplaceText: (NSString*) searchText
                    byText: (NSString*) newText
                 matchCase: (BOOL) matchCase
                 wholeWord: (BOOL) wholeWord
                     doAll: (BOOL) doAll
{
    // The current position is where we start searching for single occurrences. Otherwise we start at
    // the beginning of the document.
    int startPosition;
    if (doAll)
        startPosition = 0; // Start at the beginning of the text if we replace all occurrences.
    else
        // For a single replacement we start at the current caret position.
        startPosition = [self getGeneralProperty: SCI_GETCURRENTPOS];
    int endPosition = [self getGeneralProperty: SCI_GETTEXTLENGTH];
    
    int searchFlags= 0;
    if (matchCase)
        searchFlags |= SCFIND_MATCHCASE;
    if (wholeWord)
        searchFlags |= SCFIND_WHOLEWORD;
    [self setGeneralProperty: SCI_SETSEARCHFLAGS value: searchFlags];
    [self setGeneralProperty: SCI_SETTARGETSTART value: startPosition];
    [self setGeneralProperty: SCI_SETTARGETEND value: endPosition];
    
    const char* textToSearch = [searchText UTF8String];
    int sourceLength = strlen(textToSearch); // Length in bytes.
    const char* replacement = [newText UTF8String];
    int targetLength = strlen(replacement);  // Length in bytes.
    sptr_t result;
    
    int replaceCount = 0;
    if (doAll)
    {
        while (true)
        {
            result = [ScintillaView directCall: self
                                       message: SCI_SEARCHINTARGET
                                        wParam: sourceLength
                                        lParam: (sptr_t) textToSearch];
            if (result < 0)
                break;
            
            replaceCount++;
            [ScintillaView directCall: self
                              message: SCI_REPLACETARGET
                               wParam: targetLength
                               lParam: (sptr_t) replacement];
            
            // The replacement changes the target range to the replaced text. Continue after that till the end.
            // The text length might be changed by the replacement so make sure the target end is the actual
            // text end.
            [self setGeneralProperty: SCI_SETTARGETSTART value: [self getGeneralProperty: SCI_GETTARGETEND]];
            [self setGeneralProperty: SCI_SETTARGETEND value: [self getGeneralProperty: SCI_GETTEXTLENGTH]];
        }
    }
    else
    {
        result = [ScintillaView directCall: self
                                   message: SCI_SEARCHINTARGET
                                    wParam: sourceLength
                                    lParam: (sptr_t) textToSearch];
        replaceCount = (result < 0) ? 0 : 1;
        
        if (replaceCount > 0)
        {
            [ScintillaView directCall: self
                              message: SCI_REPLACETARGET
                               wParam: targetLength
                               lParam: (sptr_t) replacement];
            
            // For a single replace we set the new selection to the replaced text.
            [self setGeneralProperty: SCI_SETSELECTIONSTART value: [self getGeneralProperty: SCI_GETTARGETSTART]];
            [self setGeneralProperty: SCI_SETSELECTIONEND value: [self getGeneralProperty: SCI_GETTARGETEND]];
        }
    }
    
    return replaceCount;
}

//--------------------------------------------------------------------------------------------------

- (void) setFontName: (NSString*) font
                size: (int) size
                bold: (BOOL) bold
              italic: (BOOL) italic
{
    for (int i = 0; i < 128; i++)
    {
        [self setGeneralProperty: SCI_STYLESETFONT
                       parameter: i
                           value: (sptr_t)[font UTF8String]];
        [self setGeneralProperty: SCI_STYLESETSIZE
                       parameter: i
                           value: size];
        [self setGeneralProperty: SCI_STYLESETBOLD
                       parameter: i
                           value: bold];
        [self setGeneralProperty: SCI_STYLESETITALIC
                       parameter: i
                           value: italic];
    }
}

//--------------------------------------------------------------------------------------------------

@end

