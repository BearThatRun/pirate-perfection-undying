# Pirate Perfection Undying

An x64 port of **Pirate Perfection Reborn Trainer V.I.P. Edition v2.0.0** for PAYDAY 2 after the Diesel 3.0 (64-bit) update. It targets SuperBLT 64-bit, with BeardLib as a dependency.

- **x64 port:** [BearThatRun](https://github.com/BearThatRun). AI-assisted: the analysis, scripts and edits were made together with Claude (Anthropic), and every change is in the git history.
- **Original trainer:** Baddog-11 and the Pirate Perfection Developer Crew. Edited with permission from the Pirate Perfection forum admin.

> Status: **1.0.0-alpha, not yet tested in game.**

## Requirements

| What | Version |
| --- | --- |
| PAYDAY 2 | 64-bit (Diesel 3.0), update 247 or newer |
| [SuperBLT 64-bit](https://modworkshop.net/mod/58342) | loader `WSOCK32.dll` (64-bit) + `mods/base` 1.5.x |
| [BeardLib](https://modworkshop.net/mod/14924) | 5.1.0 or newer |

## Install

1. Install SuperBLT 64-bit and BeardLib.
2. Copy `mods/Pirate Perfection Undying` into `PAYDAY 2\mods\`.
3. Don't copy any old 32-bit `WSOCK32.dll`, `IPHLPAPI.dll` or `mods/base` into the game folder. They break the 64-bit game.

## What changed from the original

The history is split so every step can be reviewed on its own (`git log -p`):

| Commit | What |
| --- | --- |
| Baseline | Original V.I.P. v2.0.0 trainer folder, unmodified. The author's broken `.lnk` shortcuts are left out. |
| Phase 1 | Packaged for SuperBLT 64-bit. BeardLib dependency. Dead update block removed. |
| Phase 2 | Removed features that unlock paid content, bypass the game's ownership/cheat checks, hide the mod from other players, spoof names or loot, or grief other players (29 files). |
| Phase 3 | Hard-coded mod path replaced by `ModPath`. `io.popen` + `cmd.exe` file listing replaced by SuperBLT's `file` API. |
| Audit fixes | Hooks that pointed at missing classes/functions, wrong backup targets, invalid Lua escapes, broken keybind paths. |
| Rename | Renamed to Pirate Perfection Undying, credits added. |
| UI cleanup | No first-launch greeting, version text, banner, RSS feed, update checker, announcements, donation ticker, loading tip, in-world watermark or forum links. Menus fixed for ultrawide. BeardLib `main.xml` and new `icon.png`. |

## Tools

| File | Purpose |
| --- | --- |
| `tools/audit_hooks.py` | Lists every game function the mod wraps or replaces and checks it against two builds of the decompiled game Lua ([Payday-2-LuaJIT-Complete](https://github.com/steam-test1/Payday-2-LuaJIT-Complete)): missing functions and changed argument counts. |
| `tools/syntax_check.lua` | Compiles every Lua file with LuaJIT (`find mods -iname '*.lua' -print0 \| xargs -0 luajit tools/syntax_check.lua`). |
| `tools/port.py` | The scripted edits for phases 1, 2, 3 and the audit fixes. Every edit asserts its anchor text, so a changed file fails loudly instead of silently. |
| `tools/rename.py` | The rename and credits edits. |
| `tools/cleanup_ui.py` | The UI cleanup edits. |

## Known open items

- Not tested in game yet.
- `Shotgun Physics.LUA` has been dead code since before x64 (`NewShotgunBase` is gone). It needs a rewrite against `ShotgunBase`.
- `Media Mod.lua` loads media from `mods/Pirate Perfection Reborn/…`, which isn't part of this package.
- Throw Flash Grenade overrides `QuickFlashGrenade.destroy`, which build 248.1 no longer has.
- Next phase: move hooks, keybinds, options and translations to BeardLib (`main.xml` already lists the mod in BeardLib's mod manager). The F1–F12 menus stay on the trainer's own menu system.
