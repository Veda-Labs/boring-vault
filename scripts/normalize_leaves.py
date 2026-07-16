#!/usr/bin/env python3
"""Canonicalize committed merkle-leaf JSON so regeneration diffs cleanly.

Re-serializes each leaf file with sorted object keys and a fixed 4-space indent.
This is semantically a no-op: JSON object key order is meaningless, and arrays
(the merkle-ordered `leafs` list) are left in place, so ManageRoot / MerkleTree
are byte-preserved. forge's vm.serialize* emits keys in an unstable order, which
is what makes leaf files diff wholesale on every regeneration; running this after
generation keeps them byte-stable.

Usage:
  scripts/normalize_leaves.py           rewrite all leaf files in canonical form
  scripts/normalize_leaves.py --check   exit 1 if any leaf file is not canonical
"""
import glob, json, sys

def canonical(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return json.dumps(data, sort_keys=True, indent=4, ensure_ascii=False) + "\n", data

def main():
    check = "--check" in sys.argv
    files = [p for p in sorted(glob.glob("leafs/**/*.json", recursive=True))
             if "Temporary" not in p]
    noncanon = []
    for p in files:
        cur = open(p, encoding="utf-8").read()
        if cur.strip() == "":            # 0-byte placeholder leaf files: leave as-is
            continue
        canon, _ = canonical(p)
        if cur != canon:
            noncanon.append(p)
            if not check:
                open(p, "w", encoding="utf-8").write(canon)
    if check:
        if noncanon:
            # ::error:: makes this show as an annotation on the GitHub PR check.
            print(
                f"::error::{len(noncanon)} leaf JSON file(s) are not canonical. "
                f"Fix by running `python3 scripts/normalize_leaves.py` and committing the result."
            )
            print(f"{len(noncanon)} leaf file(s) not canonical:")
            for p in noncanon[:20]:
                print("  " + p)
            if len(noncanon) > 20:
                print(f"  ... and {len(noncanon) - 20} more")
            print("\nTo fix: run  python3 scripts/normalize_leaves.py  then commit the changes.")
            sys.exit(1)
        print(f"all {len(files)} leaf files canonical")
    else:
        print(f"normalized {len(noncanon)}/{len(files)} leaf files")

if __name__ == "__main__":
    main()
