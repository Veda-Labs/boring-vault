// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {LayerZeroTeller} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {SyUsdDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyUsdDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FlashloanDoSomething is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    address public rawDataDecoderAndSanitizer;
    RolesAuthority internal rolesAuthority = RolesAuthority(0xf7F3ace7f6cA2Cb1E7ccbE3Bf2Da13D001D36fdF);
    BoringVault internal boringVault = BoringVault(payable(0x279CAD277447965AF3d24a78197aad1B02a2c589));
    LayerZeroTeller internal teller = LayerZeroTeller(0xaefc11908fF97c335D16bdf9F2Bf720817423825);
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0x9B3e565ffC70c4b72516BC2dbec4b3c790940CE8);
    AccountantWithRateProviders internal accountant =
        AccountantWithRateProviders(0x03D9a9cE13D16C7cFCE564f41bd7E85E5cde8Da6);
    BoringOnChainQueue internal queue = BoringOnChainQueue(0xF632c10b19f2a0451cD4A653fC9ca0c15eA1040b);
    BoringSolver internal solver = BoringSolver(0x1d82e9bCc8F325caBBca6E6A3B287fE586536805);

    /// roles
    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    function setUp() external {
        setSourceChainName("mainnet");
        vm.createSelectFork(sourceChain);

        rawDataDecoderAndSanitizer = address(
            new SyUsdDecoderAndSanitizer(
                getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"), getAddress(sourceChain, "odosRouterV2")
            )
        );

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(accountant));

        vm.startPrank(rolesAuthority.owner());

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

        vm.stopPrank();
    }

    function testFlashDoSomething() external {
        uint256 flashloanAmount = 100_000 * 1e6; // 100k USDC

        // create ManageLeaf array for all operations
        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // balancerV2 flashloan leafs
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDC")); // 1 leaf
        // add AaveV3 Leafs
        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "SUSDE");
        ERC20[] memory borrowAssets = new ERC20[](1);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets); //  10 leafs
        _addCurveLeafs(
            leafs, getAddress(sourceChain, "Usde_Usdc_Curve_Pool"), 2, getAddress(sourceChain, "Usde_Usdc_Curve_Gauge")
        ); // 9 leafs
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDE"))); // 5 leafs

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(this),
            false,
            "approve(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USDC"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(this);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        vm.prank(manager.owner());
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        vm.prank(manager.owner());
        manager.setManageRoot(address(manager), manageTree[manageTree.length - 1][0]);

        bytes memory userData;
        {
            address[] memory targets = new address[](2);

            targets[0] = getAddress(sourceChain, "USDC");
            targets[1] = address(this);
            bytes[] memory targetData = new bytes[](2);
            targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(this), flashloanAmount);
            targetData[1] =
                abi.encodeWithSelector(ERC20.approve.selector, getAddress(sourceChain, "USDC"), flashloanAmount);

            ManageLeaf[] memory flashloanLeafs = new ManageLeaf[](2);
            flashloanLeafs[0] = ManageLeaf(
                getAddress(sourceChain, "USDC"),
                false,
                "approve(address,uint256)",
                new address[](1),
                "",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            flashloanLeafs[0].argumentAddresses[0] = address(this);

            flashloanLeafs[1] = ManageLeaf(
                address(this),
                false,
                "approve(address,uint256)",
                new address[](1),
                "",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            flashloanLeafs[1].argumentAddresses[0] = getAddress(sourceChain, "USDC");

            bytes32[][] memory flashloanManageProofs = _getProofsUsingTree(flashloanLeafs, manageTree);

            uint256[] memory values = new uint256[](2);
            address[] memory dAs = new address[](2);
            dAs[0] = rawDataDecoderAndSanitizer;
            dAs[1] = rawDataDecoderAndSanitizer;

            userData = abi.encode(flashloanManageProofs, dAs, targets, targetData, values);
        }

        {
            address[] memory targets = new address[](1);
            targets[0] = getAddress(sourceChain, "manager");

            address[] memory tokensToBorrow = new address[](1);
            tokensToBorrow[0] = getAddress(sourceChain, "USDC");
            uint256[] memory amountsToBorrow = new uint256[](1);
            amountsToBorrow[0] = flashloanAmount;
            bytes[] memory targetData = new bytes[](1);
            targetData[0] = abi.encodeWithSelector(
                BalancerVault.flashLoan.selector, address(manager), tokensToBorrow, amountsToBorrow, userData
            );

            ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
            manageLeafs[0] = leafs[0];

            bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

            uint256[] memory values = new uint256[](1);
            address[] memory decodersAndSanitizers = new address[](1);
            decodersAndSanitizers[0] = getAddress(sourceChain, "rawDataDecoderAndSanitizer");

            // vm.prank(manager.owner());
            manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        }
    }

    bool iDidSomething = false;

    function approve(ERC20 token, uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
        token.safeTransfer(msg.sender, amount);
        iDidSomething = true;
    }
}
