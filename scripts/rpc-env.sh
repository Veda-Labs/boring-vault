# shellcheck shell=bash
# Load boring-vault RPC endpoints into the current shell from 1Password.
#
#   source scripts/rpc-env.sh      # then: forge test / forge script …
#
# Resolves the {{ op://… }} references in .env.tpl at runtime and exports them —
# no plaintext keys are written to disk. Requires the 1Password CLI (`op`) signed
# in (`op signin`) with read access to the Shared vault.
#
# Prefer this over `op inject -i .env.tpl -o .env` when you'd rather not have a
# resolved .env sitting on disk. (Both work; foundry auto-loads a .env if present.)

_rpcenv_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

if ! command -v op >/dev/null 2>&1; then
    echo "rpc-env: 1Password CLI 'op' not found — https://developer.1password.com/docs/cli/get-started/" >&2
elif ! op whoami >/dev/null 2>&1; then
    echo "rpc-env: 'op' is not signed in — run 'op signin' first." >&2
else
    set -a
    # shellcheck disable=SC1090
    source <(op inject -i "$_rpcenv_dir/.env.tpl")
    set +a
    echo "rpc-env: loaded $(grep -cE '^[A-Z].*_RPC_URL=' "$_rpcenv_dir/.env.tpl") RPC endpoints from 1Password."
fi

unset _rpcenv_dir
