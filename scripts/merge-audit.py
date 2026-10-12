#!/usr/bin/env python3
"""Report where a merge commit's result differs from a clean three-way merge of its parents.

A resolution that takes one side of a file wholesale silently drops the other side's changes, even
where they would have merged without conflicts. This lists every such file, plus modify/delete
outcomes, so each one can be checked by hand. For a conflicted file that ended up as one side, it
also says whether the other side's non-conflicting hunks were lost.

With --ours and --theirs, RESULT may be any commit, e.g. a branch tip that a merge and later fix
commits produced; the base defaults to their merge base.

Usage: scripts/merge-audit.py [--diff] [--ours REV --theirs REV [--base REV]] [RESULT] [-- PATHSPEC...]
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


def merge_file(tmp, base, ours, theirs, *flags):
    """git merge-file of three blobs; returns (exit code, merged bytes)."""
    files = []
    for name, data in (("ours", ours), ("base", base), ("theirs", theirs)):
        p = os.path.join(tmp, name)
        with open(p, "wb") as f:
            f.write(data)
        files.append(p)
    m = subprocess.run(
        ["git", "merge-file", "-p", *flags, "-L", "ours", "-L", "base", "-L", "theirs", *files],
        capture_output=True,
    )
    return m.returncode, m.stdout


def side_name(result, ours, theirs):
    if result == ours and result == theirs:
        return "both"
    return "ours" if result == ours else "theirs" if result == theirs else "neither"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--diff", action="store_true", help="show clean merge -> recorded result diffs")
    ap.add_argument("--ours", help="first side (default: the merge's first parent)")
    ap.add_argument("--theirs", help="second side (default: the merge's second parent)")
    ap.add_argument("--base", help="merge base (default: git merge-base OURS THEIRS)")
    ap.add_argument("merge", nargs="?", default="HEAD", metavar="RESULT")
    ap.add_argument("pathspec", nargs="*")
    a = ap.parse_args()

    if bool(a.ours) != bool(a.theirs):
        sys.exit("give both --ours and --theirs, or neither")
    if a.ours:
        parents = [git("rev-parse", "--verify", f"{rev}^{{commit}}").decode().strip() for rev in (a.ours, a.theirs)]
    else:
        parents = git("rev-list", "--parents", "-n1", a.merge).decode().split()[1:]
        if len(parents) != 2:
            sys.exit(f"{a.merge} has {len(parents)} parents; expected a two-parent merge (or pass --ours/--theirs)")
    ours, theirs = parents
    base = git("rev-parse", "--verify", f"{a.base}^{{commit}}").decode().strip() if a.base else git("merge-base", ours, theirs).decode().strip()
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
            if o == b and t == b:  # neither side changed it
                if r != b:
                    findings += 1
                    state = "deleted" if r is None else "added" if b is None else "changed"
                    print(f"unchanged on both sides, result {state}: {path}")
                continue
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
            code, merged = merge_file(tmp, blob(b), blob(o), blob(t))
            if code == 0 and r is not None and merged == blob(r):
                continue
            findings += 1
            kind = "clean merge" if code == 0 else "conflicted"
            state = "deleted" if r is None else side_name(r, o, t)
            expected_name = "3-way"
            if code != 0 and state in ("ours", "theirs"):
                # Resolve only the conflicts toward the side the result took; anything that still
                # differs is the other side's non-conflicting change, which the result dropped.
                _, merged = merge_file(tmp, blob(b), blob(o), blob(t), f"--{state}")
                expected_name = f"3-way --{state}"
                lost = "keeps" if merged == blob(r) else "drops"
                other = "theirs" if state == "ours" else "ours"
                state += f", {lost} {other}' non-conflicting hunks"
            print(f"{kind}, result is {state}: {path}")
            if a.diff:
                expected = merged.decode(errors="replace").splitlines(keepends=True)
                recorded = blob(r).decode(errors="replace").splitlines(keepends=True)
                sys.stdout.writelines(
                    difflib.unified_diff(expected, recorded, f"{expected_name}/{path}", f"result/{path}")
                )
    print(f"{findings} file(s) to review")


if __name__ == "__main__":
    main()
