//
//  ScintillaNotificationProtocol.h
//  Scintilla
//
//  Created by Mac003 on 13-11-20.
//
//

#import <Foundation/Foundation.h>
#import "Scintilla.h"

namespace Scintilla
{
    /**
     * On the Mac, there is no WM_COMMAND or WM_NOTIFY message that can be sent
     * back to the parent. Therefore, there must be a callback handler that acts
     * like a Windows WndProc, where Scintilla can send notifications to. Use
     * ScintillaView registerNotifyCallback() to register such a handler.
     * Message format is:
     * <br>
     * WM_COMMAND: HIWORD (wParam) = notification code, LOWORD (wParam) = control ID, lParam = SCIController*
     * <br>
     * WM_NOTIFY: wParam = control ID, lParam = ptr to SCNotification structure, with hwndFrom set to SCIController*
     */
    typedef void(*SciNotifyFunc) (intptr_t windowid, unsigned int iMessage, uintptr_t wParam, uintptr_t lParam);
    
    class SCIController;
}

@protocol ScintillaNotificationProtocol

- (void)notification: (Scintilla::SCNotification *)notification;

@end
