#!/usr/bin/env python3
"""Detect import cycles and report cross-layer import edges for Noctra's lib/.

Used by the architecture audit. Parses relative imports only (absolute/package
imports cannot create intra-lib cycles).
"""
import os
import re
import sys

BACKSLASH = chr(92)


def norm(p: str) -> str:
    return p.replace(BACKSLASH, "/")


def main() -> int:
    root = "lib"
    edges = {}
    for dirpath, _dirs, files in os.walk(root):
        for fn in files:
            if not fn.endswith(".dart"):
                continue
            p = norm(os.path.join(dirpath, fn))
            deps = []
            with open(p, encoding="utf-8", errors="ignore") as fh:
                for line in fh:
                    m = re.match(r"\s*import '((?:\.\./)+[^']+)'", line)
                    if not m:
                        continue
                    target_raw = m.group(1)
                    ups = target_raw.count("../")
                    base = os.path.dirname(p)
                    for _ in range(ups):
                        base = os.path.dirname(base)
                    rel = target_raw[ups * 3:]
                    target = norm(os.path.normpath(os.path.join(base, rel)))
                    if target != p and target not in deps:
                        deps.append(target)
            edges[p] = deps

    state = {}
    cycles = []

    def dfs(n, path):
        state[n] = 1
        path.append(n)
        for d in edges.get(n, []):
            if d not in edges:
                continue
            if state.get(d) == 1:
                i = path.index(d)
                cycles.append(path[i:] + [d])
            elif state.get(d) is None:
                dfs(d, path)
        path.pop()
        state[n] = 2

    for n in edges:
        if state.get(n) is None:
            dfs(n, [])

    print("total files:", len(edges))
    print("cycles found:", len(cycles))
    for c in cycles[:15]:
        print(" -> ".join(c))
    return 0 if not cycles else 1


if __name__ == "__main__":
    sys.exit(main())
