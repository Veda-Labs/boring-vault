// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority, Auth} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {
    LayerZeroTellerWithRateLimiting,
    CrossChainTellerWithGenericBridge,
    PairwiseRateLimiter
} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTellerWithRateLimiting.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringVault} from "src/base/BoringVault.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract CreateTimelockTxTest is Test, MerkleTreeHelper {
    using stdStorage for StdStorage;

    TimelockController public timelock = TimelockController(payable(0x70a64840A353c58f63333570f53dba0948bEcE3d));
    RolesAuthority public rolesAuthority = RolesAuthority(0x6889E57BcA038C28520C0B047a75e567502ea5F6);
    LayerZeroTellerWithRateLimiting public teller =
        LayerZeroTellerWithRateLimiting(0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268);
    address public safe = 0xCEA8039076E35a825854c5C2f85659430b06ec96;
    address public eBTC = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642;
    address public LBTCv = 0x5401b8620E5FB570064CA9114fd1e135fd77D57c;
    address public solver = 0x989468982b08AEfA46E37CD0086142A86fa466D7;
    address public oldTeller = 0xe19a43B1b8af6CeE71749Af2332627338B3242D1;
    address public delayedWithdrawer = 0x75E3f26Ceff44258CE8cB451D7d2cC8966Ef3554;

    address public hyperNativePauser = 0x9AF1298993DC1f397973C62A5D47a284CF76844D;
    address public etherfiPauser = 0x523455838764e0ECf9adD7eAB8c1DAB86B0c6D7b;

    uint8 public constant STOP_MESSAGES_FROM_CHAIN_ROLE = 20;

    ERC20 public LBTC;
    ERC20 public wBTC;
    ERC20 public cbBTC;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21374350;
        _startFork(rpcKey, blockNumber);

        LBTC = getERC20("mainnet", "LBTC");
        wBTC = getERC20("mainnet", "WBTC");
        cbBTC = getERC20("mainnet", "cbBTC");
    }

    function testProposeAndExecuteTimelock() external {
        uint256 actionCount = 4;
        address[] memory targets = new address[](actionCount);
        targets[0] = address(rolesAuthority);
        targets[1] = address(rolesAuthority);
        targets[2] = address(rolesAuthority);
        targets[3] = address(timelock);
        uint256[] memory values = new uint256[](actionCount);
        bytes[] memory payloads = new bytes[](actionCount);
        // Set role capabilities to true
        payloads[0] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            STOP_MESSAGES_FROM_CHAIN_ROLE,
            teller,
            LayerZeroTellerWithRateLimiting.stopMessagesFromChain.selector,
            true
        );
        payloads[1] = abi.encodeWithSelector(
            RolesAuthority.setUserRole.selector, hyperNativePauser, STOP_MESSAGES_FROM_CHAIN_ROLE, true
        );
        payloads[2] = abi.encodeWithSelector(
            RolesAuthority.setUserRole.selector, etherfiPauser, STOP_MESSAGES_FROM_CHAIN_ROLE, true
        );
        payloads[3] = abi.encodeWithSelector(TimelockController.updateDelay.selector, 1 days);

        bytes32 predecessor = bytes32(0);
        bytes32 salt = bytes32(0);
        uint256 delay = 300;

        vm.prank(safe);
        timelock.scheduleBatch(targets, values, payloads, predecessor, salt, delay);

        skip(delay);

        // This will fail until previous gnosis tx goes through.
        // vm.prank(safe);
        // timelock.executeBatch(targets, values, payloads, predecessor, salt);

        _saveTimelockTx("ebtc-timelock-tx-2.json", targets, values, payloads, predecessor, salt, delay);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function _saveTimelockTx(
        string memory outputFileName,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) internal {
        // Save deployment details.
        string memory filePath = string.concat("./TimelockTxs/", outputFileName);
        if (vm.exists(filePath)) {
            // Need to delete it
            vm.removeFile(filePath);
        }

        string memory coreOutput;
        string memory finalJson;

        string memory coreContracts = "core contracts key";
        vm.serializeAddress(coreContracts, "targets", targets);
        vm.serializeBytes(coreContracts, "payloads", payloads);
        vm.serializeBytes32(coreContracts, "predecessor", predecessor);
        vm.serializeBytes32(coreContracts, "salt", salt);
        vm.serializeUint(coreContracts, "delay", delay);
        bytes32 id = timelock.hashOperationBatch(targets, values, payloads, predecessor, salt);
        vm.serializeBytes32(coreContracts, "id", id);
        coreOutput = vm.serializeUint(coreContracts, "values", values);

        finalJson = vm.serializeString(finalJson, "arguments", coreOutput);

        vm.writeJson(finalJson, filePath);
    }
}
