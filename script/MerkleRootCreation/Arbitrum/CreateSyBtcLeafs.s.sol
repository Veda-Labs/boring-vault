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
 *  source .env && forge script script/MerkleRootCreation/Arbitrum/CreateSyBtcLeafs.s.sol --rpc-url $ARBITRUM_RPC_URL
 */
contract SyBtcMerkleRootScript is Script, MerkleTreeHelper {
    uint256 public privateKey;

    //standard
    address public boringVault = 0xC0D48269f8d6E427B0637F5e0695De11C8E75F6c;
    address public rawDataDecoderAndSanitizer = 0xA902f4dADE492e44c455F1D8A848D835d70b4854;
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0x0dE47e4c2A0de8833e7bC8285eecb17c296fBB8A);
    address public accountant = 0xDda6274D69F464172CC7F52194d16FF27ec0D5A6;

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
        string memory filePath = "./leafs/Arbitrum/SyBtcArbitrumStrategyLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        vm.startBroadcast(privateKey);
        manager.setManageRoot(agent1, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(agent, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(getAddress(sourceChain, "managerAddress"), manageTree[manageTree.length - 1][0]);
        vm.stopBroadcast();
    }

    function _addLeafs(ManageLeaf[] memory leafs) internal {
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDC"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDT0"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "DAI"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDS"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WBTC"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "GYD"));

        // 1inch assets;
        address[] memory oneInchAssets = new address[](7);
        oneInchAssets[0] = getAddress(sourceChain, "USDC");
        oneInchAssets[1] = getAddress(sourceChain, "USDS");
        oneInchAssets[2] = getAddress(sourceChain, "USDT0");
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
        _addMagpieSwapLeafs(leafs, oneInchAssets, kind);

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
        borrowAssets[3] = getERC20(sourceChain, "USDT0");

        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        ERC20[] memory depositAssets = new ERC20[](1);
        depositAssets[0] = getERC20(sourceChain, "WBTC");
        _addTellerLeafs(leafs, 0x779D6E59F86C9E379ccb8e7dc131bbE0c952d3a6, depositAssets, false, false);

        _addWithdrawQueueLeafs(
            leafs, 0x88eE351D6Ef93BC4F7481a5a4fd05423639C88e4, 0xA923d8C976388518D65528324A587E4700f8F40f, depositAssets
        );
    }
}
