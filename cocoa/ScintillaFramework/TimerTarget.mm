//
//  TimerTarget.m
//  Scintilla
//
//  Created by Mac003 on 13-11-20.
//
//

#import "TimerTarget.h"
#import "Platform.h"
#import "Scintilla.h"
#import "SCIController.h"

using namespace Scintilla;

@implementation TimerTarget

- (id) init: (void*) target
{
    self = [super init];
    if (self != nil)
    {
        mTarget = target;
        
        // Get the default notification queue for the thread which created the instance (usually the
        // main thread). We need that later for idle event processing.
        NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
        notificationQueue = [[NSNotificationQueue alloc] initWithNotificationCenter: center];
        [center addObserver: self
                   selector: @selector(idleTriggered:)
                       name: @"Idle"
                     object: nil];
    }
    return self;
}



- (void) dealloc
{
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center removeObserver: self];
    [notificationQueue release];
    [super dealloc];
}



/**
 * Method called by a timer installed by SCIController. This two step approach is needed because
 * a native Obj-C class is required as target for the timer.
 */
- (void) timerFired: (NSTimer*) timer
{
    reinterpret_cast<SCIController*>(mTarget)->TimerFired(timer);
}



/**
 * Another timer callback for the idle timer.
 */
- (void) idleTimerFired: (NSTimer*) timer
{
#pragma unused(timer)
    // Idle timer event.
    // Post a new idle notification, which gets executed when the run loop is idle.
    // Since we are coalescing on name and sender there will always be only one actual notification
    // even for multiple requests.
    NSNotification *notification = [NSNotification notificationWithName: @"Idle"
                                                                 object: self];
    [notificationQueue enqueueNotification: notification
                              postingStyle: NSPostWhenIdle
                              coalesceMask: (NSNotificationCoalescingOnName
                                             | NSNotificationCoalescingOnSender)
                                  forModes: nil];
}



/**
 * Another step for idle events. The timer (for idle events) simply requests a notification on
 * idle time. Only when this notification is send we actually call back the editor.
 */
- (void) idleTriggered: (NSNotification*) notification
{
#pragma unused(notification)
    reinterpret_cast<SCIController*>(mTarget)->IdleTimerFired();
}

@end
