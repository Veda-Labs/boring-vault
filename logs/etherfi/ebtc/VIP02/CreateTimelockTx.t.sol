// SPDX-License-Identifier: UNLICENSED
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

    uint8 public constant MINTER_ROLE = 2;
    uint8 public constant BURNER_ROLE = 3;
    uint8 public constant PAUSER_ROLE = 5;
    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant MULTISIG_ROLE = 9;
    uint8 public constant STRATEGIST_MULTISIG_ROLE = 10;
    uint8 public constant SOLVER_ROLE = 12;

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
        uint256 actionCount = 29;
        address[] memory targets = new address[](actionCount);
        targets[0] = address(rolesAuthority);
        targets[1] = address(rolesAuthority);
        targets[2] = address(rolesAuthority);
        targets[3] = address(rolesAuthority);
        targets[4] = address(rolesAuthority);
        targets[5] = address(rolesAuthority);
        targets[6] = address(rolesAuthority);
        targets[7] = address(rolesAuthority);
        targets[8] = address(rolesAuthority);
        targets[9] = address(rolesAuthority);
        targets[10] = address(rolesAuthority);
        targets[11] = address(rolesAuthority);
        targets[12] = address(rolesAuthority);
        targets[13] = address(rolesAuthority);
        targets[14] = address(rolesAuthority);
        targets[15] = address(rolesAuthority);
        targets[16] = address(rolesAuthority);
        targets[17] = address(rolesAuthority);
        targets[18] = address(rolesAuthority);
        targets[19] = address(rolesAuthority);
        targets[20] = address(rolesAuthority);
        targets[21] = address(rolesAuthority);
        targets[22] = address(rolesAuthority);
        targets[23] = address(rolesAuthority);
        targets[24] = address(eBTC);
        targets[25] = address(rolesAuthority);
        targets[26] = address(rolesAuthority);
        targets[27] = address(rolesAuthority);
        targets[28] = address(rolesAuthority);
        uint256[] memory values = new uint256[](actionCount);
        bytes[] memory payloads = new bytes[](actionCount);
        // Set role capabilities to true
        payloads[0] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            OWNER_ROLE,
            teller,
            LayerZeroTellerWithRateLimiting.addChain.selector,
            true
        );
        payloads[1] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            MULTISIG_ROLE,
            teller,
            LayerZeroTellerWithRateLimiting.removeChain.selector,
            true
        );
        payloads[2] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            OWNER_ROLE,
            teller,
            LayerZeroTellerWithRateLimiting.allowMessagesFromChain.selector,
            true
        );
        payloads[3] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            OWNER_ROLE,
            teller,
            LayerZeroTellerWithRateLimiting.allowMessagesToChain.selector,
            true
        );
        payloads[4] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            MULTISIG_ROLE,
            teller,
            LayerZeroTellerWithRateLimiting.stopMessagesFromChain.selector,
            true
        );
        payloads[5] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            MULTISIG_ROLE,
            teller,
            LayerZeroTellerWithRateLimiting.stopMessagesToChain.selector,
            true
        );
        payloads[6] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            MULTISIG_ROLE,
            teller,
            LayerZeroTellerWithRateLimiting.setOutboundRateLimits.selector,
            true
        );
        payloads[7] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            MULTISIG_ROLE,
            teller,
            LayerZeroTellerWithRateLimiting.setInboundRateLimits.selector,
            true
        );
        payloads[8] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            OWNER_ROLE,
            teller,
            LayerZeroTellerWithRateLimiting.setChainGasLimit.selector,
            true
        );
        payloads[9] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            MULTISIG_ROLE,
            teller,
            TellerWithMultiAssetSupport.pause.selector,
            true
        );
        payloads[10] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            MULTISIG_ROLE,
            teller,
            TellerWithMultiAssetSupport.unpause.selector,
            true
        );
        payloads[11] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            PAUSER_ROLE,
            teller,
            TellerWithMultiAssetSupport.pause.selector,
            true
        );
        payloads[12] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            PAUSER_ROLE,
            teller,
            TellerWithMultiAssetSupport.unpause.selector,
            true
        );
        payloads[13] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            OWNER_ROLE,
            teller,
            TellerWithMultiAssetSupport.updateAssetData.selector,
            true
        );
        payloads[14] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            OWNER_ROLE,
            teller,
            TellerWithMultiAssetSupport.setShareLockPeriod.selector,
            true
        );
        payloads[15] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            SOLVER_ROLE,
            teller,
            TellerWithMultiAssetSupport.bulkDeposit.selector,
            true
        );
        payloads[16] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            SOLVER_ROLE,
            teller,
            TellerWithMultiAssetSupport.bulkWithdraw.selector,
            true
        );

        // Add public functions
        payloads[17] = abi.encodeWithSelector(
            RolesAuthority.setPublicCapability.selector, teller, TellerWithMultiAssetSupport.deposit.selector, true
        );
        payloads[18] = abi.encodeWithSelector(
            RolesAuthority.setPublicCapability.selector,
            teller,
            TellerWithMultiAssetSupport.depositWithPermit.selector,
            true
        );
        payloads[19] = abi.encodeWithSelector(
            RolesAuthority.setPublicCapability.selector,
            teller,
            CrossChainTellerWithGenericBridge.depositAndBridge.selector,
            true
        );
        payloads[20] = abi.encodeWithSelector(
            RolesAuthority.setPublicCapability.selector,
            teller,
            CrossChainTellerWithGenericBridge.depositAndBridgeWithPermit.selector,
            true
        );
        payloads[21] = abi.encodeWithSelector(
            RolesAuthority.setPublicCapability.selector, teller, CrossChainTellerWithGenericBridge.bridge.selector, true
        );

        // Grant roles
        payloads[22] = abi.encodeWithSelector(RolesAuthority.setUserRole.selector, teller, MINTER_ROLE, true);
        payloads[23] = abi.encodeWithSelector(RolesAuthority.setUserRole.selector, teller, BURNER_ROLE, true);

        // Set before transfer hook
        payloads[24] = abi.encodeWithSelector(BoringVault.setBeforeTransferHook.selector, teller);

        payloads[25] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            STRATEGIST_MULTISIG_ROLE,
            teller,
            TellerWithMultiAssetSupport.updateAssetData.selector,
            true
        );
        payloads[26] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector, OWNER_ROLE, teller, Auth.setAuthority.selector, true
        );
        payloads[27] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector, OWNER_ROLE, teller, Auth.transferOwnership.selector, true
        );
        payloads[28] = abi.encodeWithSelector(
            RolesAuthority.setRoleCapability.selector,
            STRATEGIST_MULTISIG_ROLE,
            teller,
            TellerWithMultiAssetSupport.refundDeposit.selector,
            true
        );

        bytes32 predecessor = bytes32(0);
        bytes32 salt = bytes32(0);
        uint256 delay = 300;

        vm.prank(safe);
        timelock.scheduleBatch(targets, values, payloads, predecessor, salt, delay);

        skip(delay);

        // This will fail until previous gnosis tx goes through.
        // vm.prank(safe);
        // timelock.executeBatch(targets, values, payloads, predecessor, salt);

        _saveTimelockTx("ebtc-timelock-tx-1.json", targets, values, payloads, predecessor, salt, delay);
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
