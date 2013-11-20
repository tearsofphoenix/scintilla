//
//  ScintillaContextMenu.h
//  Scintilla
//
//  Created by Mac003 on 13-11-20.
//
//

#import <Cocoa/Cocoa.h>

@interface ScintillaContextMenu : NSMenu

@property (nonatomic, assign) void *owner;

- (void) handleCommand: (NSMenuItem*) sender;

@end