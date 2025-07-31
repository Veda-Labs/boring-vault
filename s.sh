#!/usr/bin/env bash
set -euo pipefail

# ──────────────── 1. EDIT THESE ──────────────────────────────────────────────
SHARE_MOVER=0xc1CaF4915849CD5FE21Efaa4aE14E4EAfa7A3431          # the LayerZeroShareMover on Scroll
AMOUNT=1000000000000000                   # shares to bridge (uint96)
RECIPIENT=0xaa118f46fd933a74befe80395d1ddb2a094a77ca078de0070fe4e74af6c42821     # left-padded to 32 bytes
# ─────────────────────────────────────────────────────────────────────────────

# chain-specific constants
SOLANA_EID=30168
NATIVE=0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE   # LayerZero “native” sentinel
MAX_FEE_WEI=10000000000000000                       # 0.01 ETH cap
SCROLL_RPC_URL=https://scroll-mainnet.g.alchemy.com/v2/MbzciYdFs_SY9-yaS0L-E
SHARE_MOVER_DEPLOYER_KEY=0x2cd0a8a60a33004253ea25ff716ed924d48635278d3be2bbbe7d14319622a882
SLACK=1000000000000 

# build the bridgeWildCard: abi.encode(uint32,address,uint256)
WILDCARD=$(cast abi-encode \
             "dummy(uint32,address,uint256)" \
             $SOLANA_EID \
             $NATIVE \
             $MAX_FEE_WEI)

# query the fee the mover will charge
fee_hex=$(cast call $SHARE_MOVER \
          "previewFee(uint96,bytes32,bytes)" \
          $AMOUNT \
          $RECIPIENT \
          $WILDCARD \
          --rpc-url "$SCROLL_RPC_URL")

fee_wei=$(cast to-dec  "$fee_hex")
fee_eth=$(cast from-wei "$fee_wei" ether)

echo "──────────────────────────────────────────────"
echo "LayerZero native fee for this bridge:"
printf "  %s wei\n" "$fee_wei"
printf "  %s ETH\n" "$fee_eth"


# send the bridge tx
cast send $SHARE_MOVER \
  "bridge(uint96,bytes32,bytes)" \
  $AMOUNT \
  $RECIPIENT \
  $WILDCARD \
  --value       $fee_wei \
  --private-key $SHARE_MOVER_DEPLOYER_KEY \
  --rpc-url     $SCROLL_RPC_URL \
  --gas-price   3000000000            # 3 gwei, or omit for default