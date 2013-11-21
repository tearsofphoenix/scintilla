//
//  ScintillaContextMenu.m
//  Scintilla
//
//  Created by Mac003 on 13-11-20.
//
//

#import "Scintilla.h"
#import "Platform.h"
#import "ScintillaView.h"
#import "ScintillaContextMenu.h"
#import "SCIController.h"

@implementation ScintillaContextMenu : NSMenu

// This NSMenu subclass serves also as target for menu commands and forwards them as
// notification messages to the front end.

- (void) handleCommand: (NSMenuItem *) sender
{
    Scintilla::SCIController* temp = (Scintilla::SCIController *)_owner;
    temp->HandleCommand([sender tag]);
}

@end
