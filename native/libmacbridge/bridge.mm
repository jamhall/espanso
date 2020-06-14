/*
 * This file is part of espanso.
 *
 * Copyright (C) 2019 Federico Terzi
 *
 * espanso is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * espanso is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with espanso.  If not, see <https://www.gnu.org/licenses/>.
 */

#include "bridge.h"

#import <Foundation/Foundation.h>
#include <IOKit/IOKitLib.h>
#include "AppDelegate.h"
#include <stdio.h>
#include <string.h>
#include <libproc.h>
extern "C" {

}

#include <vector>

void * context_instance;
char * icon_path;
int32_t show_icon;
AppDelegate * delegate_ptr;

KeypressCallback keypress_callback;
IconClickCallback icon_click_callback;
ContextMenuClickCallback context_menu_click_callback;

int32_t initialize(void * context, const char * _icon_path, int32_t _show_icon) {
    context_instance = context;
    icon_path = strdup(_icon_path);
    show_icon = _show_icon;

    AppDelegate *delegate = [[AppDelegate alloc] init];
    delegate_ptr = delegate;
    NSApplication * application = [NSApplication sharedApplication];
    [application setDelegate:delegate];
}

void register_keypress_callback(KeypressCallback callback) {
    keypress_callback = callback;
}

void register_icon_click_callback(IconClickCallback callback) {
    icon_click_callback = callback;
}

void register_context_menu_click_callback(ContextMenuClickCallback callback) {
    context_menu_click_callback = callback;
}


int32_t eventloop() {
    [NSApp run];
}

int32_t headless_eventloop() {
    NSApplication * application = [NSApplication sharedApplication];
    [NSApp run];
    return 0;
}

void send_string(const char * string) {
    char * stringCopy = strdup(string);
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        // Convert the c string to a UniChar array as required by the CGEventKeyboardSetUnicodeString method
        NSString *nsString = [NSString stringWithUTF8String:stringCopy];
        CFStringRef cfString = (__bridge CFStringRef) nsString;
        std::vector <UniChar> buffer(nsString.length);
        CFStringGetCharacters(cfString, CFRangeMake(0, nsString.length), buffer.data());

        free(stringCopy);

        // Send the event

        // Check if the shift key is down, and if so, release it
        // To see why: https://github.com/federico-terzi/espanso/issues/279
        if (CGEventSourceKeyState(kCGEventSourceStateHIDSystemState, 0x38)) {
            CGEventRef e2 = CGEventCreateKeyboardEvent(NULL, 0x38, false);
            CGEventPost(kCGHIDEventTap, e2);
            CFRelease(e2);

            usleep(2000);
        }

        // Because of a bug ( or undocumented limit ) of the CGEventKeyboardSetUnicodeString method
        // the string gets truncated after 20 characters, so we need to send multiple events.

        int i = 0;
        while (i < buffer.size()) {
            int chunk_size = 20;
            if ((i+chunk_size) >  buffer.size()) {
                chunk_size = buffer.size() - i;
            }

            UniChar * offset_buffer = buffer.data() + i;
            CGEventRef e = CGEventCreateKeyboardEvent(NULL, 0x31, true);
            CGEventKeyboardSetUnicodeString(e, chunk_size, offset_buffer);
            CGEventPost(kCGHIDEventTap, e);
            CFRelease(e);

            usleep(2000);

            // Some applications require an explicit release of the space key
            // For more information: https://github.com/federico-terzi/espanso/issues/159
            CGEventRef e2 = CGEventCreateKeyboardEvent(NULL, 0x31, false);
            CGEventPost(kCGHIDEventTap, e2);
            CFRelease(e2);

            usleep(2000);

            i += chunk_size;
        }
    });
}

void delete_string(int32_t count) {
    send_multi_vkey(0x33, count);
}

void send_vkey(int32_t vk) {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        CGEventRef keydown;
        keydown = CGEventCreateKeyboardEvent(NULL, vk, true);
        CGEventPost(kCGHIDEventTap, keydown);
        CFRelease(keydown);

        usleep(500);

        CGEventRef keyup;
        keyup = CGEventCreateKeyboardEvent(NULL, vk, false);
        CGEventPost(kCGHIDEventTap, keyup);
        CFRelease(keyup);

        usleep(500);
    });
}

void send_multi_vkey(int32_t vk, int32_t count) {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        for (int i = 0; i < count; i++) {
            CGEventRef keydown;
            keydown = CGEventCreateKeyboardEvent(NULL, vk, true);
            CGEventPost(kCGHIDEventTap, keydown);
            CFRelease(keydown);

            usleep(500);

            CGEventRef keyup;
            keyup = CGEventCreateKeyboardEvent(NULL, vk, false);
            CGEventPost(kCGHIDEventTap, keyup);
            CFRelease(keyup);

            usleep(500);
        }
    });
}

void trigger_paste() {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        CGEventRef keydown;
        keydown = CGEventCreateKeyboardEvent(NULL, 0x37, true);  // CMD
        CGEventPost(kCGHIDEventTap, keydown);
        CFRelease(keydown);

        usleep(2000);

        CGEventRef keydown2;
        keydown2 = CGEventCreateKeyboardEvent(NULL, 0x09, true);  // V key
        CGEventPost(kCGHIDEventTap, keydown2);
        CFRelease(keydown2);

        usleep(2000);

        CGEventRef keyup;
        keyup = CGEventCreateKeyboardEvent(NULL, 0x09, false);
        CGEventPost(kCGHIDEventTap, keyup);
        CFRelease(keyup);

        usleep(2000);

        CGEventRef keyup2;
        keyup2 = CGEventCreateKeyboardEvent(NULL, 0x37, false);  // CMD
        CGEventPost(kCGHIDEventTap, keyup2);
        CFRelease(keyup2);

        usleep(2000);
    });
}


void trigger_copy() {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        CGEventRef keydown;
        keydown = CGEventCreateKeyboardEvent(NULL, 0x37, true);  // CMD
        CGEventPost(kCGHIDEventTap, keydown);
        CFRelease(keydown);

        usleep(2000);

        CGEventRef keydown2;
        keydown2 = CGEventCreateKeyboardEvent(NULL, 0x08, true);  // C key
        CGEventPost(kCGHIDEventTap, keydown2);
        CFRelease(keydown2);

        usleep(2000);

        CGEventRef keyup;
        keyup = CGEventCreateKeyboardEvent(NULL, 0x08, false);
        CGEventPost(kCGHIDEventTap, keyup);
        CFRelease(keyup);

        usleep(2000);

        CGEventRef keyup2;
        keyup2 = CGEventCreateKeyboardEvent(NULL, 0x37, false);  // CMD
        CGEventPost(kCGHIDEventTap, keyup2);
        CFRelease(keyup2);

        usleep(2000);
    });
}

int32_t get_active_app_bundle(char * buffer, int32_t size) {
    NSRunningApplication *frontApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    NSString *bundlePath = [frontApp bundleURL].path;
    const char * path = [bundlePath UTF8String];

    snprintf(buffer, size, "%s", path);

    [bundlePath release];

    return 1;
}

int32_t get_active_app_identifier(char * buffer, int32_t size) {
    NSRunningApplication *frontApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    NSString *bundleId = frontApp.bundleIdentifier;
    const char * bundle = [bundleId UTF8String];

    snprintf(buffer, size, "%s", bundle);

    [bundleId release];

    return 1;
}

int32_t get_clipboard(char * buffer, int32_t size) {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    for (id element in pasteboard.pasteboardItems) {
        NSString *string = [element stringForType: NSPasteboardTypeString];
        if (string != NULL) {
            const char * text = [string UTF8String];
            snprintf(buffer, size, "%s", text);

            [string release];

            return 1;
        }
    }

    return -1;
}

int32_t set_clipboard(char * text) {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray *array = @[NSPasteboardTypeString];
    [pasteboard declareTypes:array owner:nil];

    NSString *nsText = [NSString stringWithUTF8String:text];
    [pasteboard setString:nsText forType:NSPasteboardTypeString];
}

int32_t set_clipboard_image(char *path) {
    NSString *pathString = [NSString stringWithUTF8String:path];
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:pathString];
    int result = 0;

    if (image != nil) {
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        NSArray *copiedObjects = [NSArray arrayWithObject:image];
        [pasteboard writeObjects:copiedObjects];
        result = 1;
    }
    [image release];

    return result;
}


// CONTEXT MENU

int32_t show_context_menu(MenuItem * items, int32_t count) {
    MenuItem * item_copy = (MenuItem*)malloc(sizeof(MenuItem)*count);
    memcpy(item_copy, items, sizeof(MenuItem)*count);
    int32_t count_copy = count;

    dispatch_async(dispatch_get_main_queue(), ^(void) {

        NSMenu *espansoMenu = [[NSMenu alloc] initWithTitle:@"Espanso"];

        for (int i = 0; i<count_copy; i++) {
            if (item_copy[i].type == 1) {
                NSString *title = [NSString stringWithUTF8String:item_copy[i].name];
                NSMenuItem *newMenu = [[NSMenuItem alloc] initWithTitle:title action:@selector(contextMenuClick:) keyEquivalent:@""];
                [newMenu setTag:(NSInteger)item_copy[i].id];
                [espansoMenu addItem: newMenu];
            }else{
                [espansoMenu addItem: [NSMenuItem separatorItem]];
            }
        }

        free(item_copy);

        [delegate_ptr->myStatusItem popUpStatusItemMenu:espansoMenu];
    });
}

// 10.9+ only, see this url for compatibility:
// http://stackoverflow.com/questions/17693408/enable-access-for-assistive-devices-programmatically-on-10-9
int32_t check_accessibility() {
    NSDictionary* opts = @{(__bridge id)kAXTrustedCheckOptionPrompt: @NO};
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)opts);
}

int32_t prompt_accessibility() {
    NSDictionary* opts = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)opts);
}

void open_settings_panel() {
    NSString *urlString = @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

// Taken (with a few modifications) from the MagicKeys project: https://github.com/zsszatmari/MagicKeys
int32_t get_secure_input_process(int64_t *pid) {
    NSArray *consoleUsersArray;
    io_service_t rootService;
    int32_t result = 0;

    if ((rootService = IORegistryGetRootEntry(kIOMasterPortDefault)) != 0)
    {
        if ((consoleUsersArray = (NSArray *)IORegistryEntryCreateCFProperty((io_registry_entry_t)rootService, CFSTR("IOConsoleUsers"), kCFAllocatorDefault, 0)) != nil)
        {
            if ([consoleUsersArray isKindOfClass:[NSArray class]])  // Be careful - ensure this really is an array
            {
                for (NSDictionary *consoleUserDict in consoleUsersArray) {
                    NSNumber *secureInputPID;

                    if ((secureInputPID = [consoleUserDict objectForKey:@"kCGSSessionSecureInputPID"]) != nil)
                    {
                        if ([secureInputPID isKindOfClass:[NSNumber class]])
                        {
                            *pid = ((UInt64) [secureInputPID intValue]);
                            result = 1;
                            break;
                        }
                    }
                }
            }

            CFRelease((CFTypeRef)consoleUsersArray);
        }

        IOObjectRelease((io_object_t) rootService);
    }

    return result;
}

int32_t get_path_from_pid(int64_t pid, char *buff, int buff_size) {
    int res = proc_pidpath((pid_t) pid, buff, buff_size);
    if ( res <= 0 ) {
        return 0;
    } else {
        return 1;
    }
}