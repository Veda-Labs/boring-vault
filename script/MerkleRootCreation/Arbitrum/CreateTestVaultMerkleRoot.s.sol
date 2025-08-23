// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

contract CreateTestVaultMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    uint256 public privateKeyOwner;
    uint256 public privateKeyMorphoAgent;

    address public accountantAddress = 0xd0E254df4387B9aD31a59eFBBf66db9f809BD91E;
    address public boringVault = 0x7135CA5F74BC85a65EA1705C9461fF1A24e7F1b9;
    address public managerAddress = 0x940fA048ee64e5845e8c2F320146A926AA0a8F43;
    address public rawDataDecoderAndSanitizer01 = 0x79A5a9788E643d48F680Ac1838E4ADED83AFa7a4;

    function setUp() external {
        setSourceChainName(arbitrum);
        vm.createSelectFork(sourceChain);
    }

    function run() external {
        _generateTestVaultArbitrumMerkleRoot();
    }

    function _generateTestVaultArbitrumMerkleRoot() public {
        setAddress(true, arbitrum, "boringVault", boringVault);
        setAddress(true, arbitrum, "managerAddress", managerAddress);
        setAddress(true, arbitrum, "accountantAddress", accountantAddress);
        setAddress(true, arbitrum, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer01);

        ManageLeaf[] memory leafs = new ManageLeaf[](1024);
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = getERC20(sourceChain, "USDC");
        ERC20[] memory feeTokens = new ERC20[](1);
        feeTokens[0] = getERC20(sourceChain, "WETH");
        _addCcipBridgeLeafs(leafs, ccipArbitrumChainSelector, bridgeAssets, feeTokens);
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDC"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));

        _addArbitrumHyperliquidBridge2Leafs(leafs);

        // 1inch assets;
        address[] memory oneInchAssets = new address[](2);
        oneInchAssets[0] = getAddress(sourceChain, "USDC");
        oneInchAssets[1] = getAddress(sourceChain, "USDS");
        SwapKind[] memory kind = new SwapKind[](2);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, oneInchAssets, kind);
        _addOdosSwapLeafs(leafs, oneInchAssets, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Arbitrum/TestVaultArbitrumStrategyLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(managerAddress);
        vm.startBroadcast(vm.envUint("BORING_OWNER"));
        manager.setManageRoot(managerAddress, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(0x0307AD25281C99F22A8F3Af9e272fE3968810239, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(vm.addr(vm.envUint("BORING_MORPHO_AGENT")), manageTree[manageTree.length - 1][0]);
        vm.stopBroadcast();
    }
}
