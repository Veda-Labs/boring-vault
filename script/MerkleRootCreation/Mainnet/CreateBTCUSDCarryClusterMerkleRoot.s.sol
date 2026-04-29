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

    // {
    //   "Drones": {
    //     "drone-0": "0x501F3F065b2e27B1771CE88F8e71A863bEc70C98"
    //   },
    //   "contractAddresses": {
    //     "AccountantWithRateProviders": "0xA7F084687acB40C91A61bDc2BBF383df99eB8900",
    //     "BoringOnChainQueue": "0x03DA5D36EC1c359F39C2aDAaA9602382C92E844b",
    //     "BoringVault": "0x272BCD869CbDFcb32c335dB2f1F6C54Eb1A50aCc",
    //     "Lens": "0xEA56D7FD851C77e66666E7C4472F3A90c65009AB",
    //     "ManagerWithMerkleVerification": "0xE059cDcc94E7937FC7f7EeD9daAFaAd79B066099",
    //     "Pauser": "0x8F39E27659dbf4f9276Fc884c08f535a72616946",
    //     "QueueSolver": "0xAfA08E775646E0bdc18EB726f5f16fC74DB55AB0",
    //     "RolesAuthority": "0x43A37629C8030b38fCeC2817AAbE62501E74bA88",
    //     "TellerWithLayerZero": "0xcaa435974BC9813A2c2Fe01F5fE86AE52e2DD5E1",
    //     "Timelock": "0xF84C42Da7468256fB730de3a7645bCa0dA8b9205"
    //   }
    // }

    address public accountantAddress = 0xA7F084687acB40C91A61bDc2BBF383df99eB8900;
    address public boringVault = 0x272BCD869CbDFcb32c335dB2f1F6C54Eb1A50aCc;
    address public managerAddress = 0xE059cDcc94E7937FC7f7EeD9daAFaAd79B066099;
    address public rawDataDecoderAndSanitizer = 0x5c6202f606c71fd971A3f17c9bf29A071EFC8aa7;
    address public flashLoanAdapter = 0xCf8298839F8b710B87ba9225b1a29390Fb818759;
    address public rolesAuthority = 0x43A37629C8030b38fCeC2817AAbE62501E74bA88;

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
        feeAssets[0] = getERC20(sourceChain, "cbBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        ERC20[] memory bridgeAssets = new ERC20[](2);
        bridgeAssets[0] = getERC20(sourceChain, "USDC");
        bridgeAssets[1] = getERC20(sourceChain, "USDT");
        ERC20[] memory feeTokens = new ERC20[](1);
        feeTokens[0] = getERC20(sourceChain, "WETH");
        _addCcipBridgeLeafs(leafs, ccipBaseChainSelector, bridgeAssets, feeTokens);

        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDC"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDT"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDS"));

        address[] memory swapAssets = new address[](7);
        swapAssets[0] = getAddress(sourceChain, "USDC");
        swapAssets[1] = getAddress(sourceChain, "USDS");
        swapAssets[2] = getAddress(sourceChain, "USDT");
        swapAssets[3] = getAddress(sourceChain, "USDE");
        swapAssets[4] = getAddress(sourceChain, "GHO");
        swapAssets[5] = getAddress(sourceChain, "cbBTC");
        swapAssets[6] = getAddress(sourceChain, "WBTC");

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
        supplyAssets[0] = getERC20(sourceChain, "cbBTC");
        supplyAssets[1] = getERC20(sourceChain, "WBTC");
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

        // morpho blue markets to supply
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "cbBtc_USDC_86"));

        // morpho blue markets to collateralise
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "cbBtc_USDC_86"));


        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Mainnet/BTCUSDCarryClusterStrategyLeafs.json";
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
