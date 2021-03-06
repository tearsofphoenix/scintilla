/*
 * SCIController.h
 *
 * Mike Lischke <mlischke@sun.com>
 *
 * Based on ScintillaMacOSX.h
 * Original code by Evan Jones on Sun Sep 01 2002.
 *  Contributors:
 *  Shane Caraveo, ActiveState
 *  Bernd Paradies, Adobe
 *
 * Copyright 2009 Sun Microsystems, Inc. All rights reserved.
 * This file is dual licensed under LGPL v2.1 and the Scintilla license (http://www.scintilla.org/License.txt).
 */

#include <stdlib.h>
#include <string>
#include <stdio.h>
#include <ctype.h>
#include <time.h>

#include <vector>
#include <map>

#include "ILexer.h"

#ifdef SCI_LEXER
#include "SciLexer.h"
#include "PropSetSimple.h"
#endif

#include "SplitVector.h"
#include "Partitioning.h"
#include "RunStyles.h"
#include "ContractionState.h"
#include "CellBuffer.h"
#include "CallTip.h"
#include "KeyMap.h"
#include "Indicator.h"
#include "XPM.h"
#include "LineMarker.h"
#include "Style.h"
#include "AutoComplete.h"
#include "ViewStyle.h"
#include "CharClassify.h"
#include "Decoration.h"
#include "CaseFolder.h"
#include "Document.h"
#include "Selection.h"
#include "PositionCache.h"
#include "Editor.h"

#include "ScintillaBase.h"
#include "CaseConvert.h"
#include "ScintillaNotificationProtocol.h"

extern "C" NSString* ScintillaRecPboardType;

@class SCIContentView;
@class SCIMarginView;
@class ScintillaView;

@class FindHighlightLayer;
@class TimerTarget;
@class SCIDebugServer;

namespace Scintilla
{

    /**
     * Main scintilla class, implemented for OS X (Cocoa).
     */
    class SCIController : public ScintillaBase
    {
    private:
        TimerTarget* timerTarget;
        NSEvent* lastMouseEvent;
        
        id<ScintillaNotificationProtocol> delegate;
        
        SciNotifyFunc	notifyProc;
        intptr_t notifyObj;
        
        bool capturedMouse;
        
        bool enteredSetScrollingSize;
        
        // Private so SCIController objects can not be copied
        SCIController(const SCIController &) : ScintillaBase() {}
        SCIController &operator=(const SCIController &) { return * this; }
        
        bool GetPasteboardData(NSPasteboard* board, SelectionText* selectedText);
        void SetPasteboardData(NSPasteboard* board, const SelectionText& selectedText);
        
        int scrollSpeed;
        int scrollTicks;
        NSTimer* tickTimer;
        NSTimer* idleTimer;
        CFRunLoopObserverRef observer;
        
        FindHighlightLayer *layerFindIndicator;
        SCIDebugServer *_debugServer;
        
    protected:
        Point GetVisibleOriginInMain();
        PRectangle GetClientRectangle();
        Point ConvertPoint(NSPoint point);
        
        virtual void Initialise();
        virtual void Finalise();
        virtual CaseFolder *CaseFolderForEncoding();
        virtual std::string CaseMapString(const std::string &s, int caseMapping);
        virtual void CancelModes();
        
    public:
        SCIController(SCIContentView* view, SCIMarginView* viewMargin);
        virtual ~SCIController();
        
        void SetDelegate(id<ScintillaNotificationProtocol> delegate_);
        void RegisterNotifyCallback(intptr_t windowid, SciNotifyFunc callback);
        sptr_t WndProc(unsigned int iMessage, uptr_t wParam, sptr_t lParam);
        
        ScintillaView* TopContainer();
        NSScrollView* ScrollContainer();
        SCIContentView* ContentView();
        
        bool SyncPaint(void* gc, PRectangle rc);
        bool Draw(NSRect rect, CGContextRef gc);
        void PaintMargin(NSRect aRect);
        
        virtual sptr_t DefWndProc(unsigned int iMessage, uptr_t wParam, sptr_t lParam);
        void SetTicking(bool on);
        bool SetIdle(bool on);
        void SetMouseCapture(bool on);
        bool HaveMouseCapture();
        void ScrollText(int linesToMove);
        void SetVerticalScrollPos();
        void SetHorizontalScrollPos();
        bool ModifyScrollBars(int nMax, int nPage);
        bool SetScrollingSize(void);
        void Resize();
        void UpdateForScroll();
        
        // Notifications for the owner.
        void NotifyChange();
        void NotifyFocus(bool focus);
        void NotifyParent(SCNotification scn);
        void NotifyURIDropped(const char *uri);
        
        bool HasSelection();
        bool CanUndo();
        bool CanRedo();
        virtual void CopyToClipboard(const SelectionText &selectedText);
        virtual void Copy();
        virtual bool CanPaste();
        virtual void Paste();
        virtual void Paste(bool rectangular);
        void CTPaint(void* gc, NSRect rc);
        void CallTipMouseDown(NSPoint pt);
        virtual void CreateCallTipWindow(PRectangle rc);
        virtual void AddToPopUp(const char *label, int cmd = 0, bool enabled = true);
        virtual void ClaimSelection();
        
        NSPoint GetCaretPosition();
        
        static sptr_t DirectFunction(SCIController *sciThis, unsigned int iMessage, uptr_t wParam, sptr_t lParam);
        
        void TimerFired(NSTimer* timer);
        void IdleTimerFired();
        static void UpdateObserver(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *sci);
        void ObserverAdd();
        void ObserverRemove();
        virtual void IdleWork();
        virtual void QueueIdleWork(WorkNeeded::workItems items, int upTo);
        int InsertText(NSString* input);
        void SelectOnlyMainSelection();
        virtual void SetDocPointer(Document *document);
        
        bool KeyboardInput(NSEvent* event);
        void MouseDown(NSEvent* event);
        void MouseMove(NSEvent* event);
        void MouseUp(NSEvent* event);
        void MouseEntered(NSEvent* event);
        void MouseExited(NSEvent* event);
        void MouseWheel(NSEvent* event);
        
        // Drag and drop
        void StartDrag();
        bool GetDragData(id <NSDraggingInfo> info, NSPasteboard &pasteBoard, SelectionText* selectedText);
        NSDragOperation DraggingEntered(id <NSDraggingInfo> info);
        NSDragOperation DraggingUpdated(id <NSDraggingInfo> info);
        void DraggingExited(id <NSDraggingInfo> info);
        bool PerformDragOperation(id <NSDraggingInfo> info);
        void DragScroll();
        
        // Promote some methods needed for NSResponder actions.
        void DeleteBackward();
        
        virtual NSMenu* CreateContextMenu(NSEvent* event);
        void HandleCommand(NSInteger command);
        
        virtual void ActiveStateChanged(bool isActive);
        
        // Find indicator
        void ShowFindIndicatorForRange(NSRange charRange, BOOL retaining);
        void MoveFindIndicatorWithBounce(BOOL bounce);
        void HideFindIndicator();
        
        //debug support
        void didClickedMarginAtLineNumber(int lineAnchorPosition);
    };
    
    
}


