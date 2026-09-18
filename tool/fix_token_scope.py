#!/usr/bin/env python3
"""Fixer: inserts `final t = context.noctraTokens;` at the top of the
enclosing function for every site where the analyzer reports
"Undefined name 't'". Reads analyzer output from stdin or re-runs it.
"""
import os
import re
import subprocess
import sys
import collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DECL = 'final t = context.noctraTokens;'


def get_errors() -> dict[str, list[int]]:
    out = subprocess.run(
        ['flutter.bat', 'analyze', '--no-pub'],
        cwd=ROOT, capture_output=True, text=True, timeout=300).stdout
    sites = collections.defaultdict(list)
    # Human-readable format: "  error - Undefined name 't'. ... - lib\\path:118:26 - undefined_identifier"
    pat = re.compile(r"error\s+-\s+Undefined name 't'.*?-\s+(.+?):(\d+):\d+")
    for line in out.splitlines():
        m = pat.search(line)
        if not m:
            continue
        fp = m.group(1).strip()
        if not os.path.isabs(fp):
            fp = os.path.join(ROOT, fp)
        sites[os.path.normpath(fp)].append(int(m.group(2)))
    return sites


def enclosing_insert_point(lines: list[str], err_line: int) -> int | None:
    """Walks up from err_line to the nearest line ending in '{' whose indent
    is smaller; returns -based insertion index (after the brace line)."""
    i = err_line - 1  # 0-based index of error line
    # find indent of error line
    def indent(s):
        return len(s) - len(s.lstrip())
    target = indent(lines[i])
    j = i
    while j >= 0:
        l = lines[j]
        if l.rstrip().endswith('{') and indent(l) < target:
            return j + 1
        target = min(target, indent(l))
        j -= 1
    return None


def fix_file(path: str, err_lines: list[int]) -> int:
    with open(path, encoding='utf-8') as f:
        lines = f.read().splitlines(keepends=True)
    # Insert from bottom up so indices stay valid; dedupe insert points.
    points = sorted(
        {p for p in (enclosing_insert_point(lines, ln) for ln in err_lines if ln <= len(lines)) if p is not None},
        reverse=True)
    inserted = 0
    for p in points:
        if p is None:
            continue
        # Skip if a declaration already exists within the next 3 lines.
        window = ''.join(lines[p:p + 3])
        if DECL in window:
            continue
        indent = re.match(r'\s*', lines[p]).group(0)
        lines.insert(p, f'{indent}{DECL}\n')
        inserted += 1
    if inserted:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(''.join(lines))
    return inserted


def main() -> None:
    sites = get_errors()
    total = 0
    for path, err_lines in sites.items():
        n = fix_file(path, err_lines)
        if n:
            print(f'  {path}: {n} insertions')
            total += n
    print(f'\nInserted {total} declarations')
    sys.exit(0)


if __name__ == '__main__':
    main()
