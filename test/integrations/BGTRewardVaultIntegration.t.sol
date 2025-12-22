// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { BaseTestIntegration } from "test/integrations/BaseTestIntegration.t.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import {
    BGTRewardVaultDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/BGTRewardVaultDecoderAndSanitizer.sol";
import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";
import { ERC4626DecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import { CurveDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";
import { Test, stdStorage, StdStorage, stdError, console } from "@forge-std/Test.sol";

contract FullBGTRewardVaultDecoderAndSanitizer is BGTRewardVaultDecoderAndSanitizer {
    //function deposit(uint256, address receiver) external pure override(ERC4626DecoderAndSanitizer, CurveDecoderAndSanitizer) returns (bytes memory addressesFound) {
    //    addressesFound = abi.encodePacked(receiver);
    //}

    }

contract BGTRewardVault is BaseTestIntegration {
    address WBERA_HONEY_lp = 0x2c4a603A2aA5596287A06886862dc29d56DbC354;

    function _setUpBerachain() internal {
        super.setUp();
        _setupChain("berachain", 2_771_934);

        address bgtRewardVaultDecoder = address(new FullBGTRewardVaultDecoderAndSanitizer());

        _overrideDecoder(bgtRewardVaultDecoder);
    }

    function testBGTRewardVaultStakingFlow() external {
        //set up berachain
        _setUpBerachain();

        deal(WBERA_HONEY_lp, address(boringVault), 100e18);

        //we need to test stake(), getReward(), withdraw(), and exit()
        //1) deposit -> skip 1 week, getReward(), withdraw(), check rewards
        //2) deposit -> skip 1 week, exit(), check rewards

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBGTRewardVaultLeafs(leafs, getAddress(sourceChain, "WBERA_HONEY_reward_vault"), address(0), address(0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); //approve, deposit

        //manage leafs
        tx_.manageLeafs[0] = leafs[0]; //approve stakeToken()
        tx_.manageLeafs[1] = leafs[1]; //stake()

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = WBERA_HONEY_lp; //approve
        tx_.targets[1] = getAddress(sourceChain, "WBERA_HONEY_reward_vault");

        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "WBERA_HONEY_reward_vault"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature("stake(uint256)", 100e18);

        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 stakingBalanceBefore =
            ERC20(WBERA_HONEY_lp).balanceOf(getAddress(sourceChain, "WBERA_HONEY_reward_vault"));

        //submit call
        _submitManagerCall(manageProofs, tx_);

        //checks
        uint256 stakingBalanceAfter =
            ERC20(WBERA_HONEY_lp).balanceOf(getAddress(sourceChain, "WBERA_HONEY_reward_vault"));
        assertEq(stakingBalanceAfter, stakingBalanceBefore + 100e18);

        //accrue rewards
        skip(1 weeks);

        tx_ = _getTxArrays(2); //getReward, withdraw

        //manage leafs
        tx_.manageLeafs[0] = leafs[3]; //getReward()
        tx_.manageLeafs[1] = leafs[2]; //withdraw()

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "WBERA_HONEY_reward_vault"); //approve
        tx_.targets[1] = getAddress(sourceChain, "WBERA_HONEY_reward_vault");

        //targetDatas
        tx_.targetData[0] =
            abi.encodeWithSignature("getReward(address,address)", address(boringVault), address(boringVault));
        tx_.targetData[1] = abi.encodeWithSignature("withdraw(uint256)", 100e18);

        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        //submit call
        _submitManagerCall(manageProofs, tx_);

        //checks
        uint256 rewardBalance = getERC20(sourceChain, "BGT").balanceOf(address(boringVault));
        uint256 lpBalance = ERC20(WBERA_HONEY_lp).balanceOf(address(boringVault));

        assertGt(rewardBalance, 0);
        assertEq(lpBalance, 100e18);
    }

    function testBGTRewardVaultDelegateStaker() external {
        //set up berachain
        _setUpBerachain();

        deal(WBERA_HONEY_lp, address(boringVault), 100e18);

        //we need to test stake(), getReward(), withdraw(), and exit()
        //1) deposit -> skip 1 week, getReward(), withdraw(), check rewards
        //2) deposit -> skip 1 week, exit(), check rewards

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBGTRewardVaultLeafs(
            leafs,
            getAddress(sourceChain, "WBERA_HONEY_reward_vault"),
            getAddress(sourceChain, "dev1Address"),
            getAddress(sourceChain, "dev1Address")
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); //approve, deposit

        //manage leafs
        tx_.manageLeafs[0] = leafs[0]; //approve stakeToken()
        tx_.manageLeafs[1] = leafs[5]; //delegateStake()

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = WBERA_HONEY_lp; //approve
        tx_.targets[1] = getAddress(sourceChain, "WBERA_HONEY_reward_vault");

        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "WBERA_HONEY_reward_vault"), type(uint256).max
        );
        tx_.targetData[1] =
            abi.encodeWithSignature("delegateStake(address,uint256)", getAddress(sourceChain, "dev1Address"), 100e18);

        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 stakingBalanceBefore =
            ERC20(WBERA_HONEY_lp).balanceOf(getAddress(sourceChain, "WBERA_HONEY_reward_vault"));

        //submit call
        _submitManagerCall(manageProofs, tx_);

        //checks
        uint256 stakingBalanceAfter =
            ERC20(WBERA_HONEY_lp).balanceOf(getAddress(sourceChain, "WBERA_HONEY_reward_vault"));
        assertEq(stakingBalanceAfter, stakingBalanceBefore + 100e18);
        uint256 lpBalance = ERC20(WBERA_HONEY_lp).balanceOf(address(boringVault));
        assertEq(lpBalance, 0);

        //accrue rewards
        skip(1 weeks);

        tx_ = _getTxArrays(1); //delegateWithdraw

        //manage leafs
        tx_.manageLeafs[0] = leafs[6]; //delegateWithdraw()

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "WBERA_HONEY_reward_vault"); //delegateWithdraw

        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature(
            "delegateWithdraw(address,uint256)", getAddress(sourceChain, "dev1Address"), 100e18
        );

        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        //submit call
        _submitManagerCall(manageProofs, tx_);

        //checks
        //uint256 rewardBalance = getERC20(sourceChain, "BGT").balanceOf(address(boringVault));
        lpBalance = ERC20(WBERA_HONEY_lp).balanceOf(address(boringVault));

        //assertGt(rewardBalance, 0);
        assertEq(lpBalance, 100e18);
    }

    function testBGTRewardVaultSetOperator() external {
        //set up berachain
        _setUpBerachain();

        deal(WBERA_HONEY_lp, address(boringVault), 100e18);

        //we need to test stake(), getReward(), withdraw(), and exit()
        //1) deposit -> skip 1 week, getReward(), withdraw(), check rewards
        //2) deposit -> skip 1 week, exit(), check rewards

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBGTRewardVaultLeafs(
            leafs,
            getAddress(sourceChain, "WBERA_HONEY_reward_vault"),
            getAddress(sourceChain, "dev1Address"),
            getAddress(sourceChain, "dev1Address")
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1); //approve, deposit

        //manage leafs
        tx_.manageLeafs[0] = leafs[7]; //approve stakeToken()

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "WBERA_HONEY_reward_vault");

        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature("setOperator(address)", getAddress(sourceChain, "dev1Address"));

        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        //submit call
        _submitManagerCall(manageProofs, tx_);

        //checks
        //uint256 rewardBalance = getERC20(sourceChain, "BGT").balanceOf(address(boringVault));
        uint256 lpBalance = ERC20(WBERA_HONEY_lp).balanceOf(address(boringVault));

        //assertGt(rewardBalance, 0);
        assertEq(lpBalance, 100e18);
    }

    function testBGTRewardVaultStakingExit() external {
        //set up berachain
        _setUpBerachain();

        deal(WBERA_HONEY_lp, address(boringVault), 100e18);

        //we need to test stake(), getReward(), withdraw(), and exit()
        //1) deposit -> skip 1 week, getReward(), withdraw(), check rewards
        //2) deposit -> skip 1 week, exit(), check rewards

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBGTRewardVaultLeafs(leafs, getAddress(sourceChain, "WBERA_HONEY_reward_vault"), address(0), address(0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); //approve, deposit

        //manage leafs
        tx_.manageLeafs[0] = leafs[0]; //approve stakeToken()
        tx_.manageLeafs[1] = leafs[1]; //stake()

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = WBERA_HONEY_lp; //approve
        tx_.targets[1] = getAddress(sourceChain, "WBERA_HONEY_reward_vault");

        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "WBERA_HONEY_reward_vault"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature("stake(uint256)", 100e18);

        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 stakingBalanceBefore =
            ERC20(WBERA_HONEY_lp).balanceOf(getAddress(sourceChain, "WBERA_HONEY_reward_vault"));

        //submit call
        _submitManagerCall(manageProofs, tx_);

        //checks
        uint256 stakingBalanceAfter =
            ERC20(WBERA_HONEY_lp).balanceOf(getAddress(sourceChain, "WBERA_HONEY_reward_vault"));
        assertEq(stakingBalanceAfter, stakingBalanceBefore + 100e18);

        //accrue rewards
        skip(1 weeks);

        tx_ = _getTxArrays(1); //getReward, withdraw

        //manage leafs
        tx_.manageLeafs[0] = leafs[4]; //getReward()

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "WBERA_HONEY_reward_vault"); //approve

        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature("exit(address)", address(boringVault));

        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        //submit call
        _submitManagerCall(manageProofs, tx_);

        //checks
        uint256 rewardBalance = getERC20(sourceChain, "BGT").balanceOf(address(boringVault));
        uint256 lpBalance = ERC20(WBERA_HONEY_lp).balanceOf(address(boringVault));

        assertGt(rewardBalance, 0);
        assertEq(lpBalance, 100e18);
    }
}
