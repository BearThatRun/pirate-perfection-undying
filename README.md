# Pirate Perfection Undying

An x64 port of **Pirate Perfection Reborn Trainer V.I.P. Edition v2.0.0** for PAYDAY 2 after the Diesel 3.0 (64-bit) update. It targets SuperBLT 64-bit, with BeardLib as a dependency.

> Status: **v1.0 Unique Edition**. Tested in game in single-player, feature by feature, against a checklist. Features that need a second human player haven't been tested yet.

## Credits and permission

- **Original trainer:** Baddog-11 and the Pirate Perfection Developer Crew. All credit for the original trainer is theirs. The full original credits are kept in `Read Me!.txt` and in the in-game Help menu (F1).
- **x64 port:** [BearThatRun](https://github.com/BearThatRun). Icon artwork: BearThatRun.
- **Menu font:** [Barlow Semi Condensed](https://github.com/jpt/barlow) by The Barlow Project Authors (SIL Open Font License 1.1), plus a few symbols from Liberation Sans (OFL 1.1) and DejaVu Sans. Licenses: `mods/Pirate Perfection Undying/Assets/guis/textures/ppu/FONT_LICENSES.txt`.
- **AI-assisted:** the analysis, scripts and edits for this port were made together with Claude (Anthropic). Every change is in the git history.

**Permission:** I don't have permission from the original authors. I tried to reach them through the Pirate Perfection forum, but the admin never replied, and the forum and the team are gone. The base files come from the [Ietu/pirate-perfection](https://github.com/Ietu/pirate-perfection) repository on GitHub. If you are one of the original authors and want this changed or taken down, please contact me through GitHub.

## License

MIT, see [`LICENSE`](LICENSE) (the same license as [Ietu/pirate-perfection](https://github.com/Ietu/pirate-perfection), whose copyright notice is kept). This covers the code and the icon. The font pictures in `Assets/guis/textures/ppu/` keep their own font licenses.

Note: the original Pirate Perfection team never published a license for their trainer. The MIT notice here is the one Ietu's repository ships, plus my own changes; it can't grant rights the original authors never gave.

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

## The menu

Every trainer window uses one new menu (v1.0): mouse and keyboard (arrows, Enter, Left/Right to change values, Backspace = back, `/` = search), a tab bar for the other menus, breadcrumbs, search in long lists, Yes/No inside the row for risky actions, and greyed-out rows that say why they can't be used. Drag the header to move the window, drag its edges to resize it, Ctrl + mouse wheel to scale it (Ctrl + 0 = 100 %). F2 > Theme changes the colours. Window size and position are saved in `Trainer/configs/menu_ui.lua`.

Keys: F1 opens the Help menu with the full key list. Extra keys (fly, X-ray, replenish, teleport and so on) have no default key; set them in SuperBLT's Options > Mod Keybinds.

## What's not in this port

These parts of the original were removed on purpose and won't come back:

- DLC unlocker and paid skin unlocks
- Anticheat and ownership-check bypasses
- Hiding the mod from other players, the "not modded" lobby, name spoofing and loot card spoofing
- Fake stats, including "unlock all achievements"
- Anything that acts against, or spoofs, other human players (the F5 Troll menu only works on yourself and on AI)

## What changed from the original

The history is split so every step can be reviewed on its own (`git log -p`):

| Commit | What |
| --- | --- |
| `74d4b8e` Baseline | Original V.I.P. v2.0.0 trainer folder, unmodified. The author's broken `.lnk` shortcuts are left out. |
| `5e6a4bd` Phase 1 | Packaged for SuperBLT 64-bit. BeardLib dependency. Dead update block removed. |
| `172989a` Phase 2 | Removed the features listed above. |
| `0f5a515` Phase 3 | Hard-coded mod path replaced by `ModPath`. `io.popen` + `cmd.exe` file listing replaced by SuperBLT's `file` API. |
| `617761d` Audit fixes | Hooks that pointed at missing classes/functions, wrong backup targets, invalid Lua escapes, broken keybind paths. |
| `7cb8426` Rename | Renamed to Pirate Perfection Undying, credits added. |
| `19da0ba` UI cleanup | No first-launch greeting, version text, banner, RSS feed, update checker, announcements, donation ticker, loading tip, in-world watermark or forum links. Menus fixed for ultrawide. BeardLib `main.xml`. |
| `bcc53fd` `bb3c56a` | New icon, version set to v0.01 Unique Edition. |
| `d54cde0` | Crash fix for weapon fire rate on x64. |
| `d792912` | F5 Troll menu back, limited to yourself and AI. |
| `3f84245` to `ffad26e` | In-game test rounds 1 to 6: crash fixes, broken features fixed or removed, menu fixes, BLT keybind fixes, dead files removed. The commit messages list every change. |
| `ba6cbb7` Round 7 | Text pass: credits and permission statement, this README, `Read Me!.txt`. |
| Languages | English only: the other 10 language files, the Localization menu and the Language option were removed. |
| Round 8 | PPR Setup options reviewed against the current game: dead, risky and DLC-gated options removed or fixed; the empty "Show PPR HUD" option and its leftover HUD code removed. |
| Round 9 | AimBot aims through the camera's own spin/pitch (gun and view stay lined up) and picks the enemy nearest the crosshair. Shotgun Physics rewritten (longer, stronger shotgun ragdoll push, no damage change). Trigger recorder: one file per heist, runs are appended, also logs dialogue, interactions and bags; wraps functions without breaking Bag Stacking or the meth auto-cooker. |
| Round 10, 11 | Lab Rats support for the Meth auto-cooker (host only). PPR Setup Back goes one level up; Shotgun Physics fixed. |
| Menu redesign | New menu for every trainer window (see "The menu"). Barlow font drawn from texture atlases, rounded shapes, theme editor, inline Yes/No, section headers, key list and text pages in Help. Fixes found while mapping the menus: I Want That no longer adds weapon skins, F7 Armors title, dead rows removed. |
| v1.0 | New icon, version 1.0, MIT `LICENSE`, trigger recorder off by default, Autocooker.log only written on errors. |

## Language

The trainer is English only. The original shipped 10 other languages, but most of them didn't load (syntax errors), were missing many strings, or still described removed features, so they were removed along with the language menus.

## Tools

| File | Purpose |
| --- | --- |
| `tools/audit_hooks.py` | Lists every game function the mod wraps or replaces and checks it against two builds of the decompiled game Lua ([Payday-2-LuaJIT-Complete](https://github.com/steam-test1/Payday-2-LuaJIT-Complete)): missing functions and changed argument counts. |
| `tools/syntax_check.lua` | Compiles every Lua file with LuaJIT (`find mods -iname '*.lua' -print0 \| xargs -0 luajit tools/syntax_check.lua`). |
| `tools/port.py` | The scripted edits for phases 1, 2, 3 and the audit fixes. Every edit asserts its anchor text, so a changed file fails loudly instead of silently. |
| `tools/rename.py` | The rename and credits edits. |
| `tools/cleanup_ui.py` | The UI cleanup edits. |

## Known open items

- Features that need a second human player are untested (drop-in spawn position, teammate weapon switch).
- Later: move hooks, keybinds, options and translations to BeardLib. The F1–F12 menus stay on the trainer's own menu system.
- Menu, still to do: the F2 config list with Load/Rename/Delete in one page, one Save bar for PPR Setup and Secret Skills, key-capture rows, inventory unlock chips, F12 unit/animation tabs.
