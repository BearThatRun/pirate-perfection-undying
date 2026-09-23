#!/usr/bin/env python3
"""Phase 6: UI cleanup after the first in-game test.
- no first-launch greeting, no main-menu version text, no scrolling banner,
  no RSS feed, no update checker / announcements / donation ticker / loading tip
- no links to the (dead) Pirate Perfection forum, site, Discord or Steam group
- trainer menus: mouse hit-testing fixed for non-16:9 screens, Exit centered
- BeardLib: main.xml so the mod appears in BeardLib's mod manager; icon.png
- leftovers of cut features removed from the options
usage: cleanup_ui.py <mod folder> <new icon.png>"""
import os, re, shutil, sys

ROOT, NEW_ICON = sys.argv[1], sys.argv[2]
PORT = "BearThatRun"
log = []


def rd(p):
    with open(p, "rb") as f:
        s = f.read().decode("utf-8", "surrogateescape")
    return s, "\r\n" in s


def wr(p, s, crlf):
    s = s.replace("\r\n", "\n")
    if crlf:
        s = s.replace("\n", "\r\n")
    with open(p, "wb") as f:
        f.write(s.encode("utf-8", "surrogateescape"))


def sub(rel, old, new, count=1, regex=False):
    p = os.path.join(ROOT, rel)
    s, crlf = rd(p)
    s = s.replace("\r\n", "\n")
    if regex:
        n = len(re.findall(old, s, flags=re.M | re.S))
        assert n == count, f"{rel}: expected {count} of /{old}/, got {n}"
        s = re.sub(old, new, s, flags=re.M | re.S)
    else:
        n = s.count(old)
        assert n == count, f"{rel}: expected {count} of {old!r}, got {n}"
        s = s.replace(old, new)
    wr(p, s, crlf)
    log.append(f"edit  {rel}")


def rm(rel):
    p = os.path.join(ROOT, rel)
    assert os.path.isfile(p), p
    os.remove(p)
    log.append(f"del   {rel}")


T = "Trainer/"

# 1. First-launch greeting ("Ahoy !")
rm(T + "menu/firstlaunch.lua")
sub(T + "setup/auto_init.lua", "--First launch check\nppr_require('Trainer/menu/firstlaunch')\n\n", "")

# 8 + 7. Main-menu version text, scrolling banner, RSS feed
for f in ["hud/version_text.lua", "hud/moving_text.lua", "hud/RSS Feed.lua"]:
    rm(T + f)
sub(T + "hud/init.lua",
    r"local function exec\(\)\n.*?\nend\n",
    "local function exec()\n"
    "\t-- x64 port: the version text and the scrolling announcement banner were removed.\n"
    "end\n", regex=True)
sub(T + "hud/init.lua", "\tStopLoopIdent('moving_text')\n", "")
sub(T + "setup/auto_init.lua", "if cfg.RSSFeed then\n\tppr_require 'Trainer/hud/RSS Feed'\nend\n\n", "")

# 6 + 7. Update checker, announcements, donation stock ticker, loading-screen tip
rm(T + "addons/updatechecker.lua")
rm(T + "addons/announcements.lua")
rm(T + "addons/Customstockticker.lua")
sub(T + "setup/auto_init.lua", "if cfg.check_for_updates then\n\tppr_require 'Trainer/addons/updatechecker'\nend\n\n", "")
sub(T + "setup/auto_init.lua",
    r"^if cfg\.announcements and MenuSetup then\n.*?\n\t\tend\)\nend\n\n", "", regex=True)
sub("MOD.txt",
    r',\n\t*\{\t"hook_id"\t:\t"lib/units/props/texttemplatebase",\t"script_path"\t:\t"Trainer/addons/Customstockticker\.lua"\t\}',
    "", regex=True)
sub(T + "setup/init.lua",
    r"^backuper:hijack\('TipsTweakData\.get_a_tip'.*?^end\)\n\n", "", regex=True)

for key in ["check_for_updates", "announcements", "announcements_interval",
            "HUD_VersionText", "HUD_MovingText", "RSSFeed", "TrollAmountBags"]:
    sub(T + "config.lua", r"^[ \t]*" + key + r"[ \t]*=[^\n]*\n", "", regex=True)
sub(T + "config.lua", " -- Updates & Annoucements\n\n", "")
sub(T + "config.lua", " -- Spoof Options\t\n", " -- Detection Options\n")
sub(T + "config.lua", " -- Anticheat related Options\n\n", "")

# options menu (F2): drop the removed entries and empty separators
sub(T + "menu/pre-game/base_menu.lua",
    '\t{name = "HUD_Announce_Sub", desc = true, sub = {\n'
    '\t\t{name = "HUD"},\n\t\t{},\n\t\t{name = "HUD_VersionText"},\n\t\t{name = "HUD_MovingText"},\n'
    '\t\t{},\n\t\t{name = "announcements"},\n\t\t{name = "announcements_interval", type = "slider", max = 720},\n'
    '\t\t{},\n\t\t{name = "check_for_updates"},\n\t\t{},\n\t\t{name = "RSSFeed"},\n\t}},\n',
    '\t{name = "HUD_Announce_Sub", desc = true, sub = {\n\t\t{name = "HUD"},\n\t}},\n')
sub(T + "menu/pre-game/base_menu.lua",
    '\t{name = "Anticheat_Sub", desc = true, sub = {\n\t\t{},\n\t\t{},\n\t\t{},\n\t\t{name = "ControlCheats"',
    '\t{name = "Anticheat_Sub", desc = true, sub = {\n\t\t{name = "ControlCheats"')
sub(T + "menu/pre-game/base_menu.lua", '\t\t{name = "TrollAmountBags", type = "slider", max = 100},\n', "")

# 7. In-world "PIRATEPERFECTION" watermark on Firestarter / Bank heist
rm(T + "addons/ppr_text.lua")
sub(T + "setup/auto_ingame.lua", 'if cfg.HUD then\n\tppr_require("Trainer/addons/ppr_text")\nend\n\n', "")
# 7. Chat spam: the sentry keybind posted "pirateperfection.com" into the chat as a request
#    signal for a host running Mod Bender. Mod Bender already reacts to "sentry", use that.
sub(T + "keybinds/Spawn SentryGun loud.lua",
    'managers.chat:send_message( 1, managers.network.account:username(), "pirateperfection.com")',
    'managers.chat:send_message( 1, managers.network.account:username(), "sentry")')
sub(T + "keybinds/Mod Bender.lua",
    'managers.chat:send_message( 1, managers.network.account:username(), "pirateperfection.com")',
    'managers.chat:send_message( 1, managers.network.account:username(), "sentry")')
sub(T + "keybinds/Mod Bender.lua",
    'if message:find("sentry") or message:find("pirateperfection.com")  then',
    'if message:find("sentry") then')

# 6. Help menu: no forum button, port credit on the credits page
sub(T + "menu/help.lua",
    "\t\t\t\t\t\t\t\t{ text = tr.help_site, callback = overlay_activate, data = { Steam, \"url\",'https://pirateperfection.com' }},\n", "")
sub(T + "menu/help.lua",
    "description = tr.help_credits_desc,",
    f'description = "x64 port (Pirate Perfection Undying): {PORT} (AI-assisted)\\n\\n" .. tr.help_credits_desc,')

# 6. Language menu: no "download translation" button (it pulled from a dead bitbucket repo)
sub(T + "menu/pre-game/loc_menu.lua", "\t\t{ text = tr.loc_menu_choose_remote, callback = dl_main, menu = true },\n", "")

# 5. Help text: F5 (spoof / troll menu) no longer exists
for lang in ["English", "German"]:
    sub(T + f"translations/{lang}.txt", r"^F5 : Spoof Name Men[uü] / Troll Men[uü]\n", "", regex=True)

# 2. Trainer menus on ultrawide / non-16:9 screens.
# The menus live in a 1280x720 layout workspace, but the mouse position comes from the
# fullscreen workspace. On 16:9 both match; on 21:9 the hit areas were shifted to the left.
# Convert like the game's own GenericDialog does (MousePointerManager:convert_1280_mouse_pos).
sub(T + "tools/new_menu/menu.lua",
    "ppr_require 'Trainer/tools/new_menu/tickbox'\n",
    "-- x64 port: mouse position in the menus' 1280 layout workspace (fixes ultrawide hit areas)\n"
    "function ppr_menu_mouse_pos()\n"
    "\tlocal mp = managers.mouse_pointer\n"
    "\tlocal x, y = mp._mouse:world_position()\n"
    "\tif mp.convert_1280_mouse_pos then\n"
    "\t\treturn mp:convert_1280_mouse_pos( x, y )\n"
    "\tend\n"
    "\treturn x, y\n"
    "end\n\n"
    "ppr_require 'Trainer/tools/new_menu/tickbox'\n")
sub(T + "tools/new_menu/menu.lua",
    "\tlocal x, y = M_mouse_pointer._mouse:x(), M_mouse_pointer._mouse:y()\n",
    "\tlocal x, y = ppr_menu_mouse_pos()\n")
sub(T + "tools/new_menu/menu.lua",
    "\tclose_button:set_x( navigation_panel:w()/2 )\n",
    "\tclose_button:set_center_x( navigation_panel:w()/2 )\n")
sub(T + "tools/new_menu/multi_choice.lua", "\tlocal x, y = gui_mouse:x(), gui_mouse:y()\n", "\tlocal x, y = ppr_menu_mouse_pos()\n")
sub(T + "tools/new_menu/slider.lua",
    "\tlocal M = M_mouse_pointer._mouse\n\tlocal x, y = M:x(), M:y()\n", "\tlocal x, y = ppr_menu_mouse_pos()\n")
sub(T + "tools/new_menu/text_input.lua",
    "\tlocal M = M_mouse_pointer._mouse\n\tlocal x, y = M:x(), M:y()\n", "\tlocal x, y = ppr_menu_mouse_pos()\n")

# 3 + 4. BeardLib mod manager entry and a new icon (old one showed "v2.0.0 V.I.P. / SuperBLT R026")
old_icon = os.path.join(ROOT, "Pirate Perfection Undying.png")
assert os.path.isfile(old_icon)
os.remove(old_icon)
shutil.copyfile(NEW_ICON, os.path.join(ROOT, "icon.png"))
log.append("icon  Pirate Perfection Undying.png -> icon.png (new artwork)")
sub("MOD.txt", '"image"\t\t\t\t\t:\t"Pirate Perfection Undying.png"', '"image"\t\t\t\t\t:\t"icon.png"')
sub("MOD.txt",
    r'"contact"\t\t\t\t:\t"[^"]*"',
    f'"contact"\t\t\t\t:\t"https://github.com/{PORT}"', regex=True)
with open(os.path.join(ROOT, "main.xml"), "w", newline="\r\n") as f:
    f.write('<table name="Pirate Perfection Undying"\n'
            f'\tauthor="{PORT} (x64 port), Pirate Perfection Developer Crew (original)"\n'
            '\tversion="1.0.0-alpha"\n'
            '\tcolor="Color(0.98, 0.78, 0.12)"\n'
            '\tmin_lib_ver="5.1.0">\n'
            '\t<!-- BeardLib reads this file to list the mod in its mod manager.\n'
            '\t     Hooks and keybinds are still loaded by SuperBLT from MOD.txt. -->\n'
            '</table>\n')
log.append("new   main.xml")

print("\n".join(log))
print(f"\n{len(log)} operations OK")
