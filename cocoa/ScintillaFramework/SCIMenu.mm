//
//  SCIMenu.mm
//  Scintilla
//
//  Created by Mac003 on 13-11-20.
//
//

#import "PlatCocoa.h"
#import "ScintillaContextMenu.h"

using namespace Scintilla;

Menu::Menu()
: mid(0)
{
}



void Menu::CreatePopUp()
{
    Destroy();
    mid = [[ScintillaContextMenu alloc] initWithTitle: @""];
}



void Menu::Destroy()
{
    ScintillaContextMenu* menu = reinterpret_cast<ScintillaContextMenu*>(mid);
    [menu release];
    mid = NULL;
}



void Menu::Show(Point, Window &)
{
    // Cocoa menus are handled a bit differently. We only create the menu. The framework
    // takes care to show it properly.
}