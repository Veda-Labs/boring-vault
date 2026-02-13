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
 *  source .env && forge script script/MerkleRootCreation/Arbitrum/CreateSyBtcStrategyAMerkleRoot.s.sol --rpc-url $ARBITRUM_RPC_URL
 */
contract ArbitrumMerkleRootScript is Script, MerkleTreeHelper {
    uint256 public privateKey;

    //standard
    address public boringVault = 0xA923d8C976388518D65528324A587E4700f8F40f;
    address public rawDataDecoderAndSanitizer = 0xA902f4dADE492e44c455F1D8A848D835d70b4854;
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0x84Fa6EcB08c9E053C5F2E7156bc6562F62210709);
    address public accountant = 0xc80E787e1c2A3841928F69e6a35e3F12c7b38a00;

    address manager0 = 0x0307AD25281C99F22A8F3Af9e272fE3968810239;
    address manager1 = 0xa86b3Bf249478488B4304B50726c7D4689aD6320;
    address manager2 = 0x3Ad4a628b3B47A593e8d39c51d53b5C40C1b5f46;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("arbitrum");
        setSourceChainName(arbitrum);

        setAddress(true, sourceChain, "boringVault", address(boringVault));
        setAddress(true, sourceChain, "managerAddress", address(manager));
        setAddress(true, sourceChain, "manager", address(manager));
        setAddress(true, sourceChain, "accountantAddress", address(accountant));
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
    }

    function run() public {
        ManageLeaf[] memory leafs = new ManageLeaf[](1024);
        _addLeafs(leafs);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Arbitrum/SyBtcStrategyALeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        vm.startBroadcast(privateKey);
        manager.setManageRoot(manager0, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(manager1, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(manager2, manageTree[manageTree.length - 1][0]);
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
        _addTellerLeafs(leafs, 0xdE4FD4DD35F78389CDaCF111D7Ba31A31A61b2a7, depositAssets, false, false);

        _addWithdrawQueueLeafs(
            leafs, 0x2f2e71bdd62f87FCF8d19d234CA3bd903848D3a5, 0xC0D48269f8d6E427B0637F5e0695De11C8E75F6c, depositAssets
        );
    }
}
