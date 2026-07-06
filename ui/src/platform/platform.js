//
//  UI for IVPN Client Desktop
//  https://github.com/ivpn/desktop-app
//
//  Created by Stelnykovych Alexandr.
//  Copyright (c) 2023 IVPN Limited.
//
//  This file is part of the UI for IVPN Client Desktop.
//
//  The UI for IVPN Client Desktop is free software: you can redistribute it and/or
//  modify it under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option) any later version.
//
//  The UI for IVPN Client Desktop is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
//  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
//  details.
//
//  You should have received a copy of the GNU General Public License
//  along with the UI for IVPN Client Desktop. If not, see <https://www.gnu.org/licenses/>.
//
import { IsRenderer } from "../helpers/helpers";

export const PlatformEnum = Object.freeze({
  unknown: 0,
  macOS: 1,
  Linux: 2,
  Windows: 3,
});


let hashedCurrPlatform = null;
export function Platform() {
  if (hashedCurrPlatform) return hashedCurrPlatform;

  if (IsRenderer())     
    hashedCurrPlatform = window.ipcSender.Platform();
  else {
    // main process
    switch (process.platform) {
      case "win32":
        hashedCurrPlatform = PlatformEnum.Windows;
        break;
      case "linux":
        hashedCurrPlatform = PlatformEnum.Linux;
        break;
      case "darwin":
        hashedCurrPlatform = PlatformEnum.macOS;
        break;
      default:
        hashedCurrPlatform = PlatformEnum.unknown;
    }
  }
  return hashedCurrPlatform;
}

export function IsWindowHasFrame() {
  return Platform() === PlatformEnum.macOS;
}

/**
 * Returns whether BrowserWindows should have a native drop shadow.
 *
 * A dedicated function is used instead of reusing IsWindowHasFrame() so that
 * the shadow policy can evolve independently of the frame/titlebar policy.
 *
 * Background: Electron v42 changed behaviour on Wayland (Linux) — frameless
 * windows now receive GTK client-side-decoration (CSD) drop shadows and
 * extended resize boundaries allocated *inside* the declared window size,
 * shrinking the visible content area (e.g. 800×600 becomes 768×558).
 * Setting hasShadow: false in the BrowserWindow constructor opts out of the
 * GTK CSD shadow allocation and restores the intended dimensions.
 * See: https://github.com/electron/electron/pull/49295
 */
export function IsWindowHasShadow() {
  // Disable shadow on Linux to suppress GTK CSD insets (Electron v42 Wayland).
  // On all other platforms the default shadow behaviour is preserved.
  return Platform() !== PlatformEnum.Linux;
}

/**
 * Returns whether BrowserWindows should be created with resizable: true.
 *
 * On Windows, setting resizable: false causes a permanent WS_THICKFRAME inset
 * (Electron v28+): all size APIs become unreliable because Windows silently
 * strips the invisible border from every dimension (e.g. setBounds({width:800})
 * produces a ~784 px window). To avoid this, Windows windows are created with
 * resizable: true and user-initiated drag resizes are blocked via the
 * 'will-resize' event handler instead.
 *
 * On macOS and Linux, resizable: false works correctly and is used directly.
 * Note: 'will-resize' is not emitted on Linux, so the event-based approach
 * cannot be used there.
 */
export function IsResizableWindow() {
  // Only Windows needs resizable:true to avoid the WS_THICKFRAME inset bug.
  return Platform() === PlatformEnum.Windows;
}
