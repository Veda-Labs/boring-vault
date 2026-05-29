// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Monad/CreateVmUSDMerkleRoot.s.sol --rpc-url $MONAD_RPC_URL
 */
contract CreateVmUSDMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x1C8a336051D2024E318A229d01F9F6CF96efD316;
    address public managerAddress = 0xf05bFFA1c0aeF77473B5D8A15502d52f0F41dF2B;
    address public accountantAddress = 0x98A45D90E81849a5743241d3ff765F9Fd788206a;
    address public rawDataDecoderAndSanitizer = 0x9d193c809bb5aCEdDD1eE5db377BB29bCFeDfc0D;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(monad);
        setAddress(false, monad, "boringVault", boringVault);
        setAddress(false, monad, "managerAddress", managerAddress);
        setAddress(false, monad, "accountantAddress", accountantAddress);
        setAddress(false, monad, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WMON"));

        // ========================== Steakhouse ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "steakhouseMUSDVault")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "steakhouseUSDCVault")));

        // ========================== Uniswap V4 ==========================
        {
            address[] memory hooks = new address[](1);
            address[] memory token0 = new address[](1);
            address[] memory token1 = new address[](1);

            hooks[0] = address(0);
            token0[0] = getAddress(sourceChain, "mUSD");
            token1[0] = getAddress(sourceChain, "USDC");
            _addUniswapV4Leafs(leafs, token0, token1, hooks);
        }
        {
            address[] memory hooks = new address[](1);
            address[] memory token0 = new address[](1);
            address[] memory token1 = new address[](1);

            hooks[0] = address(0);
            token0[0] = getAddress(sourceChain, "NATIVE");
            token1[0] = getAddress(sourceChain, "USDC");
            _addUniswapV4OneWaySwapLeafs(leafs, token0, token1, hooks);
        }

        // ========================== UniswapV3 ==========================
        {
            address[] memory token0 = new address[](1);
            token0[0] = getAddress(sourceChain, "WMON");

            address[] memory token1 = new address[](1);
            token1[0] = getAddress(sourceChain, "USDC");

            bool swapRouter02 = true;
            _addUniswapV3OneWaySwapLeafs(leafs, token0, token1, swapRouter02);
        }

        // ========================== CCTP ==========================
        // Bridge USDC to mainnet
        _addCCTPBridgeLeafs(leafs, cctpMainnetDomainId);

        // ========================== MPortal ==========================
        {
            ERC20 mUSD = getERC20(sourceChain, "mUSD");
            address mportalProxy = getAddress(sourceChain, "mportalProxy");

            // Recipient and refund go back to the vault (on mainnet at the same address).
            bytes32 vaultAsBytes32 = bytes32(uint256(uint160(address(boringVault))));

            // destinationToken is mUSD on mainnet — same EVM address, padded to bytes32.
            bytes32 destinationToken = bytes32(uint256(uint160(address(mUSD))));

            uint32 mainnetChainId = 1;
            _addMPortalLeafs(leafs, mportalProxy, mUSD, mainnetChainId, destinationToken, vaultAsBytes32, vaultAsBytes32);
        }

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Monad/vmUSDMerkleRoot.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
