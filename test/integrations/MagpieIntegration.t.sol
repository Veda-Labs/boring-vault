// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, stdStorage, StdStorage, stdError, console, Vm} from "../../lib/forge-std/src/Test.sol";
import {BoringVault, Auth} from "../../src/base/BoringVault.sol";
import {LayerZeroTeller} from "../../src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {AccountantWithRateProviders} from "../../src/base/Roles/AccountantWithRateProviders.sol";
import {ManagerWithMerkleVerification} from "../../src/base/Roles/ManagerWithMerkleVerification.sol";
import {
    ChainlinkCCIPTeller,
    CrossChainTellerWithGenericBridge
} from "../../src/base/Roles/CrossChain/Bridges/CCIP/ChainlinkCCIPTeller.sol";
import {Deployer} from "../../src/helper/Deployer.sol";
import {Pauser} from "../../src/base/Roles/Pauser.sol";
import {SafeTransferLib} from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";
import {IRateProvider} from "../../src/interfaces/IRateProvider.sol";
import {RolesAuthority, Authority} from "../../lib/solmate/src/auth/authorities/RolesAuthority.sol";
import {MockLayerZeroEndPoint} from "../../src/helper/MockLayerZeroEndPoint.sol";
import {TellerWithMultiAssetSupport} from "../../src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringOnChainQueue} from "../../src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "../../src/base/Roles/BoringQueue/BoringSolver.sol";
import {GenericRateProvider} from "../../src/helper/GenericRateProvider.sol";
import {MerkleTreeHelper} from "../../test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AddressToBytes32Lib} from "../../src/helper/AddressToBytes32Lib.sol";
import {BaseDecoderAndSanitizer} from "../../src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {MagpieDecoderAndSanitizer} from "../../src/base/DecodersAndSanitizers/MagpieDecoderAndSanitizer.sol";
import {console} from "../../lib/forge-std/src/Test.sol";

contract MagpieIntegTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    using AddressToBytes32Lib for address;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    function _setUpSpecificBlock__USDCSwap() internal {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 25016617;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new FullMagpieDecoderAndSanitizer(address(boringVault), getAddress(sourceChain, "magpieDexAggregator"))
        );

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );

        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MANGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        );
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        );

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);
    }

    function testFlyTradeSwapERC20() external {
        _setUpSpecificBlock__USDCSwap();

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e18);

        address[] memory tokens = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        tokens[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        tokens[1] = getAddress(sourceChain, "WETH");
        kind[1] = SwapKind.BuyAndSell;
        tokens[2] = getAddress(sourceChain, "USDT");
        kind[2] = SwapKind.BuyAndSell;

        ERC20 token0 = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // weth
        ERC20 token1 = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // usdc

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addMagpieSwapLeafs(leafs, tokens, kind);

        // leafs[0] = ManageLeaf(
        //     address(token0),
        //     false,
        //     "approve(address,uint256)",
        //     new address[](1),
        //     string.concat("Approve Magpie Router V3 to spend ", token0.symbol()),
        //     getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        // );
        // leafs[0].argumentAddresses[0] = getAddress(sourceChain, "magpieRouterV3");

        // leafs[1] = ManageLeaf(
        //     getAddress(sourceChain, "magpieRouterV3"),
        //     false,
        //     "swapWithMagpieSignature(bytes)",
        //     new address[](3),
        //     string.concat("Swap Compact ", token0.symbol(), " for ", token1.symbol()),
        //     getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        // );
        // leafs[1].argumentAddresses[0] = getAddress(sourceChain, "WETH");
        // leafs[1].argumentAddresses[1] = getAddress(sourceChain, "USDC");
        // leafs[1].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = ManageLeaf(
            getAddress(sourceChain, "WETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        manageLeafs[0].argumentAddresses[0] = getAddress(sourceChain, "magpieDexAggregatorCore");

        manageLeafs[1] = ManageLeaf(
            getAddress(sourceChain, "magpieDexAggregator"),
            false,
            "swapWithBackendSignature(bytes)",
            new address[](3),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        manageLeafs[1].argumentAddresses[0] = getAddress(sourceChain, "WETH");
        manageLeafs[1].argumentAddresses[1] = getAddress(sourceChain, "USDC");
        manageLeafs[1].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "magpieDexAggregator");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "magpieDexAggregatorCore"), type(uint256).max
        );
        targetData[1] =
            hex"46ec278a0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000021b01f500205615deb798bb3e4dfa0139dfa1b3d433cc23b72fc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000002386f26fc10000e00114e00119e0011efde14bf73078340029ac3cd3a457f9d968152535076b4a3a4fa904fa9a87f925f00123005d837bf31e890c61145539edeee2589155df695bf2a502d7eb125827068638ed290c6a840b5d15568b6f941d5523798140c2df066dfb81ddddd2e73b4623cc521c00e06a01b058e001411a97e00164c836f001f4c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2c82386f26fc100000201250e0139013924856bc3f840f880f801001000000000000000000000000000000000000000000000000000000000000000f820f00340f80300060c0f0000000000000000000000000000000000000000000000000000000000f860f001e0f00240f00160f800f001f2f80af001200c0139013901014903014d03014f03015103015303015103017403017603014d03014f03017903017b03017903019c03019e0301a10301a40301740301a70200700301a90301ac0301a70301510e013901390301a70301ae0301a703014d0301a70e0139013903014d0200700301a766a9893cc07d91d95644aedd05d03f95e1dba8af0200700705000005000001410149000000000001b10220022006002001ef01f200000300000234023b00000000000000";

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullMagpieDecoderAndSanitizer is MagpieDecoderAndSanitizer {
    constructor(address _boringVault, address _magpieRouter) MagpieDecoderAndSanitizer(_magpieRouter) {}
}
