#!/usr/bin/env python3
"""Report where a merge commit's result differs from a clean three-way merge of its parents.

A resolution that takes one side of a file wholesale silently drops the other side's changes, even
where they would have merged without conflicts. This lists every such file, plus modify/delete
outcomes, so each one can be checked by hand.

Usage: scripts/merge-audit.py [--diff] [MERGE] [-- PATHSPEC...]
"""

import argparse
import difflib
import os
import subprocess
import sys
import tempfile


def git(*args, data=None):
    r = subprocess.run(["git", *args], input=data, capture_output=True)
    if r.returncode:
        sys.exit(f"git {' '.join(args)}: {r.stderr.decode().strip()}")
    return r.stdout


def entries(rev, paths):
    """Map path -> (mode, object id) for the given paths in rev."""
    out = {}
    for i in range(0, len(paths), 500):
        raw = git("ls-tree", "-z", rev, "--", *paths[i : i + 500])
        for item in raw.split(b"\0"):
            if item:
                meta, path = item.split(b"\t", 1)
                mode, _, oid = meta.decode().split()
                out[path.decode()] = (mode, oid)
    return out


def blob(entry):
    return git("cat-file", "blob", entry[1]) if entry else b""


def side_name(result, ours, theirs):
    if result == ours and result == theirs:
        return "both"
    return "ours" if result == ours else "theirs" if result == theirs else "neither"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--diff", action="store_true", help="show clean merge -> recorded result diffs")
    ap.add_argument("merge", nargs="?", default="HEAD")
    ap.add_argument("pathspec", nargs="*")
    a = ap.parse_args()

    parents = git("rev-list", "--parents", "-n1", a.merge).decode().split()[1:]
    if len(parents) != 2:
        sys.exit(f"{a.merge} has {len(parents)} parents; expected a two-parent merge")
    ours, theirs = parents
    base = git("merge-base", ours, theirs).decode().strip()
    names = set()
    for parent in parents:
        names.update(git("diff", "--name-only", "-z", parent, a.merge, "--", *a.pathspec).decode().split("\0"))
    names.discard("")
    paths = sorted(names)
    tb, to, tt, tr = (entries(rev, paths) for rev in (base, ours, theirs, a.merge))
    print(f"merge {a.merge}: base {base[:10]}, ours {ours[:10]}, theirs {theirs[:10]}")

    findings = 0
    with tempfile.TemporaryDirectory() as tmp:
        for path in paths:
            b, o, t, r = tb.get(path), to.get(path), tt.get(path), tr.get(path)
            if o == b:  # only theirs changed it, so a clean merge takes theirs
                if r != t:
                    findings += 1
                    print(f"theirs-only changed, result is {side_name(r, o, t)}: {path}")
                continue
            if t == b:
                if r != o:
                    findings += 1
                    print(f"ours-only changed, result is {side_name(r, o, t)}: {path}")
                continue
            if o is None or t is None:  # deleted on one side, changed on the other
                findings += 1
                state = "deleted" if r is None else side_name(r, o, t)
                print(f"modify/delete, result is {state}: {path}")
                continue
            if o == t:
                if r != o:
                    findings += 1
                    print(f"same change on both sides, result is neither: {path}")
                continue
            files = []
            for name, entry in (("ours", o), ("base", b), ("theirs", t)):
                p = os.path.join(tmp, name)
                with open(p, "wb") as f:
                    f.write(blob(entry))
                files.append(p)
            m = subprocess.run(
                ["git", "merge-file", "-p", "-L", "ours", "-L", "base", "-L", "theirs", *files],
                capture_output=True,
            )
            if m.returncode == 0 and r is not None and m.stdout == blob(r):
                continue
            findings += 1
            kind = "clean merge" if m.returncode == 0 else "conflicted"
            state = "deleted" if r is None else side_name(r, o, t)
            print(f"{kind}, result is {state}: {path}")
            if a.diff:
                expected = m.stdout.decode(errors="replace").splitlines(keepends=True)
                recorded = blob(r).decode(errors="replace").splitlines(keepends=True)
                sys.stdout.writelines(
                    difflib.unified_diff(expected, recorded, f"3-way/{path}", f"result/{path}")
                )
    print(f"{findings} file(s) to review")


if __name__ == "__main__":
    main()
