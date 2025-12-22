// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { Test, stdStorage, StdStorage, stdError, console } from "@forge-std/Test.sol";
import { TellerWithBuffer } from "src/base/Roles/TellerWithBuffer.sol";
import { TellerWithRemediation } from "src/base/Roles/TellerWithRemediation.sol";
import { TellerWithYieldStreaming } from "src/base/Roles/TellerWithYieldStreaming.sol";
import { TellerWithMultiAssetSupport } from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import { LayerZeroTeller } from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {
    LayerZeroTellerWithRateLimiting
} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTellerWithRateLimiting.sol";
import { BoringVault } from "src/base/BoringVault.sol";
import { AccountantWithRateProviders } from "src/base/Roles/AccountantWithRateProviders.sol";
import { ChainValues } from "test/resources/ChainValues.sol";
import { MerkleTreeHelper } from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import { MockLayerZeroEndPoint } from "src/helper/MockLayerZeroEndPoint.sol";

contract TellerVersionsTest is Test, MerkleTreeHelper {
    using stdStorage for StdStorage;

    TellerWithBuffer public tellerWithBuffer;
    TellerWithRemediation public tellerWithRemediation;
    TellerWithYieldStreaming public tellerWithYieldStreaming;
    LayerZeroTeller public layerZeroTeller;
    LayerZeroTellerWithRateLimiting public layerZeroTellerWithRateLimiting;

    BoringVault public boringVault;
    AccountantWithRateProviders public accountant;

    MockLayerZeroEndPoint public endPoint;

    function setUp() public {
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 23_091_932;
        vm.createSelectFork(vm.envString(rpcKey), blockNumber);

        endPoint = new MockLayerZeroEndPoint();

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);
        accountant = new AccountantWithRateProviders(
            address(this),
            address(boringVault),
            address(0),
            1e18,
            getAddress(mainnet, "WETH"),
            1.001e4,
            0.999e4,
            1,
            0,
            0
        );
        tellerWithBuffer = new TellerWithBuffer(address(this), address(boringVault), address(accountant), address(0));
        tellerWithRemediation =
            new TellerWithRemediation(address(this), address(boringVault), address(accountant), address(0));
        tellerWithYieldStreaming =
            new TellerWithYieldStreaming(address(this), address(boringVault), address(accountant), address(0));
        layerZeroTeller = new LayerZeroTeller(
            address(this),
            address(boringVault),
            address(accountant),
            address(0),
            address(endPoint),
            address(this),
            address(0)
        );
        layerZeroTellerWithRateLimiting = new LayerZeroTellerWithRateLimiting(
            address(this),
            address(boringVault),
            address(accountant),
            address(0),
            address(endPoint),
            address(this),
            address(0)
        );
    }

    function testTellerVersions() public view {
        assertEq(tellerWithBuffer.version(), "Buffer V0.1, Base V0.1");
        assertEq(tellerWithRemediation.version(), "Remediation V0.1, Base V0.1");
        assertEq(tellerWithYieldStreaming.version(), "Yield Streaming V0.1, Buffer V0.1, Base V0.1");
        assertEq(layerZeroTeller.version(), "LayerZero V0.1, Cross Chain V0.1, Base V0.1");
        assertEq(layerZeroTellerWithRateLimiting.version(), "LayerZero Rate Limiting V0.1, Cross Chain V0.1, Base V0.1");
    }
}
