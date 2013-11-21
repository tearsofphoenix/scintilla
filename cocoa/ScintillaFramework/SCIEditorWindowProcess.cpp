//
//  SCIEditorWindowProcess.cpp
//  Scintilla
//
//  Created by Lei on 11/21/13.
//
//

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <math.h>
#include <assert.h>

#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <memory>

#include "Platform.h"

#include "ILexer.h"
#include "Scintilla.h"

#include "SplitVector.h"
#include "Partitioning.h"
#include "RunStyles.h"
#include "ContractionState.h"
#include "CellBuffer.h"
#include "KeyMap.h"
#include "Indicator.h"
#include "XPM.h"
#include "LineMarker.h"
#include "Style.h"
#include "ViewStyle.h"
#include "CharClassify.h"
#include "Decoration.h"
#include "CaseFolder.h"
#include "Document.h"
#include "UniConversion.h"
#include "Selection.h"
#include "PositionCache.h"
#include "Editor.h"

#ifdef SCI_NAMESPACE
using namespace Scintilla;
#endif

static bool ValidMargin(unsigned long wParam) {
	return wParam <= SC_MAX_MARGIN;
}

static char *CharPtrFromSPtr(sptr_t lParam) {
	return reinterpret_cast<char *>(lParam);
}

void Editor::StyleSetMessage(unsigned int iMessage, uptr_t wParam, sptr_t lParam) {
	vs.EnsureStyle(wParam);
	switch (iMessage) {
        case SCI_STYLESETFORE:
            vs.styles[wParam].fore = ColourDesired(lParam);
            break;
        case SCI_STYLESETBACK:
            vs.styles[wParam].back = ColourDesired(lParam);
            break;
        case SCI_STYLESETBOLD:
            vs.styles[wParam].weight = lParam != 0 ? SC_WEIGHT_BOLD : SC_WEIGHT_NORMAL;
            break;
        case SCI_STYLESETWEIGHT:
            vs.styles[wParam].weight = lParam;
            break;
        case SCI_STYLESETITALIC:
            vs.styles[wParam].italic = lParam != 0;
            break;
        case SCI_STYLESETEOLFILLED:
            vs.styles[wParam].eolFilled = lParam != 0;
            break;
        case SCI_STYLESETSIZE:
            vs.styles[wParam].size = lParam * SC_FONT_SIZE_MULTIPLIER;
            break;
        case SCI_STYLESETSIZEFRACTIONAL:
            vs.styles[wParam].size = lParam;
            break;
        case SCI_STYLESETFONT:
            if (lParam != 0) {
                vs.SetStyleFontName(wParam, CharPtrFromSPtr(lParam));
            }
            break;
        case SCI_STYLESETUNDERLINE:
            vs.styles[wParam].underline = lParam != 0;
            break;
        case SCI_STYLESETCASE:
            vs.styles[wParam].caseForce = static_cast<Style::ecaseForced>(lParam);
            break;
        case SCI_STYLESETCHARACTERSET:
            vs.styles[wParam].characterSet = lParam;
            pdoc->SetCaseFolder(NULL);
            break;
        case SCI_STYLESETVISIBLE:
            vs.styles[wParam].visible = lParam != 0;
            break;
        case SCI_STYLESETCHANGEABLE:
            vs.styles[wParam].changeable = lParam != 0;
            break;
        case SCI_STYLESETHOTSPOT:
            vs.styles[wParam].hotspot = lParam != 0;
            break;
	}
	InvalidateStyleRedraw();
}

sptr_t Editor::StyleGetMessage(unsigned int iMessage, uptr_t wParam, sptr_t lParam) {
	vs.EnsureStyle(wParam);
	switch (iMessage) {
        case SCI_STYLEGETFORE:
            return vs.styles[wParam].fore.AsLong();
        case SCI_STYLEGETBACK:
            return vs.styles[wParam].back.AsLong();
        case SCI_STYLEGETBOLD:
            return vs.styles[wParam].weight > SC_WEIGHT_NORMAL;
        case SCI_STYLEGETWEIGHT:
            return vs.styles[wParam].weight;
        case SCI_STYLEGETITALIC:
            return vs.styles[wParam].italic ? 1 : 0;
        case SCI_STYLEGETEOLFILLED:
            return vs.styles[wParam].eolFilled ? 1 : 0;
        case SCI_STYLEGETSIZE:
            return vs.styles[wParam].size / SC_FONT_SIZE_MULTIPLIER;
        case SCI_STYLEGETSIZEFRACTIONAL:
            return vs.styles[wParam].size;
        case SCI_STYLEGETFONT:
            if (!vs.styles[wParam].fontName)
                return 0;
            if (lParam != 0)
                strcpy(CharPtrFromSPtr(lParam), vs.styles[wParam].fontName);
            return strlen(vs.styles[wParam].fontName);
        case SCI_STYLEGETUNDERLINE:
            return vs.styles[wParam].underline ? 1 : 0;
        case SCI_STYLEGETCASE:
            return static_cast<int>(vs.styles[wParam].caseForce);
        case SCI_STYLEGETCHARACTERSET:
            return vs.styles[wParam].characterSet;
        case SCI_STYLEGETVISIBLE:
            return vs.styles[wParam].visible ? 1 : 0;
        case SCI_STYLEGETCHANGEABLE:
            return vs.styles[wParam].changeable ? 1 : 0;
        case SCI_STYLEGETHOTSPOT:
            return vs.styles[wParam].hotspot ? 1 : 0;
	}
	return 0;
}

sptr_t Editor::StringResult(sptr_t lParam, const char *val) {
	const size_t n = strlen(val);
	if (lParam != 0) {
		char *ptr = reinterpret_cast<char *>(lParam);
		strcpy(ptr, val);
	}
	return n;	// Not including NUL
}

sptr_t Editor::WndProc(unsigned int iMessage, uptr_t wParam, sptr_t lParam) {
	//Platform::DebugPrintf("S start wnd proc %d %d %d\n",iMessage, wParam, lParam);
    
	// Optional macro recording hook
	if (recordingMacro)
		NotifyMacroRecord(iMessage, wParam, lParam);
    
	switch (iMessage) {
            
        case SCI_GETTEXT: {
			if (lParam == 0)
				return pdoc->Length() + 1;
			if (wParam == 0)
				return 0;
			char *ptr = CharPtrFromSPtr(lParam);
			unsigned int iChar = 0;
			for (; iChar < wParam - 1; iChar++)
				ptr[iChar] = pdoc->CharAt(iChar);
			ptr[iChar] = '\0';
			return iChar;
		}
            
        case SCI_SETTEXT: {
			if (lParam == 0)
				return 0;
			UndoGroup ug(pdoc);
			pdoc->DeleteChars(0, pdoc->Length());
			SetEmptySelection(0);
			pdoc->InsertCString(0, CharPtrFromSPtr(lParam));
			return 1;
		}
            
        case SCI_GETTEXTLENGTH:
            return pdoc->Length();
            
        case SCI_CUT:
            Cut();
            SetLastXChosen();
            break;
            
        case SCI_COPY:
            Copy();
            break;
            
        case SCI_COPYALLOWLINE:
            CopyAllowLine();
            break;
            
        case SCI_VERTICALCENTRECARET:
            VerticalCentreCaret();
            break;
            
        case SCI_MOVESELECTEDLINESUP:
            MoveSelectedLinesUp();
            break;
            
        case SCI_MOVESELECTEDLINESDOWN:
            MoveSelectedLinesDown();
            break;
            
        case SCI_COPYRANGE:
            CopyRangeToClipboard(wParam, lParam);
            break;
            
        case SCI_COPYTEXT:
            CopyText(wParam, CharPtrFromSPtr(lParam));
            break;
            
        case SCI_PASTE:
            Paste();
            if ((caretSticky == SC_CARETSTICKY_OFF) || (caretSticky == SC_CARETSTICKY_WHITESPACE)) {
                SetLastXChosen();
            }
            EnsureCaretVisible();
            break;
            
        case SCI_CLEAR:
            Clear();
            SetLastXChosen();
            EnsureCaretVisible();
            break;
            
        case SCI_UNDO:
            Undo();
            SetLastXChosen();
            break;
            
        case SCI_CANUNDO:
            return (pdoc->CanUndo() && !pdoc->IsReadOnly()) ? 1 : 0;
            
        case SCI_EMPTYUNDOBUFFER:
            pdoc->DeleteUndoHistory();
            return 0;
            
        case SCI_GETFIRSTVISIBLELINE:
            return topLine;
            
        case SCI_SETFIRSTVISIBLELINE:
            ScrollTo(wParam);
            break;
            
        case SCI_GETLINE: {	// Risk of overwriting the end of the buffer
			int lineStart = pdoc->LineStart(wParam);
			int lineEnd = pdoc->LineStart(wParam + 1);
			if (lParam == 0) {
				return lineEnd - lineStart;
			}
			char *ptr = CharPtrFromSPtr(lParam);
			int iPlace = 0;
			for (int iChar = lineStart; iChar < lineEnd; iChar++) {
				ptr[iPlace++] = pdoc->CharAt(iChar);
			}
			return iPlace;
		}
            
        case SCI_GETLINECOUNT:
            if (pdoc->LinesTotal() == 0)
                return 1;
            else
                return pdoc->LinesTotal();
            
        case SCI_GETMODIFY:
            return !pdoc->IsSavePoint();
            
        case SCI_SETSEL: {
			int nStart = static_cast<int>(wParam);
			int nEnd = static_cast<int>(lParam);
			if (nEnd < 0)
				nEnd = pdoc->Length();
			if (nStart < 0)
				nStart = nEnd; 	// Remove selection
			InvalidateSelection(SelectionRange(nStart, nEnd));
			sel.Clear();
			sel.selType = Selection::selStream;
			SetSelection(nEnd, nStart);
			EnsureCaretVisible();
		}
            break;
            
        case SCI_GETSELTEXT: {
			SelectionText selectedText;
			CopySelectionRange(&selectedText);
			if (lParam == 0) {
				return selectedText.LengthWithTerminator();
			} else {
				char *ptr = CharPtrFromSPtr(lParam);
				unsigned int iChar = 0;
				if (selectedText.Length()) {
					for (; iChar < selectedText.LengthWithTerminator(); iChar++)
						ptr[iChar] = selectedText.Data()[iChar];
				} else {
					ptr[0] = '\0';
				}
				return iChar;
			}
		}
            
        case SCI_LINEFROMPOSITION:
            if (static_cast<int>(wParam) < 0)
                return 0;
            return pdoc->LineFromPosition(wParam);
            
        case SCI_POSITIONFROMLINE:
            if (static_cast<int>(wParam) < 0)
                wParam = pdoc->LineFromPosition(SelectionStart().Position());
            if (wParam == 0)
                return 0; 	// Even if there is no text, there is a first line that starts at 0
            if (static_cast<int>(wParam) > pdoc->LinesTotal())
                return -1;
            //if (wParam > pdoc->LineFromPosition(pdoc->Length()))	// Useful test, anyway...
            //	return -1;
            return pdoc->LineStart(wParam);
            
            // Replacement of the old Scintilla interpretation of EM_LINELENGTH
        case SCI_LINELENGTH:
            if ((static_cast<int>(wParam) < 0) ||
		        (static_cast<int>(wParam) > pdoc->LineFromPosition(pdoc->Length())))
                return 0;
            return pdoc->LineStart(wParam + 1) - pdoc->LineStart(wParam);
            
        case SCI_REPLACESEL:
        {
			if (lParam == 0)
				return 0;
			UndoGroup ug(pdoc);
			ClearSelection();
			char *replacement = CharPtrFromSPtr(lParam);
			pdoc->InsertCString(sel.MainCaret(), replacement);
			SetEmptySelection(sel.MainCaret() + strlen(replacement));
			EnsureCaretVisible();
		}
            break;
            
        case SCI_SETTARGETSTART:
            targetStart = wParam;
            break;
            
        case SCI_GETTARGETSTART:
            return targetStart;
            
        case SCI_SETTARGETEND:
            targetEnd = wParam;
            break;
            
        case SCI_GETTARGETEND:
            return targetEnd;
            
        case SCI_TARGETFROMSELECTION:
            if (sel.MainCaret() < sel.MainAnchor()) {
                targetStart = sel.MainCaret();
                targetEnd = sel.MainAnchor();
            } else {
                targetStart = sel.MainAnchor();
                targetEnd = sel.MainCaret();
            }
            break;
            
        case SCI_REPLACETARGET:
            PLATFORM_ASSERT(lParam);
            return ReplaceTarget(false, CharPtrFromSPtr(lParam), wParam);
            
        case SCI_REPLACETARGETRE:
            PLATFORM_ASSERT(lParam);
            return ReplaceTarget(true, CharPtrFromSPtr(lParam), wParam);
            
        case SCI_SEARCHINTARGET:
            PLATFORM_ASSERT(lParam);
            return SearchInTarget(CharPtrFromSPtr(lParam), wParam);
            
        case SCI_SETSEARCHFLAGS:
            searchFlags = wParam;
            break;
            
        case SCI_GETSEARCHFLAGS:
            return searchFlags;
            
        case SCI_GETTAG:
            return GetTag(CharPtrFromSPtr(lParam), wParam);
            
        case SCI_POSITIONBEFORE:
            return pdoc->MovePositionOutsideChar(wParam - 1, -1, true);
            
        case SCI_POSITIONAFTER:
            return pdoc->MovePositionOutsideChar(wParam + 1, 1, true);
            
        case SCI_POSITIONRELATIVE:
            return Platform::Clamp(pdoc->GetRelativePosition(wParam, lParam), 0, pdoc->Length());
            
        case SCI_LINESCROLL:
            ScrollTo(topLine + lParam);
            HorizontalScrollTo(xOffset + static_cast<int>(wParam) * vs.spaceWidth);
            return 1;
            
        case SCI_SETXOFFSET:
            xOffset = wParam;
            ContainerNeedsUpdate(SC_UPDATE_H_SCROLL);
            SetHorizontalScrollPos();
            Redraw();
            break;
            
        case SCI_GETXOFFSET:
            return xOffset;
            
        case SCI_CHOOSECARETX:
            SetLastXChosen();
            break;
            
        case SCI_SCROLLCARET:
            EnsureCaretVisible();
            break;
            
        case SCI_SETREADONLY:
            pdoc->SetReadOnly(wParam != 0);
            return 1;
            
        case SCI_GETREADONLY:
            return pdoc->IsReadOnly();
            
        case SCI_CANPASTE:
            return CanPaste();
            
        case SCI_POINTXFROMPOSITION:
            if (lParam < 0) {
                return 0;
            } else {
                Point pt = LocationFromPosition(lParam);
                // Convert to view-relative
                return pt.x - vs.textStart + vs.fixedColumnWidth;
            }
            
        case SCI_POINTYFROMPOSITION:
            if (lParam < 0) {
                return 0;
            } else {
                Point pt = LocationFromPosition(lParam);
                return pt.y;
            }
            
        case SCI_FINDTEXT:
            return FindText(wParam, lParam);
            
        case SCI_GETTEXTRANGE: {
			if (lParam == 0)
				return 0;
			Sci_TextRange *tr = reinterpret_cast<Sci_TextRange *>(lParam);
			int cpMax = tr->chrg.cpMax;
			if (cpMax == -1)
				cpMax = pdoc->Length();
			PLATFORM_ASSERT(cpMax <= pdoc->Length());
			int len = cpMax - tr->chrg.cpMin; 	// No -1 as cpMin and cpMax are referring to inter character positions
			pdoc->GetCharRange(tr->lpstrText, tr->chrg.cpMin, len);
			// Spec says copied text is terminated with a NUL
			tr->lpstrText[len] = '\0';
			return len; 	// Not including NUL
		}
            
        case SCI_HIDESELECTION:
            hideSelection = wParam != 0;
            Redraw();
            break;
            
        case SCI_FORMATRANGE:
            return FormatRange(wParam != 0, reinterpret_cast<Sci_RangeToFormat *>(lParam));
            
        case SCI_GETMARGINLEFT:
            return vs.leftMarginWidth;
            
        case SCI_GETMARGINRIGHT:
            return vs.rightMarginWidth;
            
        case SCI_SETMARGINLEFT:
            lastXChosen += lParam - vs.leftMarginWidth;
            vs.leftMarginWidth = lParam;
            InvalidateStyleRedraw();
            break;
            
        case SCI_SETMARGINRIGHT:
            vs.rightMarginWidth = lParam;
            InvalidateStyleRedraw();
            break;
            
            // Control specific mesages
            
        case SCI_ADDTEXT: {
			if (lParam == 0)
				return 0;
			pdoc->InsertString(CurrentPosition(), CharPtrFromSPtr(lParam), wParam);
			SetEmptySelection(sel.MainCaret() + wParam);
			return 0;
		}
            
        case SCI_ADDSTYLEDTEXT:
            if (lParam)
                AddStyledText(CharPtrFromSPtr(lParam), wParam);
            return 0;
            
        case SCI_INSERTTEXT: {
			if (lParam == 0)
				return 0;
			int insertPos = wParam;
			if (static_cast<int>(wParam) == -1)
				insertPos = CurrentPosition();
			int newCurrent = CurrentPosition();
			char *sz = CharPtrFromSPtr(lParam);
			pdoc->InsertCString(insertPos, sz);
			if (newCurrent > insertPos)
            {
				newCurrent += strlen(sz);
            }
            
			SetEmptySelection(newCurrent);
			return 0;
		}
            
        case SCI_APPENDTEXT:
            pdoc->InsertString(pdoc->Length(), CharPtrFromSPtr(lParam), wParam);
            return 0;
            
        case SCI_CLEARALL:
            ClearAll();
            return 0;
            
        case SCI_DELETERANGE:
            pdoc->DeleteChars(wParam, lParam);
            return 0;
            
        case SCI_CLEARDOCUMENTSTYLE:
            ClearDocumentStyle();
            return 0;
            
        case SCI_SETUNDOCOLLECTION:
            pdoc->SetUndoCollection(wParam != 0);
            return 0;
            
        case SCI_GETUNDOCOLLECTION:
            return pdoc->IsCollectingUndo();
            
        case SCI_BEGINUNDOACTION:
            pdoc->BeginUndoAction();
            return 0;
            
        case SCI_ENDUNDOACTION:
            pdoc->EndUndoAction();
            return 0;
            
        case SCI_GETCARETPERIOD:
            return caret.period;
            
        case SCI_SETCARETPERIOD:
            caret.period = wParam;
            break;
            
        case SCI_GETWORDCHARS:
            return pdoc->GetCharsOfClass(CharClassify::ccWord, reinterpret_cast<unsigned char *>(lParam));
            
        case SCI_SETWORDCHARS: {
			pdoc->SetDefaultCharClasses(false);
			if (lParam == 0)
				return 0;
			pdoc->SetCharClasses(reinterpret_cast<unsigned char *>(lParam), CharClassify::ccWord);
		}
            break;
            
        case SCI_GETWHITESPACECHARS:
            return pdoc->GetCharsOfClass(CharClassify::ccSpace, reinterpret_cast<unsigned char *>(lParam));
            
        case SCI_SETWHITESPACECHARS: {
			if (lParam == 0)
				return 0;
			pdoc->SetCharClasses(reinterpret_cast<unsigned char *>(lParam), CharClassify::ccSpace);
		}
            break;
            
        case SCI_GETPUNCTUATIONCHARS:
            return pdoc->GetCharsOfClass(CharClassify::ccPunctuation, reinterpret_cast<unsigned char *>(lParam));
            
        case SCI_SETPUNCTUATIONCHARS: {
			if (lParam == 0)
				return 0;
			pdoc->SetCharClasses(reinterpret_cast<unsigned char *>(lParam), CharClassify::ccPunctuation);
		}
            break;
            
        case SCI_SETCHARSDEFAULT:
            pdoc->SetDefaultCharClasses(true);
            break;
            
        case SCI_GETLENGTH:
            return pdoc->Length();
            
        case SCI_ALLOCATE:
            pdoc->Allocate(wParam);
            break;
            
        case SCI_GETCHARAT:
            return pdoc->CharAt(wParam);
            
        case SCI_SETCURRENTPOS:
            if (sel.IsRectangular()) {
                sel.Rectangular().caret.SetPosition(wParam);
                SetRectangularRange();
                Redraw();
            } else {
                SetSelection(wParam, sel.MainAnchor());
            }
            break;
            
        case SCI_GETCURRENTPOS:
            return sel.IsRectangular() ? sel.Rectangular().caret.Position() : sel.MainCaret();
            
        case SCI_SETANCHOR:
            if (sel.IsRectangular()) {
                sel.Rectangular().anchor.SetPosition(wParam);
                SetRectangularRange();
                Redraw();
            } else {
                SetSelection(sel.MainCaret(), wParam);
            }
            break;
            
        case SCI_GETANCHOR:
            return sel.IsRectangular() ? sel.Rectangular().anchor.Position() : sel.MainAnchor();
            
        case SCI_SETSELECTIONSTART:
            SetSelection(Platform::Maximum(sel.MainCaret(), wParam), wParam);
            break;
            
        case SCI_GETSELECTIONSTART:
            return sel.LimitsForRectangularElseMain().start.Position();
            
        case SCI_SETSELECTIONEND:
            SetSelection(wParam, Platform::Minimum(sel.MainAnchor(), wParam));
            break;
            
        case SCI_GETSELECTIONEND:
            return sel.LimitsForRectangularElseMain().end.Position();
            
        case SCI_SETEMPTYSELECTION:
            SetEmptySelection(wParam);
            break;
            
        case SCI_SETPRINTMAGNIFICATION:
            printParameters.magnification = wParam;
            break;
            
        case SCI_GETPRINTMAGNIFICATION:
            return printParameters.magnification;
            
        case SCI_SETPRINTCOLOURMODE:
            printParameters.colourMode = wParam;
            break;
            
        case SCI_GETPRINTCOLOURMODE:
            return printParameters.colourMode;
            
        case SCI_SETPRINTWRAPMODE:
            printParameters.wrapState = (wParam == SC_WRAP_WORD) ? eWrapWord : eWrapNone;
            break;
            
        case SCI_GETPRINTWRAPMODE:
            return printParameters.wrapState;
            
        case SCI_GETSTYLEAT:
            if (static_cast<int>(wParam) >= pdoc->Length())
                return 0;
            else
                return pdoc->StyleAt(wParam);
            
        case SCI_REDO:
            Redo();
            break;
            
        case SCI_SELECTALL:
            SelectAll();
            break;
            
        case SCI_SETSAVEPOINT:
            pdoc->SetSavePoint();
            break;
            
        case SCI_GETSTYLEDTEXT: {
			if (lParam == 0)
				return 0;
			Sci_TextRange *tr = reinterpret_cast<Sci_TextRange *>(lParam);
			int iPlace = 0;
			for (int iChar = tr->chrg.cpMin; iChar < tr->chrg.cpMax; iChar++) {
				tr->lpstrText[iPlace++] = pdoc->CharAt(iChar);
				tr->lpstrText[iPlace++] = pdoc->StyleAt(iChar);
			}
			tr->lpstrText[iPlace] = '\0';
			tr->lpstrText[iPlace + 1] = '\0';
			return iPlace;
		}
            
        case SCI_CANREDO:
            return (pdoc->CanRedo() && !pdoc->IsReadOnly()) ? 1 : 0;
            
        case SCI_MARKERLINEFROMHANDLE:
            return pdoc->LineFromHandle(wParam);
            
        case SCI_MARKERDELETEHANDLE:
            pdoc->DeleteMarkFromHandle(wParam);
            break;
            
        case SCI_GETVIEWWS:
            return vs.viewWhitespace;
            
        case SCI_SETVIEWWS:
            vs.viewWhitespace = static_cast<WhiteSpaceVisibility>(wParam);
            Redraw();
            break;
            
        case SCI_GETWHITESPACESIZE:
            return vs.whitespaceSize;
            
        case SCI_SETWHITESPACESIZE:
            vs.whitespaceSize = static_cast<int>(wParam);
            Redraw();
            break;
            
        case SCI_POSITIONFROMPOINT:
            return PositionFromLocation(Point(wParam - vs.ExternalMarginWidth(), lParam),
                                        false, false);
            
        case SCI_POSITIONFROMPOINTCLOSE:
            return PositionFromLocation(Point(wParam - vs.ExternalMarginWidth(), lParam),
                                        true, false);
            
        case SCI_CHARPOSITIONFROMPOINT:
            return PositionFromLocation(Point(wParam - vs.ExternalMarginWidth(), lParam),
                                        false, true);
            
        case SCI_CHARPOSITIONFROMPOINTCLOSE:
            return PositionFromLocation(Point(wParam - vs.ExternalMarginWidth(), lParam),
                                        true, true);
            
        case SCI_GOTOLINE:
            GoToLine(wParam);
            break;
            
        case SCI_GOTOPOS:
            SetEmptySelection(wParam);
            EnsureCaretVisible();
            break;
            
        case SCI_GETCURLINE: {
			int lineCurrentPos = pdoc->LineFromPosition(sel.MainCaret());
			int lineStart = pdoc->LineStart(lineCurrentPos);
			unsigned int lineEnd = pdoc->LineStart(lineCurrentPos + 1);
			if (lParam == 0) {
				return 1 + lineEnd - lineStart;
			}
			PLATFORM_ASSERT(wParam > 0);
			char *ptr = CharPtrFromSPtr(lParam);
			unsigned int iPlace = 0;
			for (unsigned int iChar = lineStart; iChar < lineEnd && iPlace < wParam - 1; iChar++) {
				ptr[iPlace++] = pdoc->CharAt(iChar);
			}
			ptr[iPlace] = '\0';
			return sel.MainCaret() - lineStart;
		}
            
        case SCI_GETENDSTYLED:
            return pdoc->GetEndStyled();
            
        case SCI_GETEOLMODE:
            return pdoc->eolMode;
            
        case SCI_SETEOLMODE:
            pdoc->eolMode = wParam;
            break;
            
        case SCI_SETLINEENDTYPESALLOWED:
            if (pdoc->SetLineEndTypesAllowed(wParam)) {
                cs.Clear();
                cs.InsertLines(0, pdoc->LinesTotal() - 1);
                SetAnnotationHeights(0, pdoc->LinesTotal());
                InvalidateStyleRedraw();
            }
            break;
            
        case SCI_GETLINEENDTYPESALLOWED:
            return pdoc->GetLineEndTypesAllowed();
            
        case SCI_GETLINEENDTYPESACTIVE:
            return pdoc->GetLineEndTypesActive();
            
        case SCI_STARTSTYLING:
            pdoc->StartStyling(wParam, static_cast<char>(lParam));
            break;
            
        case SCI_SETSTYLING:
            pdoc->SetStyleFor(wParam, static_cast<char>(lParam));
            break;
            
        case SCI_SETSTYLINGEX:             // Specify a complete styling buffer
            if (lParam == 0)
                return 0;
            pdoc->SetStyles(wParam, CharPtrFromSPtr(lParam));
            break;
            
        case SCI_SETBUFFEREDDRAW:
            bufferedDraw = wParam != 0;
            break;
            
        case SCI_GETBUFFEREDDRAW:
            return bufferedDraw;
            
        case SCI_GETTWOPHASEDRAW:
            return twoPhaseDraw;
            
        case SCI_SETTWOPHASEDRAW:
            twoPhaseDraw = wParam != 0;
            InvalidateStyleRedraw();
            break;
            
        case SCI_SETFONTQUALITY:
            vs.extraFontFlag &= ~SC_EFF_QUALITY_MASK;
            vs.extraFontFlag |= (wParam & SC_EFF_QUALITY_MASK);
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETFONTQUALITY:
            return (vs.extraFontFlag & SC_EFF_QUALITY_MASK);
            
        case SCI_SETTABWIDTH:
            if (wParam > 0) {
                pdoc->tabInChars = wParam;
                if (pdoc->indentInChars == 0)
                    pdoc->actualIndentInChars = pdoc->tabInChars;
            }
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETTABWIDTH:
            return pdoc->tabInChars;
            
        case SCI_SETINDENT:
            pdoc->indentInChars = wParam;
            if (pdoc->indentInChars != 0)
                pdoc->actualIndentInChars = pdoc->indentInChars;
            else
                pdoc->actualIndentInChars = pdoc->tabInChars;
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETINDENT:
            return pdoc->indentInChars;
            
        case SCI_SETUSETABS:
            pdoc->useTabs = wParam != 0;
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETUSETABS:
            return pdoc->useTabs;
            
        case SCI_SETLINEINDENTATION:
            pdoc->SetLineIndentation(wParam, lParam);
            break;
            
        case SCI_GETLINEINDENTATION:
            return pdoc->GetLineIndentation(wParam);
            
        case SCI_GETLINEINDENTPOSITION:
            return pdoc->GetLineIndentPosition(wParam);
            
        case SCI_SETTABINDENTS:
            pdoc->tabIndents = wParam != 0;
            break;
            
        case SCI_GETTABINDENTS:
            return pdoc->tabIndents;
            
        case SCI_SETBACKSPACEUNINDENTS:
            pdoc->backspaceUnindents = wParam != 0;
            break;
            
        case SCI_GETBACKSPACEUNINDENTS:
            return pdoc->backspaceUnindents;
            
        case SCI_SETMOUSEDWELLTIME:
            dwellDelay = wParam;
            ticksToDwell = dwellDelay;
            break;
            
        case SCI_GETMOUSEDWELLTIME:
            return dwellDelay;
            
        case SCI_WORDSTARTPOSITION:
            return pdoc->ExtendWordSelect(wParam, -1, lParam != 0);
            
        case SCI_WORDENDPOSITION:
            return pdoc->ExtendWordSelect(wParam, 1, lParam != 0);
            
        case SCI_SETWRAPMODE:
            if (vs.SetWrapState(wParam)) {
                xOffset = 0;
                ContainerNeedsUpdate(SC_UPDATE_H_SCROLL);
                InvalidateStyleRedraw();
                ReconfigureScrollBars();
            }
            break;
            
        case SCI_GETWRAPMODE:
            return vs.wrapState;
            
        case SCI_SETWRAPVISUALFLAGS:
            if (vs.SetWrapVisualFlags(wParam)) {
                InvalidateStyleRedraw();
                ReconfigureScrollBars();
            }
            break;
            
        case SCI_GETWRAPVISUALFLAGS:
            return vs.wrapVisualFlags;
            
        case SCI_SETWRAPVISUALFLAGSLOCATION:
            if (vs.SetWrapVisualFlagsLocation(wParam)) {
                InvalidateStyleRedraw();
            }
            break;
            
        case SCI_GETWRAPVISUALFLAGSLOCATION:
            return vs.wrapVisualFlagsLocation;
            
        case SCI_SETWRAPSTARTINDENT:
            if (vs.SetWrapVisualStartIndent(wParam)) {
                InvalidateStyleRedraw();
                ReconfigureScrollBars();
            }
            break;
            
        case SCI_GETWRAPSTARTINDENT:
            return vs.wrapVisualStartIndent;
            
        case SCI_SETWRAPINDENTMODE:
            if (vs.SetWrapIndentMode(wParam)) {
                InvalidateStyleRedraw();
                ReconfigureScrollBars();
            }
            break;
            
        case SCI_GETWRAPINDENTMODE:
            return vs.wrapIndentMode;
            
        case SCI_SETLAYOUTCACHE:
            llc.SetLevel(wParam);
            break;
            
        case SCI_GETLAYOUTCACHE:
            return llc.GetLevel();
            
        case SCI_SETPOSITIONCACHE:
            posCache.SetSize(wParam);
            break;
            
        case SCI_GETPOSITIONCACHE:
            return posCache.GetSize();
            
        case SCI_SETSCROLLWIDTH:
            PLATFORM_ASSERT(wParam > 0);
            if ((wParam > 0) && (wParam != static_cast<unsigned int >(scrollWidth))) {
                lineWidthMaxSeen = 0;
                scrollWidth = wParam;
                SetScrollBars();
            }
            break;
            
        case SCI_GETSCROLLWIDTH:
            return scrollWidth;
            
        case SCI_SETSCROLLWIDTHTRACKING:
            trackLineWidth = wParam != 0;
            break;
            
        case SCI_GETSCROLLWIDTHTRACKING:
            return trackLineWidth;
            
        case SCI_LINESJOIN:
            LinesJoin();
            break;
            
        case SCI_LINESSPLIT:
            LinesSplit(wParam);
            break;
            
        case SCI_TEXTWIDTH:
            PLATFORM_ASSERT(wParam < vs.styles.size());
            PLATFORM_ASSERT(lParam);
            return TextWidth(wParam, CharPtrFromSPtr(lParam));
            
        case SCI_TEXTHEIGHT:
            return vs.lineHeight;
            
        case SCI_SETENDATLASTLINE:
            PLATFORM_ASSERT((wParam == 0) || (wParam == 1));
            if (endAtLastLine != (wParam != 0)) {
                endAtLastLine = wParam != 0;
                SetScrollBars();
            }
            break;
            
        case SCI_GETENDATLASTLINE:
            return endAtLastLine;
            
        case SCI_SETCARETSTICKY:
            PLATFORM_ASSERT(wParam <= SC_CARETSTICKY_WHITESPACE);
            if (wParam <= SC_CARETSTICKY_WHITESPACE) {
                caretSticky = wParam;
            }
            break;
            
        case SCI_GETCARETSTICKY:
            return caretSticky;
            
        case SCI_TOGGLECARETSTICKY:
            caretSticky = !caretSticky;
            break;
            
        case SCI_GETCOLUMN:
            return pdoc->GetColumn(wParam);
            
        case SCI_FINDCOLUMN:
            return pdoc->FindColumn(wParam, lParam);
            
        case SCI_SETHSCROLLBAR :
            if (horizontalScrollBarVisible != (wParam != 0)) {
                horizontalScrollBarVisible = wParam != 0;
                SetScrollBars();
                ReconfigureScrollBars();
            }
            break;
            
        case SCI_GETHSCROLLBAR:
            return horizontalScrollBarVisible;
            
        case SCI_SETVSCROLLBAR:
            if (verticalScrollBarVisible != (wParam != 0)) {
                verticalScrollBarVisible = wParam != 0;
                SetScrollBars();
                ReconfigureScrollBars();
                if (verticalScrollBarVisible)
                    SetVerticalScrollPos();
            }
            break;
            
        case SCI_GETVSCROLLBAR:
            return verticalScrollBarVisible;
            
        case SCI_SETINDENTATIONGUIDES:
            vs.viewIndentationGuides = IndentView(wParam);
            Redraw();
            break;
            
        case SCI_GETINDENTATIONGUIDES:
            return vs.viewIndentationGuides;
            
        case SCI_SETHIGHLIGHTGUIDE:
            if ((highlightGuideColumn != static_cast<int>(wParam)) || (wParam > 0)) {
                highlightGuideColumn = wParam;
                Redraw();
            }
            break;
            
        case SCI_GETHIGHLIGHTGUIDE:
            return highlightGuideColumn;
            
        case SCI_GETLINEENDPOSITION:
            return pdoc->LineEnd(wParam);
            
        case SCI_SETCODEPAGE:
            if (ValidCodePage(wParam)) {
                if (pdoc->SetDBCSCodePage(wParam)) {
                    cs.Clear();
                    cs.InsertLines(0, pdoc->LinesTotal() - 1);
                    SetAnnotationHeights(0, pdoc->LinesTotal());
                    InvalidateStyleRedraw();
                    SetRepresentations();
                }
            }
            break;
            
        case SCI_GETCODEPAGE:
            return pdoc->dbcsCodePage;
            
#ifdef INCLUDE_DEPRECATED_FEATURES
        case SCI_SETUSEPALETTE:
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETUSEPALETTE:
            return 0;
#endif
            
            // Marker definition and setting
        case SCI_MARKERDEFINE:
            if (wParam <= MARKER_MAX) {
                vs.markers[wParam].markType = lParam;
                vs.CalcLargestMarkerHeight();
            }
            InvalidateStyleData();
            RedrawSelMargin();
            break;
            
        case SCI_MARKERSYMBOLDEFINED:
            if (wParam <= MARKER_MAX)
                return vs.markers[wParam].markType;
            else
                return 0;
            
        case SCI_MARKERSETFORE:
            if (wParam <= MARKER_MAX)
                vs.markers[wParam].fore = ColourDesired(lParam);
            InvalidateStyleData();
            RedrawSelMargin();
            break;
        case SCI_MARKERSETBACKSELECTED:
            if (wParam <= MARKER_MAX)
                vs.markers[wParam].backSelected = ColourDesired(lParam);
            InvalidateStyleData();
            RedrawSelMargin();
            break;
        case SCI_MARKERENABLEHIGHLIGHT:
            highlightDelimiter.isEnabled = wParam == 1;
            RedrawSelMargin();
            break;
        case SCI_MARKERSETBACK:
            if (wParam <= MARKER_MAX)
                vs.markers[wParam].back = ColourDesired(lParam);
            InvalidateStyleData();
            RedrawSelMargin();
            break;
        case SCI_MARKERSETALPHA:
            if (wParam <= MARKER_MAX)
                vs.markers[wParam].alpha = lParam;
            InvalidateStyleRedraw();
            break;
        case SCI_MARKERADD: {
			int markerID = pdoc->AddMark(wParam, lParam);
			return markerID;
		}
        case SCI_MARKERADDSET:
            if (lParam != 0)
                pdoc->AddMarkSet(wParam, lParam);
            break;
            
        case SCI_MARKERDELETE:
            pdoc->DeleteMark(wParam, lParam);
            break;
            
        case SCI_MARKERDELETEALL:
            pdoc->DeleteAllMarks(static_cast<int>(wParam));
            break;
            
        case SCI_MARKERGET:
            return pdoc->GetMark(wParam);
            
        case SCI_MARKERNEXT:
            return pdoc->MarkerNext(wParam, lParam);
            
        case SCI_MARKERPREVIOUS: {
			for (int iLine = wParam; iLine >= 0; iLine--) {
				if ((pdoc->GetMark(iLine) & lParam) != 0)
					return iLine;
			}
		}
            return -1;
            
        case SCI_MARKERDEFINEPIXMAP:
            if (wParam <= MARKER_MAX) {
                vs.markers[wParam].SetXPM(CharPtrFromSPtr(lParam));
                vs.CalcLargestMarkerHeight();
            };
            InvalidateStyleData();
            RedrawSelMargin();
            break;
            
        case SCI_RGBAIMAGESETWIDTH:
            sizeRGBAImage.x = wParam;
            break;
            
        case SCI_RGBAIMAGESETHEIGHT:
            sizeRGBAImage.y = wParam;
            break;
            
        case SCI_RGBAIMAGESETSCALE:
            scaleRGBAImage = wParam;
            break;
            
        case SCI_MARKERDEFINERGBAIMAGE:
            if (wParam <= MARKER_MAX) {
                vs.markers[wParam].SetRGBAImage(sizeRGBAImage, scaleRGBAImage / 100.0, reinterpret_cast<unsigned char *>(lParam));
                vs.CalcLargestMarkerHeight();
            };
            InvalidateStyleData();
            RedrawSelMargin();
            break;
            
        case SCI_SETMARGINTYPEN:
            if (ValidMargin(wParam)) {
                vs.ms[wParam].style = lParam;
                InvalidateStyleRedraw();
            }
            break;
            
        case SCI_GETMARGINTYPEN:
            if (ValidMargin(wParam))
                return vs.ms[wParam].style;
            else
                return 0;
            
        case SCI_SETMARGINWIDTHN:
            if (ValidMargin(wParam)) {
                // Short-circuit if the width is unchanged, to avoid unnecessary redraw.
                if (vs.ms[wParam].width != lParam) {
                    lastXChosen += lParam - vs.ms[wParam].width;
                    vs.ms[wParam].width = lParam;
                    InvalidateStyleRedraw();
                }
            }
            break;
            
        case SCI_GETMARGINWIDTHN:
            if (ValidMargin(wParam))
                return vs.ms[wParam].width;
            else
                return 0;
            
        case SCI_SETMARGINMASKN:
            if (ValidMargin(wParam)) {
                vs.ms[wParam].mask = lParam;
                InvalidateStyleRedraw();
            }
            break;
            
        case SCI_GETMARGINMASKN:
            if (ValidMargin(wParam))
                return vs.ms[wParam].mask;
            else
                return 0;
            
        case SCI_SETMARGINSENSITIVEN:
            if (ValidMargin(wParam)) {
                vs.ms[wParam].sensitive = lParam != 0;
                InvalidateStyleRedraw();
            }
            break;
            
        case SCI_GETMARGINSENSITIVEN:
            if (ValidMargin(wParam))
                return vs.ms[wParam].sensitive ? 1 : 0;
            else
                return 0;
            
        case SCI_SETMARGINCURSORN:
            if (ValidMargin(wParam))
                vs.ms[wParam].cursor = lParam;
            break;
            
        case SCI_GETMARGINCURSORN:
            if (ValidMargin(wParam))
                return vs.ms[wParam].cursor;
            else
                return 0;
            
        case SCI_STYLECLEARALL:
            vs.ClearStyles();
            InvalidateStyleRedraw();
            break;
            
        case SCI_STYLESETFORE:
        case SCI_STYLESETBACK:
        case SCI_STYLESETBOLD:
        case SCI_STYLESETWEIGHT:
        case SCI_STYLESETITALIC:
        case SCI_STYLESETEOLFILLED:
        case SCI_STYLESETSIZE:
        case SCI_STYLESETSIZEFRACTIONAL:
        case SCI_STYLESETFONT:
        case SCI_STYLESETUNDERLINE:
        case SCI_STYLESETCASE:
        case SCI_STYLESETCHARACTERSET:
        case SCI_STYLESETVISIBLE:
        case SCI_STYLESETCHANGEABLE:
        case SCI_STYLESETHOTSPOT:
            StyleSetMessage(iMessage, wParam, lParam);
            break;
            
        case SCI_STYLEGETFORE:
        case SCI_STYLEGETBACK:
        case SCI_STYLEGETBOLD:
        case SCI_STYLEGETWEIGHT:
        case SCI_STYLEGETITALIC:
        case SCI_STYLEGETEOLFILLED:
        case SCI_STYLEGETSIZE:
        case SCI_STYLEGETSIZEFRACTIONAL:
        case SCI_STYLEGETFONT:
        case SCI_STYLEGETUNDERLINE:
        case SCI_STYLEGETCASE:
        case SCI_STYLEGETCHARACTERSET:
        case SCI_STYLEGETVISIBLE:
        case SCI_STYLEGETCHANGEABLE:
        case SCI_STYLEGETHOTSPOT:
            return StyleGetMessage(iMessage, wParam, lParam);
            
        case SCI_STYLERESETDEFAULT:
            vs.ResetDefaultStyle();
            InvalidateStyleRedraw();
            break;
        case SCI_SETSTYLEBITS:
            vs.EnsureStyle((1 << wParam) - 1);
            pdoc->SetStylingBits(wParam);
            break;
            
        case SCI_GETSTYLEBITS:
            return pdoc->stylingBits;
            
        case SCI_SETLINESTATE:
            return pdoc->SetLineState(wParam, lParam);
            
        case SCI_GETLINESTATE:
            return pdoc->GetLineState(wParam);
            
        case SCI_GETMAXLINESTATE:
            return pdoc->GetMaxLineState();
            
        case SCI_GETCARETLINEVISIBLE:
            return vs.showCaretLineBackground;
        case SCI_SETCARETLINEVISIBLE:
            vs.showCaretLineBackground = wParam != 0;
            InvalidateStyleRedraw();
            break;
        case SCI_GETCARETLINEVISIBLEALWAYS:
            return vs.alwaysShowCaretLineBackground;
        case SCI_SETCARETLINEVISIBLEALWAYS:
            vs.alwaysShowCaretLineBackground = wParam != 0;
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETCARETLINEBACK:
            return vs.caretLineBackground.AsLong();
        case SCI_SETCARETLINEBACK:
            vs.caretLineBackground = wParam;
            InvalidateStyleRedraw();
            break;
        case SCI_GETCARETLINEBACKALPHA:
            return vs.caretLineAlpha;
        case SCI_SETCARETLINEBACKALPHA:
            vs.caretLineAlpha = wParam;
            InvalidateStyleRedraw();
            break;
            
            // Folding messages
            
        case SCI_VISIBLEFROMDOCLINE:
            return cs.DisplayFromDoc(wParam);
            
        case SCI_DOCLINEFROMVISIBLE:
            return cs.DocFromDisplay(wParam);
            
        case SCI_WRAPCOUNT:
            return WrapCount(wParam);
            
        case SCI_SETFOLDLEVEL: {
			int prev = pdoc->SetLevel(wParam, lParam);
			if (prev != lParam)
				RedrawSelMargin();
			return prev;
		}
            
        case SCI_GETFOLDLEVEL:
            return pdoc->GetLevel(wParam);
            
        case SCI_GETLASTCHILD:
            return pdoc->GetLastChild(wParam, lParam);
            
        case SCI_GETFOLDPARENT:
            return pdoc->GetFoldParent(wParam);
            
        case SCI_SHOWLINES:
            cs.SetVisible(wParam, lParam, true);
            SetScrollBars();
            Redraw();
            break;
            
        case SCI_HIDELINES:
            if (wParam > 0)
                cs.SetVisible(wParam, lParam, false);
            SetScrollBars();
            Redraw();
            break;
            
        case SCI_GETLINEVISIBLE:
            return cs.GetVisible(wParam);
            
        case SCI_GETALLLINESVISIBLE:
            return cs.HiddenLines() ? 0 : 1;
            
        case SCI_SETFOLDEXPANDED:
            SetFoldExpanded(wParam, lParam != 0);
            break;
            
        case SCI_GETFOLDEXPANDED:
            return cs.GetExpanded(wParam);
            
        case SCI_SETAUTOMATICFOLD:
            foldAutomatic = wParam;
            break;
            
        case SCI_GETAUTOMATICFOLD:
            return foldAutomatic;
            
        case SCI_SETFOLDFLAGS:
            foldFlags = wParam;
            Redraw();
            break;
            
        case SCI_TOGGLEFOLD:
            FoldLine(wParam, SC_FOLDACTION_TOGGLE);
            break;
            
        case SCI_FOLDLINE:
            FoldLine(wParam, lParam);
            break;
            
        case SCI_FOLDCHILDREN:
            FoldExpand(wParam, lParam, pdoc->GetLevel(wParam));
            break;
            
        case SCI_FOLDALL:
            FoldAll(wParam);
            break;
            
        case SCI_EXPANDCHILDREN:
            FoldExpand(wParam, SC_FOLDACTION_EXPAND, lParam);
            break;
            
        case SCI_CONTRACTEDFOLDNEXT:
            return ContractedFoldNext(wParam);
            
        case SCI_ENSUREVISIBLE:
            EnsureLineVisible(wParam, false);
            break;
            
        case SCI_ENSUREVISIBLEENFORCEPOLICY:
            EnsureLineVisible(wParam, true);
            break;
            
        case SCI_SCROLLRANGE:
            ScrollRange(SelectionRange(lParam, wParam));
            break;
            
        case SCI_SEARCHANCHOR:
            SearchAnchor();
            break;
            
        case SCI_SEARCHNEXT:
        case SCI_SEARCHPREV:
            return SearchText(iMessage, wParam, lParam);
            
        case SCI_SETXCARETPOLICY:
            caretXPolicy = wParam;
            caretXSlop = lParam;
            break;
            
        case SCI_SETYCARETPOLICY:
            caretYPolicy = wParam;
            caretYSlop = lParam;
            break;
            
        case SCI_SETVISIBLEPOLICY:
            visiblePolicy = wParam;
            visibleSlop = lParam;
            break;
            
        case SCI_LINESONSCREEN:
            return LinesOnScreen();
            
        case SCI_SETSELFORE:
            vs.selColours.fore = ColourOptional(wParam, lParam);
            vs.selAdditionalForeground = ColourDesired(lParam);
            InvalidateStyleRedraw();
            break;
            
        case SCI_SETSELBACK:
            vs.selColours.back = ColourOptional(wParam, lParam);
            vs.selAdditionalBackground = ColourDesired(lParam);
            InvalidateStyleRedraw();
            break;
            
        case SCI_SETSELALPHA:
            vs.selAlpha = wParam;
            vs.selAdditionalAlpha = wParam;
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETSELALPHA:
            return vs.selAlpha;
            
        case SCI_GETSELEOLFILLED:
            return vs.selEOLFilled;
            
        case SCI_SETSELEOLFILLED:
            vs.selEOLFilled = wParam != 0;
            InvalidateStyleRedraw();
            break;
            
        case SCI_SETWHITESPACEFORE:
            vs.whitespaceColours.fore = ColourOptional(wParam, lParam);
            InvalidateStyleRedraw();
            break;
            
        case SCI_SETWHITESPACEBACK:
            vs.whitespaceColours.back = ColourOptional(wParam, lParam);
            InvalidateStyleRedraw();
            break;
            
        case SCI_SETCARETFORE:
            vs.caretcolour = ColourDesired(wParam);
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETCARETFORE:
            return vs.caretcolour.AsLong();
            
        case SCI_SETCARETSTYLE:
            if (wParam <= CARETSTYLE_BLOCK)
                vs.caretStyle = wParam;
            else
			/* Default to the line caret */
                vs.caretStyle = CARETSTYLE_LINE;
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETCARETSTYLE:
            return vs.caretStyle;
            
        case SCI_SETCARETWIDTH:
            if (static_cast<int>(wParam) <= 0)
                vs.caretWidth = 0;
            else if (wParam >= 3)
                vs.caretWidth = 3;
            else
                vs.caretWidth = wParam;
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETCARETWIDTH:
            return vs.caretWidth;
            
        case SCI_ASSIGNCMDKEY:
            kmap.AssignCmdKey(Platform::LowShortFromLong(wParam),
                              Platform::HighShortFromLong(wParam), lParam);
            break;
            
        case SCI_CLEARCMDKEY:
            kmap.AssignCmdKey(Platform::LowShortFromLong(wParam),
                              Platform::HighShortFromLong(wParam), SCI_NULL);
            break;
            
        case SCI_CLEARALLCMDKEYS:
            kmap.Clear();
            break;
            
        case SCI_INDICSETSTYLE:
            if (wParam <= INDIC_MAX) {
                vs.indicators[wParam].style = lParam;
                InvalidateStyleRedraw();
            }
            break;
            
        case SCI_INDICGETSTYLE:
            return (wParam <= INDIC_MAX) ? vs.indicators[wParam].style : 0;
            
        case SCI_INDICSETFORE:
            if (wParam <= INDIC_MAX) {
                vs.indicators[wParam].fore = ColourDesired(lParam);
                InvalidateStyleRedraw();
            }
            break;
            
        case SCI_INDICGETFORE:
            return (wParam <= INDIC_MAX) ? vs.indicators[wParam].fore.AsLong() : 0;
            
        case SCI_INDICSETUNDER:
            if (wParam <= INDIC_MAX) {
                vs.indicators[wParam].under = lParam != 0;
                InvalidateStyleRedraw();
            }
            break;
            
        case SCI_INDICGETUNDER:
            return (wParam <= INDIC_MAX) ? vs.indicators[wParam].under : 0;
            
        case SCI_INDICSETALPHA:
            if (wParam <= INDIC_MAX && lParam >=0 && lParam <= 255) {
                vs.indicators[wParam].fillAlpha = lParam;
                InvalidateStyleRedraw();
            }
            break;
            
        case SCI_INDICGETALPHA:
            return (wParam <= INDIC_MAX) ? vs.indicators[wParam].fillAlpha : 0;
            
        case SCI_INDICSETOUTLINEALPHA:
            if (wParam <= INDIC_MAX && lParam >=0 && lParam <= 255) {
                vs.indicators[wParam].outlineAlpha = lParam;
                InvalidateStyleRedraw();
            }
            break;
            
        case SCI_INDICGETOUTLINEALPHA:
            return (wParam <= INDIC_MAX) ? vs.indicators[wParam].outlineAlpha : 0;
            
        case SCI_SETINDICATORCURRENT:
            pdoc->decorations.SetCurrentIndicator(wParam);
            break;
        case SCI_GETINDICATORCURRENT:
            return pdoc->decorations.GetCurrentIndicator();
        case SCI_SETINDICATORVALUE:
            pdoc->decorations.SetCurrentValue(wParam);
            break;
        case SCI_GETINDICATORVALUE:
            return pdoc->decorations.GetCurrentValue();
            
        case SCI_INDICATORFILLRANGE:
            pdoc->DecorationFillRange(wParam, pdoc->decorations.GetCurrentValue(), lParam);
            break;
            
        case SCI_INDICATORCLEARRANGE:
            pdoc->DecorationFillRange(wParam, 0, lParam);
            break;
            
        case SCI_INDICATORALLONFOR:
            return pdoc->decorations.AllOnFor(wParam);
            
        case SCI_INDICATORVALUEAT:
            return pdoc->decorations.ValueAt(wParam, lParam);
            
        case SCI_INDICATORSTART:
            return pdoc->decorations.Start(wParam, lParam);
            
        case SCI_INDICATOREND:
            return pdoc->decorations.End(wParam, lParam);
            
        case SCI_LINEDOWN:
        case SCI_LINEDOWNEXTEND:
        case SCI_PARADOWN:
        case SCI_PARADOWNEXTEND:
        case SCI_LINEUP:
        case SCI_LINEUPEXTEND:
        case SCI_PARAUP:
        case SCI_PARAUPEXTEND:
        case SCI_CHARLEFT:
        case SCI_CHARLEFTEXTEND:
        case SCI_CHARRIGHT:
        case SCI_CHARRIGHTEXTEND:
        case SCI_WORDLEFT:
        case SCI_WORDLEFTEXTEND:
        case SCI_WORDRIGHT:
        case SCI_WORDRIGHTEXTEND:
        case SCI_WORDLEFTEND:
        case SCI_WORDLEFTENDEXTEND:
        case SCI_WORDRIGHTEND:
        case SCI_WORDRIGHTENDEXTEND:
        case SCI_HOME:
        case SCI_HOMEEXTEND:
        case SCI_LINEEND:
        case SCI_LINEENDEXTEND:
        case SCI_HOMEWRAP:
        case SCI_HOMEWRAPEXTEND:
        case SCI_LINEENDWRAP:
        case SCI_LINEENDWRAPEXTEND:
        case SCI_DOCUMENTSTART:
        case SCI_DOCUMENTSTARTEXTEND:
        case SCI_DOCUMENTEND:
        case SCI_DOCUMENTENDEXTEND:
        case SCI_SCROLLTOSTART:
        case SCI_SCROLLTOEND:
            
        case SCI_STUTTEREDPAGEUP:
        case SCI_STUTTEREDPAGEUPEXTEND:
        case SCI_STUTTEREDPAGEDOWN:
        case SCI_STUTTEREDPAGEDOWNEXTEND:
            
        case SCI_PAGEUP:
        case SCI_PAGEUPEXTEND:
        case SCI_PAGEDOWN:
        case SCI_PAGEDOWNEXTEND:
        case SCI_EDITTOGGLEOVERTYPE:
        case SCI_CANCEL:
        case SCI_DELETEBACK:
        case SCI_TAB:
        case SCI_BACKTAB:
        case SCI_NEWLINE:
        case SCI_FORMFEED:
        case SCI_VCHOME:
        case SCI_VCHOMEEXTEND:
        case SCI_VCHOMEWRAP:
        case SCI_VCHOMEWRAPEXTEND:
        case SCI_VCHOMEDISPLAY:
        case SCI_VCHOMEDISPLAYEXTEND:
        case SCI_ZOOMIN:
        case SCI_ZOOMOUT:
        case SCI_DELWORDLEFT:
        case SCI_DELWORDRIGHT:
        case SCI_DELWORDRIGHTEND:
        case SCI_DELLINELEFT:
        case SCI_DELLINERIGHT:
        case SCI_LINECOPY:
        case SCI_LINECUT:
        case SCI_LINEDELETE:
        case SCI_LINETRANSPOSE:
        case SCI_LINEDUPLICATE:
        case SCI_LOWERCASE:
        case SCI_UPPERCASE:
        case SCI_LINESCROLLDOWN:
        case SCI_LINESCROLLUP:
        case SCI_WORDPARTLEFT:
        case SCI_WORDPARTLEFTEXTEND:
        case SCI_WORDPARTRIGHT:
        case SCI_WORDPARTRIGHTEXTEND:
        case SCI_DELETEBACKNOTLINE:
        case SCI_HOMEDISPLAY:
        case SCI_HOMEDISPLAYEXTEND:
        case SCI_LINEENDDISPLAY:
        case SCI_LINEENDDISPLAYEXTEND:
        case SCI_LINEDOWNRECTEXTEND:
        case SCI_LINEUPRECTEXTEND:
        case SCI_CHARLEFTRECTEXTEND:
        case SCI_CHARRIGHTRECTEXTEND:
        case SCI_HOMERECTEXTEND:
        case SCI_VCHOMERECTEXTEND:
        case SCI_LINEENDRECTEXTEND:
        case SCI_PAGEUPRECTEXTEND:
        case SCI_PAGEDOWNRECTEXTEND:
        case SCI_SELECTIONDUPLICATE:
            return KeyCommand(iMessage);
            
        case SCI_BRACEHIGHLIGHT:
            SetBraceHighlight(static_cast<int>(wParam), lParam, STYLE_BRACELIGHT);
            break;
            
        case SCI_BRACEHIGHLIGHTINDICATOR:
            if (lParam >= 0 && lParam <= INDIC_MAX) {
                vs.braceHighlightIndicatorSet = wParam != 0;
                vs.braceHighlightIndicator = lParam;
            }
            break;
            
        case SCI_BRACEBADLIGHT:
            SetBraceHighlight(static_cast<int>(wParam), -1, STYLE_BRACEBAD);
            break;
            
        case SCI_BRACEBADLIGHTINDICATOR:
            if (lParam >= 0 && lParam <= INDIC_MAX) {
                vs.braceBadLightIndicatorSet = wParam != 0;
                vs.braceBadLightIndicator = lParam;
            }
            break;
            
        case SCI_BRACEMATCH:
            // wParam is position of char to find brace for,
            // lParam is maximum amount of text to restyle to find it
            return pdoc->BraceMatch(wParam, lParam);
            
        case SCI_GETVIEWEOL:
            return vs.viewEOL;
            
        case SCI_SETVIEWEOL:
            vs.viewEOL = wParam != 0;
            InvalidateStyleRedraw();
            break;
            
        case SCI_SETZOOM:
            vs.zoomLevel = wParam;
            InvalidateStyleRedraw();
            NotifyZoom();
            break;
            
        case SCI_GETZOOM:
            return vs.zoomLevel;
            
        case SCI_GETEDGECOLUMN:
            return vs.theEdge;
            
        case SCI_SETEDGECOLUMN:
            vs.theEdge = wParam;
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETEDGEMODE:
            return vs.edgeState;
            
        case SCI_SETEDGEMODE:
            vs.edgeState = wParam;
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETEDGECOLOUR:
            return vs.edgecolour.AsLong();
            
        case SCI_SETEDGECOLOUR:
            vs.edgecolour = ColourDesired(wParam);
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETDOCPOINTER:
            return reinterpret_cast<sptr_t>(pdoc);
            
        case SCI_SETDOCPOINTER:
            CancelModes();
            SetDocPointer(reinterpret_cast<Document *>(lParam));
            return 0;
            
        case SCI_CREATEDOCUMENT: {
			Document *doc = new Document();
			doc->AddRef();
			return reinterpret_cast<sptr_t>(doc);
		}
            
        case SCI_ADDREFDOCUMENT:
            (reinterpret_cast<Document *>(lParam))->AddRef();
            break;
            
        case SCI_RELEASEDOCUMENT:
            (reinterpret_cast<Document *>(lParam))->Release();
            break;
            
        case SCI_CREATELOADER: {
			Document *doc = new Document();
			doc->AddRef();
			doc->Allocate(wParam);
			doc->SetUndoCollection(false);
			return reinterpret_cast<sptr_t>(static_cast<ILoader *>(doc));
		}
            
        case SCI_SETMODEVENTMASK:
            modEventMask = wParam;
            return 0;
            
        case SCI_GETMODEVENTMASK:
            return modEventMask;
            
        case SCI_CONVERTEOLS:
            pdoc->ConvertLineEnds(wParam);
            SetSelection(sel.MainCaret(), sel.MainAnchor());	// Ensure selection inside document
            return 0;
            
        case SCI_SETLENGTHFORENCODE:
            lengthForEncode = wParam;
            return 0;
            
        case SCI_SELECTIONISRECTANGLE:
            return sel.selType == Selection::selRectangle ? 1 : 0;
            
        case SCI_SETSELECTIONMODE: {
			switch (wParam) {
                case SC_SEL_STREAM:
                    sel.SetMoveExtends(!sel.MoveExtends() || (sel.selType != Selection::selStream));
                    sel.selType = Selection::selStream;
                    break;
                case SC_SEL_RECTANGLE:
                    sel.SetMoveExtends(!sel.MoveExtends() || (sel.selType != Selection::selRectangle));
                    sel.selType = Selection::selRectangle;
                    break;
                case SC_SEL_LINES:
                    sel.SetMoveExtends(!sel.MoveExtends() || (sel.selType != Selection::selLines));
                    sel.selType = Selection::selLines;
                    break;
                case SC_SEL_THIN:
                    sel.SetMoveExtends(!sel.MoveExtends() || (sel.selType != Selection::selThin));
                    sel.selType = Selection::selThin;
                    break;
                default:
                    sel.SetMoveExtends(!sel.MoveExtends() || (sel.selType != Selection::selStream));
                    sel.selType = Selection::selStream;
			}
			InvalidateSelection(sel.RangeMain(), true);
			break;
		}
        case SCI_GETSELECTIONMODE:
            switch (sel.selType) {
                case Selection::selStream:
                    return SC_SEL_STREAM;
                case Selection::selRectangle:
                    return SC_SEL_RECTANGLE;
                case Selection::selLines:
                    return SC_SEL_LINES;
                case Selection::selThin:
                    return SC_SEL_THIN;
                default:	// ?!
                    return SC_SEL_STREAM;
            }
        case SCI_GETLINESELSTARTPOSITION:
        case SCI_GETLINESELENDPOSITION: {
			SelectionSegment segmentLine(SelectionPosition(pdoc->LineStart(wParam)),
                                         SelectionPosition(pdoc->LineEnd(wParam)));
			for (size_t r=0; r<sel.Count(); r++) {
				SelectionSegment portion = sel.Range(r).Intersect(segmentLine);
				if (portion.start.IsValid()) {
					return (iMessage == SCI_GETLINESELSTARTPOSITION) ? portion.start.Position() : portion.end.Position();
				}
			}
			return INVALID_POSITION;
		}
            
        case SCI_SETOVERTYPE:
            inOverstrike = wParam != 0;
            break;
            
        case SCI_GETOVERTYPE:
            return inOverstrike ? 1 : 0;
            
        case SCI_SETFOCUS:
            SetFocusState(wParam != 0);
            break;
            
        case SCI_GETFOCUS:
            return hasFocus;
            
        case SCI_SETSTATUS:
            errorStatus = wParam;
            break;
            
        case SCI_GETSTATUS:
            return errorStatus;
            
        case SCI_SETMOUSEDOWNCAPTURES:
            mouseDownCaptures = wParam != 0;
            break;
            
        case SCI_GETMOUSEDOWNCAPTURES:
            return mouseDownCaptures;
            
        case SCI_SETCURSOR:
            cursorMode = wParam;
            DisplayCursor(Window::cursorText);
            break;
            
        case SCI_GETCURSOR:
            return cursorMode;
            
        case SCI_SETCONTROLCHARSYMBOL:
            vs.controlCharSymbol = wParam;
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETCONTROLCHARSYMBOL:
            return vs.controlCharSymbol;
            
        case SCI_SETREPRESENTATION:
            reprs.SetRepresentation(reinterpret_cast<const char *>(wParam), CharPtrFromSPtr(lParam));
            break;
            
        case SCI_GETREPRESENTATION: {
			Representation *repr = reprs.RepresentationFromCharacter(
                                                                     reinterpret_cast<const char *>(wParam), UTF8MaxBytes);
			if (repr) {
				if (lParam != 0)
					strcpy(CharPtrFromSPtr(lParam), repr->stringRep.c_str());
				return repr->stringRep.size();
			}
			return 0;
		}
            
        case SCI_CLEARREPRESENTATION:
            reprs.ClearRepresentation(reinterpret_cast<const char *>(wParam));
            break;
            
        case SCI_STARTRECORD:
            recordingMacro = true;
            return 0;
            
        case SCI_STOPRECORD:
            recordingMacro = false;
            return 0;
            
        case SCI_MOVECARETINSIDEVIEW:
            MoveCaretInsideView();
            break;
            
        case SCI_SETFOLDMARGINCOLOUR:
            vs.foldmarginColour = ColourOptional(wParam, lParam);
            InvalidateStyleRedraw();
            break;
            
        case SCI_SETFOLDMARGINHICOLOUR:
            vs.foldmarginHighlightColour = ColourOptional(wParam, lParam);
            InvalidateStyleRedraw();
            break;
            
        case SCI_SETHOTSPOTACTIVEFORE:
            vs.hotspotColours.fore = ColourOptional(wParam, lParam);
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETHOTSPOTACTIVEFORE:
            return vs.hotspotColours.fore.AsLong();
            
        case SCI_SETHOTSPOTACTIVEBACK:
            vs.hotspotColours.back = ColourOptional(wParam, lParam);
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETHOTSPOTACTIVEBACK:
            return vs.hotspotColours.back.AsLong();
            
        case SCI_SETHOTSPOTACTIVEUNDERLINE:
            vs.hotspotUnderline = wParam != 0;
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETHOTSPOTACTIVEUNDERLINE:
            return vs.hotspotUnderline ? 1 : 0;
            
        case SCI_SETHOTSPOTSINGLELINE:
            vs.hotspotSingleLine = wParam != 0;
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETHOTSPOTSINGLELINE:
            return vs.hotspotSingleLine ? 1 : 0;
            
        case SCI_SETPASTECONVERTENDINGS:
            convertPastes = wParam != 0;
            break;
            
        case SCI_GETPASTECONVERTENDINGS:
            return convertPastes ? 1 : 0;
            
        case SCI_GETCHARACTERPOINTER:
            return reinterpret_cast<sptr_t>(pdoc->BufferPointer());
            
        case SCI_GETRANGEPOINTER:
            return reinterpret_cast<sptr_t>(pdoc->RangePointer(wParam, lParam));
            
        case SCI_GETGAPPOSITION:
            return pdoc->GapPosition();
            
        case SCI_SETEXTRAASCENT:
            vs.extraAscent = wParam;
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETEXTRAASCENT:
            return vs.extraAscent;
            
        case SCI_SETEXTRADESCENT:
            vs.extraDescent = wParam;
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETEXTRADESCENT:
            return vs.extraDescent;
            
        case SCI_MARGINSETSTYLEOFFSET:
            vs.marginStyleOffset = wParam;
            InvalidateStyleRedraw();
            break;
            
        case SCI_MARGINGETSTYLEOFFSET:
            return vs.marginStyleOffset;
            
        case SCI_SETMARGINOPTIONS:
            marginOptions = wParam;
            break;
            
        case SCI_GETMARGINOPTIONS:
            return marginOptions;
            
        case SCI_MARGINSETTEXT:
            pdoc->MarginSetText(wParam, CharPtrFromSPtr(lParam));
            break;
            
        case SCI_MARGINGETTEXT: {
			const StyledText st = pdoc->MarginStyledText(wParam);
			if (lParam) {
				if (st.text)
					memcpy(CharPtrFromSPtr(lParam), st.text, st.length);
				else
					strcpy(CharPtrFromSPtr(lParam), "");
			}
			return st.length;
		}
            
        case SCI_MARGINSETSTYLE:
            pdoc->MarginSetStyle(wParam, lParam);
            break;
            
        case SCI_MARGINGETSTYLE: {
			const StyledText st = pdoc->MarginStyledText(wParam);
			return st.style;
		}
            
        case SCI_MARGINSETSTYLES:
            pdoc->MarginSetStyles(wParam, reinterpret_cast<const unsigned char *>(lParam));
            break;
            
        case SCI_MARGINGETSTYLES: {
			const StyledText st = pdoc->MarginStyledText(wParam);
			if (lParam) {
				if (st.styles)
					memcpy(CharPtrFromSPtr(lParam), st.styles, st.length);
				else
					strcpy(CharPtrFromSPtr(lParam), "");
			}
			return st.styles ? st.length : 0;
		}
            
        case SCI_MARGINTEXTCLEARALL:
            pdoc->MarginClearAll();
            break;
            
        case SCI_ANNOTATIONSETTEXT:
            pdoc->AnnotationSetText(wParam, CharPtrFromSPtr(lParam));
            break;
            
        case SCI_ANNOTATIONGETTEXT: {
			const StyledText st = pdoc->AnnotationStyledText(wParam);
			if (lParam) {
				if (st.text)
					memcpy(CharPtrFromSPtr(lParam), st.text, st.length);
				else
					strcpy(CharPtrFromSPtr(lParam), "");
			}
			return st.length;
		}
            
        case SCI_ANNOTATIONGETSTYLE: {
			const StyledText st = pdoc->AnnotationStyledText(wParam);
			return st.style;
		}
            
        case SCI_ANNOTATIONSETSTYLE:
            pdoc->AnnotationSetStyle(wParam, lParam);
            break;
            
        case SCI_ANNOTATIONSETSTYLES:
            pdoc->AnnotationSetStyles(wParam, reinterpret_cast<const unsigned char *>(lParam));
            break;
            
        case SCI_ANNOTATIONGETSTYLES: {
			const StyledText st = pdoc->AnnotationStyledText(wParam);
			if (lParam) {
				if (st.styles)
					memcpy(CharPtrFromSPtr(lParam), st.styles, st.length);
				else
					strcpy(CharPtrFromSPtr(lParam), "");
			}
			return st.styles ? st.length : 0;
		}
            
        case SCI_ANNOTATIONGETLINES:
            return pdoc->AnnotationLines(wParam);
            
        case SCI_ANNOTATIONCLEARALL:
            pdoc->AnnotationClearAll();
            break;
            
        case SCI_ANNOTATIONSETVISIBLE:
            SetAnnotationVisible(wParam);
            break;
            
        case SCI_ANNOTATIONGETVISIBLE:
            return vs.annotationVisible;
            
        case SCI_ANNOTATIONSETSTYLEOFFSET:
            vs.annotationStyleOffset = wParam;
            InvalidateStyleRedraw();
            break;
            
        case SCI_ANNOTATIONGETSTYLEOFFSET:
            return vs.annotationStyleOffset;
            
        case SCI_RELEASEALLEXTENDEDSTYLES:
            vs.ReleaseAllExtendedStyles();
            break;
            
        case SCI_ALLOCATEEXTENDEDSTYLES:
            return vs.AllocateExtendedStyles(wParam);
            
        case SCI_ADDUNDOACTION:
            pdoc->AddUndoAction(wParam, lParam & UNDO_MAY_COALESCE);
            break;
            
        case SCI_SETMOUSESELECTIONRECTANGULARSWITCH:
            mouseSelectionRectangularSwitch = wParam != 0;
            break;
            
        case SCI_GETMOUSESELECTIONRECTANGULARSWITCH:
            return mouseSelectionRectangularSwitch;
            
        case SCI_SETMULTIPLESELECTION:
            multipleSelection = wParam != 0;
            InvalidateCaret();
            break;
            
        case SCI_GETMULTIPLESELECTION:
            return multipleSelection;
            
        case SCI_SETADDITIONALSELECTIONTYPING:
            additionalSelectionTyping = wParam != 0;
            InvalidateCaret();
            break;
            
        case SCI_GETADDITIONALSELECTIONTYPING:
            return additionalSelectionTyping;
            
        case SCI_SETMULTIPASTE:
            multiPasteMode = wParam;
            break;
            
        case SCI_GETMULTIPASTE:
            return multiPasteMode;
            
        case SCI_SETADDITIONALCARETSBLINK:
            additionalCaretsBlink = wParam != 0;
            InvalidateCaret();
            break;
            
        case SCI_GETADDITIONALCARETSBLINK:
            return additionalCaretsBlink;
            
        case SCI_SETADDITIONALCARETSVISIBLE:
            additionalCaretsVisible = wParam != 0;
            InvalidateCaret();
            break;
            
        case SCI_GETADDITIONALCARETSVISIBLE:
            return additionalCaretsVisible;
            
        case SCI_GETSELECTIONS:
            return sel.Count();
            
        case SCI_GETSELECTIONEMPTY:
            return sel.Empty();
            
        case SCI_CLEARSELECTIONS:
            sel.Clear();
            Redraw();
            break;
            
        case SCI_SETSELECTION:
            sel.SetSelection(SelectionRange(wParam, lParam));
            Redraw();
            break;
            
        case SCI_ADDSELECTION:
            sel.AddSelection(SelectionRange(wParam, lParam));
            Redraw();
            break;
            
        case SCI_SETMAINSELECTION:
            sel.SetMain(wParam);
            Redraw();
            break;
            
        case SCI_GETMAINSELECTION:
            return sel.Main();
            
        case SCI_SETSELECTIONNCARET:
            sel.Range(wParam).caret.SetPosition(lParam);
            Redraw();
            break;
            
        case SCI_GETSELECTIONNCARET:
            return sel.Range(wParam).caret.Position();
            
        case SCI_SETSELECTIONNANCHOR:
            sel.Range(wParam).anchor.SetPosition(lParam);
            Redraw();
            break;
        case SCI_GETSELECTIONNANCHOR:
            return sel.Range(wParam).anchor.Position();
            
        case SCI_SETSELECTIONNCARETVIRTUALSPACE:
            sel.Range(wParam).caret.SetVirtualSpace(lParam);
            Redraw();
            break;
            
        case SCI_GETSELECTIONNCARETVIRTUALSPACE:
            return sel.Range(wParam).caret.VirtualSpace();
            
        case SCI_SETSELECTIONNANCHORVIRTUALSPACE:
            sel.Range(wParam).anchor.SetVirtualSpace(lParam);
            Redraw();
            break;
            
        case SCI_GETSELECTIONNANCHORVIRTUALSPACE:
            return sel.Range(wParam).anchor.VirtualSpace();
            
        case SCI_SETSELECTIONNSTART:
            sel.Range(wParam).anchor.SetPosition(lParam);
            Redraw();
            break;
            
        case SCI_GETSELECTIONNSTART:
            return sel.Range(wParam).Start().Position();
            
        case SCI_SETSELECTIONNEND:
            sel.Range(wParam).caret.SetPosition(lParam);
            Redraw();
            break;
            
        case SCI_GETSELECTIONNEND:
            return sel.Range(wParam).End().Position();
            
        case SCI_SETRECTANGULARSELECTIONCARET:
            if (!sel.IsRectangular())
                sel.Clear();
            sel.selType = Selection::selRectangle;
            sel.Rectangular().caret.SetPosition(wParam);
            SetRectangularRange();
            Redraw();
            break;
            
        case SCI_GETRECTANGULARSELECTIONCARET:
            return sel.Rectangular().caret.Position();
            
        case SCI_SETRECTANGULARSELECTIONANCHOR:
            if (!sel.IsRectangular())
                sel.Clear();
            sel.selType = Selection::selRectangle;
            sel.Rectangular().anchor.SetPosition(wParam);
            SetRectangularRange();
            Redraw();
            break;
            
        case SCI_GETRECTANGULARSELECTIONANCHOR:
            return sel.Rectangular().anchor.Position();
            
        case SCI_SETRECTANGULARSELECTIONCARETVIRTUALSPACE:
            if (!sel.IsRectangular())
                sel.Clear();
            sel.selType = Selection::selRectangle;
            sel.Rectangular().caret.SetVirtualSpace(wParam);
            SetRectangularRange();
            Redraw();
            break;
            
        case SCI_GETRECTANGULARSELECTIONCARETVIRTUALSPACE:
            return sel.Rectangular().caret.VirtualSpace();
            
        case SCI_SETRECTANGULARSELECTIONANCHORVIRTUALSPACE:
            if (!sel.IsRectangular())
                sel.Clear();
            sel.selType = Selection::selRectangle;
            sel.Rectangular().anchor.SetVirtualSpace(wParam);
            SetRectangularRange();
            Redraw();
            break;
            
        case SCI_GETRECTANGULARSELECTIONANCHORVIRTUALSPACE:
            return sel.Rectangular().anchor.VirtualSpace();
            
        case SCI_SETVIRTUALSPACEOPTIONS:
            virtualSpaceOptions = wParam;
            break;
            
        case SCI_GETVIRTUALSPACEOPTIONS:
            return virtualSpaceOptions;
            
        case SCI_SETADDITIONALSELFORE:
            vs.selAdditionalForeground = ColourDesired(wParam);
            InvalidateStyleRedraw();
            break;
            
        case SCI_SETADDITIONALSELBACK:
            vs.selAdditionalBackground = ColourDesired(wParam);
            InvalidateStyleRedraw();
            break;
            
        case SCI_SETADDITIONALSELALPHA:
            vs.selAdditionalAlpha = wParam;
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETADDITIONALSELALPHA:
            return vs.selAdditionalAlpha;
            
        case SCI_SETADDITIONALCARETFORE:
            vs.additionalCaretColour = ColourDesired(wParam);
            InvalidateStyleRedraw();
            break;
            
        case SCI_GETADDITIONALCARETFORE:
            return vs.additionalCaretColour.AsLong();
            
        case SCI_ROTATESELECTION:
            sel.RotateMain();
            InvalidateSelection(sel.RangeMain(), true);
            break;
            
        case SCI_SWAPMAINANCHORCARET:
            InvalidateSelection(sel.RangeMain());
            sel.RangeMain() = SelectionRange(sel.RangeMain().anchor, sel.RangeMain().caret);
            break;
            
        case SCI_CHANGELEXERSTATE:
            pdoc->ChangeLexerState(wParam, lParam);
            break;
            
        case SCI_SETIDENTIFIER:
            SetCtrlID(wParam);
            break;
            
        case SCI_GETIDENTIFIER:
            return GetCtrlID();
            
        case SCI_SETTECHNOLOGY:
            // No action by default
            break;
            
        case SCI_GETTECHNOLOGY:
            return technology;
            
        case SCI_COUNTCHARACTERS:
            return pdoc->CountCharacters(wParam, lParam);
            
        default:
            return DefWndProc(iMessage, wParam, lParam);
	}
	//Platform::DebugPrintf("end wnd proc\n");
	return 0l;
}
