# shellcheck shell=bash
# Load boring-vault RPC endpoints into the current shell from 1Password.
#
#   source scripts/rpc-env.sh      # then: forge test / forge script …
#
# Resolves the {{ ... }} references in .env.tpl at runtime and exports them — no
# plaintext keys are written to disk. Requires the 1Password CLI signed in
# (op signin) with read access to the Shared vault.
#
# Prefer this over `op inject -i .env.tpl -o .env` when you'd rather not have a
# resolved .env on disk. (Both work; foundry auto-loads a .env if present.)

_rpcenv_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

if ! command -v op >/dev/null 2>&1; then
    echo "rpc-env: 1Password CLI 'op' not found — https://developer.1password.com/docs/cli/get-started/" >&2
elif ! op whoami >/dev/null 2>&1; then
    echo "rpc-env: 'op' is not signed in — run 'op signin' first. RPC endpoints NOT loaded." >&2
# Capture first so a failed inject (network / perms / missing item) is caught and
# reported instead of silently "succeeding" with an empty environment.
elif ! _rpcenv_rendered="$(op inject -i "$_rpcenv_dir/.env.tpl")" || [ -z "$_rpcenv_rendered" ]; then
    echo "rpc-env: 'op inject' failed — RPC endpoints NOT loaded." >&2
else
    # Only toggle allexport if the caller didn't already have it on, so we don't
    # clobber their -a state when we're done.
    case "$-" in *a*) _rpcenv_had_a=1 ;; *) _rpcenv_had_a=0 ;; esac
    set -a
    eval "$_rpcenv_rendered"
    [ "$_rpcenv_had_a" -eq 1 ] || set +a
    echo "rpc-env: loaded $(printf '%s\n' "$_rpcenv_rendered" | grep -cE '^[A-Z][A-Z0-9_]*_RPC_URL=') RPC endpoints from 1Password."
fi

unset _rpcenv_dir _rpcenv_rendered _rpcenv_had_a
