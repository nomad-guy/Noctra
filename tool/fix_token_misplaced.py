#!/usr/bin/env python3
"""Second-pass fixer for the token codemod.

Removes `final t = context.noctraTokens;` declarations that landed in invalid
spots (class field initializers, constructor bodies, top level) — detected by
these analyzer errors:
  - implicit_this_reference_in_initializer
  - const_constructor_with_field_initialized_by_non_const
  - instance_member_access_from_static
  - Undefined name 'context'
  - expected_token / body_might_complete_normally (brace damage from bad insert)

Then re-runs the scope fixer's enclosing-function insertion for the sites
that lost their declaration.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DECL = 'final t = context.noctraTokens;'
BAD_PATTERNS = [
    'implicit_this_reference_in_initializer',
    'const_constructor_with_field_initialized_by_non_const',
    'instance_member_access_from_static',
    "Undefined name 'context'",
    'expected_token',
    'expected_declaration',
    'body_might_complete_normally',
    'invalid_use_of_this',
]


def remove_bad_decls(path: str, err_lines: list[int]) -> int:
    with open(path, encoding='utf-8') as f:
        lines = f.read().splitlines(keepends=True)
    removed = 0
    # Collect line indexes containing the declaration; delete those that are
    # plausibly the cause (error line within +/- 6 lines) or that sit directly
    # before a field/constructor context.
    decl_idx = [i for i, l in enumerate(lines) if DECL in l]
    for i in reversed(decl_idx):
        for ln in err_lines:
            if abs((ln - 1) - i) <= 6:
                # Only remove if this decl is NOT directly after a function
                # signature (function-scope decls are legal).
                prev = lines[i - 1].strip() if i > 0 else ''
                if re.search(r'\)\s*\{?$', prev) or 'build(' in prev:
                    continue
                del lines[i]
                removed += 1
                break
    if removed:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(''.join(lines))
    return removed


def main() -> None:
    out = subprocess.run(
        ['flutter.bat', 'analyze', '--no-pub'],
        cwd=ROOT, capture_output=True, text=True, timeout=300).stdout
    per_file = {}
    for line in out.splitlines():
        if not any(p in line for p in BAD_PATTERNS):
            continue
        # Analyzer lines end with: "- lib\path\file.dart:LINE:COL - code".
        m = re.search(r"(lib[\\/][\w\\/.]+\.dart):(\d+):\d+\s+-\s+\w+", line)
        if not m:
            continue
        fp = os.path.join(ROOT, m.group(1).replace('/', os.sep))
        per_file.setdefault(os.path.normpath(fp), []).append(int(m.group(2)))

    total = 0
    for path, lns in per_file.items():
        n = remove_bad_decls(path, lns)
        if n:
            print(f'  {path}: removed {n}')
            total += n
    print(f'\nRemoved {total} misplaced declarations')
    sys.exit(0)


if __name__ == '__main__':
    main()
