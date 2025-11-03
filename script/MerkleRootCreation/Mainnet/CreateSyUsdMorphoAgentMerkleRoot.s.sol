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

contract CreateSyUsdMorphoAgentMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    uint256 public privateKeyOwner;
    uint256 public privateKeyMorphoAgent;

    address public accountantAddress = 0x03D9a9cE13D16C7cFCE564f41bd7E85E5cde8Da6;
    address public boringVault = 0x279CAD277447965AF3d24a78197aad1B02a2c589;
    address public managerAddress = 0x9B3e565ffC70c4b72516BC2dbec4b3c790940CE8;
    address public rawDataDecoderAndSanitizer01 = 0xedbB1308b8E213d7C76F65Ca11cF38136b8a8a83;

    function setUp() external {
        setSourceChainName(mainnet);
        vm.createSelectFork(sourceChain);
    }

    function run() external {
        _generateSyUsdMorphoAgentMerkleRoot();
    }

    function _generateSyUsdMorphoAgentMerkleRoot() public {
        setAddress(true, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer01);

        ManageLeaf[] memory leafs = new ManageLeaf[](1024);
        ERC20[] memory feeAssets = new ERC20[](3);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "USDT");
        feeAssets[2] = getERC20(sourceChain, "USDS");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        ERC20[] memory bridgeAssets = new ERC20[](2);
        bridgeAssets[0] = getERC20(sourceChain, "USDC");
        bridgeAssets[1] = getERC20(sourceChain, "USDT");
        ERC20[] memory feeTokens = new ERC20[](2);
        feeTokens[0] = getERC20(sourceChain, "WETH");
        feeTokens[1] = getERC20(sourceChain, "GHO");
        _addCcipBridgeLeafs(leafs, ccipBaseChainSelector, bridgeAssets, feeTokens);
        _addCcipBridgeLeafs(leafs, ccipArbitrumChainSelector, bridgeAssets, feeTokens);
        _addCcipBridgeLeafs(leafs, ccipBscChainSelector, bridgeAssets, feeTokens);

        _addInfiniV1Leafs(leafs, getAddress(sourceChain, "USDC"));

        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDC"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDT"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "DAI"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDS"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));

        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "syrupUSDC_USDC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "PT-syrupUSDC-28AUG2025_USDC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "PT-iUSD-4SEP2025_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "syrupUSDC_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "PT-syrupUSDC-28AUG2025_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "PT-iUSD-4SEP2025_USDC_915"));

        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_iUSD_09_04_2025"), false);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_syrupUSDC_08_28_2025"), false);

        // 1inch assets;
        address[] memory oneInchAssets = new address[](10);
        oneInchAssets[0] = getAddress(sourceChain, "USDC");
        oneInchAssets[1] = getAddress(sourceChain, "SUSDE");
        oneInchAssets[2] = getAddress(sourceChain, "USDS");
        oneInchAssets[3] = getAddress(sourceChain, "USDT");
        oneInchAssets[4] = getAddress(sourceChain, "USDE");
        oneInchAssets[5] = getAddress(sourceChain, "lvlUSD");
        oneInchAssets[6] = getAddress(sourceChain, "RLP");
        oneInchAssets[7] = getAddress(sourceChain, "USR");
        oneInchAssets[8] = getAddress(sourceChain, "wstUSR");
        oneInchAssets[9] = getAddress(sourceChain, "cUSDO");
        SwapKind[] memory kind = new SwapKind[](10);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;
        kind[2] = SwapKind.BuyAndSell;
        kind[3] = SwapKind.BuyAndSell;
        kind[4] = SwapKind.BuyAndSell;
        kind[5] = SwapKind.BuyAndSell;
        kind[6] = SwapKind.BuyAndSell;
        kind[7] = SwapKind.BuyAndSell;
        kind[8] = SwapKind.BuyAndSell;
        kind[9] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, oneInchAssets, kind);
        _addOdosSwapLeafs(leafs, oneInchAssets, kind);

        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "SUSDE");
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDE")));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(managerAddress);
        vm.startBroadcast(vm.envUint("BORING_OWNER"));
        manager.setManageRoot(managerAddress, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(vm.addr(vm.envUint("BORING_MORPHO_AGENT")), manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(0x0307AD25281C99F22A8F3Af9e272fE3968810239, manageTree[manageTree.length - 1][0]);
        vm.stopBroadcast();
    }
}
