/**
 * AppController.m
 * ScintillaTest
 *
 * Created by Mike Lischke on 01.04.09.
 * Copyright 2009 Sun Microsystems, Inc. All rights reserved.
 * This file is dual licensed under LGPL v2.1 and the Scintilla license (http://www.scintilla.org/License.txt).
 */

#import "AppController.h"
#import "VEBundle.h"

const char major_keywords[] =
"and       break     do        else      elseif    end "
" false     for       function  goto      if        in "
" local     nil       not       or        repeat    return "
" then      true      until     while";



@implementation AppController

- (void) awakeFromNib
{
//    VEBundle *luaBundle = [[VEBundle alloc] initWithPath: [[NSBundle mainBundle] pathForResource: @"Lua"
//                                                                                          ofType: @"tmbundle"]];
//    
    
    // Manually set up the scintilla editor. Create an instance and dock it to our edit host.
    // Leave some free space around the new view to avoid overlapping with the box borders.
    NSRect newFrame = mEditHost.frame;
    newFrame.size.width -= 2 * newFrame.origin.x;
    newFrame.size.height -= 2 * newFrame.origin.y;
    
    mEditor = [[ScintillaView alloc] initWithFrame: newFrame];
    
    [mEditHost addSubview: mEditor];
    [mEditor setAutoresizesSubviews: YES];
    [mEditor setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    
    // Let's load some text for the editor, as initial content.
    NSError* error = nil;
    
    NSString* path = [[NSBundle mainBundle] pathForResource: @"TestData"
                                                     ofType: @"lua"
                                                inDirectory: nil];
    
    NSString* sql = [NSString stringWithContentsOfFile: path
                                              encoding: NSUTF8StringEncoding
                                                 error: &error];
    if (error && [[error domain] isEqual: NSCocoaErrorDomain])
    {
        NSLog(@"%@", error);
    }
    
    [mEditor setString: sql];
    
    [self setupEditor];
}



/**
 * Initialize scintilla editor (styles, colors, markers, folding etc.].
 */
- (void) setupEditor
{
    [mEditor setGeneralProperty: SCI_SETLEXER
                      parameter: SCLEX_LUA
                          value: 0];
    
    // Number of styles we use with this lexer.
    [mEditor setGeneralProperty: SCI_SETSTYLEBITS
                          value: [mEditor getGeneralProperty: SCI_GETSTYLEBITSNEEDED]];
    
    // Keywords to highlight. Indices are:
    // 0 - Major keywords (reserved keywords)
    // 1 - Normal keywords (everything not reserved but integral part of the language)
    // 2 - Database objects
    // 3 - Function keywords
    // 4 - System variable keywords
    // 5 - Procedure keywords (keywords used in procedures like "begin" and "end")
    // 6..8 - User keywords 1..3
    [mEditor setReferenceProperty: SCI_SETKEYWORDS
                        parameter: 0
                            value: major_keywords];
    
    // Colors and styles for various syntactic elements. First the default style.
    [mEditor setStringProperty: SCI_STYLESETFONT
                     parameter: STYLE_DEFAULT
                         value: @"Menlo-Regular"];
    
    [mEditor setGeneralProperty: SCI_STYLESETSIZE
                      parameter: STYLE_DEFAULT
                          value: 14];
    [mEditor setColorProperty: SCI_STYLESETFORE
                    parameter: STYLE_DEFAULT
                        value: [NSColor blackColor]];
    
    [mEditor setGeneralProperty: SCI_STYLECLEARALL parameter: 0 value: 0];
    
    [mEditor setColorProperty: SCI_STYLESETFORE
                    parameter: SCE_LUA_DEFAULT
                        value: [NSColor blackColor]];
    [mEditor setColorProperty: SCI_STYLESETFORE
                    parameter: SCE_LUA_COMMENT
                     fromHTML: @"#097BF7"];
    [mEditor setColorProperty: SCI_STYLESETFORE
                    parameter: SCE_LUA_COMMENTLINE
                     fromHTML: @"#097BF7"];
    
    [mEditor setColorProperty: SCI_STYLESETFORE parameter: SCE_LUA_NUMBER fromHTML: @"#7F7F00"];
    [mEditor setColorProperty: SCI_STYLESETFORE
                    parameter: SCE_LUA_STRING
                     fromHTML: @"#D13D9C"];
    [mEditor setColorProperty: SCI_STYLESETFORE
                    parameter: SCE_LUA_LITERALSTRING
                     fromHTML: @"#D13D9C"];

    [mEditor setColorProperty: SCI_STYLESETFORE
                    parameter: SCE_LUA_CHARACTER
                     fromHTML: @"#D13D9C"];

    
    
    // Note: if we were using ANSI quotes we would set the DQSTRING to the same color as the
    //       the back tick string.
    
    // Keyword highlighting.
    [mEditor setColorProperty: SCI_STYLESETFORE parameter: SCE_LUA_WORD fromHTML: @"#007F00"];

    // The following 3 styles have no impact as we did not set a keyword list for any of them.

    [mEditor setColorProperty: SCI_STYLESETFORE parameter: SCE_LUA_IDENTIFIER value: [NSColor blackColor]];
    
    // Line number style.
    [mEditor setColorProperty: SCI_STYLESETFORE parameter: STYLE_LINENUMBER fromHTML: @"#F0F0F0"];
    [mEditor setColorProperty: SCI_STYLESETBACK parameter: STYLE_LINENUMBER fromHTML: @"#808080"];
    
    [mEditor setGeneralProperty: SCI_SETMARGINTYPEN parameter: 0 value: SC_MARGIN_NUMBER];
	[mEditor setGeneralProperty: SCI_SETMARGINWIDTHN parameter: 0 value: 35];
    
    // Markers.
    [mEditor setGeneralProperty: SCI_SETMARGINWIDTHN parameter: 1 value: 16];
    
    // Some special lexer properties.
    [mEditor setLexerProperty: @"fold" value: @"1"];
    [mEditor setLexerProperty: @"fold.compact" value: @"0"];
    [mEditor setLexerProperty: @"fold.comment" value: @"1"];
    [mEditor setLexerProperty: @"fold.preprocessor" value: @"1"];
    
    // Folder setup.
    [mEditor setGeneralProperty: SCI_SETMARGINWIDTHN parameter: 2 value: 16];
    [mEditor setGeneralProperty: SCI_SETMARGINMASKN parameter: 2 value: SC_MASK_FOLDERS];
    [mEditor setGeneralProperty: SCI_SETMARGINSENSITIVEN parameter: 2 value: 1];
    [mEditor setGeneralProperty: SCI_MARKERDEFINE parameter: SC_MARKNUM_FOLDEROPEN value: SC_MARK_BOXMINUS];
    [mEditor setGeneralProperty: SCI_MARKERDEFINE parameter: SC_MARKNUM_FOLDER value: SC_MARK_BOXPLUS];
    [mEditor setGeneralProperty: SCI_MARKERDEFINE parameter: SC_MARKNUM_FOLDERSUB value: SC_MARK_VLINE];
    [mEditor setGeneralProperty: SCI_MARKERDEFINE parameter: SC_MARKNUM_FOLDERTAIL value: SC_MARK_LCORNER];
    [mEditor setGeneralProperty: SCI_MARKERDEFINE parameter: SC_MARKNUM_FOLDEREND value: SC_MARK_BOXPLUSCONNECTED];
    [mEditor setGeneralProperty: SCI_MARKERDEFINE parameter: SC_MARKNUM_FOLDEROPENMID value: SC_MARK_BOXMINUSCONNECTED];
    [mEditor setGeneralProperty: SCI_MARKERDEFINE parameter: SC_MARKNUM_FOLDERMIDTAIL value: SC_MARK_TCORNER];
    
    for (int n= 25; n < 32; ++n) // Markers 25..31 are reserved for folding.
    {
        [mEditor setColorProperty: SCI_MARKERSETFORE parameter: n value: [NSColor whiteColor]];
        [mEditor setColorProperty: SCI_MARKERSETBACK parameter: n value: [NSColor blackColor]];
    }
    
    // Init markers & indicators for highlighting of syntax errors.
    [mEditor setColorProperty: SCI_INDICSETFORE parameter: 0 value: [NSColor redColor]];
    [mEditor setGeneralProperty: SCI_INDICSETUNDER parameter: 0 value: 1];
    [mEditor setGeneralProperty: SCI_INDICSETSTYLE parameter: 0 value: INDIC_SQUIGGLE];
    
    [mEditor setColorProperty: SCI_MARKERSETBACK parameter: 0 fromHTML: @"#B1151C"];
    
    [mEditor setColorProperty: SCI_SETSELBACK parameter: 1 value: [NSColor selectedTextBackgroundColor]];
    
    // Uncomment if you wanna see auto wrapping in action.
    //[mEditor setGeneralProperty: SCI_SETWRAPMODE parameter: SC_WRAP_WORD value: 0];
    
    InfoBar* infoBar = [[[InfoBar alloc] initWithFrame: NSMakeRect(0, 0, 400, 0)] autorelease];
    [infoBar setDisplay: IBShowAll];
    [mEditor setInfoBar: infoBar top: NO];
    [mEditor setStatusText: @"Operation complete"];
}



/* XPM */
static const char * box_xpm[] =
{
	"12 12 2 1",
	" 	c None",
	".	c #800000",
	"   .........",
	"  .   .   ..",
	" .   .   . .",
	".........  .",
	".   .   .  .",
	".   .   . ..",
	".   .   .. .",
	".........  .",
	".   .   .  .",
	".   .   . . ",
	".   .   ..  ",
	".........   "};


- (void) showAutocompletion
{
	const char *words = "Babylon-5?1 Battlestar-Galactica Millenium-Falcon?2 Moya?2 Serenity Voyager";
	[mEditor setGeneralProperty: SCI_AUTOCSETIGNORECASE parameter: 1 value:0];
	[mEditor setGeneralProperty: SCI_REGISTERIMAGE parameter: 1 value:(sptr_t)box_xpm];
	const int imSize = 12;
	[mEditor setGeneralProperty: SCI_RGBAIMAGESETWIDTH parameter: imSize value:0];
	[mEditor setGeneralProperty: SCI_RGBAIMAGESETHEIGHT parameter: imSize value:0];
	char image[imSize * imSize * 4];
	for (size_t y = 0; y < imSize; y++) {
		for (size_t x = 0; x < imSize; x++) {
			char *p = image + (y * imSize + x) * 4;
			p[0] = 0xFF;
			p[1] = 0xA0;
			p[2] = 0;
			p[3] = x * 23;
		}
	}
	[mEditor setGeneralProperty: SCI_REGISTERRGBAIMAGE parameter: 2 value:(sptr_t)image];
	[mEditor setGeneralProperty: SCI_AUTOCSHOW parameter: 0 value:(sptr_t)words];
}

- (IBAction) searchText: (id) sender
{
    NSSearchField* searchField = (NSSearchField*) sender;
    [mEditor findAndHighlightText: [searchField stringValue]
                        matchCase: NO
                        wholeWord: NO
                         scrollTo: YES
                             wrap: YES];
    
    long matchStart = [mEditor getGeneralProperty: SCI_GETSELECTIONSTART parameter: 0];
    long matchEnd = [mEditor getGeneralProperty: SCI_GETSELECTIONEND parameter: 0];
    [mEditor setGeneralProperty: SCI_FINDINDICATORFLASH parameter: matchStart value:matchEnd];
    
    if ([[searchField stringValue] isEqualToString: @"XX"])
        [self showAutocompletion];
}

-(IBAction) setFontQuality: (id) sender
{
    [ScintillaView directCall:mEditor message:SCI_SETFONTQUALITY wParam:[sender tag] lParam:0];
}

@end



