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

contract CreateArbitrumSyHlpMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    uint256 public privateKeyOwner;
    uint256 public privateKeyMorphoAgent;

    address public accountantAddress = 0x98C0B9042C6142F3cBc5bed58a7BF412752737b5;
    address public boringVault = 0x592B45AeaeaaA75D58FD097a7254bA3F56125904;
    address public managerAddress = 0x7E35B3dE911C179ab9d3582CBd2c94166B9c4350;
    address public rawDataDecoderAndSanitizer01 = 0x53F0b212d28320DD0aB504AbD6871941EFf5AD45;

    function setUp() external {
        setSourceChainName(arbitrum);
        vm.createSelectFork(sourceChain);
    }

    function run() external {
        _generateSyUsdArbitrumMerkleRoot();
    }

    function _generateSyUsdArbitrumMerkleRoot() public {
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

        // 1inch assets;
        address[] memory oneInchAssets = new address[](2);
        oneInchAssets[0] = getAddress(sourceChain, "USDC");
        oneInchAssets[1] = getAddress(sourceChain, "USDS");
        SwapKind[] memory kind = new SwapKind[](2);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, oneInchAssets, kind);
        _addOdosSwapLeafs(leafs, oneInchAssets, kind);
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "YearnOgUsdc")));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Base/SyUsdBaseStrategyLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(managerAddress);
        vm.startBroadcast(vm.envUint("BORING_OWNER"));
        manager.setManageRoot(managerAddress, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(vm.addr(vm.envUint("BORING_MORPHO_AGENT")), manageTree[manageTree.length - 1][0]);
        vm.stopBroadcast();
    }
}
