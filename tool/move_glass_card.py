#!/usr/bin/env python3
"""Rewrite relative imports that still resolve to the old glass_card location.

glass_card.dart moved from lib/ui/widgets/ to lib/shared/widgets/. This pass
updates every relative import whose resolved target is the old location,
computing the correct relative depth per importing file. Run from the project
root: python tool/move_glass_card.py
"""
import os
import re
import sys

BACKSLASH = chr(92)
ROOT = "lib"
OLD = os.path.join(ROOT, "ui", "widgets", "glass_card.dart")
NEW = os.path.join(ROOT, "shared", "widgets", "glass_card.dart")


def norm(p: str) -> str:
    return p.replace(BACKSLASH, "/")


def main() -> int:
    old_norm = norm(os.path.normpath(OLD))
    changed = []
    for dirpath, _dirs, files in os.walk(ROOT):
        for fn in files:
            if not fn.endswith(".dart"):
                continue
            path = norm(os.path.join(dirpath, fn))
            if path == old_norm or path == norm(os.path.normpath(NEW)):
                continue
            out_lines = []
            touched = False
            with open(path, encoding="utf-8", errors="ignore", newline="") as fh:
                for line in fh:
                    stripped = line.rstrip("\r\n")
                    m = re.match(
                        r"^(\s*import ')((?:\.\./)+)([^']*glass_card\.dart)('.*)$",
                        stripped)
                    if not m:
                        out_lines.append(line)
                        continue
                    resolved = norm(os.path.normpath(
                        os.path.join(dirpath, m.group(2) + m.group(3))))
                    if resolved != old_norm:
                        out_lines.append(line)
                        continue
                    new_rel = norm(os.path.relpath(NEW, dirpath))
                    out_lines.append(f"{m.group(1)}{new_rel}{m.group(4)}\n")
                    touched = True
            if touched:
                with open(path, "w", encoding="utf-8", newline="") as fh:
                    fh.writelines(out_lines)
                changed.append(path)
    print(f"rewrote {len(changed)} files")
    for c in changed:
        print(" ", c)
    return 0


if __name__ == "__main__":
    sys.exit(main())
