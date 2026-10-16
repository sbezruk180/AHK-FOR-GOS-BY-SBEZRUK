# Included software

The application embeds the official unmodified AutoHotkey 1.1.37.02 ANSI x86 compiler base.
AutoHotkey is distributed under GPL v2 or later; its copyright/license notices are preserved
in `AutoHotkey-GPL-2.0.txt` and the EXE's `LICENSE_ENGINE` resource.

The complete corresponding AutoHotkey engine source for this exact release is included as
`AutoHotkey-1.1.37.02-source.zip`. Its upstream URL and SHA-256, and the runtime archive/base
hashes, are pinned in `tools/build/toolchain.lock.json`. No engine patches are applied.
The application sources have their own MIT license in the repository root.

Runtime binaries: https://github.com/AutoHotkey/AutoHotkey/releases/tag/v1.1.37.02
Engine source: https://github.com/AutoHotkey/AutoHotkey/tree/v1.1.37.02

The application can export both embedded notices with `AHK_FOR_GOS.exe --export-licenses`.
This writes text files to the user's data directory. It extracts no executable components.
