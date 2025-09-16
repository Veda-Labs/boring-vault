// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Arbitrum/CreateMultiChainLiquidEthMerkleRoot.s.sol:CreateMultiChainLiquidEthMerkleRootScript --rpc-url $ARBITRUM_RPC_URL
 */
contract ArbitrumMerkleRootScript is Script, MerkleTreeHelper {
    uint256 public privateKey;

    //standard
    address public boringVault = 0xEa96252EaBE2F2A0EA20ff42779CD985Ba596657;
    address public rawDataDecoderAndSanitizer = 0xF267699929FBe258A3aEdC76c5402f860a629496;
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0x699b31C615AEF5b7E35E3d2A05E5911f6c51C9cd);
    address public accountant = 0x63c9934E832823Be6A2b7e140877777C75eD3A99;

    //one offs
    address public camelotFullDecoderAndSanitizer = 0xe315ADA67dB9Fd97523620194ccdd727102830c7;

    //itb
    address public itbDecoderAndSanitizer = 0xEEb53299Cb894968109dfa420D69f0C97c835211;
    address public itbGearboxProtocolPositionManager = 0xad5dB17b44506785931dbc49c8857482c3b4F622;
    address agent = 0x0307AD25281C99F22A8F3Af9e272fE3968810239;
    address agent1 = 0xa86b3Bf249478488B4304B50726c7D4689aD6320;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("arbitrum");
        setSourceChainName(arbitrum);

        setAddress(true, arbitrum, "boringVault", address(boringVault));
        setAddress(true, arbitrum, "managerAddress", address(manager));
        setAddress(true, arbitrum, "manager", address(manager));
        setAddress(true, arbitrum, "accountantAddress", address(accountant));
        setAddress(true, arbitrum, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
    }

    function run() public {
        ManageLeaf[] memory leafs = new ManageLeaf[](1024);
        _addLeafs(leafs);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Arbitrum/SyEthArbitrumStrategyLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        vm.startBroadcast(privateKey);
        manager.setManageRoot(agent1, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(agent, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(getAddress(sourceChain, "managerAddress"), manageTree[manageTree.length - 1][0]);
        vm.stopBroadcast();
    }

    function _addLeafs(ManageLeaf[] memory leafs) internal {
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDC"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDT"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "DAI"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDS"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WBTC"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "GYD"));

        // 1inch assets;
        address[] memory oneInchAssets = new address[](7);
        oneInchAssets[0] = getAddress(sourceChain, "USDC");
        oneInchAssets[1] = getAddress(sourceChain, "USDS");
        oneInchAssets[2] = getAddress(sourceChain, "USDT");
        oneInchAssets[3] = getAddress(sourceChain, "USDE");
        oneInchAssets[4] = getAddress(sourceChain, "WETH");
        oneInchAssets[5] = getAddress(sourceChain, "WBTC");
        oneInchAssets[6] = getAddress(sourceChain, "GYD");

        SwapKind[] memory kind = new SwapKind[](7);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;
        kind[2] = SwapKind.BuyAndSell;
        kind[3] = SwapKind.BuyAndSell;
        kind[4] = SwapKind.BuyAndSell;
        kind[5] = SwapKind.BuyAndSell;
        kind[6] = SwapKind.BuyAndSell;
        _addOdosSwapLeafs(leafs, oneInchAssets, kind);

        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        token0[2] = getAddress(sourceChain, "WBTC");
        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "USDC");
        token1[1] = getAddress(sourceChain, "WBTC");
        token1[2] = getAddress(sourceChain, "USDC");
        _addUniswapV3Leafs(leafs, token0, token1, false, false);

        ERC20[] memory supplyAssets = new ERC20[](2);
        supplyAssets[0] = getERC20(sourceChain, "WBTC");
        supplyAssets[1] = getERC20(sourceChain, "WETH");
        ERC20[] memory borrowAssets = new ERC20[](4);
        borrowAssets[0] = getERC20(sourceChain, "WBTC");
        borrowAssets[1] = getERC20(sourceChain, "WETH");
        borrowAssets[2] = getERC20(sourceChain, "USDC");
        borrowAssets[3] = getERC20(sourceChain, "USDT");

        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);
    }
}
