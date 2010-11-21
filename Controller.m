//
//  Controller.m
//  MiddleClick
//
//  Created by Alex Galonsky on 11/9/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "Controller.h"
#import <Cocoa/Cocoa.h>
#import "TrayMenu.h"
#include <math.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h> 
#import "WakeObserver.h"




@implementation Controller

CGEventRef clickCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
	
	CGPoint ourLoc = CGEventGetLocation(event);
	
	if(threeDown)
	{
		if(type == kCGEventLeftMouseDown)
		{
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
			CGEventPost (kCGHIDEventTap, CGEventCreateMouseEvent (NULL,kCGEventOtherMouseDown,ourLoc,kCGMouseButtonCenter));
#else
			CGPostMouseEvent( ourLoc, 1, 3, 0, 0, 1);
#endif
		}
		else if(type == kCGEventLeftMouseUp)
		{
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
			CGEventPost (kCGHIDEventTap, CGEventCreateMouseEvent (NULL,kCGEventOtherMouseUp,ourLoc,kCGMouseButtonCenter));
#else
			CGPostMouseEvent( ourLoc, 1, 3, 0, 0, 0);
#endif
			
		}
		return NULL;
	}


	return event;
}

- (void) start
{
	threeDown = NO;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	
    [NSApplication sharedApplication];
	
	
	
	tap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, CGEventMaskBit(kCGEventLeftMouseUp) | CGEventMaskBit(kCGEventLeftMouseDown), clickCallback, NULL);
	CGEventTapEnable(tap, FALSE);
	
	CFRunLoopSourceRef loop = CFMachPortCreateRunLoopSource(NULL, tap, 0);
	CFRunLoopAddSource(CFRunLoopGetMain(), loop, kCFRunLoopDefaultMode);
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *appDefaults = [NSDictionary
								 dictionaryWithObject:@"NO" forKey:@"NeedToClick"];
	
    [defaults registerDefaults:appDefaults];
	
	needToClick = [[NSUserDefaults standardUserDefaults] boolForKey:@"NeedToClick"];
	
	//Get list of all multi touch devices
	NSMutableArray* deviceList = (NSMutableArray*)MTDeviceCreateList(); //grab our device list
	
	
	//Iterate and register callbacks for multitouch devices.
	for(int i = 0; i<[deviceList count]; i++) //iterate available devices
	{
		MTRegisterContactFrameCallback((MTDeviceRef)[deviceList objectAtIndex:i], callback); //assign callback for device
		MTDeviceStart((MTDeviceRef)[deviceList objectAtIndex:i]); //start sending events
	}
	
	
	//register a callback to know when osx come back from sleep
	WakeObserver *wo = [[WakeObserver alloc] init];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: wo selector: @selector(receiveWakeNote:) name: NSWorkspaceDidWakeNotification object: NULL];
	
	
	//add traymenu
    TrayMenu *menu = [[TrayMenu alloc] initWithController:self];
    [NSApp setDelegate:menu];
    [NSApp run];
	
	[pool release];
}

- (BOOL)getClickMode
{
	return needToClick;
}

- (void)setMode:(BOOL)click
{
	needToClick = click;
	if(click)
	{
		[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"NeedToClick"];
	}
	else {
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:@"NeedToClick"];
	}

}

int callback(int device, Finger *data, int nFingers, double timestamp, int frame) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	if(needToClick)
	{
		
		if(nFingers == 3)
		{
			if(!pressed)
			{
				threeDown = YES;
				CGEventTapEnable(tap, TRUE);
				pressed = YES;
			}
			
		}
		
		if(nFingers == 0) {
			if(pressed)
			{
				threeDown = NO;
				CGEventTapEnable(tap, FALSE);
				
				pressed = NO;
			}
		}
	}
	else
	{
		if (nFingers==0)
		{
			if (removeFingerStartTime)
			{
				if (fabs([removeFingerStartTime timeIntervalSinceNow]) > 0.25)
					maybeMiddleClick = NO;
				
				[removeFingerStartTime release];
				removeFingerStartTime = NULL;
			}
			
			if (maybeMiddleClick == YES)
			{
				// Emulate a middle click
				
				// get the current pointer location
				CGEventRef ourEvent = CGEventCreate(NULL);
				CGPoint ourLoc = CGEventGetLocation(ourEvent);
				
				/*
				 // CMD+Click code
				 CGPostKeyboardEvent( (CGCharCode)0, (CGKeyCode)55, true );
				 CGPostMouseEvent( ourLoc, 1, 1, 1);
				 CGPostMouseEvent( ourLoc, 1, 1, 0);
				 CGPostKeyboardEvent( (CGCharCode)0, (CGKeyCode)55, false );
				 */
				
				// Real middle click
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
				CGEventPost (kCGHIDEventTap, CGEventCreateMouseEvent (NULL,kCGEventOtherMouseDown,ourLoc,kCGMouseButtonCenter));
				CGEventPost (kCGHIDEventTap, CGEventCreateMouseEvent (NULL,kCGEventOtherMouseUp,ourLoc,kCGMouseButtonCenter));
#else
				CGPostMouseEvent( ourLoc, 1, 3, 0, 0, 1);
				CGPostMouseEvent( ourLoc, 1, 3, 0, 0, 0);
#endif
			}
			
			touchStart = FALSE;
			maybeMiddleClick = NO;
		}
		
		if (nFingers == 3)
		{
			Finger *f1 = &data[0];
			Finger *f2 = &data[1];
			Finger *f3 = &data[2];
			
			[removeFingerStartTime release];
			removeFingerStartTime = NULL;
			
			if (!touchStart)
			{
				touchStart = TRUE;
				
				maybeMiddleClick = YES;
				
				middleclickX = (f1->normalized.pos.x+f2->normalized.pos.x+f3->normalized.pos.x);
				middleclickY = (f1->normalized.pos.y+f2->normalized.pos.y+f3->normalized.pos.y);
			}
			else
			{
				if (maybeMiddleClick == YES)
				{
					float middleclickX2, middleclickY2;
					
					middleclickX2 = (f1->normalized.pos.x+f2->normalized.pos.x+f3->normalized.pos.x);
					middleclickY2 = (f1->normalized.pos.y+f2->normalized.pos.y+f3->normalized.pos.y);
					
					float delta = ABS(middleclickX-middleclickX2)+ABS(middleclickY-middleclickY2);
					if (delta > 0.1f)
					{
						maybeMiddleClick = NO;
					}
				}
				
			}
		}
		
		if ((nFingers == 2) || (nFingers > 3))
		{
			if ((maybeMiddleClick == YES) && (removeFingerStartTime == NULL))
				removeFingerStartTime = [[NSDate alloc] init];
		}
	}
	
	[pool release];
	return 0;
}

@end
