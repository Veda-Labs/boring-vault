// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 * @title Deploy LBTC Replacement Contracts
 * @notice Deploys new Accountant, Teller, and BoringQueue contracts for vaults using LBTC as base asset
 * @dev Outputs a JSON file with role configurations that can be used with Boring Bureaucracy
 * 
 * Usage:
 * source .env && forge script script/DeployLBTCReplacementContracts.s.sol:DeployLBTCReplacementContracts --broadcast --verify
 */
contract DeployLBTCReplacementContracts is Script, Test {
    using stdJson for string;

    // Deployment configuration struct
    struct VaultConfig {
        string productName;
        address boringVault;
        address existingAccountant;
        address existingTeller;
        address existingQueue;
        address existingQueueSolver;
        address rolesAuthority;
        address payoutAddress;
        address newBaseAsset; 
        address lbtcAddress; 
        address lbtcRateProvider; // Rate provider for yield-bearing LBTC
        uint96 startingExchangeRate;
        uint16 allowedExchangeRateChangeUpper;
        uint16 allowedExchangeRateChangeLower;
        uint24 minimumUpdateDelayInSeconds;
        uint16 platformFee;
        uint16 performanceFee;
        bool allowPublicDeposits;
        uint256 shareLockPeriod;
        bool allowPublicWithdrawals;
        bool excessToSolverNonSelfSolve;
    }

    // Role IDs (you'll need to provide these)
    uint8 constant MINTER_ROLE = 2;
    uint8 constant BURNER_ROLE = 3;
    uint8 constant PAUSER_ROLE = 5;
    uint8 constant OWNER_ROLE = 8;
    uint8 constant MULTISIG_ROLE = 9;
    uint8 constant STRATEGIST_MULTISIG_ROLE = 10;
    uint8 constant UPDATE_EXCHANGE_RATE_ROLE = 11;
    uint8 constant SOLVER_ROLE = 12;
    uint8 constant CAN_SOLVE_ROLE = 31;
    uint8 constant ONLY_QUEUE_ROLE = 32;
    uint8 constant SOLVER_ORIGIN_ROLE = 33;

    // Contract deployer
    Deployer public deployer;
    
    // Private key for deployment
    uint256 public privateKey;

    // Network configuration
    uint256 public networkId;
    uint256 public nonce = 6; // REPLACE

    // JSON output
    string outputJson;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        // Set network ID based on chain
        if (block.chainid == 1) {
            networkId = 1; // Mainnet
        } else if (block.chainid == 42161) {
            networkId = 42161; // Arbitrum
        } else {
            revert("Unsupported network");
        }
    }

    function run() external {
        // Initialize JSON structure
        outputJson = "root";
        outputJson.serialize("network_id", networkId);
        outputJson.serialize("nonce", nonce);

        // Array to store all actions
        string memory actionsArray = "";

        // Example configuration - you'll need to fill this with actual values
        VaultConfig[] memory vaults = new VaultConfig[](1);
        
        // Example: TAC LBTC Vault configuration
        vaults[0] = VaultConfig({
            productName: "tac_lbtc",
            boringVault: address(0), // Fill with actual address
            existingAccountant: address(0), // Fill with actual address
            existingTeller: address(0), // Fill with actual address
            existingQueue: address(0), // Fill with actual address
            existingQueueSolver: address(0), // Fill with actual address
            rolesAuthority: address(0), // Fill with actual address
            payoutAddress: address(0), // Fill with actual address
            newBaseAsset: address(0), // Fill with actual WBTC address
            lbtcAddress: address(0), // Fill with actual LBTC address
            lbtcRateProvider: address(0), // Fill with rate provider for yield-bearing LBTC
            startingExchangeRate: 100000000, // Example for BTC-based vault
            allowedExchangeRateChangeUpper: 10100,
            allowedExchangeRateChangeLower: 9900,
            minimumUpdateDelayInSeconds: 21600,
            platformFee: 150,
            performanceFee: 0,
            allowPublicDeposits: true,
            shareLockPeriod: 86400,
            allowPublicWithdrawals: true,
            excessToSolverNonSelfSolve: false
        });

        vm.startBroadcast(privateKey);

        // Deploy contracts for each vault
        for (uint256 i = 0; i < vaults.length; i++) {
            actionsArray = deployAndConfigureVault(vaults[i], actionsArray, i);
        }

        vm.stopBroadcast();

        // Finalize JSON output
        outputJson = outputJson.serialize("actions", actionsArray);
        
        // Write to file
        string memory filename = string.concat("deployments/role_updates/lbtc_replacement_", vm.toString(block.timestamp), ".json");
        vm.writeJson(outputJson, filename);
        
        console.log("Deployment complete. JSON output written to:", filename);
    }

    function deployAndConfigureVault(
        VaultConfig memory config,
        string memory actionsArray,
        uint256 index
    ) internal returns (string memory) {
        console.log("Deploying contracts for:", config.productName);

        // Deploy new Accountant with WBTC as base asset
        AccountantWithRateProviders newAccountant = new AccountantWithRateProviders(
            address(0), // Owner will be set to address(0) after configuration
            config.boringVault,
            config.payoutAddress,
            config.startingExchangeRate,
            config.newBaseAsset, // WBTC as new base asset
            config.allowedExchangeRateChangeUpper,
            config.allowedExchangeRateChangeLower,
            config.minimumUpdateDelayInSeconds,
            config.platformFee,
            config.performanceFee
        );

        // Deploy new Teller
        TellerWithMultiAssetSupport newTeller = new TellerWithMultiAssetSupport(
            address(0), // Owner will be set to address(0) after configuration
            config.boringVault,
            address(newAccountant),
            config.newBaseAsset // Native wrapper (WBTC for BTC vaults)
        );

        // Deploy new BoringOnChainQueue
        BoringOnChainQueue newQueue = new BoringOnChainQueue(
            address(0), // Owner will be set to address(0) after configuration
            config.rolesAuthority,
            payable(config.boringVault),
            address(newAccountant)
        );

        // Deploy new BoringSolver
        BoringSolver newSolver = new BoringSolver(
            address(0), // Owner will be set to address(0) after configuration
            config.rolesAuthority,
            address(newQueue),
            config.excessToSolverNonSelfSolve
        );

        // Configure LBTC as yield-bearing asset in accountant
        newAccountant.setRateProviderData(
            ERC20(config.lbtcAddress),
            false, // Not pegged to base
            config.lbtcRateProvider
        );

        // Set authorities
        newAccountant.setAuthority(RolesAuthority(config.rolesAuthority));
        newTeller.setAuthority(RolesAuthority(config.rolesAuthority));
        newQueue.setAuthority(RolesAuthority(config.rolesAuthority));
        newSolver.setAuthority(RolesAuthority(config.rolesAuthority));

        // Transfer ownership to address(0)
        newAccountant.transferOwnership(address(0));
        newTeller.transferOwnership(address(0));
        newQueue.transferOwnership(address(0));
        newSolver.transferOwnership(address(0));

        // Build role configuration JSON
        string memory actionObj = "";
        actionObj = actionObj.serialize("product", config.productName);
        
        string memory rolesArray = "";
        uint256 roleIndex = 0;

        // Disable roles on old contracts
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setUserRole", config.existingTeller, MINTER_ROLE, false, "");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setUserRole", config.existingTeller, BURNER_ROLE, false, "");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setRoleCapability", config.existingQueueSolver, ONLY_QUEUE_ROLE, false, "boringSolve(address,address,address,uint256,uint256,bytes)");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setUserRole", config.existingQueueSolver, CAN_SOLVE_ROLE, false, "");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setUserRole", config.existingQueueSolver, SOLVER_ROLE, false, "");

        // Disable public capabilities on old queue
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setPublicCapability", config.existingQueue, 0, false, "requestOnChainWithdraw(address,uint96,uint16,bool)");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setPublicCapability", config.existingQueue, 0, false, "requestOnChainWithdrawWithPermit(address,uint96,uint16,bool,uint256,uint8,bytes32,bytes32)");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setPublicCapability", config.existingQueue, 0, false, "cancelOnChainWithdraw(address,address)");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setPublicCapability", config.existingQueue, 0, false, "replaceOnChainWithdraw(address,address,uint96,uint16,bool)");

        // Enable roles on new contracts
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setUserRole", address(newTeller), MINTER_ROLE, true, "");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setUserRole", address(newTeller), BURNER_ROLE, true, "");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setRoleCapability", address(newSolver), ONLY_QUEUE_ROLE, true, "boringSolve(address,address,address,uint256,uint256,bytes)");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setUserRole", address(newSolver), CAN_SOLVE_ROLE, true, "");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setUserRole", address(newSolver), SOLVER_ROLE, true, "");

        // Enable public capabilities on new queue
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setPublicCapability", address(newQueue), 0, true, "requestOnChainWithdraw(address,uint96,uint16,bool)");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setPublicCapability", address(newQueue), 0, true, "requestOnChainWithdrawWithPermit(address,uint96,uint16,bool,uint256,uint8,bytes32,bytes32)");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setPublicCapability", address(newQueue), 0, true, "cancelOnChainWithdraw(address,address)");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setPublicCapability", address(newQueue), 0, true, "replaceOnChainWithdraw(address,address,uint96,uint16,bool)");

        // Add pauser roles for new contracts
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setRoleCapability", address(newAccountant), PAUSER_ROLE, true, "pause()");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setRoleCapability", address(newAccountant), PAUSER_ROLE, true, "unpause()");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setRoleCapability", address(newTeller), PAUSER_ROLE, true, "pause()");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setRoleCapability", address(newTeller), PAUSER_ROLE, true, "unpause()");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setRoleCapability", address(newQueue), PAUSER_ROLE, true, "pause()");
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setRoleCapability", address(newQueue), PAUSER_ROLE, true, "unpause()");

        // Add update exchange rate role for accountant
        rolesArray = addRoleAction(rolesArray, roleIndex++, "setRoleCapability", address(newAccountant), UPDATE_EXCHANGE_RATE_ROLE, true, "updateExchangeRate(uint96)");

        // Add self-solve public capabilities if configured
        if (config.allowPublicWithdrawals) {
            rolesArray = addRoleAction(rolesArray, roleIndex++, "setPublicCapability", address(newSolver), 0, true, "boringRedeemSelfSolve((uint96,address,address,uint128,uint128,uint40,uint24,uint24),address)");
            rolesArray = addRoleAction(rolesArray, roleIndex++, "setPublicCapability", address(newSolver), 0, true, "boringRedeemMintSelfSolve((uint96,address,address,uint128,uint128,uint40,uint24,uint24),address,address,address)");
        }

        actionObj = actionObj.serialize("new_roles", rolesArray);
        
        // Add to actions array
        if (index == 0) {
            actionsArray = actionObj;
        } else {
            actionsArray = string.concat(actionsArray, ",", actionObj);
        }

        // Log deployed addresses
        console.log("New Accountant:", address(newAccountant));
        console.log("New Teller:", address(newTeller));
        console.log("New Queue:", address(newQueue));
        console.log("New Solver:", address(newSolver));

        return actionsArray;
    }

    function addRoleAction(
        string memory rolesArray,
        uint256 index,
        string memory actionType,
        address targetContract,
        uint8 roleId,
        bool enabled,
        string memory functionSignature
    ) internal returns (string memory) {
        string memory roleObj = "";
        roleObj = roleObj.serialize("action_type", actionType);
        
        if (keccak256(bytes(actionType)) == keccak256(bytes("setRoleCapability"))) {
            roleObj = roleObj.serialize("role_id", roleId);
            roleObj = roleObj.serialize("target_contract", targetContract);
            roleObj = roleObj.serialize("function_signature", functionSignature);
            roleObj = roleObj.serialize("enabled", enabled);
        } else if (keccak256(bytes(actionType)) == keccak256(bytes("setUserRole"))) {
            roleObj = roleObj.serialize("user", targetContract);
            roleObj = roleObj.serialize("role_id", roleId);
            roleObj = roleObj.serialize("enabled", enabled);
        } else if (keccak256(bytes(actionType)) == keccak256(bytes("setPublicCapability"))) {
            roleObj = roleObj.serialize("target_contract", targetContract);
            roleObj = roleObj.serialize("function_signature", functionSignature);
            roleObj = roleObj.serialize("enabled", enabled);
        }
        
        if (index == 0) {
            return roleObj;
        }
        return string.concat(rolesArray, ",", roleObj);
    }
}