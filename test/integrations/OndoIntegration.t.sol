// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {OndoDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OndoDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullOndoDecoderAndSanitizer is OndoDecoderAndSanitizer, BaseDecoderAndSanitizer {}

interface IOndoIDRegistry {
    function setUserID(address rwaToken, address[] calldata userAddresses, bytes32 newUserID) external;
}

contract OndoIntegrationTest is BaseTestIntegration {
    address internal constant ONDO_ID_REGISTRY = 0xcf6958D69d535FD03BD6Df3F4fe6CDcd127D97df;
    address internal constant ONDO_ID_REGISTRY_MASTER_CONFIGURER = 0x5AE21c99FC5f1584D8Cb09a298CFFd92B5d178eF;

    ManageLeaf[] internal leafs;
    bytes32[][] internal manageTree;

    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 26079000);

        _overrideDecoder(address(new FullOndoDecoderAndSanitizer()));

        ManageLeaf[] memory leafs_ = new ManageLeaf[](8);
        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = getERC20(sourceChain, "USDC");
        _addOndoUSDYInstantManagerLeafs(leafs_, tokens);

        manageTree = _generateMerkleTree(leafs_);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        for (uint256 i; i < leafs_.length; i++) {
            leafs.push(leafs_[i]);
        }
    }

    function _registerVault() internal {
        address[] memory users = new address[](1);
        users[0] = address(boringVault);
        vm.prank(ONDO_ID_REGISTRY_MASTER_CONFIGURER);
        IOndoIDRegistry(ONDO_ID_REGISTRY).setUserID(getAddress(sourceChain, "USDY"), users, keccak256("veda-boring-vault"));
    }

    function _manage(uint256 approveLeaf, address approveTarget, uint256 actionLeaf, bytes memory actionData) internal {
        Tx memory tx_ = _getTxArrays(2);
        tx_.manageLeafs[0] = leafs[approveLeaf];
        tx_.manageLeafs[1] = leafs[actionLeaf];
        bytes32[][] memory proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        address instantManager = getAddress(sourceChain, "usdyInstantManager");
        tx_.targets[0] = approveTarget;
        tx_.targets[1] = instantManager;
        tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", instantManager, type(uint256).max);
        tx_.targetData[1] = actionData;
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(proofs, tx_);
    }

    function testSubscribeAndRedeemUSDY() external {
        _setUpMainnet();
        _registerVault();

        ERC20 usdc = getERC20(sourceChain, "USDC");
        ERC20 usdy = getERC20(sourceChain, "USDY");
        deal(address(usdc), address(boringVault), 10_000e6);

        _manage(
            2,
            address(usdc),
            3,
            abi.encodeWithSignature("subscribe(address,uint256,uint256)", address(usdc), 10_000e6, 0)
        );

        uint256 usdyBal = usdy.balanceOf(address(boringVault));
        assertGt(usdyBal, 0);
        assertEq(usdc.balanceOf(address(boringVault)), 0);

        _manage(
            0,
            address(usdy),
            5,
            abi.encodeWithSignature("redeem(uint256,address,uint256)", usdyBal, address(usdc), 0)
        );

        assertEq(usdy.balanceOf(address(boringVault)), 0);
        assertApproxEqRel(usdc.balanceOf(address(boringVault)), 10_000e6, 0.01e18);
    }

    function testSubscribeAndRedeemRebasingUSDY() external {
        _setUpMainnet();
        _registerVault();

        ERC20 usdc = getERC20(sourceChain, "USDC");
        ERC20 rusdy = getERC20(sourceChain, "rUSDY");
        deal(address(usdc), address(boringVault), 10_000e6);

        _manage(
            2,
            address(usdc),
            4,
            abi.encodeWithSignature("subscribeRebasingUSDY(address,uint256,uint256)", address(usdc), 10_000e6, 0)
        );

        uint256 rusdyBal = rusdy.balanceOf(address(boringVault));
        assertGt(rusdyBal, 0);
        assertEq(usdc.balanceOf(address(boringVault)), 0);

        _manage(
            1,
            address(rusdy),
            6,
            abi.encodeWithSignature("redeemRebasingUSDY(uint256,address,uint256)", rusdyBal, address(usdc), 0)
        );

        assertLt(rusdy.balanceOf(address(boringVault)), 1e12);
        assertApproxEqRel(usdc.balanceOf(address(boringVault)), 10_000e6, 0.01e18);
    }

    function testSubscribeRevertsWhenVaultNotRegistered() external {
        _setUpMainnet();

        ERC20 usdc = getERC20(sourceChain, "USDC");
        deal(address(usdc), address(boringVault), 10_000e6);

        vm.expectRevert(bytes4(keccak256("UserNotRegistered()")));
        _manage(
            2,
            address(usdc),
            3,
            abi.encodeWithSignature("subscribe(address,uint256,uint256)", address(usdc), 10_000e6, 0)
        );
    }

    function testSubscribeWithUnapprovedTokenFails() external {
        _setUpMainnet();
        _registerVault();

        address usdt = getAddress(sourceChain, "USDT");
        bytes memory data = abi.encodeWithSignature("subscribe(address,uint256,uint256)", usdt, 10_000e6, 0);

        Tx memory tx_ = _getTxArrays(1);
        tx_.manageLeafs[0] = leafs[3];
        bytes32[][] memory proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        tx_.targets[0] = getAddress(sourceChain, "usdyInstantManager");
        tx_.targetData[0] = data;
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
                tx_.targets[0],
                data,
                0
            )
        );
        _submitManagerCall(proofs, tx_);
    }
}
