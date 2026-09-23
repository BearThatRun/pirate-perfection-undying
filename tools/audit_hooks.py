#!/usr/bin/env python3
"""Static hook audit for PAYDAY 2 Lua mods.

Lists every game function a mod wraps (backuper backup/hijack/add_clbk) or
replaces (`function Class:method`) and checks it against two builds of the
decompiled game Lua: does the function still exist, and did its argument
count change?

usage: audit_hooks.py <mod dir> <game lua, new build> <game lua, old build> [report.json]
Decompiled game Lua: https://github.com/steam-test1/Payday-2-LuaJIT-Complete
"""
import collections, json, os, re, sys

HIJACK = re.compile(r'(?:backup|hijack|hijack_adv|add_clbk|remove_clbk)\s*\(\s*(?:backuper\s*,\s*)?[\'"]([^\'"]+)[\'"]')
DEFINE = re.compile(r'^\s*function\s+([A-Z]\w*)[:.](\w+)\s*\(', re.M)
SIG = re.compile(r'^\s*function\s+([A-Za-z_][\w.]*)([:.])(\w+)\s*\(([^)]*)\)', re.M)
ASSIGN = re.compile(r'^\s*([A-Z]\w*(?:\.\w+)*)\.(\w+)\s*=\s*(?:function|[A-Z]\w*\.\w+)', re.M)
CLASS = re.compile(r'^\s*(?:local\s+)?([A-Z]\w*)\s*=\s*(?:\1\s+or\s+)?[\w.]*class\(', re.M)


def lua_files(root):
    for d, _, fs in os.walk(root):
        for f in fs:
            if f.lower().endswith(".lua"):
                p = os.path.join(d, f)
                with open(p, encoding="utf-8", errors="replace") as fh:
                    yield os.path.relpath(p, root), fh.read()


def index_game(root):
    sigs, classes = {}, set()
    for _, s in lua_files(root):
        for m in SIG.finditer(s):
            params = [p.strip() for p in m.group(4).split(",") if p.strip()]
            if m.group(2) == "." and params[:1] == ["self"]:
                params = params[1:]
            sigs[f"{m.group(1)}.{m.group(3)}"] = params
        for m in ASSIGN.finditer(s):  # aliases like X.f = Y.f
            sigs.setdefault(f"{m.group(1)}.{m.group(2)}", None)
        classes.update(m.group(1) for m in CLASS.finditer(s))
    return sigs, classes


def main():
    mod, new_root, old_root = sys.argv[1:4]
    new, new_cls = index_game(new_root)
    old, old_cls = index_game(old_root)

    targets = collections.defaultdict(set)
    mod_classes = set()
    for rel, s in lua_files(mod):
        for m in HIJACK.finditer(s):
            targets[m.group(1)].add(rel)
        for m in DEFINE.finditer(s):
            targets[f"{m.group(1)}.{m.group(2)}"].add(rel)
        mod_classes.update(m.group(1) for m in CLASS.finditer(s))

    report = {}
    for name, files in sorted(targets.items()):
        if not re.fullmatch(r"[A-Za-z_]\w*(\.\w+)+", name):
            status = "dynamic: check in game"
        elif name in new:
            status = "ok"
            if name in old and new[name] is not None and old[name] is not None \
                    and len(new[name]) != len(old[name]):
                status = f"ok, argument count changed {len(old[name])} -> {len(new[name])}"
        elif name in old:
            status = "GONE in new build"
        else:
            cls = name.split(".")[0]
            if cls in mod_classes:
                continue  # the mod's own class
            if cls in new_cls or cls in old_cls:
                status = "not defined on this class (inherited, or added by the mod)"
            else:
                status = "class unknown: engine class or does not exist"
        report[name] = {"status": status, "files": sorted(files)}

    counts = collections.Counter(v["status"].split(",")[0] for v in report.values())
    print(f"{len(report)} game functions touched")
    for k, v in counts.most_common():
        print(f"  {v:4}  {k}")
    print()
    for name, v in report.items():
        if v["status"] != "ok":
            print(f"{v['status']:<60} {name}  ({', '.join(v['files'])})")
    if len(sys.argv) > 4:
        with open(sys.argv[4], "w") as fh:
            json.dump(report, fh, indent=1)


if __name__ == "__main__":
    main()
