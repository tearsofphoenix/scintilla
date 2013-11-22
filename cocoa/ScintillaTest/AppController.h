/**
 * AppController.h
 * SciTest
 *
 * Created by Mike Lischke on 01.04.09.
 * Copyright 2009 Sun Microsystems, Inc. All rights reserved.
 * This file is dual licensed under LGPL v2.1 and the Scintilla license (http://www.scintilla.org/License.txt).
 */

#import <Cocoa/Cocoa.h>


@class ScintillaView;

@interface AppController : NSObject
{
    IBOutlet NSView *mEditHost;
    ScintillaView* mEditor;
}

- (void)awakeFromNib;

- (void)setupEditor;

- (IBAction)showPreferencesPanel: (id)sender;

@end
