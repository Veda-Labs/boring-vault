// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {OneInchAdapter} from "src/base/Periphery/adapters/OneInchAdapter.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";

import "forge-std/Script.sol";

/**
 * Deploys a new OneInchAdapter (v2 — _ARGS_HAS_TARGET check added to fillOrder),
 * registers it in the AdapterRegistry, and approves it on the swapper.
 *
 *   source .env && forge script script/Test/DeployOneInchAdapterV2.s.sol:DeployOneInchAdapterV2 \
 *     --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 */
contract DeployOneInchAdapterV2 is Script {
    uint256 public privateKey;

    address registry = 0x291cf51d077F71509C0B41C26f857149Bb26D21b;
    address swapper  = 0xA19a28547d07C35B2F9C71DFDF7cEBA89C41E6CC;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        OneInchAdapter newAdapter = new OneInchAdapter(
            0x111111125421cA6dc452d289314280a0f8842A65, // router
            0xc0DFdB9E7a392c3dBBE7c6FBe8FBC1789C9FE05e  // feeTaker
        );
        console.log("OneInchAdapter (v2):", address(newAdapter));

        AdapterRegistry(registry).put(address(newAdapter), "ONEINCH");
        BoringSwapper(swapper).setApprovedAdapter(address(newAdapter), true);

        vm.stopBroadcast();
    }
}
