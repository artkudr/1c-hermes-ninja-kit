#!/usr/bin/env python3
"""ninja_json.py — работа с tools/projects.json (вызывается из ninja.sh).

Использование:
  ninja_json.py list <projects.json>
  ninja_json.py set  <projects.json> <key> <path> <created> [ext1,ext2,...]
  ninja_json.py del  <projects.json> <key>
"""
import json
import sys


def load(path):
    return json.load(open(path, encoding="utf-8"))


def save(path, data):
    open(path, "w", encoding="utf-8").write(
        json.dumps(data, ensure_ascii=False, indent=2)
    )


def main():
    cmd, path = sys.argv[1], sys.argv[2]
    if cmd == "set":
        key, pval, created = sys.argv[3], sys.argv[4], sys.argv[5]
        exts = [e for e in (sys.argv[6].split(",") if len(sys.argv) > 6 else []) if e]
        data = load(path)
        data.setdefault("projects", {})[key] = {
            "path": pval,
            "created": created,
            "extensions": exts,
        }
        save(path, data)
    elif cmd == "del":
        key = sys.argv[3]
        data = load(path)
        data.get("projects", {}).pop(key, None)
        save(path, data)
    elif cmd == "list":
        data = load(path)
        projs = data.get("projects", {})
        if not projs:
            print("(пусто)")
        for name, p in sorted(projs.items()):
            exts = ", ".join(p.get("extensions") or [])
            print("%-22s %s  [%s]" % (name, p.get("path", "?"), exts))
    elif cmd == "get":  # get <projects.json> <key>  → печатает path
        key = sys.argv[3]
        data = load(path)
        p = data.get("projects", {}).get(key)
        if p:
            print(p.get("path", ""))
    else:
        sys.exit("неизвестная команда: %s" % cmd)


if __name__ == "__main__":
    main()