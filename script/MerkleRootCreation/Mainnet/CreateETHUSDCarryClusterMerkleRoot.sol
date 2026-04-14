// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

contract CreateBTCUSDCarryClusterMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    uint256 public privateKeyOwner;
    uint256 public privateKeyMorphoAgent;

    //     {
    //   "Drones": {
    //     "drone-0": "0xF05BA079F8bAa6B80a60d98f0bB7bC0182EFc4c7"
    //   },
    //   "contractAddresses": {
    //     "AccountantWithRateProviders": "0x167e26B03d2e504485aa8F468A5778422BA06758",
    //     "BoringOnChainQueue": "0x5A4c0377b74da3BBF6730c7fD0fe4414ABA20e7f",
    //     "BoringVault": "0x5373690c930553648f0aaA2e53B51f0C59290B7d",
    //     "Lens": "0x3699d50C4E1c06F00F0166dad1AD2A2C4b52E6e4",
    //     "ManagerWithMerkleVerification": "0x82D80b2e4B30eC260D282d7988a72e3365f85673",
    //     "Pauser": "0x215173195823C24eE1A1dB872c9071584D5E7970",
    //     "QueueSolver": "0xe1CCa11D3f37504D077891Cd18A9D1D2077bE2e3",
    //     "RolesAuthority": "0xD5B18b7CD8264C265c748d5db6E958A6ba0477f7",
    //     "TellerWithLayerZero": "0xaEFf267F227d3E56CFe024c3D3B281faa66A2c64",
    //     "Timelock": "0x4a7902Cd8Ed95D627B9636C9c833C71f46F44a0E"
    //   }
    // }
    address public accountantAddress = 0x167e26B03d2e504485aa8F468A5778422BA06758;
    address public boringVault = 0x5373690c930553648f0aaA2e53B51f0C59290B7d;
    address public managerAddress = 0x82D80b2e4B30eC260D282d7988a72e3365f85673;
    address public rawDataDecoderAndSanitizer = 0x5c6202f606c71fd971A3f17c9bf29A071EFC8aa7;
    address public flashLoanAdapter = 0x759378c58f9611f28eaFbAf2133Cf5603FFBcD76;
    address public rolesAuthority = 0xD5B18b7CD8264C265c748d5db6E958A6ba0477f7;

    address public syUsdVault = 0x279CAD277447965AF3d24a78197aad1B02a2c589;
    address public syUsdWithdrawQueue = 0xF632c10b19f2a0451cD4A653fC9ca0c15eA1040b;
    address public syUsdTeller = 0xaefc11908fF97c335D16bdf9F2Bf720817423825;
    address public syUsdQueueSolver = 0x1d82e9bCc8F325caBBca6E6A3B287fE586536805;

    function setUp() external {
        setSourceChainName(mainnet);
        vm.createSelectFork(sourceChain);
    }

    function run() external {
        _generateMerkleRoot();
    }

    function _generateMerkleRoot() public {
        setAddress(true, mainnet, "boringVault", boringVault);
        setAddress(true, mainnet, "managerAddress", managerAddress);
        setAddress(true, mainnet, "accountantAddress", accountantAddress);
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(true, mainnet, "morphoBlueFlashLoanAdapterAddress", flashLoanAdapter);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "WETH");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = getERC20(sourceChain, "WETH");
        ERC20[] memory feeTokens = new ERC20[](1);
        feeTokens[0] = getERC20(sourceChain, "WETH");
        _addCcipBridgeLeafs(leafs, ccipBaseChainSelector, bridgeAssets, feeTokens);

        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WSTETH"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDC"));

        address[] memory swapAssets = new address[](7);
        swapAssets[0] = getAddress(sourceChain, "USDC");
        swapAssets[1] = getAddress(sourceChain, "USDS");
        swapAssets[2] = getAddress(sourceChain, "USDT");
        swapAssets[3] = getAddress(sourceChain, "USDE");
        swapAssets[4] = getAddress(sourceChain, "WETH");
        swapAssets[5] = getAddress(sourceChain, "WSTETH");
        swapAssets[6] = getAddress(sourceChain, "STETH");

        SwapKind[] memory kind = new SwapKind[](7);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;
        kind[2] = SwapKind.BuyAndSell;
        kind[3] = SwapKind.BuyAndSell;
        kind[4] = SwapKind.BuyAndSell;
        kind[5] = SwapKind.BuyAndSell;
        kind[6] = SwapKind.BuyAndSell;
        _addMagpieSwapLeafs(leafs, swapAssets, kind);

        ERC20[] memory supplyAssets = new ERC20[](2);
        supplyAssets[0] = getERC20(sourceChain, "WSTETH");
        supplyAssets[1] = getERC20(sourceChain, "WETH");
        ERC20[] memory borrowAssets = new ERC20[](5);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");
        borrowAssets[2] = getERC20(sourceChain, "USDE");
        borrowAssets[3] = getERC20(sourceChain, "USDS");
        borrowAssets[4] = getERC20(sourceChain, "GHO");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        ERC20[] memory assets = new ERC20[](1);
        assets[0] = ERC20(getAddress(sourceChain, "USDC"));
        _addTellerLeafs(leafs, address(syUsdTeller), assets, false, true);
        _addWithdrawQueueLeafs(leafs, syUsdWithdrawQueue, syUsdVault, assets);
        _addSelfSolveLeafs(leafs, assets, syUsdQueueSolver, boringVault, syUsdTeller);

        _addMorphoBlueFlashLoanLeafs(leafs, getAddress(sourceChain, "USDC"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Mainnet/ETHUSDCarryClusterStrategyLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        RolesAuthority authority = RolesAuthority(rolesAuthority);
        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(managerAddress);
        vm.startBroadcast(vm.envUint("PK"));
        manager.setManageRoot(0x0307AD25281C99F22A8F3Af9e272fE3968810239, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(flashLoanAdapter, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(vm.addr(vm.envUint("BTCUSDCarryStrategist")), manageTree[manageTree.length - 1][0]);

        // authority.setUserRole(flashLoanAdapter, 1, true);
        // authority.setUserRole(flashLoanAdapter, 7, true);
        vm.stopBroadcast();
    }
}
