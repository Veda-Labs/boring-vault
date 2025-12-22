// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { BaseTestIntegration } from "test/integrations/BaseTestIntegration.t.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import {
    BalancerV2DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/BalancerV2DecoderAndSanitizer.sol";
import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";
import { ERC4626DecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import { CurveDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";
import { Test, stdStorage, StdStorage, stdError, console } from "@forge-std/Test.sol";

/// @notice balancer decoder has the correct funciton signature already, so we can reuse it here
contract FullBalancerDecoderAndSanitizer is BalancerV2DecoderAndSanitizer { }

contract SonicCRVClaimingIntegrationTest is BaseTestIntegration {
    function _setUpSonic() internal {
        super.setUp();
        _setupChain("sonicMainnet", 19_168_242);

        address balancerDecoder = address(new FullBalancerDecoderAndSanitizer());

        _overrideDecoder(balancerDecoder);
        _overrideBoringVault(0x4D85bA8c3918359c78Ed09581E5bc7578ba932ba);
        _overrideManager(0x5F7f5205A3E7c63c3bd287EecBe7879687D4c698);
        _setStrategist(0xB26AEb430b5Bf6Be55763b42095E82DB9a1838B8);
    }

    function testScUSDClaimingCRV() public {
        _setUpSonic();

        address gauge = 0x12F89168C995e54Ec2ce9ee461D663a6dC72793A;

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addCRVClaimingLeafs(leafs, gauge);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        vm.prank(boringVault.owner());
        manager.setManageRoot(strategist, manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[0]; //mint(gauge)

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "curve_CRV_claiming");

        tx_.targetData[0] = abi.encodeWithSignature("mint(address)", gauge);

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        vm.prank(strategist);
        _submitManagerCall(manageProofs, tx_);

        uint256 crvBalance = getERC20(sourceChain, "CRV").balanceOf(address(boringVault));
        console.log("stkSCUSD address: ", address(boringVault));
        console.log("BORING VAULT HAS ", crvBalance, "CURVE");
        assertGt(crvBalance, 0);
    }
}
