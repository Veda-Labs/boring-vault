// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {
    ManagerWithMerkleVerification
} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    EthereumUsdStrategyDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EthereumUsdStrategyDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {
    RolesAuthority,
    Authority
} from "@solmate/auth/authorities/RolesAuthority.sol";
import {
    MerkleTreeHelper
} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {
    MorphoFlashLoanAdapter
} from "src/base/Roles/MorphoFlashLoan/MorphoFlashLoanAdapter.sol";

import {
    Test,
    stdStorage,
    StdStorage,
    stdError,
    console
} from "@forge-std/Test.sol";

contract MorphoFlashLoanIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;
    MorphoFlashLoanAdapter public flashLoanAdapter;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    function setUp() external {
        setSourceChainName("mainnet");
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19826676;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(
            address(this),
            address(boringVault),
            getAddress(sourceChain, "vault")
        );

        rawDataDecoderAndSanitizer = address(
            new EthereumUsdStrategyDecoderAndSanitizer(
                getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
                getAddress(sourceChain, "odosRouterV2"),
                getAddress(sourceChain, "magpieRouterV3")
            )
        );

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(
            false,
            sourceChain,
            "rawDataDecoderAndSanitizer",
            rawDataDecoderAndSanitizer
        );
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        flashLoanAdapter = new MorphoFlashLoanAdapter(
            getAddress(sourceChain, "morphoBlue"),
            getAddress(sourceChain, "boringVault"),
            getAddress(sourceChain, "manager")
        );

        setAddress(
            false,
            sourceChain,
            "morphoBlueFlashLoanAdapterAddress",
            address(flashLoanAdapter)
        );

        rolesAuthority = new RolesAuthority(
            address(this),
            Authority(address(0))
        );
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(
                keccak256(abi.encodePacked("manage(address,bytes,uint256)"))
            ),
            true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(
                keccak256(
                    abi.encodePacked("manage(address[],bytes[],uint256[])")
                )
            ),
            true
        );

        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification
                .manageVaultWithMerkleVerification
                .selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MANGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification
                .manageVaultWithMerkleVerification
                .selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE,
            address(manager),
            ManagerWithMerkleVerification.setManageRoot.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE,
            address(manager),
            ManagerWithMerkleVerification.flashLoan.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE,
            address(manager),
            ManagerWithMerkleVerification.receiveFlashLoan.selector,
            true
        );

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(
            address(manager),
            MANGER_INTERNAL_ROLE,
            true
        );
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(
            address(boringVault),
            BORING_VAULT_ROLE,
            true
        );
        rolesAuthority.setUserRole(
            getAddress(sourceChain, "vault"),
            BALANCER_VAULT_ROLE,
            true
        );

        rolesAuthority.setUserRole(
            address(flashLoanAdapter),
            MANAGER_ROLE,
            true
        );
        rolesAuthority.setUserRole(
            address(flashLoanAdapter),
            STRATEGIST_ROLE,
            true
        );
    }

    /// @dev run ` MAINNET_RPC_URL=$MAINNET_RPC_URL forge test --mp test/integrations/MorphoFlashLoanIntegration.t.sol -vvvvv`
    function test__MorphoFlashLoanAdapterTest() external {
        uint256 flashLoanAmount = 100_000e6;

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addMorphoBlueFlashLoanLeafs(leafs, getAddress(sourceChain, "USDC"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(
            address(this),
            manageTree[manageTree.length - 1][0]
        );
        manager.setManageRoot(
            address(flashLoanAdapter),
            manageTree[manageTree.length - 1][0]
        );

        bytes memory userData;
        {
            bytes32[][] memory emptyProofs = new bytes32[][](0);
            address[] memory emptyDecoders = new address[](0);
            address[] memory emptyTargets = new address[](0);
            bytes[] memory emptyData = new bytes[](0);
            uint256[] memory emptyValues = new uint256[](0);

            userData = abi.encode(
                getAddress(sourceChain, "USDC"),
                emptyProofs,
                emptyDecoders,
                emptyTargets,
                emptyData,
                emptyValues
            );
        }

        {
            ManageLeaf[] memory outerLeafs = new ManageLeaf[](1);
            outerLeafs[0] = ManageLeaf(
                address(flashLoanAdapter),
                false,
                "morphoFlashLoan(address,uint256,bytes)",
                new address[](1),
                "Initiate morphoBlueFlashLoan USDC",
                rawDataDecoderAndSanitizer
            );
            outerLeafs[0].argumentAddresses[0] = getAddress(
                sourceChain,
                "USDC"
            );

            address[] memory targets = new address[](1);
            targets[0] = address(flashLoanAdapter);

            bytes[] memory targetData = new bytes[](1);
            targetData[0] = abi.encodeWithSignature(
                "morphoFlashLoan(address,uint256,bytes)",
                getAddress(sourceChain, "USDC"),
                flashLoanAmount,
                userData
            );

            uint256[] memory values = new uint256[](1);
            address[] memory decodersAndSanitizers = new address[](1);
            decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

            bytes32[][] memory manageProofs = _getProofsUsingTree(
                outerLeafs,
                manageTree
            );

            uint256 vaultUsdcBefore = ERC20(getAddress(sourceChain, "USDC"))
                .balanceOf(address(boringVault));
            uint256 morphoUsdcBefore = ERC20(getAddress(sourceChain, "USDC"))
                .balanceOf(getAddress(sourceChain, "morphoBlue"));

            manager.manageVaultWithMerkleVerification(
                manageProofs,
                decodersAndSanitizers,
                targets,
                targetData,
                values
            );

            uint256 vaultUsdcAfter = ERC20(getAddress(sourceChain, "USDC"))
                .balanceOf(address(boringVault));
            uint256 morphoUsdcAfter = ERC20(getAddress(sourceChain, "USDC"))
                .balanceOf(getAddress(sourceChain, "morphoBlue"));
            uint256 adapterUsdcAfter = ERC20(getAddress(sourceChain, "USDC"))
                .balanceOf(address(flashLoanAdapter));

            assertEq(
                vaultUsdcAfter,
                0,
                "Vault should have spent all USDC on repayment"
            );
            assertEq(
                morphoUsdcAfter,
                morphoUsdcBefore,
                "Morpho USDC balance should be unchanged"
            );
            assertEq(
                adapterUsdcAfter,
                0,
                "Adapter should hold no USDC after flash loan"
            );

            console.log("Flash loan executed successfully");
            console.log("Vault USDC before:", vaultUsdcBefore);
            console.log("Vault USDC after:", vaultUsdcAfter);
            console.log(
                "Morpho USDC delta:",
                morphoUsdcAfter - morphoUsdcBefore
            );
        }
    }

    function test__MorphoFlashLoanAdapter__RevertsOnNestedFlashLoan() external {
        uint256 outerAmount = 100_000e6;
        uint256 innerAmount = 1e6;

        address usdc = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addMorphoBlueFlashLoanLeafs(leafs, usdc);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(
            address(this),
            manageTree[manageTree.length - 1][0]
        );
        manager.setManageRoot(
            address(flashLoanAdapter),
            manageTree[manageTree.length - 1][0]
        );

        (
            bytes32[][] memory outerProofs,
            address[] memory outerDecoders,
            address[] memory outerTargets,
            bytes[] memory outerTargetData,
            uint256[] memory outerValues
        ) = _buildNestedFlashLoanPayload(usdc, manageTree);

        vm.expectRevert(
            MorphoFlashLoanAdapter
                .MorphoFlashLoanAdapter__FlashLoanAlreadyInProgress
                .selector
        );
        manager.manageVaultWithMerkleVerification(
            outerProofs,
            outerDecoders,
            outerTargets,
            outerTargetData,
            outerValues
        );
    }

    function test__MorphoFlashLoanAdapter__EmergencyRescueTokens() external {
        address usdc = getAddress(sourceChain, "USDC");
        uint256 rescueAmount = 5_000e6;

        deal(usdc, address(flashLoanAdapter), rescueAmount);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addMorphoBlueFlashLoanLeafs(leafs, getAddress(sourceChain, "USDC"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(
            address(this),
            manageTree[manageTree.length - 1][0]
        );

        address[] memory targets = new address[](1);
        targets[0] = address(flashLoanAdapter);

        address[] memory assets = new address[](1);
        assets[0] = usdc;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = rescueAmount;

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature(
            "emergencyRescueTokens(address[],uint256[])",
            assets,
            amounts
        );

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = ManageLeaf(
            address(flashLoanAdapter),
            false,
            "emergencyRescueTokens(address[],uint256[])",
            new address[](1),
            "Initiate morphoBlueFlashLoan USDC",
            rawDataDecoderAndSanitizer
        );
        manageLeafs[0].argumentAddresses[0] = getAddress(sourceChain, "USDC");

        bytes32[][] memory manageProofs = _getProofsUsingTree(
            manageLeafs,
            manageTree
        );

        uint256 vaultUsdcBefore = ERC20(usdc).balanceOf(address(boringVault));
        uint256 adapterUsdcBefore = ERC20(usdc).balanceOf(
            address(flashLoanAdapter)
        );

        manager.manageVaultWithMerkleVerification(
            manageProofs,
            decodersAndSanitizers,
            targets,
            targetData,
            new uint256[](1)
        );

        uint256 vaultUsdcAfter = ERC20(usdc).balanceOf(address(boringVault));
        uint256 adapterUsdcAfter = ERC20(usdc).balanceOf(
            address(flashLoanAdapter)
        );

        assertEq(
            adapterUsdcBefore,
            rescueAmount,
            "Adapter should start with rescue amount"
        );
        assertEq(
            adapterUsdcAfter,
            0,
            "Adapter should transfer rescued USDC out"
        );
        assertEq(
            vaultUsdcAfter,
            vaultUsdcBefore + rescueAmount,
            "Vault should receive rescued USDC"
        );
    }

    function test__MorphoFlashLoanAdapter__EmergencyRescueTokensRevertsOnlyVault()
        external
    {
        address[] memory assets = new address[](1);
        assets[0] = getAddress(sourceChain, "USDC");
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e6;

        vm.expectRevert(
            MorphoFlashLoanAdapter.MorphoFlashLoanAdapter__OnlyVault.selector
        );
        flashLoanAdapter.emergencyRescueTokens(assets, amounts);
    }

    function test__MorphoFlashLoanAdapter__EmergencyRescueTokensRevertsInvalidLengths()
        external
    {
        address[] memory assets = new address[](1);
        assets[0] = getAddress(sourceChain, "USDC");
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1e6;
        amounts[1] = 1e6;

        vm.prank(address(boringVault));
        vm.expectRevert(
            MorphoFlashLoanAdapter
                .MorphoFlashLoanAdapter__InvalidLengths
                .selector
        );
        flashLoanAdapter.emergencyRescueTokens(assets, amounts);
    }

    function _buildNestedFlashLoanPayload(
        address token,
        bytes32[][] memory manageTree
    )
        internal
        view
        returns (
            bytes32[][] memory outerProofs,
            address[] memory outerDecoders,
            address[] memory outerTargets,
            bytes[] memory outerTargetData,
            uint256[] memory outerValues
        )
    {
        bytes memory userData = _buildInnerFlashLoanUserData(token, manageTree);

        ManageLeaf[] memory outerLeafs = new ManageLeaf[](1);
        outerLeafs[0] = ManageLeaf(
            address(flashLoanAdapter),
            false,
            "morphoFlashLoan(address,uint256,bytes)",
            new address[](1),
            "Initiate morphoBlueFlashLoan USDC",
            rawDataDecoderAndSanitizer
        );
        outerLeafs[0].argumentAddresses[0] = token;

        outerProofs = _getProofsUsingTree(outerLeafs, manageTree);
        outerTargets = new address[](1);
        outerTargets[0] = address(flashLoanAdapter);
        outerTargetData = new bytes[](1);
        outerTargetData[0] = abi.encodeWithSignature(
            "morphoFlashLoan(address,uint256,bytes)",
            token,
            uint256(100_000e6),
            userData
        );
        outerDecoders = new address[](1);
        outerDecoders[0] = rawDataDecoderAndSanitizer;
        outerValues = new uint256[](1);
    }

    function _buildInnerFlashLoanUserData(
        address token,
        bytes32[][] memory manageTree
    ) internal view returns (bytes memory) {
        ManageLeaf[] memory innerLeafs = new ManageLeaf[](1);
        innerLeafs[0] = ManageLeaf(
            address(flashLoanAdapter),
            false,
            "morphoFlashLoan(address,uint256,bytes)",
            new address[](1),
            "Initiate morphoBlueFlashLoan USDC",
            rawDataDecoderAndSanitizer
        );
        innerLeafs[0].argumentAddresses[0] = token;

        bytes32[][] memory innerProofs = _getProofsUsingTree(
            innerLeafs,
            manageTree
        );
        address[] memory innerTargets = new address[](1);
        innerTargets[0] = address(flashLoanAdapter);
        bytes[] memory innerTargetData = new bytes[](1);
        innerTargetData[0] = abi.encodeWithSignature(
            "morphoFlashLoan(address,uint256,bytes)",
            token,
            uint256(1e6),
            _emptyUserData(token)
        );
        address[] memory innerDecoders = new address[](1);
        innerDecoders[0] = rawDataDecoderAndSanitizer;

        return
            abi.encode(
                token,
                innerProofs,
                innerDecoders,
                innerTargets,
                innerTargetData,
                new uint256[](1)
            );
    }

    function _emptyUserData(
        address token
    ) internal pure returns (bytes memory) {
        bytes32[][] memory emptyProofs = new bytes32[][](0);
        address[] memory emptyDecoders = new address[](0);
        address[] memory emptyTargets = new address[](0);
        bytes[] memory emptyData = new bytes[](0);
        uint256[] memory emptyValues = new uint256[](0);
        return
            abi.encode(
                token,
                emptyProofs,
                emptyDecoders,
                emptyTargets,
                emptyData,
                emptyValues
            );
    }

    function _startFork(
        string memory rpcKey,
        uint256 blockNumber
    ) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
