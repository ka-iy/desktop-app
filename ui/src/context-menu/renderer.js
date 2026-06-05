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

const sender = window.ipcSender;

export function InitDefaultCopyMenus() {
  document.body.addEventListener("contextmenu", (e) => {
    e.preventDefault();
    e.stopPropagation();

    let node = e.target;

    while (node) {
      if (
        node.nodeName.match(/^(input|textarea)$/i) ||
        node.isContentEditable
      ) {
        sender.ShowContextMenuEdit();
        break;
      } else if (node.nodeName.match(/^(label)$/i)) {
        if (getSelection().toString()) {
          sender.ShowContextMenuCopy();
        }
        break;
      }
      node = node.parentNode;
    }
  });
}
