#!/usr/bin/env python3
"""Pirate Perfection x64 port: scripted edits, one phase per run.
Runs on the NEW copy only. Every edit asserts that its anchor text exists
exactly once, so a silent no-op is impossible."""
import os, re, shutil, sys, json

# usage: port.py <mod folder> <phase>   phase = 1 | 2 | 3 | 5
ROOT, PHASE = sys.argv[1], sys.argv[2]
T = os.path.join(ROOT, "Trainer")
assert os.path.isdir(T), T
log = []

CRLF = {}
def rd(p):
    with open(p, "rb") as f:
        s = f.read().decode("utf-8", "surrogateescape")
    CRLF[p] = "\r\n" in s          # keep each file's own line endings
    return s.replace("\r\n", "\n")

def wr(p, s):
    if CRLF.get(p):
        s = s.replace("\n", "\r\n")
    with open(p, "wb") as f:
        f.write(s.encode("utf-8", "surrogateescape"))

def sub1(rel, old, new, count=1, regex=False):
    p = os.path.join(ROOT, rel)
    s = rd(p)
    if regex:
        n = len(re.findall(old, s, flags=re.M | re.S))
        assert n == count, f"{rel}: expected {count} match(es) of /{old}/, got {n}"
        s = re.sub(old, new, s, flags=re.M | re.S)
    else:
        n = s.count(old)
        assert n == count, f"{rel}: expected {count} match(es) of {old!r}, got {n}"
        s = s.replace(old, new)
    wr(p, s)
    log.append(f"edit  {rel}")

def phase1():
    mp = os.path.join(ROOT, "MOD.txt")
    s = rd(mp)
    s = s.replace('"description"\t\t\t:\t"Trainer: v2.0.0-VE\\nSuperBLT: v3.1.2 (R026)\\nCreator: Baddog-11"',
                  '"description"\t\t\t:\t"Trainer: v2.0.0-VE (x64 port)\\nRequires: SuperBLT 64-bit + BeardLib 5.1+\\nCreator: Baddog-11"')
    assert "x64 port" in s, "description anchor not found"
    new, n = re.subn(r'"updates"\s*:\s*\[.*?\]\s*,\s*\n',
                     '"dependencies"\t\t:\t{\t"BeardLib"\t:\t{\t"download_url"\t:\t"https://api.modworkshop.net/mods/14924/download"\t}\t},\n',
                     s, count=1, flags=re.S)
    assert n == 1, "updates block not found"
    wr(mp, new)
    log.append("edit  MOD.txt (dependency on BeardLib, dead update block removed)")


def phase2():
    CUT = [
        "Trainer/addons/dlc_unlocker.lua",
        "Trainer/addons/all_weaponskins.lua",
        "Trainer/addons/all_armorskins.lua",
        "Trainer/addons/disable_anticheat.lua",
        "Trainer/addons/Hide Mods.lua",
        "Trainer/addons/Hide All Mods.lua",
        "Trainer/addons/Hide Pirate Perfection.lua",
        "Trainer/addons/non_modded_lobby.lua",
        "Trainer/addons/namespoof.lua",
        "Trainer/addons/spoof_cards.lua",
        "Trainer/menu/spoof_name-troll_menu.lua",
        "Trainer/menu/ingame/troll_menu.lua",
        "Trainer/menu/ingame/public/troll_menu.lua",
        "Trainer/menu/pre-game/spoof_name.lua",
    ]
    for rel in CUT:
        p = os.path.join(ROOT, rel)
        assert os.path.isfile(p), p
        os.remove(p)
        log.append(f"del   {rel}")
    for d in ["Trainer/addons/troll_menu", "Trainer/menu/ingame/public"]:
        p = os.path.join(ROOT, d)
        n = sum(len(fs) for _, _, fs in os.walk(p))
        shutil.rmtree(p)
        log.append(f"deldir {d} ({n} files)")

    # auto_init.lua: drop the loaders of cut features
    for key in ["DisableAnticheat", "NameSpoof", "DLCUnlocker", "AllWeaponSkins",
                "AllArmorSkins", "Hide_All_Mods", "Hide_Pirate_Perfection"]:
        sub1("Trainer/setup/auto_init.lua",
             r"^if cfg\." + key + r" then\n.*?\nend\n\n?", "", regex=True)
    sub1("Trainer/setup/auto_init.lua",
         r"^if cfg\.non_modded_lobby then\n.*?\nend\n\n?", "", count=2, regex=True)
    sub1("Trainer/setup/auto_init.lua",
         r"^if cfg\.SpoofCards and not Global\.game_settings\.single_player then\n.*?\nend\n\n?",
         "", regex=True)

    # config.lua: drop the options of cut features
    for key in ["DLCUnlocker", "AllWeaponSkins", "AllArmorSkins", "NameSpoof",
                "DisableAnticheat", "PreventEquipDetecting", "Hide_All_Mods",
                "Hide_Pirate_Perfection", "non_modded_lobby", "SpoofCards", "SpoofCards_sub"]:
        sub1("Trainer/config.lua", r"^[ \t]*" + key + r"[ \t]*=[^\n]*\n", "", regex=True)
    sub1("Trainer/config.lua", r"^ -- Loot Card Spoofer Option\n\n?", "", regex=True)
    sub1("Trainer/config.lua", "(maybe usefull when you want to use only DLCUnlocker and some stealth cheats, like no recoil)",
         "(maybe usefull when you want to use only some stealth cheats, like no recoil)")

    # base_menu.lua (config menu): drop the entries of cut features
    for key in ["NameSpoof", "DLCUnlocker", "AllWeaponSkins", "AllArmorSkins",
                "Hide_All_Mods", "Hide_Pirate_Perfection", "non_modded_lobby",
                "DisableAnticheat", "PreventEquipDetecting"]:
        sub1("Trainer/menu/pre-game/base_menu.lua",
             r'^[ \t]*\{name = "' + key + r'"[^\n]*\},[ \t]*\n', "", regex=True)
    # the SpoofCards submenu is a multi-line function entry ending in "end},"
    sub1("Trainer/menu/pre-game/base_menu.lua",
         r'^[ \t]*\{name = "SpoofCards_sub".*?^[ \t]*end\},[ \t]*\n', "", regex=True)

    # main menu: drop the two paid-skin unlock buttons
    sub1("Trainer/menu/pre-game/main_menu.lua",
         r"^[ \t]*\{ text = tr\['unlock_all_weapon_skins'\][^\n]*\n", "", regex=True)
    sub1("Trainer/menu/pre-game/main_menu.lua",
         r"^[ \t]*\{ text = tr\['unlock_all_armor_skins'\][^\n]*\n", "", regex=True)

    # F5 key (spoof/troll menu)
    sub1("Trainer/keyconfig.lua", r"^[ \t]*\['f5'\][^\n]*spoof_name-troll_menu[^\n]*\n", "", regex=True)

    # unlock_items.lua: never add items from DLCs the player does not own
    sub1("Trainer/addons/main_menu/unlock_items.lua",
         "\t\tlocal global_value = get_global_value( data )\n\t\tmanagers.blackmarket:add_to_inventory( global_value, item_type, id )\n",
         "\t\tlocal global_value = get_global_value( data )\n"
         "\t\t-- x64 port: skip items that belong to a DLC the player does not own\n"
         "\t\tlocal gv_tweak = tweak_data.lootdrop.global_values[ global_value ]\n"
         "\t\tlocal dlc_locked = gv_tweak and gv_tweak.dlc and not managers.dlc:is_dlc_unlocked( global_value )\n"
         "\t\tif not dlc_locked then\n"
         "\t\t\tmanagers.blackmarket:add_to_inventory( global_value, item_type, id )\n"
         "\t\tend\n")
    sub1("Trainer/addons/main_menu/unlock_items.lua",
         "\tfor weapon_id in pairs( weapons ) do\n\t\tmanagers.upgrades:aquire( weapon_id )\n\t\tweapons[ weapon_id ].unlocked = true\n\tend\n",
         "\tfor weapon_id in pairs( weapons ) do\n"
         "\t\t-- x64 port: leave weapons from unowned DLCs locked\n"
         "\t\tlocal def = tweak_data.upgrades.definitions[ weapon_id ]\n"
         "\t\tlocal dlc = def and def.dlc\n"
         "\t\tif not dlc or managers.dlc:is_dlc_unlocked( dlc ) then\n"
         "\t\t\tmanagers.upgrades:aquire( weapon_id )\n"
         "\t\t\tweapons[ weapon_id ].unlocked = true\n"
         "\t\tend\n\tend\n")


    # stealth_v2: respawns spawned equipment so it is not flagged by cheat detection
    sub1("Trainer/setup/auto_ingame.lua",
         "if cfg.PreventEquipDetecting and is_server then\n\tppr_require('Trainer/experimental/stealth_v2')\nend\n\n", "")
    os.remove(os.path.join(ROOT, "Trainer/experimental/stealth_v2.lua"))
    log.append("del   Trainer/experimental/stealth_v2.lua")

def phase3():
    OLDROOT = '"mods/[MOD] Pirate Perfection Reborn Trainer! V.I.P. Edition/"'
    sub1("Trainer/setup/__require.lua",
         "-- Fix for blt\nppr_io = {}\n",
         "-- Fix for blt\nppr_io = {}\n"
         "-- x64 port: mod root comes from SuperBLT's ModPath, so the folder can be renamed\n"
         "ppr_io.root = rawget(_G, \"ModPath\") or " + OLDROOT + "\n"
         "if ppr_io.root:sub(-1) ~= \"/\" and ppr_io.root:sub(-1) ~= \"\\\\\" then ppr_io.root = ppr_io.root .. \"/\" end\n")
    sub1("Trainer/setup/__require.lua",
         "\tfile = " + OLDROOT + " .. file\n", "\tfile = ppr_io.root .. file\n", count=2)
    sub1("Trainer/setup/__require.lua",
         '\tcommand = command:gsub("Trainer/", "mods/[MOD] Pirate Perfection Reborn Trainer! V.I.P. Edition/Trainer/")\n\treturn io_popen( command )\nend\n',
         '\tcommand = command:gsub("Trainer/", ppr_io.root .. "Trainer/")\n\treturn io_popen( command )\nend\n\n'
         '-- x64 port: recursive file listing through SuperBLT\'s file API instead of\n'
         '-- io.popen + cmd.exe. Returns short names without extension (like %~nf), or nil.\n'
         'ppr_io.list_files = function( rel_dir, ext )\n'
         '\text = ( ext or "lua" ):lower()\n'
         '\tlocal out = {}\n'
         '\tlocal function walk( dir )\n'
         '\t\tfor _, name in ipairs( file.GetFiles( dir ) or {} ) do\n'
         '\t\t\tlocal base, e = name:match( "^(.*)%.([^%.]+)$" )\n'
         '\t\t\tif base and e:lower() == ext then\n'
         '\t\t\t\ttable.insert( out, base )\n'
         '\t\t\tend\n'
         '\t\tend\n'
         '\t\tfor _, sub in ipairs( file.GetDirectories( dir ) or {} ) do\n'
         '\t\t\twalk( dir .. sub .. "/" )\n'
         '\t\tend\n'
         '\tend\n'
         '\tlocal dir = ppr_io.root .. rel_dir\n'
         '\tif dir:sub(-1) ~= "/" then dir = dir .. "/" end\n'
         '\twalk( dir )\n'
         '\tif #out > 0 then return out end\n'
         'end\n')

    sub1("Trainer/setup/init.lua",
         "\tlocal list = io_popen(\"@echo OFF & cd \"..path..\" & for /r %f in (*.\"..ext..\") do echo %~nf\"):read(\"*all\")\n"
         "\t\n\tif list ~= '' then\n\t\treturn str_split(list, '\\n')\n\telse\n",
         "\tlocal list = ppr_io.list_files( path, ext ) -- x64 port: no io.popen/cmd.exe\n"
         "\t\n\tif list then\n\t\treturn list\n\telse\n")
    sub1("Trainer/menu/custom_plugins.lua",
         "\tlocal list = io_popen(\"@echo OFF & cd Trainer/plugins & for /r %f in (*.lua) do echo %~nf\"):read(\"*all\")\n"
         "\tif ( list ~= \"\" ) then\n\t\tlist = str_split(list, '\\n')\n\t\treturn list\n\tend\n",
         "\treturn ppr_io.list_files( \"Trainer/plugins\", \"lua\" ) -- x64 port: no io.popen/cmd.exe\n")
    sub1("Trainer/menu/ingame/lego_menu.lua",
         "\tlocal list = io_popen(\"@echo OFF & cd Trainer/addons/lego & for /r %f in (*.lua) do echo %~nf\"):read(\"*all\")\n"
         "\tif ( list ~= \"\" ) then\n\t\tlist = str_split(list, '\\n')\n\t\treturn list\n\tend\n",
         "\treturn ppr_io.list_files( \"Trainer/addons/lego\", \"lua\" ) -- x64 port: no io.popen/cmd.exe\n")

    sub1("Trainer/setup/init.lua",
         "clbk = function() os.execute('start latestcrash') end,",
         "clbk = function() m_log_error('crash_t', 'Crash log: %LOCALAPPDATA%\\\\PAYDAY 2\\\\crashlog.txt') end, -- x64 port: no shell")
    sub1("Trainer/setup/init.lua",
         'assert( not f, "Please, remove IPHLPAPI.dll from game folder.")',
         'assert( not f, "Please remove the old 32-bit IPHLPAPI.dll from the game folder. PAYDAY 2 x64 uses the 64-bit SuperBLT WSOCK32.dll.")')


def phase5():
    # NewShotgunBase no longer exists; the shotgun class is ShotgunBase.
    sub1("Trainer/addons/charmenu/explosive_bullets.lua",
         r'^\thijack\(backuper, "NewShotgunBase\._fire_raycast",function\( o, self, \.\.\. \)\n.*?\n\tend\)\n\n', "", regex=True)
    sub1("Trainer/addons/charmenu/explosive_bullets.lua",
         '\trestore(backuper, "NewShotgunBase._fire_raycast")\n', "")
    sub1("Trainer/pvp/pvp.lua", 'local NewShotgunBase_fire_raycast = backuper:backup("NewShotgunBase._fire_raycast")\nfunction NewShotgunBase:_fire_raycast(',
         'local NewShotgunBase_fire_raycast = backuper:backup("ShotgunBase._fire_raycast") -- x64 port: NewShotgunBase is gone\nfunction ShotgunBase:_fire_raycast(')
    # no_bag_cooldown backed up the wrong class, so turning it off never restored the original
    sub1("Trainer/addons/charmenu/no_bag_cooldown.lua",
         "PlayerMovement.carry_blocked_by_cooldown", "PlayerManager.carry_blocked_by_cooldown", count=2)
    # Loop Fire Sounds: don't double up with BeardLib's own sound fix
    sub1("Trainer/addons/fixes/Loop Fire Sounds.lua",
         'if\tself:get_name_id()\t==\t"saw"\tthen\n\t\t\t\t\tbase_fire_sound(self)',
         'if\tself:get_name_id()\t==\t"saw"\tor\t(self.use_soundfix\tand\tself:use_soundfix())\tthen -- x64 port: BeardLib handles use_fix weapons\n\t\t\t\t\tbase_fire_sound(self)')
    sub1("Trainer/addons/fixes/Loop Fire Sounds.lua",
         'if\tself:get_name_id()\t==\t"saw"\tthen\n\t\t\t\t\treturn\tresult',
         'if\tself:get_name_id()\t==\t"saw"\tor\t(self.use_soundfix\tand\tself:use_soundfix())\tthen -- x64 port\n\t\t\t\t\treturn\tresult')

    # pre-existing bug: "\\[" / "\\]" are invalid escapes in LuaJIT, so these two keybind
    # scripts never compiled. Plain brackets need no escaping.
    for rel, n in [("Trainer/keybinds/Media Mod.lua", None), ("Trainer/keybinds/Mod Bender.lua", None)]:
        p = os.path.join(ROOT, rel); s = rd(p)
        c = s.count("\\[") + s.count("\\]")
        assert c > 0, rel
        wr(p, s.replace("\\[", "[").replace("\\]", "]"))
        log.append(f"edit  {rel} ({c} invalid escapes)")


    mp = os.path.join(ROOT, "MOD.txt")
    new = rd(mp)
    # pre-existing bug: two keybinds pointed at files that never existed
    for a, b in [("Trainer/keybinds/Share xray Vision.LUA", "Trainer/keybinds/Share X-Ray Vision.LUA"),
                 ("Trainer/keybinds/xray Vision.LUA", "Trainer/keybinds/X-Ray Vision.LUA")]:
        assert new.count('"' + a + '"') == 1, a
        new = new.replace('"' + a + '"', '"' + b + '"')
    wr(mp, new)
    log.append("edit  MOD.txt (X-Ray keybind paths)")


{"1": phase1, "2": phase2, "3": phase3, "5": phase5}[PHASE]()
print("\n".join(log))
print(f"\nphase {PHASE}: {len(log)} operations OK")
