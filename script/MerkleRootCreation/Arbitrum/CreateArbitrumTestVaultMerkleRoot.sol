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
    address public boringVault = 0x7135CA5F74BC85a65EA1705C9461fF1A24e7F1b9;
    address public rawDataDecoderAndSanitizer = 0xdCbC0DeF063C497aA25Eb52eB29aa96C90be0F79;
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0x940fA048ee64e5845e8c2F320146A926AA0a8F43);
    address public accountant = 0xd0E254df4387B9aD31a59eFBBf66db9f809BD91E;

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
        string memory filePath = "./leafs/Arbitrum/TestVaultArbitrumStrategyLeafs.json";
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

        // 1inch assets;
        address[] memory oneInchAssets = new address[](5);
        oneInchAssets[0] = getAddress(sourceChain, "USDC");
        oneInchAssets[1] = getAddress(sourceChain, "USDS");
        oneInchAssets[2] = getAddress(sourceChain, "USDT");
        oneInchAssets[3] = getAddress(sourceChain, "USDE");
        oneInchAssets[4] = getAddress(sourceChain, "WETH");

        SwapKind[] memory kind = new SwapKind[](5);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;
        kind[2] = SwapKind.BuyAndSell;
        kind[3] = SwapKind.BuyAndSell;
        kind[4] = SwapKind.BuyAndSell;
        _addOdosSwapLeafs(leafs, oneInchAssets, kind);

        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "WETH");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        _addUniswapV3Leafs(leafs, token0, token1, false, false);
    }
}

