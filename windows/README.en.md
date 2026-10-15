# Clothesline for Windows — First Candidate

English · [简体中文](README.md)

A native WPF/.NET 10 LTS application for Windows 10 1809+ / Windows 11 x64 (Intel/AMD). The installer includes the runtime and the full MIT license, including the original author notice.

Install Setup.exe or extract the entire portable ZIP into a permanent directory and run Clothesline.exe. Do not copy the EXE alone. Find the app in the taskbar notification area (possibly under hidden icons), then move the pointer to the top of the primary work area. The tray menu can keep the clothesline visible.

Downloads is watched by default using the Windows known-folder location. Add more watched folders, or drag files/folders from Explorer onto the clothesline. Downloads must remain stable across scans for about two seconds; common temporary extensions are filtered. Dragging out provides real file paths with copy-only effects. Right-click cards to open, copy, rename, pin, save clipboard content, or take down. Use the mouse wheel to reach overflow cards. Removing cards never deletes source files; renaming keeps extensions and rejects collisions or stale metadata.

The tray menu provides recent-file search, launch at login, manual Windows release checks, About/license, and Chinese/English language selection. Clipboard image/text intake is independently off by default; enabled types accept new copies only, deduplicate content, and ignore the app's own copies. Notes can be edited; clipboard items can be saved elsewhere. Owned session copies have current-user-only permissions and are excluded from persistent recent records. Normal exit removes only the owned session directory; crashes may leave temporary copies.

This candidate uses the primary work area only. It does not include macOS Quick Look, system sharing, Trash deletion, a global hotkey, or pointer-following across displays. Folders are not recursively monitored or sized. Hidden/system files and links are excluded. Full Windows desktop drag-and-drop, login, and multi-DPI acceptance are still pending.

Preferences are stored in `%LocalAppData%\Clothesline\settings.json`. Only manual update checks connect to this repository's GitHub Releases; files and clipboard content are not uploaded. Windows uses `windows-v` release tags so macOS never offers a Windows installer. Launch at login changes only the current user's Run entry when explicitly selected. Installation needs no administrator rights. Uninstallation removes the installed program and its matching startup entry, preserving preferences and source files.

Build on Windows with .NET 10 SDK and Inno Setup 6:

```powershell
./scripts/build-windows.ps1
```

The Windows workflow runs core safety/watcher tests, self-contained publishing, a WPF construction/file-drop payload smoke test, installation, installed-app smoke test, and uninstallation with a source-file sentinel. These automated checks do not establish complete interactive UI acceptance. The installer is not Authenticode-signed; Windows may show an unknown publisher.

Completion detection is heuristic: a transfer paused for over two seconds under its final name may appear early. Folder contents are not recursively checked for completion.
