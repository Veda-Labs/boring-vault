#!/usr/bin/env bash
# Point git at the repo's committed hooks. Run once after cloning.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath .githooks
echo "Enabled .githooks — pre-commit will canonicalize staged leaf JSON (scripts/normalize_leaves.py)."
