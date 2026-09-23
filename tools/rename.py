#!/usr/bin/env python3
"""Rename the trainer to "Pirate Perfection Undying" and add port credits.
Run after `git mv` of the folder and the icon. usage: rename.py <mod folder>"""
import os, sys

ROOT = sys.argv[1]
OLD = "Pirate Perfection Reborn Trainer! V.I.P. Edition"
NEW = "Pirate Perfection Undying"
VERSION = "1.0.0-alpha"
PORT = "BearThatRun"


def edit(rel, old, new, count=1):
    p = os.path.join(ROOT, rel)
    with open(p, "rb") as f:
        s = f.read().decode("utf-8", "surrogateescape")
    crlf = "\r\n" in s
    s = s.replace("\r\n", "\n")
    n = s.count(old)
    assert n == count, f"{rel}: expected {count} of {old!r}, got {n}"
    s = s.replace(old, new)
    if crlf:
        s = s.replace("\n", "\r\n")
    with open(p, "wb") as f:
        f.write(s.encode("utf-8", "surrogateescape"))
    print("edit", rel)


edit("MOD.txt", f'"name"\t\t\t\t\t:\t"{OLD}"', f'"name"\t\t\t\t\t:\t"{NEW}"')
edit("MOD.txt",
     '"description"\t\t\t:\t"Trainer: v2.0.0-VE (x64 port)\\nRequires: SuperBLT 64-bit + BeardLib 5.1+\\nCreator: Baddog-11"',
     f'"description"\t\t\t:\t"{NEW} {VERSION}\\nx64 port of Pirate Perfection Reborn Trainer V.I.P. v2.0.0\\n'
     f'Port: {PORT} (AI-assisted)\\nOriginal: Baddog-11 & the Pirate Perfection Developer Crew\\n'
     f'Requires: SuperBLT 64-bit + BeardLib 5.1+"')
edit("MOD.txt", '"author"\t\t\t\t\t:\t"Pirate Perfection Developer Crew"',
     f'"author"\t\t\t\t\t:\t"{PORT} (x64 port), Pirate Perfection Developer Crew (original)"')
edit("MOD.txt", '"version"\t\t\t\t:\t"v2.0.0-V.I.P. Edition"', f'"version"\t\t\t\t:\t"{VERSION}"')
edit("MOD.txt", f'"image"\t\t\t\t\t:\t"{OLD}.png"', f'"image"\t\t\t\t\t:\t"{NEW}.png"')

edit("Trainer/config.lua", f"-- {OLD} Main Configuration File.",
     f"-- {NEW} Main Configuration File. (x64 port of {OLD})")
edit("Trainer/setup/__require.lua", f'or "mods/[MOD] {OLD}/"', f'or "mods/{NEW}/"')
edit("Trainer/setup/init.lua", "local BLT_VERSION = 'v3.1.2 (R026)'", "local BLT_VERSION = 'SuperBLT 64-bit'")
edit("Trainer/setup/init.lua",
     f'title = "{OLD}", text = "Trainer: v2.0.0-PaE\\nSuperBLT: v3.1.2 (R026)\\nCreator: Baddog-11\\nVisit us at www.Pirateperfection.com"',
     f'title = "{NEW}", text = "{VERSION}, x64 port by {PORT} (AI-assisted)\\nOriginal trainer: Baddog-11 & Pirate Perfection crew\\nRequires SuperBLT 64-bit + BeardLib"')
edit("Trainer/setup/main_init.lua",
     'print("Pirate Perfection Reborn Trainer! \\nv2.0.0-V.I.P. Edition \\nSuperBLT v3.1.2 (R026) \\nby Baddog-11 \\ninitialized")',
     f'print("{NEW} {VERSION} \\nx64 port by {PORT} (AI-assisted) \\nbased on Pirate Perfection Reborn Trainer V.I.P. v2.0.0 by Baddog-11 \\ninitialized")')

readme = os.path.join(ROOT, "Read Me!.txt")
with open(readme, "rb") as f:
    body = f.read()
crlf = b"\r\n" in body
header = f"""{NEW} {VERSION} - x64 port for PAYDAY 2 (Diesel 3.0, 64-bit)
Port by {PORT} (AI-assisted). Based on {OLD} v2.0.0
by Baddog-11 and the Pirate Perfection Developer Crew. Edited with permission.

Requirements:
	- PAYDAY 2 64-bit (update 247 or newer)
	- SuperBLT 64-bit  (https://modworkshop.net/mod/58342)
	- BeardLib 5.1+    (https://modworkshop.net/mod/14924)

Install: copy the "{NEW}" folder into PAYDAY 2\\mods\\
Do NOT copy an old 32-bit WSOCK32.dll, IPHLPAPI.dll or mods\\base folder into your game.

Changes from the original:
	- Packaged for SuperBLT 64-bit, BeardLib is required
	- Removed: DLC unlocker, paid skin unlocks, anticheat bypass, mod hiding,
	  "not modded" lobby, name spoof, loot card spoof, troll menu (F5), stealth_v2
	- No more cmd.exe / hard-coded paths; several old bugs fixed
	- Full history: see the git log

=====================================================================
Original Read Me follows.
=====================================================================

"""
nl = "\r\n" if crlf else "\n"
with open(readme, "wb") as f:
    f.write(header.replace("\n", nl).encode("utf-8") + body)
print("edit Read Me!.txt")
