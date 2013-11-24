//
//  SCIEditorNotify.cpp
//  Scintilla
//
//  Created by Mac003 on 13-11-22.
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

void Editor::NotifyStyleToNeeded(int endStyleNeeded) {
	SCNotification scn = {};
	scn.nmhdr.code = SCN_STYLENEEDED;
	scn.position = endStyleNeeded;
	NotifyParent(scn);
}

void Editor::NotifyStyleNeeded(Document *, void *, int endStyleNeeded) {
	NotifyStyleToNeeded(endStyleNeeded);
}

void Editor::NotifyLexerChanged(Document *, void *) {
}

void Editor::NotifyErrorOccurred(Document *, void *, int status) {
	errorStatus = status;
}

void Editor::NotifyChar(int ch) {
	SCNotification scn = {};
	scn.nmhdr.code = SCN_CHARADDED;
	scn.ch = ch;
	NotifyParent(scn);
}

void Editor::NotifySavePoint(bool isSavePoint) {
	SCNotification scn = {};
	if (isSavePoint) {
		scn.nmhdr.code = SCN_SAVEPOINTREACHED;
	} else {
		scn.nmhdr.code = SCN_SAVEPOINTLEFT;
	}
	NotifyParent(scn);
}

void Editor::NotifyModifyAttempt() {
	SCNotification scn = {};
	scn.nmhdr.code = SCN_MODIFYATTEMPTRO;
	NotifyParent(scn);
}

void Editor::NotifyDoubleClick(Point pt, bool shift, bool ctrl, bool alt) {
	SCNotification scn = {};
	scn.nmhdr.code = SCN_DOUBLECLICK;
	scn.line = LineFromLocation(pt);
	scn.position = PositionFromLocation(pt, true);
	scn.modifiers = (shift ? SCI_SHIFT : 0) | (ctrl ? SCI_CTRL : 0) |
    (alt ? SCI_ALT : 0);
	NotifyParent(scn);
}

void Editor::NotifyHotSpotDoubleClicked(int position, bool shift, bool ctrl, bool alt) {
	SCNotification scn = {};
	scn.nmhdr.code = SCN_HOTSPOTDOUBLECLICK;
	scn.position = position;
	scn.modifiers = (shift ? SCI_SHIFT : 0) | (ctrl ? SCI_CTRL : 0) |
    (alt ? SCI_ALT : 0);
	NotifyParent(scn);
}

void Editor::NotifyHotSpotClicked(int position, bool shift, bool ctrl, bool alt) {
	SCNotification scn = {};
	scn.nmhdr.code = SCN_HOTSPOTCLICK;
	scn.position = position;
	scn.modifiers = (shift ? SCI_SHIFT : 0) | (ctrl ? SCI_CTRL : 0) |
    (alt ? SCI_ALT : 0);
	NotifyParent(scn);
}

void Editor::NotifyHotSpotReleaseClick(int position, bool shift, bool ctrl, bool alt) {
	SCNotification scn = {};
	scn.nmhdr.code = SCN_HOTSPOTRELEASECLICK;
	scn.position = position;
	scn.modifiers = (shift ? SCI_SHIFT : 0) | (ctrl ? SCI_CTRL : 0) |
    (alt ? SCI_ALT : 0);
	NotifyParent(scn);
}

bool Editor::NotifyUpdateUI() {
	if (needUpdateUI) {
		SCNotification scn = {};
		scn.nmhdr.code = SCN_UPDATEUI;
		scn.updated = needUpdateUI;
		NotifyParent(scn);
		needUpdateUI = 0;
		return true;
	}
	return false;
}

void Editor::NotifyPainted() {
	SCNotification scn = {};
	scn.nmhdr.code = SCN_PAINTED;
	NotifyParent(scn);
}

void Editor::NotifyIndicatorClick(bool click, int position, bool shift, bool ctrl, bool alt) {
	int mask = pdoc->decorations.AllOnFor(position);
	if ((click && mask) || pdoc->decorations.clickNotified) {
		SCNotification scn = {};
		pdoc->decorations.clickNotified = click;
		scn.nmhdr.code = click ? SCN_INDICATORCLICK : SCN_INDICATORRELEASE;
		scn.modifiers = (shift ? SCI_SHIFT : 0) | (ctrl ? SCI_CTRL : 0) | (alt ? SCI_ALT : 0);
		scn.position = position;
		NotifyParent(scn);
	}
}

bool Editor::NotifyMarginClick(Point pt, bool shift, bool ctrl, bool alt) {
	int marginClicked = -1;
	int x = vs.textStart - vs.fixedColumnWidth;
	for (int margin = 0; margin <= SC_MAX_MARGIN; margin++) {
		if ((pt.x >= x) && (pt.x < x + vs.ms[margin].width))
			marginClicked = margin;
		x += vs.ms[margin].width;
	}
	if ((marginClicked >= 0) && vs.ms[marginClicked].sensitive) {
		int position = pdoc->LineStart(LineFromLocation(pt));
		if ((vs.ms[marginClicked].mask & SC_MASK_FOLDERS) && (foldAutomatic & SC_AUTOMATICFOLD_CLICK)) {
			int lineClick = pdoc->LineFromPosition(position);
			if (shift && ctrl) {
				FoldAll(SC_FOLDACTION_TOGGLE);
			} else {
				int levelClick = pdoc->GetLevel(lineClick);
				if (levelClick & SC_FOLDLEVELHEADERFLAG) {
					if (shift) {
						// Ensure all children visible
						FoldExpand(lineClick, SC_FOLDACTION_EXPAND, levelClick);
					} else if (ctrl) {
						FoldExpand(lineClick, SC_FOLDACTION_TOGGLE, levelClick);
					} else {
						// Toggle this line
						FoldLine(lineClick, SC_FOLDACTION_TOGGLE);
					}
				}
			}
			return true;
		}
		SCNotification scn = {};
		scn.nmhdr.code = SCN_MARGINCLICK;
		scn.modifiers = (shift ? SCI_SHIFT : 0) | (ctrl ? SCI_CTRL : 0) |
        (alt ? SCI_ALT : 0);
		scn.position = position;
		scn.margin = marginClicked;
		NotifyParent(scn);
		return true;
	} else {
		return false;
	}
}

void Editor::NotifyNeedShown(int pos, int len) {
	SCNotification scn = {};
	scn.nmhdr.code = SCN_NEEDSHOWN;
	scn.position = pos;
	scn.length = len;
	NotifyParent(scn);
}

void Editor::NotifyDwelling(Point pt, bool state) {
	SCNotification scn = {};
	scn.nmhdr.code = state ? SCN_DWELLSTART : SCN_DWELLEND;
	scn.position = PositionFromLocation(pt, true);
	scn.x = pt.x + vs.ExternalMarginWidth();
	scn.y = pt.y;
	NotifyParent(scn);
}

void Editor::NotifyZoom() {
	SCNotification scn = {};
	scn.nmhdr.code = SCN_ZOOM;
	NotifyParent(scn);
}

// Notifications from document
void Editor::NotifyModifyAttempt(Document *, void *) {
	//Platform::DebugPrintf("** Modify Attempt\n");
	NotifyModifyAttempt();
}

void Editor::NotifySavePoint(Document *, void *, bool atSavePoint) {
	//Platform::DebugPrintf("** Save Point %s\n", atSavePoint ? "On" : "Off");
	NotifySavePoint(atSavePoint);
}
