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

contract CreateCsUsdcMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    uint256 public privateKeyOwner;
    uint256 public privateKeyMorphoAgent;

    address public accountantAddress = 0xDb1d385Fb08f96C573021BBeB0B144ab978Fcb23;
    address public boringVault = 0xB2b97885919e5ec4bb17a203B1B3473776436049;
    address public managerAddress = 0x35e09ed7e5B1AA61b8a9AB3caE46840aA17401EA;
    address public rawDataDecoderAndSanitizer01 = 0x0053fd970D9a18eD1C52E0ddB2F0a88CE197c611;

    function setUp() external {
        setSourceChainName(base);
        vm.createSelectFork(sourceChain);
    }

    function run() external {
        _generateMerkleRoot();
    }

    function _generateMerkleRoot() public {
        setAddress(true, base, "boringVault", boringVault);
        setAddress(true, base, "managerAddress", managerAddress);
        setAddress(true, base, "accountantAddress", accountantAddress);
        setAddress(true, base, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer01);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = getERC20(sourceChain, "USDC");
        ERC20[] memory feeTokens = new ERC20[](1);
        feeTokens[0] = getERC20(sourceChain, "WETH");
        _addCcipBridgeLeafs(leafs, ccipMainnetChainSelector, bridgeAssets, feeTokens);

        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDC"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));

        // fly.trade
        address[] memory oneInchAssets = new address[](4);
        oneInchAssets[0] = getAddress(sourceChain, "USDC");
        oneInchAssets[1] = getAddress(sourceChain, "USDS");
        oneInchAssets[2] = getAddress(sourceChain, "cbBTC");
        oneInchAssets[3] = getAddress(sourceChain, "WETH");
        SwapKind[] memory kind = new SwapKind[](4);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;
        kind[2] = SwapKind.BuyAndSell;
        kind[3] = SwapKind.BuyAndSell;
        _addMagpieSwapLeafs(leafs, oneInchAssets, kind);

        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "YearnOgUsdc")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletCbBTCcore")));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Base/CsUsdcStrategyLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(managerAddress);
        vm.startBroadcast(vm.envUint("DEPLOYER01"));
        manager.setManageRoot(managerAddress, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(0xa86b3Bf249478488B4304B50726c7D4689aD6320, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(0xB959281323D3eAeF172223C0d27115cA8f51fb7a, manageTree[manageTree.length - 1][0]);
        vm.stopBroadcast();
    }
}
