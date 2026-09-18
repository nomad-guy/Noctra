#!/usr/bin/env python3
"""Final-pass cleaner: removes misplaced token declarations reported by the
analyzer, working from its line numbers. Run: python tool/clean_badsites.py
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DECL = 'final t = context.noctraTokens;'


def main() -> None:
    out = subprocess.run(
        ['flutter.bat', 'analyze', '--no-pub'],
        cwd=ROOT, capture_output=True, text=True, timeout=300).stdout

    # Collect candidate (file, line) for every error that is NOT simply
    # "Undefined name 't'" (those are handled by the scope fixer).
    sites: dict[str, list[int]] = {}
    for line in out.splitlines():
        if 'error' not in line or "Undefined name 't'" in line:
            continue
        m = re.search(r'(lib[\\/][\w\\/.]+\.dart):(\d+):\d+', line)
        if not m:
            continue
        fp = os.path.normpath(m.group(1).replace('/', os.sep))
        sites.setdefault(fp, []).append(int(m.group(2)))

    total = 0
    for path, lns in sites.items():
        full = os.path.join(ROOT, path)
        if not os.path.exists(full):
            continue
        lines = open(full, encoding='utf-8').read().splitlines(keepends=True)
        removed = 0
        # Bottom-up: the decl line itself, or 1-2 lines above the reported
        # field error line.
        for ln in sorted(set(lns), reverse=True):
            for cand in (ln - 1, ln - 2, ln):
                if 0 <= cand - 1 < len(lines) and DECL in lines[cand - 1]:
                    del lines[cand - 1]
                    removed += 1
                    break
        if removed:
            open(full, 'w', encoding='utf-8').write(''.join(lines))
            print(f'  {path}: removed {removed}')
            total += removed
    print(f'total removed: {total}')
    sys.exit(0)


if __name__ == '__main__':
    main()
