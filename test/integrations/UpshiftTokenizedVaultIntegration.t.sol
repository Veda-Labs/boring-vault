// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {FullUpshiftTokenizedVaultDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/FullUpshiftTokenizedVaultDecoderAndSanitizer.sol";

interface IUpshiftTokenizedVault {
    function getWithdrawalEpoch()
        external
        view
        returns (uint256 year, uint256 month, uint256 day, uint256 claimableEpoch);
}

contract UpshiftTokenizedVaultIntegrationTest is BaseTestIntegration {
    address internal upshiftVault;
    ERC20 internal sentUSD;
    ERC20 internal usdc;

    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 25574942);
        _overrideDecoder(address(new FullUpshiftTokenizedVaultDecoderAndSanitizer()));

        upshiftVault = getAddress(sourceChain, "upshiftSentUSDVault");
        sentUSD = getERC20(sourceChain, "sentUSD");
        usdc = getERC20(sourceChain, "USDC");
    }

    function _depositIntoUpshift(bytes32[][] memory manageTree, ManageLeaf[] memory leafs, uint256 usdcAmount)
        internal
    {
        Tx memory tx_ = _getTxArrays(2);
        tx_.manageLeafs[0] = leafs[0]; // approve USDC
        tx_.manageLeafs[1] = leafs[2]; // deposit

        bytes32[][] memory proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = address(usdc);
        tx_.targets[1] = upshiftVault;

        tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", upshiftVault, usdcAmount);
        tx_.targetData[1] = abi.encodeWithSignature(
            "deposit(address,uint256,address)", address(usdc), usdcAmount, address(boringVault)
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(proofs, tx_);
    }

    function _getDepositTokens() internal view returns (ERC20[] memory depositTokens) {
        depositTokens = new ERC20[](1);
        depositTokens[0] = usdc;
    }

    function testUpshiftDepositAndLaggedRedeem() external {
        _setUpMainnet();

        uint256 usdcAmount = 100_000e6;
        deal(address(usdc), address(boringVault), usdcAmount);

        ManageLeaf[] memory leafs = new ManageLeaf[](8); // Six leaves padded to a power of two for the tree builder.
        _addUpshiftTokenizedVaultLeafs(leafs, upshiftVault, _getDepositTokens());

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        _depositIntoUpshift(manageTree, leafs, usdcAmount);

        uint256 shares = sentUSD.balanceOf(address(boringVault));
        assertGt(shares, 0, "BoringVault should have sentUSD after deposit");
        assertEq(usdc.balanceOf(address(boringVault)), 0, "USDC should be fully deposited");

        // Grab the cluster date the redemption request will land on (3 day lag).
        (uint256 year, uint256 month, uint256 day, uint256 claimableEpoch) =
            IUpshiftTokenizedVault(upshiftVault).getWithdrawalEpoch();

        // Approve sentUSD to the vault + request redemption of all shares.
        {
            Tx memory tx_ = _getTxArrays(2);
            tx_.manageLeafs[0] = leafs[1]; // approve sentUSD
            tx_.manageLeafs[1] = leafs[3]; // requestRedeem

            bytes32[][] memory proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

            tx_.targets[0] = address(sentUSD);
            tx_.targets[1] = upshiftVault;

            tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", upshiftVault, shares);
            tx_.targetData[1] = abi.encodeWithSignature("requestRedeem(uint256,address)", shares, address(boringVault));

            tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
            tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

            _submitManagerCall(proofs, tx_);
        }

        assertEq(sentUSD.balanceOf(address(boringVault)), 0, "sentUSD should be escrowed in the vault");

        // Warp past the claimable epoch and claim.
        vm.warp(claimableEpoch + 1);

        {
            Tx memory tx_ = _getTxArrays(1);
            tx_.manageLeafs[0] = leafs[4]; // claim

            bytes32[][] memory proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

            tx_.targets[0] = upshiftVault;
            tx_.targetData[0] =
                abi.encodeWithSignature("claim(uint256,uint256,uint256,address)", year, month, day, address(boringVault));
            tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

            _submitManagerCall(proofs, tx_);
        }

        uint256 usdcOut = usdc.balanceOf(address(boringVault));
        assertGt(usdcOut, 0, "BoringVault should have USDC after claim");
        // withdrawalFee is currently 0, so we should get back roughly the full amount.
        assertApproxEqRel(usdcOut, usdcAmount, 0.01e18, "claimed USDC should be close to deposit");
    }

    function testUpshiftDepositAndInstantRedeem() external {
        _setUpMainnet();

        uint256 usdcAmount = 100_000e6;
        deal(address(usdc), address(boringVault), usdcAmount);

        ManageLeaf[] memory leafs = new ManageLeaf[](8); // Six leaves padded to a power of two for the tree builder.
        _addUpshiftTokenizedVaultLeafs(leafs, upshiftVault, _getDepositTokens());

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        _depositIntoUpshift(manageTree, leafs, usdcAmount);

        uint256 shares = sentUSD.balanceOf(address(boringVault));
        assertGt(shares, 0, "BoringVault should have sentUSD after deposit");

        // Instant redeem burns shares directly from the caller, no LP approval needed.
        {
            Tx memory tx_ = _getTxArrays(1);
            tx_.manageLeafs[0] = leafs[5]; // instantRedeem

            bytes32[][] memory proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

            tx_.targets[0] = upshiftVault;
            tx_.targetData[0] = abi.encodeWithSignature("instantRedeem(uint256,address)", shares, address(boringVault));
            tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

            _submitManagerCall(proofs, tx_);
        }

        assertEq(sentUSD.balanceOf(address(boringVault)), 0, "sentUSD should be fully redeemed");

        uint256 usdcOut = usdc.balanceOf(address(boringVault));
        assertGt(usdcOut, 0, "BoringVault should have USDC after instant redeem");
        // 20 bps instant redemption fee currently configured.
        assertApproxEqRel(usdcOut, usdcAmount, 0.01e18, "instant redeem should return close to deposit minus fee");
    }

    function testUpshiftLeafsSupportMultipleDepositTokens() external {
        _setUpMainnet();

        ERC20 usdt = getERC20(sourceChain, "USDT");
        ERC20[] memory depositTokens = new ERC20[](2);
        depositTokens[0] = usdc;
        depositTokens[1] = usdt;

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addUpshiftTokenizedVaultLeafs(leafs, upshiftVault, depositTokens);

        assertEq(leafs[0].target, address(usdc), "first approval should target USDC");
        assertEq(leafs[1].target, address(usdt), "second approval should target USDT");
        assertEq(leafs[2].target, address(sentUSD), "LP approval should target sentUSD");
        assertEq(leafs[3].target, upshiftVault, "USDC deposit should target the Upshift vault");
        assertEq(leafs[3].argumentAddresses[0], address(usdc), "USDC deposit leaf should bind USDC");
        assertEq(leafs[4].target, upshiftVault, "USDT deposit should target the Upshift vault");
        assertEq(leafs[4].argumentAddresses[0], address(usdt), "USDT deposit leaf should bind USDT");
        assertEq(leafs[3].argumentAddresses[1], address(boringVault), "USDC receiver should be the BoringVault");
        assertEq(leafs[4].argumentAddresses[1], address(boringVault), "USDT receiver should be the BoringVault");
        assertEq(leafs[5].signature, "requestRedeem(uint256,address)");
        assertEq(leafs[6].signature, "claim(uint256,uint256,uint256,address)");
        assertEq(leafs[7].signature, "instantRedeem(uint256,address)");
    }
}
