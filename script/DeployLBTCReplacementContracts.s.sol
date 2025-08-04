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
import {BoringVault} from "src/base/BoringVault.sol";
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

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        // Set network ID based on chain
        if (block.chainid == 1) {
            networkId = 1; // Mainnet
        } else if (block.chainid == 42161) {
            networkId = 42161; // Arbitrum
        } else if (block.chainid == 31337) {
            networkId = 31337; // Local Anvil/Hardhat
        } else if (block.chainid == 1147) {
            networkId = 1147; // TAC (if this is the correct chain ID)
        } else if (block.chainid == 11147) {
            networkId = 11147; // TAC Testnet (if applicable)
        } else {
            // For development: Allow any network and use its chain ID
            networkId = block.chainid;
            console.log("Warning: Running on unsupported network with chain ID:", block.chainid);
        }
    }

    function run() external {
        uint256 nonce = 6; // Set nonce for governance proposals
        
        // Array to store all actions
        string memory actionsArray = "";

        // Configuration for Sonic BTC vault on mainnet
        VaultConfig[] memory vaults = new VaultConfig[](1);
        
        // Sonic BTC Vault configuration (replacing LBTC with WBTC as base)
        vaults[0] = VaultConfig({
            productName: "sonic_btc_lbtc_replacement",
            boringVault: 0xBb30e76d9Bb2CC9631F7fC5Eb8e87B5Aff32bFbd, // SonicBTC Vault
            existingAccountant: 0xC1a2C650D2DcC8EAb3D8942477De71be52318Acb, // SonicBTC AccountantWithFixedRate
            existingTeller: 0xAce7DEFe3b94554f0704d8d00F69F273A0cFf079, // SonicBTC TellerWithLayerZero
            existingQueue: 0x488000E6a0CfC32DCB3f37115e759aF50F55b48B, // SonicBTC BoringOnChainQueue
            existingQueueSolver: 0x921bBB663A0164c9867e494B8E0331B84213a984, // SonicBTC QueueSolver
            rolesAuthority: 0xe2C7E397b35fF40962eBc205217B6795520Fb264, // SonicBTC RolesAuthority
            payoutAddress: 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A, // Liquid payout address
            newBaseAsset: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, // WBTC address
            lbtcAddress: 0x8236a87084f8B84306f72007F36F2618A5634494, // LBTC address
            lbtcRateProvider: 0x94916a66fC119a0AC7d612927F0D909cAc15314C, // LBTC Rate Provider V0.0
            startingExchangeRate: 100000000, // 1e8 for BTC-based vault
            allowedExchangeRateChangeUpper: 10100, // 1.01% upper bound
            allowedExchangeRateChangeLower: 9900, // 1% lower bound
            minimumUpdateDelayInSeconds: 21600, // 6 hours
            platformFee: 150, // 1.5%
            performanceFee: 0,
            allowPublicDeposits: true,
            shareLockPeriod: 86400, // 24 hours
            allowPublicWithdrawals: true,
            excessToSolverNonSelfSolve: false
        });

        vm.startBroadcast(privateKey);

        // Deploy contracts for each vault
        for (uint256 i = 0; i < vaults.length; i++) {
            actionsArray = deployAndConfigureVault(vaults[i], actionsArray, i);
        }

        vm.stopBroadcast();

        // Build the final JSON manually to ensure proper array formatting
        string memory finalJson = string.concat(
            '{"network_id":', vm.toString(networkId), ',',
            '"nonce":', vm.toString(nonce), ',',
            '"actions":[', actionsArray, ']}'
        );
        
        // Write to file
        string memory filename = string.concat("deployments/role_updates/lbtc_replacement_", vm.toString(block.timestamp), ".json");
        vm.writeFile(filename, finalJson);
        
        console.log("Deployment complete. JSON output written to:", filename);
    }

    function deployAndConfigureVault(
        VaultConfig memory config,
        string memory actionsArray,
        uint256 index
    ) internal returns (string memory) {
        console.log("Deploying contracts for:", config.productName);

        // Get the actual deployer address
        address deployerAddress = vm.addr(privateKey);
        
        // Deploy new Accountant with WBTC as base asset
        AccountantWithRateProviders newAccountant = new AccountantWithRateProviders(
            deployerAddress, // Deploy with actual deployer address
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
            deployerAddress, // Deploy with actual deployer address
            config.boringVault,
            address(newAccountant),
            config.newBaseAsset // Native wrapper (WBTC for BTC vaults)
        );

        // Deploy new BoringOnChainQueue
        BoringOnChainQueue newQueue = new BoringOnChainQueue(
            deployerAddress, // Deploy with actual deployer address
            config.rolesAuthority,
            payable(config.boringVault),
            address(newAccountant)
        );

        // Deploy new BoringSolver
        BoringSolver newSolver = new BoringSolver(
            deployerAddress, // Deploy with actual deployer address
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

        // Transfer ownership to address(0) after all configuration is complete
        newAccountant.transferOwnership(address(0));
        newTeller.transferOwnership(address(0));
        newQueue.transferOwnership(address(0));
        newSolver.transferOwnership(address(0));

        // Build role configuration JSON
        string memory actionObj = "";
        actionObj = actionObj.serialize("product", config.productName);
        
        // Initialize roles array
        string memory rolesArray = "[";
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

        // Close the roles array
        rolesArray = string.concat(rolesArray, "]");
        
        // Build the complete action object as a JSON string
        string memory completeAction = string.concat(
            '{"product":"', config.productName, '",',
            '"new_roles":', rolesArray, '}'
        );
        
        // Add to actions array
        if (index == 0) {
            actionsArray = completeAction;
        } else {
            actionsArray = string.concat(actionsArray, ",", completeAction);
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
    ) internal view returns (string memory) {
        string memory roleObj = "{";
        
        if (keccak256(bytes(actionType)) == keccak256(bytes("setRoleCapability"))) {
            roleObj = string.concat(roleObj, 
                '"action_type":"', actionType, '",',
                '"role_id":', vm.toString(roleId), ',',
                '"target_contract":"', vm.toString(targetContract), '",',
                '"function_signature":"', functionSignature, '",',
                '"enabled":', enabled ? 'true' : 'false'
            );
        } else if (keccak256(bytes(actionType)) == keccak256(bytes("setUserRole"))) {
            roleObj = string.concat(roleObj,
                '"action_type":"', actionType, '",',
                '"user":"', vm.toString(targetContract), '",',
                '"role_id":', vm.toString(roleId), ',',
                '"enabled":', enabled ? 'true' : 'false'
            );
        } else if (keccak256(bytes(actionType)) == keccak256(bytes("setPublicCapability"))) {
            roleObj = string.concat(roleObj,
                '"action_type":"', actionType, '",',
                '"target_contract":"', vm.toString(targetContract), '",',
                '"function_signature":"', functionSignature, '",',
                '"enabled":', enabled ? 'true' : 'false'
            );
        }
        
        roleObj = string.concat(roleObj, "}");
        
        // If it's the first role, just add it, otherwise prepend a comma
        if (index == 0) {
            return string.concat(rolesArray, roleObj);
        }
        return string.concat(rolesArray, ",", roleObj);
    }
}