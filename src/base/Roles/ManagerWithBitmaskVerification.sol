// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol"; 
import {BoringVault} from "src/base/BoringVault.sol";
import {MerkleProofLib} from "@solmate/utils/MerkleProofLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Registry} from "src/base/Registry/Registry.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {IPausable} from "src/interfaces/IPausable.sol";
import {DroneLib} from "src/base/Drones/DroneLib.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {TokenWhitelistStorageModule} from "src/base/Modules/StorgeModules/TokenWhitelistStorageModule.sol";

//import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract ManagerWithBitmaskVerification is Auth { 
    using Address for address;

    //bits and bobs
    uint256[2] public subscriptions;  //512 unique protocols

    /**
     * @notice Used to pause calls to `manageVaultWithMerkleVerification`.
     */
    bool public isPaused;

    /**
     * @notice The BoringVault this contract can manage.
     */
    BoringVault public immutable vault;

    /**
     */
    Registry public immutable registry;

    /**
     */
    TokenWhitelistStorageModule public storageContract;

    //============================== ERRORS ===============================
    
    error ManagerWithBitmaskVerification__ProtocolNotInMask(uint256 bit, uint256 index); 
    error ManagerWithBitmaskVerification__TokenNotApproved(address token); 


    constructor(address _owner, address _vault, address _registry, address _storageContract) Auth(_owner, Authority(address(0))) {
        vault = BoringVault(payable(_vault));
        registry = Registry(_registry);
        storageContract = TokenWhitelistStorageModule(_storageContract);
    }

    /**
     * @notice ADDs to the protocol mask by page index.
     * @dev Callable by OWNER_ROLE.
     */
    function subscribe(uint256 protocolBits, uint256 index) external {
        subscriptions[index] |= protocolBits;
    }

    /**
     * @notice REMOVEs the protocol mask by page index.
     * @dev Callable by OWNER_ROLE.
     */
    function unsubscribe(uint256 protocolBits, uint256 index) external {
        subscriptions[index] &= ~protocolBits;
    }
       

    //this is interesting because we have a couple of options here
    //1) keep passing in the decoders along w/ the call (kinda aids devex)
    //2) pull it out for the user somewhere (increases gas cost, have to SLOAD it)
    //  //if we pull it out for them based on what, target address? We need a mapping of targets to protocols
    function manageVaultWithBitmaskVerification(
        address[] calldata targets,
        bytes[] calldata targetData,
        uint256[] calldata values
        //address[][] calldata postRunHooks,
    ) external {
        uint256 targetsLength = targets.length;
        //if (targetsLength != targetData.length) revert ManagerWithMerkleVerification__InvalidTargetDataLength();
        //if (targetsLength != values.length) revert ManagerWithMerkleVerification__InvalidValuesLength();
        //    revert ManagerWithMerkleVerification__InvalidDecodersAndSanitizersLength();
        
        Registry.ProtocolConfig[] memory protocolConfigs = new Registry.ProtocolConfig[](targetsLength); 
        for (uint256 i; i < targetsLength;) { //gas efficient boomer loop
            protocolConfigs[i] = registry.getProtocolConfigFromTarget(targets[i]);
            unchecked {
                ++i; 
            }
        }

        uint256 totalSupply = vault.totalSupply();

        //issues with this approach 
        //if the mapping is wrong the target data will be wrong? no, we can still check that the call is going where we need it to in the module
        //the real question is, is that a waste? We can optionally pass in the decoder like before, and instead ONLY verify the target in the module
        //for now, I think we can do both and then see what the devex is like
       
        //approvals:
        //the issue is that approvals need special handling because we cannot map every erc20 to an approval decoder, that would suck
        //I do not like handling them in an if/else because that is gross, though it is clear what is happening
        //perhaps we move the logic to the registry?
        
        for (uint256 i; i < targetsLength; ++i) {
            if (protocolConfigs[i].decoder == address(0)) {
                //TODO figure out a better way to this, it's a POS
                _verifyApproval(targets[i], values[i], targetData[i], address(vault));
            } else {
                _verifyCallData(
                    protocolConfigs[i], targets[i], values[i], targetData[i]
                );
            }
                //after each manage call, we can run some optional checks to verify the state of the vault across manage calls
            // _postManageModuleChecks(postRunHooks); //check slippage, check target received funds, check other things, whatever you want
            vault.manage(targets[i], targetData[i], values[i]);
        }

        //at the end, we still just verify the supply doesn't change
        if (totalSupply != vault.totalSupply()) {
            revert("yeet");
            //revert ManagerWithMerkleVerification__TotalSupplyMustRemainConstantDuringPlatform();
        }

        //emit BoringVaultManaged(targetsLength);
    }

    // ========================================= VIEW FUNCTIONS =========================================
    /**
     */
    function hasProtocol(uint256 protocolBit, uint256 index) public view returns (bool) {
        return (subscriptions[index] & protocolBit) != 0; 
    }

    /**
     */ 
    function hasProtocols(uint256 protocolBits, uint256 index) public view returns (bool) {
        return (subscriptions[index] & protocolBits) == protocolBits; 
    }

    // ========================================= INTERNAL HELPER FUNCTIONS =========================================

    /**
     * @notice Helper function to decode, sanitize, and verify call data.
     */
    function _verifyCallData(
        Registry.ProtocolConfig memory protocolConfig,
        address target,
        uint256 value,
        bytes calldata targetData
    ) internal view {
        //TODO add drones
        // Use address decoder to get addresses in call data.
        //first, verify that the protocol is enabled for the vault
        bool success = hasProtocol(protocolConfig.bit, protocolConfig.index); 
        if (!success) revert ManagerWithBitmaskVerification__ProtocolNotInMask(protocolConfig.bit, protocolConfig.index);
        
        success = abi.decode(protocolConfig.decoder.functionStaticCall(targetData), (bool));
        //we can potentially extract the same things here and then reuse them in the module checks? so we do not have to rewrite decoders
        //some call to a module failed, we should handle this inside the module itself so errors are more clear, 
        //rather than handling them here with a generic failure case, which is confusing and unclear
    }

    function _verifyApproval(
        address target,
        uint256 value,
        bytes calldata targetData,
        address vault
    ) internal view {
        //this sucks hard, but for now we are hardcoding the approval decoder to the 1 address and a special case
        //approve(aaave, 500);
        //append calldata to the targetData
        bytes memory appended = abi.encodePacked(targetData, vault, target, storageContract);
        bool success = abi.decode(registry.getProtocolConfigFromTarget(address(1)).decoder.functionStaticCall(appended), (bool));
        if (!success) revert ManagerWithBitmaskVerification__TokenNotApproved(target);
    }
}
