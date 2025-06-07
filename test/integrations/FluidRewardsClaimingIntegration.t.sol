// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {FluidRewardsClaimingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FluidRewardsClaimingDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullFluidRewardsClaimingDecoderAndSanitizer is FluidRewardsClaimingDecoderAndSanitizer { }

contract FluidRewardsClaimingIntegration is BaseTestIntegration {
        
    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 22175064); 
            
        address fluidDecoder = address(new FullFluidRewardsClaimingDecoderAndSanitizer()); 

        _overrideDecoder(fluidDecoder); 
    }

    function testFluidRewardsClaiming() external {
        _setUpMainnet(); 
        
        //starting with just the base assets 
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addFluidRewardsClaiming(leafs);  

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[0]; //approve token0


        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
    
        //targets
        tx_.targets[0] = getAddress(sourceChain, "fluidMerkleDistributor"); //claim 

        bytes32[] memory claimProofs = new bytes32[](10); 

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "claim(address,uint256,uint8,bytes32,uint256,bytes32[],bytes)",
            address(boringVault),
            100e18,
            1,
            0x0000000000000000000000009fb7b4477576fe5b32be4c1843afb1e55f251b33,
            330,
            claimProofs,
            ""
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        
        vm.expectRevert(); //no proof data, need this from FE 
        _submitManagerCall(manageProofs, tx_); 
         
        //check that swap went through 
        //assert we sold all iBGT for WETH
        uint256 rewardBalance = getERC20(sourceChain, "FLUID").balanceOf(address(boringVault)); 
        assertEq(rewardBalance, 0); 

    }
}
