// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { MainnetAddresses } from "test/resources/MainnetAddresses.sol";
import { BoringVault } from "src/base/BoringVault.sol";
import { ManagerWithMerkleVerification } from "src/base/Roles/ManagerWithMerkleVerification.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { ERC4626 } from "@solmate/tokens/ERC4626.sol";
import { SiloDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/SiloDecoderAndSanitizer.sol";
import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";
import { RolesAuthority, Authority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { MerkleTreeHelper } from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import { Test, stdStorage, StdStorage, stdError, console } from "@forge-std/Test.sol";

contract SiloFinanceClaimingIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

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

    function setUp() external {
        setSourceChainName("sonicMainnet");
        // Setup forked environment.
        string memory rpcKey = "SONIC_MAINNET_RPC_URL";
        uint256 blockNumber = 16_095_480;

        _startFork(rpcKey, blockNumber);

        boringVault = BoringVault(payable(0x4D85bA8c3918359c78Ed09581E5bc7578ba932ba)); //stkscUSD

        manager = ManagerWithMerkleVerification(0x5F7f5205A3E7c63c3bd287EecBe7879687D4c698);

        rawDataDecoderAndSanitizer = address(new FullSiloDecoderAndSanitizer());

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        //rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        rolesAuthority = RolesAuthority(address(boringVault.authority()));

        //boringVault.setAuthority(rolesAuthority);
        //manager.setAuthority(rolesAuthority);

        // Setup roles authority.
        //rolesAuthority.setRoleCapability(
        //    MANAGER_ROLE,
        //    address(boringVault),
        //    bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
        //    true
        //);
        //rolesAuthority.setRoleCapability(
        //    MANAGER_ROLE,
        //    address(boringVault),
        //    bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
        //    true
        //);

        //rolesAuthority.setRoleCapability(
        //    STRATEGIST_ROLE,
        //    address(manager),
        //    ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
        //    true
        //);
        //rolesAuthority.setRoleCapability(
        //    MANGER_INTERNAL_ROLE,
        //    address(manager),
        //    ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
        //    true
        //);
        //rolesAuthority.setRoleCapability(
        //    ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        //);
        //rolesAuthority.setRoleCapability(
        //    BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        //);
        //rolesAuthority.setRoleCapability(
        //    BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        //);

        //// Grant roles
        //rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        //rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        //rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        //rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        //rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        //rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);
    }

    function testSiloClaiming() external {
        address stkscUSDStrategist = 0xE89CeE9837e6Fce3b1Ebd8E1C779b76fd6E20136;

        ManageLeaf[] memory leafs = new ManageLeaf[](64);
        address[] memory incentivesControllers = new address[](2);
        incentivesControllers[0] = getAddress(sourceChain, "silo_wS_USDC_id20_USDC_IncentivesController");
        incentivesControllers[1] = address(0);
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_wS_USDC_id20_config"), incentivesControllers);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        vm.prank(boringVault.owner());
        manager.setManageRoot(stkscUSDStrategist, manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[34]; //claimRewards

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "silo_wS_USDC_id20_USDC_IncentivesController");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("claimRewards(address)", address(boringVault));

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](1);

        uint256 wSBalance = getERC20(sourceChain, "wS").balanceOf(address(0x4D85bA8c3918359c78Ed09581E5bc7578ba932ba));

        vm.prank(stkscUSDStrategist);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 wSBalanceAfter =
            getERC20(sourceChain, "wS").balanceOf(address(0x4D85bA8c3918359c78Ed09581E5bc7578ba932ba));
        uint256 siloBalance =
            getERC20(sourceChain, "SILO").balanceOf(address(0x4D85bA8c3918359c78Ed09581E5bc7578ba932ba));

        //after forfeiting claim, claim amount is 4697531591687134387860;
        assertGt(wSBalanceAfter, wSBalance);
        assertGt(siloBalance, 0);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullSiloDecoderAndSanitizer is SiloDecoderAndSanitizer { }

interface ISiloConfig {
    function getSilos() external view returns (address, address);
}
