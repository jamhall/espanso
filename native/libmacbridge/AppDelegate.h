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

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

#include "bridge.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    @public NSStatusItem *myStatusItem;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
- (IBAction) statusIconClick: (id) sender;
- (IBAction) contextMenuClick: (id) sender;
- (void) updateIcon: (char *)iconPath;
- (void) setIcon: (char *)iconPath;

@end