# shellcheck shell=bash
# Load boring-vault RPC endpoints into the current shell from 1Password.
#
#   source scripts/rpc-env.sh      # then: forge test / forge script …
#   source scripts/rpc-env.sh && forge test        # only runs if loading succeeded
#
# Resolves the {{ ... }} references in .env.tpl at runtime and exports them — no
# plaintext keys are written to disk. Requires the 1Password CLI signed in
# (op signin) with read access to the Shared vault.
#
# Prefer this over `op inject -i .env.tpl -o .env` when you'd rather not have a
# resolved .env on disk. (Both work; foundry auto-loads a .env if present.)
# Returns non-zero (when sourced) if anything fails, so `&& forge test` is safe.

_rpcenv_load() {
    local dir tpl rendered had_a=0
    # Resolve the repo root (this script lives in <root>/scripts/). BASH_SOURCE is
    # bash-only; under zsh it's empty, so fall back to $PWD (script is normally
    # sourced from the repo root) and then to the git toplevel if sourced elsewhere.
    if [ -n "${BASH_SOURCE:-}" ]; then
        dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    else
        dir="$PWD"
    fi
    tpl="$dir/.env.tpl"
    if [ ! -f "$tpl" ]; then
        dir="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")"
        tpl="$dir/.env.tpl"
    fi

    if ! command -v op >/dev/null 2>&1; then
        echo "rpc-env: 1Password CLI 'op' not found — https://developer.1password.com/docs/cli/get-started/" >&2
        return 1
    fi
    # Don't gate on `op whoami`: under 1Password desktop-app CLI integration there
    # is no session token (secrets come via per-command biometric approval), so
    # `op whoami` reports "not signed in" even though `op inject`/`op read` work.
    # Let the inject below be the single source of truth — it fails cleanly if `op`
    # is genuinely unauthorized (session signin OR desktop integration both work).
    #
    # Capture first so a failed inject (not signed in / network / perms / missing
    # item) is caught and reported instead of silently exporting an empty environment.
    if ! rendered="$(op inject -i "$tpl")" || [ -z "$rendered" ]; then
        echo "rpc-env: 'op inject' failed — RPC endpoints NOT loaded. Sign in with" \
             "'op signin', or enable 1Password desktop-app CLI integration and unlock it." >&2
        return 1
    fi

    # Only toggle allexport if the caller didn't already have it on, so we don't
    # clobber their -a state when we're done.
    case "$-" in *a*) had_a=1 ;; esac
    set -a
    # shellcheck disable=SC1090
    source <(printf '%s\n' "$rendered")   # load KEY="value" lines (no eval)
    [ "$had_a" -eq 1 ] || set +a

    echo "rpc-env: loaded $(printf '%s\n' "$rendered" | grep -cE '^[A-Z][A-Z0-9_]*_RPC_URL=') RPC endpoints from 1Password."
}

_rpcenv_load
