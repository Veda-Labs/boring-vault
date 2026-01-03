// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    MerkleTreeHelper
} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {
    ManagerWithMerkleVerification
} from "src/base/Roles/ManagerWithMerkleVerification.sol";

import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import {BaseStablecoinStrategyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseStablecoinStrategyDecoderAndSanitizer.sol";
import "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

contract CreateAeroUsdcMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    uint256 public privateKeyOwner;
    uint256 public privateKeyMorphoAgent;

    uint8 public MANAGER_INTERNAL_ROLE = 4;

    address public accountantAddress =
        0x49C1df396FfeD48d821A425beFc1C021Af0D43fE;
    address public boringVault = 0x8645756d4DF86Ff81419Bd50B936774452bbF313;
    address public managerAddress = 0x540511A761Aaa6E009748e3eD77b3053ABe52280;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority = RolesAuthority(0x24f7B70331bCeddb1bd5000b61941582cf3f15A8);
    address public teller = 0xC586C775bcc2Fa5f787Ef288B333af9Ea332BAAe;

    address public user1 = 0xa86b3Bf249478488B4304B50726c7D4689aD6320;
    address public user2 = 0x124B527d76cB8192ac59da7276f815b4529870C9;
    address public user3 = 0x0307AD25281C99F22A8F3Af9e272fE3968810239;

    function setUp() external {
        setSourceChainName(base);
        vm.createSelectFork(sourceChain);
    }

    function run() external {
        _generateSyUsdMultiChainMerkleRoot();
    }

    function _generateSyUsdMultiChainMerkleRoot() public {

        rawDataDecoderAndSanitizer = address(
            0x5F2863EeF8854171F2AC4E07A0D056CFC8e13c3E
        );

        console.log("Address of decoder and sanitizer:", rawDataDecoderAndSanitizer);

        setAddress(true, base, "boringVault", boringVault);
        setAddress(true, base, "managerAddress", managerAddress);
        setAddress(true, base, "accountantAddress", accountantAddress);
        setAddress(
            true,
            base,
            "rawDataDecoderAndSanitizer",
            rawDataDecoderAndSanitizer
        );

        ManageLeaf[] memory leafs = new ManageLeaf[](512);
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(
            leafs,
            getAddress(sourceChain, "accountantAddress"),
            feeAssets,
            false
        );

        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = getERC20(sourceChain, "USDC");
        ERC20[] memory feeTokens = new ERC20[](1);
        feeTokens[0] = getERC20(sourceChain, "WETH");
        _addCcipBridgeLeafs(
            leafs,
            ccipMainnetChainSelector,
            bridgeAssets,
            feeTokens
        );
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDC"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));

        // 1inch assets;
        address[] memory oneInchAssets = new address[](3);
        oneInchAssets[0] = getAddress(sourceChain, "USDC");
        oneInchAssets[1] = getAddress(sourceChain, "USDS");
        oneInchAssets[2] = getAddress(sourceChain, "EURC");
        SwapKind[] memory kind = new SwapKind[](3);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;
        kind[2] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, oneInchAssets, kind);
        _addOdosSwapLeafs(leafs, oneInchAssets, kind);
        _addERC4626Leafs(
            leafs,
            ERC4626(getAddress(sourceChain, "YearnOgUsdc"))
        );
        _addERC4626Leafs(
            leafs,
            ERC4626(getAddress(sourceChain, "JUNIOR TRANCHE Tranche USD Coin"))
        );

        ERC20[] memory assets = new ERC20[](1);
        assets[0] = ERC20(getAddress(sourceChain, "USDC"));
        _addTellerLeafs(leafs, address(teller), assets, false, true);

        address[] memory token0 = new address[](2);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "EURC");
        address[] memory token1 = new address[](2);
        token1[0] = getAddress(sourceChain, "USDC");
        token1[1] = getAddress(sourceChain, "USDC");
        address[] memory gauges = new address[](2);
        gauges[0] = getAddress(sourceChain, "aerodrome_Weth_Usdc_v3_1_gauge");
        gauges[1] = getAddress(sourceChain, "aerodrome_Eurc_Usdc_v3_07_gauge");
        _addVelodromeV3Leafs(
            leafs, token0, token1, getAddress(sourceChain, "aerodromeNonFungiblePositionManager"), gauges
        );

        _addMagpieSwapLeafs(leafs, oneInchAssets, kind);


        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Base/AeroUsdStrategyLeafs.json";
        _generateLeafs(
            filePath,
            leafs,
            manageTree[manageTree.length - 1][0],
            manageTree
        );

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(
            managerAddress
        );
        vm.startBroadcast(vm.envUint("PK"));

        if (
            !rolesAuthority.doesRoleHaveCapability(
                MANAGER_INTERNAL_ROLE,
                address(manager),
                ManagerWithMerkleVerification
                    .manageVaultWithMerkleVerification
                    .selector
            )
        ) {
            rolesAuthority.setRoleCapability(
                MANAGER_INTERNAL_ROLE,
                address(manager),
                ManagerWithMerkleVerification
                    .manageVaultWithMerkleVerification
                    .selector,
                true
            );
        }
        rolesAuthority.setUserRole(user1, MANAGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(user3, MANAGER_INTERNAL_ROLE, true);

        manager.setManageRoot(
            managerAddress,
            manageTree[manageTree.length - 1][0]
        );
        manager.setManageRoot(
            user1,
            manageTree[manageTree.length - 1][0]
        );
        // manager.setManageRoot(
        //     user2,
        //     manageTree[manageTree.length - 1][0]
        // );
        manager.setManageRoot(
            user3,
            manageTree[manageTree.length - 1][0]
        );
        vm.stopBroadcast();
    }
}
