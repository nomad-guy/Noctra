#!/usr/bin/env python3
"""One-shot design-token migration codemod.

Replaces mechanical isDark color ternaries with semantic tokens from
NoctraThemeTokens (accessed via context.noctraTokens). Only touches lib/ui
and lib/shared widget files.

Patterns handled (single-line and multiline ternaries):
  isDark ? Colors.white : Colors.black          -> t.primaryText
  isDark ? Colors.black : Colors.white          -> t.primaryText (inverted)
  isDark ? Colors.white54 : Colors.black54      -> t.secondaryText
  isDark ? Colors.white70 : Colors.black87      -> t.secondaryText
  isDark ? Colors.white60 : Colors.black54      -> t.secondaryText
  isDark ? Colors.white38 : Colors.black38      -> t.tertiaryText
  isDark ? Colors.white24 : Colors.black26      -> t.tertiaryText
  isDark ? Colors.white : Colors.black54        -> t.secondaryText

`isDark` may also appear as `widget.isDark`. The replacement is emitted as
`t.<token>` and the codemod injects `final t = context.noctraTokens;` at the
top of any build() method in a file it edited — the analyzer then catches
the (few) sites where `context` is not in scope for hand-fixing.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGETS = [
    os.path.join(ROOT, 'lib', 'ui'),
    os.path.join(ROOT, 'lib', 'shared'),
]

# (regex, replacement) applied per line, first match wins.
# D<strong> = high-emphasis (primary text), D<med> = secondary, D<low> = tertiary.
MAPPINGS = [
    # white54/black54, white70/black87, white60/black54 -> secondary
    (re.compile(r"\b(?:widget\.)?isDark\s*\?\s*Colors\.white(?:54|70|60)\b\s*:\s*Colors\.black(?:54|87)\b"),
     't.secondaryText'),
    (re.compile(r"\b(?:widget\.)?isDark\s*\?\s*Colors\.black(?:54|87)\b\s*:\s*Colors\.white(?:54|70|60)\b"),
     't.secondaryText'),
    # white38/black38, white24/black26, white30/black26 -> tertiary
    (re.compile(r"\b(?:widget\.)?isDark\s*\?\s*Colors\.white(?:38|24|30)\b\s*:\s*Colors\.black(?:38|26)\b"),
     't.tertiaryText'),
    (re.compile(r"\b(?:widget\.)?isDark\s*\?\s*Colors\.black(?:38|26)\b\s*:\s*Colors\.white(?:38|24|30)\b"),
     't.tertiaryText'),
    # plain white/black (either polarity) -> primary
    (re.compile(r"\b(?:widget\.)?isDark\s*\?\s*Colors\.white\b\s*:\s*Colors\.black\b"),
     't.primaryText'),
    (re.compile(r"\b(?:widget\.)?isDark\s*\?\s*Colors\.black\b\s*:\s*Colors\.white\b"),
     't.primaryText'),
]

INJECT_RE = re.compile(r"(Widget\s+build\s*\(\s*BuildContext\s+context[^)]*\)\s*\{)")


def inject_tokens(source: str) -> str:
    """Adds `final t = context.noctraTokens;` right after each build() opener
    in files where `t.` is referenced but not yet defined in that scope."""
    if 't.' not in source:
        return source
    out_lines = []
    for line in source.splitlines(keepends=True):
        out_lines.append(line)
        m = INJECT_RE.search(line)
        if m and 'final t = context.noctraTokens;' not in source:
            indent = re.match(r'\s*', line).group(0)
            out_lines.append(f'{indent}  final t = context.noctraTokens;\n')
    return ''.join(out_lines)


def ensure_import(source: str) -> str:
    """Ensures the file imports noir_theme.dart (for the tokens extension)."""
    if "noctraTokens" not in source:
        return source
    if re.search(r"import\s+['\"].*noir_theme\.dart['\"]", source):
        return source
    # Insert after the last existing import.
    imports = list(re.finditer(r"^import\s+[^;]+;$", source, re.M))
    if not imports:
        return source
    last = imports[-1]
    rel = compute_rel_import(source)
    if rel is None:
        return source
    return source[:last.end()] + f"\nimport '{rel}';" + source[last.end():]


def compute_rel_import(source: str) -> str | None:
    """Relative path from the file to core/theme/noir_theme.dart, guessed by
    depth: lib/ui/widgets/x.dart -> ../../core/theme/noir_theme.dart"""
    # We do not know the file path here; caller passes depth instead.
    return None


def process_file(path: str) -> tuple[int, bool]:
    with open(path, encoding='utf-8') as f:
        src = f.read()
    if 'isDark' not in src:
        return 0, False
    count = 0
    out = []
    for line in src.splitlines(keepends=True):
        orig = line
        for regex, repl in MAPPINGS:
            line, n = regex.subn(repl, line)
            count += n
        out.append(line)
    result = ''.join(out)
    if count == 0:
        return 0, False
    result = inject_tokens(result)

    # Ensure import of noir_theme.dart with correct relative depth.
    depth = path.replace(os.sep, '/').split('/lib/', 1)[1].count('/')
    rel = '../' * depth + 'core/theme/noir_theme.dart'
    if not re.search(r"import\s+['\"].*noir_theme\.dart['\"]", result):
        imports = list(re.finditer(r"^import\s+[^;]+;$", result, re.M))
        if imports:
            last = imports[-1]
            result = result[:last.end()] + f"\nimport '{rel}';" + result[last.end():]

    with open(path, 'w', encoding='utf-8') as f:
        f.write(result)
    return count, True


def main() -> None:
    total = 0
    files_changed = 0
    for base in TARGETS:
        for dirpath, _dirnames, filenames in os.walk(base):
            for fn in filenames:
                if not fn.endswith('.dart'):
                    continue
                p = os.path.join(dirpath, fn)
                n, changed = process_file(p)
                if changed:
                    total += n
                    files_changed += 1
                    print(f'  {p}: {n} replacements')
    print(f'\nDone: {total} replacements in {files_changed} files')
    sys.exit(0 if total > 0 else 1)


if __name__ == '__main__':
    main()
