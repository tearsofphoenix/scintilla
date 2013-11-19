//
//  VEBundle.m
//  VEBundle
//
//  Created by Lei on 11/19/13.
//  Copyright (c) 2013 Lei. All rights reserved.
//

#import "VEBundle.h"


@interface VEBundle ()
{
    NSDictionary *_bundleInfo;
    
    NSMutableArray *_commands;
    NSMutableArray *_preferences;
    NSMutableArray *_snippets;
    NSMutableArray *_syntaxes;
}
@end

@implementation VEBundle

- (id)init
{
    [self doesNotRecognizeSelector: _cmd];
    return nil;
}

static void VEBundleLoadPlistInFolder(NSMutableArray *array, NSString *folder)
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *names = [fileManager contentsOfDirectoryAtPath:folder
                                                      error: &error];
    if (error)
    {
        NSLog(@"%@", error);
    }else
    {
        for (NSString *nLooper in names)
        {
            NSString *pathLooper = [folder stringByAppendingPathComponent: nLooper];
            
            NSDictionary *dictLooper = [[NSDictionary alloc] initWithContentsOfFile: pathLooper];
            [array addObject: dictLooper];
            [dictLooper release];
        }
    }
}

- (id)initWithPath: (NSString *)path
{
    if ((self = [super init]))
    {
        NSString *infoPath = [path stringByAppendingPathComponent: @"Info.plist"];
        _bundleInfo = [[NSDictionary alloc] initWithContentsOfFile: infoPath];
        
        _commands = [[NSMutableArray alloc] init];
        _preferences = [[NSMutableArray alloc] init];
        _snippets = [[NSMutableArray alloc] init];
        _syntaxes = [[NSMutableArray alloc] init];
        
        NSString *commandsFolder = [path stringByAppendingPathComponent: @"Commands"];
        NSString *preferencesFolder = [path stringByAppendingPathComponent: @"Preferences"];
        NSString *snippetsFolder = [path stringByAppendingPathComponent: @"Snippets"];
        NSString *syntaxesFolder = [path stringByAppendingPathComponent: @"Syntaxes"];
        
        VEBundleLoadPlistInFolder(_commands, commandsFolder);
        VEBundleLoadPlistInFolder(_preferences, preferencesFolder);
        VEBundleLoadPlistInFolder(_snippets, snippetsFolder);
        VEBundleLoadPlistInFolder(_syntaxes, syntaxesFolder);
    }
    
    return self;
}

- (void)dealloc
{
    [_bundleInfo release];
    
    [_commands release];
    [_preferences release];
    [_snippets release];
    [_syntaxes release];
    
    [super dealloc];
}

@end
