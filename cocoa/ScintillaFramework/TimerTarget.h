//
//  TimerTarget.h
//  Scintilla
//
//  Created by Mac003 on 13-11-20.
//
//

#import <Foundation/Foundation.h>

/**
 * Helper class to be used as timer target (NSTimer).
 */
@interface TimerTarget : NSObject
{
    void* mTarget;
    NSNotificationQueue* notificationQueue;
}

- (id) init: (void*) target;
- (void) timerFired: (NSTimer*) timer;
- (void) idleTimerFired: (NSTimer*) timer;
- (void) idleTriggered: (NSNotification*) notification;

@end