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
 *  source .env && forge script script/MerkleRootCreation/Arbitrum/BtcCarryStrategyMerkleRoot.s.sol --rpc-url $ARBITRUM_RPC_URL
 */
contract BtcCStrategyMerkleRootScript is Script, MerkleTreeHelper {
    uint256 public privateKey;

    //standard
    address public boringVault = 0x02B2784DC5a994a06a880b57B38b526c318c7490;
    address public rawDataDecoderAndSanitizer = 0x307803373Ac73Fb99077d363cdD4D26bf28b89ed;
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0x1E9bEF0e9f33C438aF4C29ee393857d1E92f4485);
    address public accountant = 0x83a9d9aE20C0C5b36FB211Ef32BF269B43097FEC;
    address agent = 0x0307AD25281C99F22A8F3Af9e272fE3968810239;
    address agent1 = 0xa86b3Bf249478488B4304B50726c7D4689aD6320;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
        setSourceChainName(mainnet);

        setAddress(true, mainnet, "boringVault", address(boringVault));
        setAddress(true, mainnet, "managerAddress", address(manager));
        setAddress(true, mainnet, "manager", address(manager));
        setAddress(true, mainnet, "accountantAddress", address(accountant));
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
    }

    function run() public {
        ManageLeaf[] memory leafs = new ManageLeaf[](1024);
        _addLeafs(leafs);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Mainnet/BtcCarryStrategyLeafs.json";
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

        ERC20[] memory supplyTokens = new ERC20[](2);
        supplyTokens[0] = getERC20(sourceChain, "WBTC");
        supplyTokens[1] = getERC20(sourceChain, "cbBTC");

        ERC20[] memory borrowTokens = new ERC20[](1);
        borrowTokens[0] = getERC20(sourceChain, "USDT");

        uint256 dexType = 2000;

        _addFluidDexLeafs(
            leafs, getAddress(sourceChain, "wBTC-cbBTCDex-USDT"), dexType, supplyTokens, borrowTokens, false
        );
    }
}
