#!/usr/bin/env python3
"""Compare hosts between a revision and the working tree (or another revision).

Evaluates scripts/host-facts.nix (boot, storage, networking, secrets, services, packages, Home
Manager files) for each host at both points and prints what was added (+), removed (-) or changed
(~). A merge should only show differences that its commits explain.

Usage: scripts/host-diff.py --old REV [--new REV] [--jobs N] HOST...
"""

import argparse
import json
import os
import subprocess
import sys

KEYS = ("directory", "file", "device")


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout.strip()


def facts(root, flake, host, jobs):
    expr = f'import {root}/scripts/host-facts.nix {{ flake = "{flake}"; host = "{host}"; }}'
    r = subprocess.run(
        ["nix", "eval", "--impure", "--json", "--max-jobs", jobs, "--cores", jobs, "--expr", expr],
        capture_output=True,
        text=True,
    )
    if r.returncode:
        sys.exit(f"evaluating {host} at {flake} failed:\n{r.stderr[-4000:]}")
    return json.loads(r.stdout)


def keyed(items):
    """Lists of attribute sets that name a path (preserved directories, swap devices) by that path."""
    for k in KEYS:
        if items and all(isinstance(x, dict) and k in x for x in items):
            return {x[k]: x for x in items}
    return None


def show(value):
    text = json.dumps(value, ensure_ascii=False)
    return text if len(text) <= 160 else text[:157] + "..."


def walk(a, b, path=""):
    if isinstance(a, list) and isinstance(b, list):
        ka, kb = keyed(a), keyed(b)
        if ka is not None and kb is not None:
            a, b = ka, kb
        elif all(isinstance(x, str) for x in a + b):
            for x in sorted(set(b) - set(a)):
                print(f"+ {path}: {x}")
            for x in sorted(set(a) - set(b)):
                print(f"- {path}: {x}")
            return
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)):
            p = f"{path}/{k}"
            if k not in a:
                print(f"+ {p}: {show(b[k])}")
            elif k not in b:
                print(f"- {p}: {show(a[k])}")
            else:
                walk(a[k], b[k], p)
    elif a != b:
        print(f"~ {path}: {show(a)} -> {show(b)}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--old", required=True, help="revision to compare against, e.g. the local branch before the merge")
    ap.add_argument("--new", help="revision to compare (default: the working tree)")
    ap.add_argument("--jobs", default="8", help="--max-jobs/--cores for evaluation (default 8)")
    ap.add_argument("hosts", nargs="+")
    a = ap.parse_args()

    root = git("rev-parse", "--show-toplevel")
    old = f"git+file://{root}?rev={git('rev-parse', '--verify', a.old + '^{commit}')}"
    new = f"git+file://{root}" + (f"?rev={git('rev-parse', '--verify', a.new + '^{commit}')}" if a.new else "")
    for host in a.hosts:
        print(f"## {host}")
        walk(facts(root, old, host, a.jobs), facts(root, new, host, a.jobs))


if __name__ == "__main__":
    main()
