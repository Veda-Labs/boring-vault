// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";

import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import {
    BaseStablecoinStrategyDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/BaseStablecoinStrategyDecoderAndSanitizer.sol";
import "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

contract CreateAeroUsdcMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    uint256 public privateKeyOwner;
    uint256 public privateKeyMorphoAgent;

    uint8 public MANAGER_INTERNAL_ROLE = 4;

    address public accountantAddress = 0x69Bd4D1Fd3B0D832A8FfE9f51e49Ffb2923285a9;
    address public boringVault = 0x4A0768ad836E787391f85bBaA110DF64D35C64d9;

    address public syusd_vault = 0x279CAD277447965AF3d24a78197aad1B02a2c589;

    address public syusd_withdraw_queue = 0xF632c10b19f2a0451cD4A653fC9ca0c15eA1040b;
    address public managerAddress = 0x6a5e31602E531307FA7a75900B7feB43F5E1d763;
    address public rawDataDecoderAndSanitizer;

    RolesAuthority public rolesAuthority = RolesAuthority(0x64d1aF305631c4D3c1BbC74C1f7600c2C33A6Fe6);
    address public syusd_teller = 0xaefc11908fF97c335D16bdf9F2Bf720817423825;
    bytes32 cbBtc_market_id = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;

    address public user1 = 0xa86b3Bf249478488B4304B50726c7D4689aD6320;
    address public user2 = 0x0307AD25281C99F22A8F3Af9e272fE3968810239;

    function setUp() external {
        setSourceChainName(base);
        vm.createSelectFork(sourceChain);
    }

    function run() external {
        _generateSyUsdMultiChainMerkleRoot();
    }

    function _generateSyUsdMultiChainMerkleRoot() public {
        rawDataDecoderAndSanitizer = address(0xcE81e05962be48f8B692D11a62F33Bf9318E2A77);

        console.log("Address of decoder and sanitizer:", rawDataDecoderAndSanitizer);

        setAddress(true, base, "boringVault", boringVault);
        setAddress(true, base, "managerAddress", managerAddress);
        setAddress(true, base, "accountantAddress", accountantAddress);
        setAddress(true, base, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "cbBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = getERC20(sourceChain, "cbBTC");
        ERC20[] memory feeTokens = new ERC20[](1);
        feeTokens[0] = getERC20(sourceChain, "WETH");
        _addCcipBridgeLeafs(leafs, ccipMainnetChainSelector, bridgeAssets, feeTokens);
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "cbBTC"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDC"));

        // 1inch assets;
        address[] memory oneInchAssets = new address[](2);
        oneInchAssets[0] = getAddress(sourceChain, "USDC");
        oneInchAssets[1] = getAddress(sourceChain, "cbBTC");
        SwapKind[] memory kind = new SwapKind[](2);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, oneInchAssets, kind);
        _addOdosSwapLeafs(leafs, oneInchAssets, kind);
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "YearnOgUsdc")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "JUNIOR TRANCHE Tranche USD Coin")));

        ERC20[] memory assets = new ERC20[](1);
        assets[0] = ERC20(getAddress(sourceChain, "USDC"));
        _addTellerLeafs(leafs, address(syusd_teller), assets, false, true);

        _addMorphoBlueCollateralLeafs(leafs, cbBtc_market_id);
        _addMorphoBlueSupplyLeafs(leafs, cbBtc_market_id);

        _addWithdrawQueueLeafs(leafs, syusd_qithdraw_queue, syusd_vault, assets);
        _addSelfSolveLeafs(leafs, assets, syusd_qithdraw_queue, boringVault, syusd_teller);

        _addMagpieSwapLeafs(leafs, oneInchAssets, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Base/BTCCarryStrategyLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(managerAddress);
        vm.startBroadcast(vm.envUint("PK"));

        if (!rolesAuthority.doesRoleHaveCapability(
                MANAGER_INTERNAL_ROLE,
                address(manager),
                ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector
            )) {
            rolesAuthority.setRoleCapability(
                MANAGER_INTERNAL_ROLE,
                address(manager),
                ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
                true
            );
        }
        rolesAuthority.setUserRole(user1, MANAGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(user2, MANAGER_INTERNAL_ROLE, true);

        manager.setManageRoot(managerAddress, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(user1, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(user2, manageTree[manageTree.length - 1][0]);
        vm.stopBroadcast();
    }
}
