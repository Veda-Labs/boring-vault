# boring-vault-private — RPC endpoints, 1Password template.
#
# Regenerate the real (gitignored) .env, resolving the API keys from 1Password:
#     op inject -i .env.tpl -o .env
# …or load into the shell without writing any plaintext to disk:
#     source scripts/rpc-env.sh
#
# Requires the 1Password CLI (`op`) signed in (`op signin`) with read access to the
# Shared vault. Only the two API keys are secret (the 1Password references below). Every
# other endpoint is a public, pinned archive RPC. Changing an endpoint or rotating a
# key is one diff here / one 1Password edit — no per-dev .env drift.

# ── Alchemy (paid key — needed for HyperEVM archive) ────────────────────────────
MAINNET_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"
ARBITRUM_RPC_URL="https://arb-mainnet.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"
BASE_RPC_URL="https://base-mainnet.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"
AVALANCHE_RPC_URL="https://avax-mainnet.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"
OPTIMISM_RPC_URL="https://opt-mainnet.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"
LINEA_RPC_URL="https://linea-mainnet.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"
MANTLE_RPC_URL="https://mantle-mainnet.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"
HOLESKY_RPC_URL="https://eth-holesky.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"
SEPOLIA_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"
SCROLL_RPC_URL="https://scroll-mainnet.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"
SONIC_MAINNET_RPC_URL="https://sonic-mainnet.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"
BERA_CHAIN_RPC_URL="https://berachain-mainnet.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"
PLASMA_RPC_URL="https://plasma-mainnet.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"
BOB_RPC_URL="https://bob-mainnet.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"
HYPER_EVM_RPC_URL="https://hyperliquid-mainnet.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"

# ── Solana (same Alchemy key; used by vault-risk SVM assessments via curl JSON-RPC) ──
SOLANA_RPC_URL="https://solana-mainnet.g.alchemy.com/v2/{{ op://Shared/Alchemy API Key/notesPlain }}"

# ── Goldsky (only source serving Monad archive at the tests' pinned block) ───────
MONAD_RPC_URL="https://edge.goldsky.com/standard/evm/143?secret={{ op://Shared/Goldsky API Key/notesPlain }}"

# ── Public keyless archive endpoints (no API key) ───────────────────────────────
SWELL_CHAIN_RPC_URL="https://rpc.ankr.com/swell"
DERIVE_RPC_URL="https://rpc.derive.xyz"
TAC_RPC_URL="https://rpc.tac.build"
KATANA_RPC_URL="https://rpc.katana.network"
PLUME_RPC_URL="https://rpc.plume.org"
FLARE_RPC_URL="https://flare-api.flare.network/ext/C/rpc"

# Tempo has no env var: it's a hardcoded [rpc_endpoints] entry in foundry.toml
# (used only under FOUNDRY_PROFILE=tempo). Nothing to set here.
#
# Intentionally omitted: RPCs used ONLY by suites CI skips as deprecated (ETHFI-35).
# Notably BARTIO_RPC_URL (KodiakIsland / Infrared / Honey / GoldiVault fork the
# bArtio Berachain testnet, which is sunset — no live endpoint to point at), plus
# the Corn / Scroll suites. A naive local `forge test` runs these and fails on the
# missing/dead RPC, so run locally with the SAME --skip set as CI (see README /
# .github/workflows/test.yml). foundry.toml [rpc_endpoints] lists further chains the
# suite doesn't exercise (polygon, bsc, zircuit, sei, ink, unichain, *Testnet); add
# here only if you enable tests that fork them.
