// SPDX-License-Identifier: SEL-1.0
pragma solidity 0.8.21;

import {Script, console} from "forge-std/Script.sol";

import {AaveV3BufferHelperFactory} from "factories/AaveV3BufferHelperFactory.sol";
import {AaveV3BufferLensFactory} from "factories/AaveV3BufferLensFactory.sol";
import {AccountantWithFixedRateFactory} from "factories/AccountantWithFixedRateFactory.sol";
import {AccountantWithRateProvidersFactory} from "factories/AccountantWithRateProvidersFactory.sol";
import {AccountantWithYieldStreamingFactory} from "factories/AccountantWithYieldStreamingFactory.sol";
import {ArcticArchitectureLensFactory} from "factories/ArcticArchitectureLensFactory.sol";
import {BoringDroneFactory} from "factories/BoringDroneFactory.sol";
import {BoringOnChainQueueFactory} from "factories/BoringOnChainQueueFactory.sol";
import {BoringOnChainQueueWithTrackingFactory} from "factories/BoringOnChainQueueWithTrackingFactory.sol";
import {BoringSolverFactory} from "factories/BoringSolverFactory.sol";
import {BoringVaultFactory} from "factories/BoringVaultFactory.sol";
import {ChainlinkCCIPTellerFactory} from "factories/ChainlinkCCIPTellerFactory.sol";
import {DeployerFactory} from "factories/DeployerFactory.sol";
import {LayerZeroTellerFactory} from "factories/LayerZeroTellerFactory.sol";
import {LayerZeroTellerWithRateLimitingFactory} from "factories/LayerZeroTellerWithRateLimitingFactory.sol";
import {ManagerWithMerkleVerificationFactory} from "factories/ManagerWithMerkleVerificationFactory.sol";
import {PauserFactory} from "factories/PauserFactory.sol";
import {RolesAuthorityFactory} from "factories/RolesAuthorityFactory.sol";
import {TellerWithMultiAssetSupportFactory} from "factories/TellerWithMultiAssetSupportFactory.sol";
import {TellerWithRemediationFactory} from "factories/TellerWithRemediationFactory.sol";
import {TellerWithYieldStreamingFactory} from "factories/TellerWithYieldStreamingFactory.sol";
import {TimelockControllerFactory} from "factories/TimelockControllerFactory.sol";

contract DeployFactories is Script {
    address constant CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    string constant SALT_NAMESPACE = "veda.factories.v1";
    uint256 constant FACTORY_COUNT = 22;

    function run() external {
        bytes32 commitHash = vm.envBytes32("COMMIT_HASH");
        string memory version = vm.envString("VERSION");
        bytes memory constructorArgs = abi.encode(commitHash, version);

        require(CREATE2_FACTORY.code.length > 0, "CREATE2 Factory not deployed on this chain");

        string memory contractsKey = "contracts";
        string memory contractsJson;

        vm.startBroadcast();

        contractsJson = vm.serializeAddress(contractsKey, "AaveV3BufferHelperFactory",
            _deployFactory("AaveV3BufferHelperFactory", type(AaveV3BufferHelperFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "AaveV3BufferLensFactory",
            _deployFactory("AaveV3BufferLensFactory", type(AaveV3BufferLensFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "AccountantWithFixedRateFactory",
            _deployFactory("AccountantWithFixedRateFactory", type(AccountantWithFixedRateFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "AccountantWithRateProvidersFactory",
            _deployFactory("AccountantWithRateProvidersFactory", type(AccountantWithRateProvidersFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "AccountantWithYieldStreamingFactory",
            _deployFactory("AccountantWithYieldStreamingFactory", type(AccountantWithYieldStreamingFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "ArcticArchitectureLensFactory",
            _deployFactory("ArcticArchitectureLensFactory", type(ArcticArchitectureLensFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "BoringDroneFactory",
            _deployFactory("BoringDroneFactory", type(BoringDroneFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "BoringOnChainQueueFactory",
            _deployFactory("BoringOnChainQueueFactory", type(BoringOnChainQueueFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "BoringOnChainQueueWithTrackingFactory",
            _deployFactory("BoringOnChainQueueWithTrackingFactory", type(BoringOnChainQueueWithTrackingFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "BoringSolverFactory",
            _deployFactory("BoringSolverFactory", type(BoringSolverFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "BoringVaultFactory",
            _deployFactory("BoringVaultFactory", type(BoringVaultFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "ChainlinkCCIPTellerFactory",
            _deployFactory("ChainlinkCCIPTellerFactory", type(ChainlinkCCIPTellerFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "DeployerFactory",
            _deployFactory("DeployerFactory", type(DeployerFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "LayerZeroTellerFactory",
            _deployFactory("LayerZeroTellerFactory", type(LayerZeroTellerFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "LayerZeroTellerWithRateLimitingFactory",
            _deployFactory("LayerZeroTellerWithRateLimitingFactory", type(LayerZeroTellerWithRateLimitingFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "ManagerWithMerkleVerificationFactory",
            _deployFactory("ManagerWithMerkleVerificationFactory", type(ManagerWithMerkleVerificationFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "PauserFactory",
            _deployFactory("PauserFactory", type(PauserFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "RolesAuthorityFactory",
            _deployFactory("RolesAuthorityFactory", type(RolesAuthorityFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "TellerWithMultiAssetSupportFactory",
            _deployFactory("TellerWithMultiAssetSupportFactory", type(TellerWithMultiAssetSupportFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "TellerWithRemediationFactory",
            _deployFactory("TellerWithRemediationFactory", type(TellerWithRemediationFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "TellerWithYieldStreamingFactory",
            _deployFactory("TellerWithYieldStreamingFactory", type(TellerWithYieldStreamingFactory).creationCode, constructorArgs));
        contractsJson = vm.serializeAddress(contractsKey, "TimelockControllerFactory",
            _deployFactory("TimelockControllerFactory", type(TimelockControllerFactory).creationCode, constructorArgs));

        vm.stopBroadcast();

        // Write deployment manifest
        string memory root = "root";
        vm.serializeUint(root, "chainId", block.chainid);
        vm.serializeString(root, "version", version);
        vm.serializeBytes32(root, "boringVaultCommitBytes32", commitHash);
        string memory finalJson = vm.serializeString(root, "contracts", contractsJson);
        vm.writeJson(finalJson, "deployments/latest-deploy.json");

        console.log("Deployment manifest written to deployments/latest-deploy.json");
    }

    /// @dev Write deployment manifest from computed CREATE2 addresses (no deployment).
    ///      Used for record-only recovery when deployment succeeded but CI failed.
    ///      Requires RPC_URL to resolve block.chainid.
    function writeManifest() external {
        bytes32 commitHash = vm.envBytes32("COMMIT_HASH");
        string memory version = vm.envString("VERSION");
        bytes memory constructorArgs = abi.encode(commitHash, version);
        address[] memory addrs = computeAddresses(constructorArgs);

        string[22] memory names = _factoryNames();
        string memory contractsKey = "contracts";
        string memory contractsJson;
        for (uint256 i; i < FACTORY_COUNT; i++) {
            contractsJson = vm.serializeAddress(contractsKey, names[i], addrs[i]);
        }

        string memory root = "root";
        vm.serializeUint(root, "chainId", block.chainid);
        vm.serializeString(root, "version", version);
        vm.serializeBytes32(root, "boringVaultCommitBytes32", commitHash);
        string memory finalJson = vm.serializeString(root, "contracts", contractsJson);
        vm.writeJson(finalJson, "deployments/latest-deploy.json");

        console.log("Manifest written to deployments/latest-deploy.json (record-only, no deployment)");
    }

    function predictAddresses() external view {
        bytes32 commitHash = vm.envBytes32("COMMIT_HASH");
        string memory version = vm.envString("VERSION");
        bytes memory constructorArgs = abi.encode(commitHash, version);

        console.log("Predicted factory addresses (CREATE2 via CREATE2 Factory)");
        console.log(string.concat("  COMMIT_HASH: ", vm.toString(commitHash)));
        console.log(string.concat("  VERSION:     ", version));
        console.log("");

        _logPrediction("AaveV3BufferHelperFactory", type(AaveV3BufferHelperFactory).creationCode, constructorArgs);
        _logPrediction("AaveV3BufferLensFactory", type(AaveV3BufferLensFactory).creationCode, constructorArgs);
        _logPrediction("AccountantWithFixedRateFactory", type(AccountantWithFixedRateFactory).creationCode, constructorArgs);
        _logPrediction("AccountantWithRateProvidersFactory", type(AccountantWithRateProvidersFactory).creationCode, constructorArgs);
        _logPrediction("AccountantWithYieldStreamingFactory", type(AccountantWithYieldStreamingFactory).creationCode, constructorArgs);
        _logPrediction("ArcticArchitectureLensFactory", type(ArcticArchitectureLensFactory).creationCode, constructorArgs);
        _logPrediction("BoringDroneFactory", type(BoringDroneFactory).creationCode, constructorArgs);
        _logPrediction("BoringOnChainQueueFactory", type(BoringOnChainQueueFactory).creationCode, constructorArgs);
        _logPrediction("BoringOnChainQueueWithTrackingFactory", type(BoringOnChainQueueWithTrackingFactory).creationCode, constructorArgs);
        _logPrediction("BoringSolverFactory", type(BoringSolverFactory).creationCode, constructorArgs);
        _logPrediction("BoringVaultFactory", type(BoringVaultFactory).creationCode, constructorArgs);
        _logPrediction("ChainlinkCCIPTellerFactory", type(ChainlinkCCIPTellerFactory).creationCode, constructorArgs);
        _logPrediction("DeployerFactory", type(DeployerFactory).creationCode, constructorArgs);
        _logPrediction("LayerZeroTellerFactory", type(LayerZeroTellerFactory).creationCode, constructorArgs);
        _logPrediction("LayerZeroTellerWithRateLimitingFactory", type(LayerZeroTellerWithRateLimitingFactory).creationCode, constructorArgs);
        _logPrediction("ManagerWithMerkleVerificationFactory", type(ManagerWithMerkleVerificationFactory).creationCode, constructorArgs);
        _logPrediction("PauserFactory", type(PauserFactory).creationCode, constructorArgs);
        _logPrediction("RolesAuthorityFactory", type(RolesAuthorityFactory).creationCode, constructorArgs);
        _logPrediction("TellerWithMultiAssetSupportFactory", type(TellerWithMultiAssetSupportFactory).creationCode, constructorArgs);
        _logPrediction("TellerWithRemediationFactory", type(TellerWithRemediationFactory).creationCode, constructorArgs);
        _logPrediction("TellerWithYieldStreamingFactory", type(TellerWithYieldStreamingFactory).creationCode, constructorArgs);
        _logPrediction("TimelockControllerFactory", type(TimelockControllerFactory).creationCode, constructorArgs);
    }

    /// @dev Compute expected CREATE2 addresses for all factories without deploying.
    ///      Used by tests and predictAddresses().
    function computeAddresses(bytes memory constructorArgs) public pure returns (address[] memory addrs) {
        addrs = new address[](FACTORY_COUNT);
        addrs[0]  = _computeAddress("AaveV3BufferHelperFactory", type(AaveV3BufferHelperFactory).creationCode, constructorArgs);
        addrs[1]  = _computeAddress("AaveV3BufferLensFactory", type(AaveV3BufferLensFactory).creationCode, constructorArgs);
        addrs[2]  = _computeAddress("AccountantWithFixedRateFactory", type(AccountantWithFixedRateFactory).creationCode, constructorArgs);
        addrs[3]  = _computeAddress("AccountantWithRateProvidersFactory", type(AccountantWithRateProvidersFactory).creationCode, constructorArgs);
        addrs[4]  = _computeAddress("AccountantWithYieldStreamingFactory", type(AccountantWithYieldStreamingFactory).creationCode, constructorArgs);
        addrs[5]  = _computeAddress("ArcticArchitectureLensFactory", type(ArcticArchitectureLensFactory).creationCode, constructorArgs);
        addrs[6]  = _computeAddress("BoringDroneFactory", type(BoringDroneFactory).creationCode, constructorArgs);
        addrs[7]  = _computeAddress("BoringOnChainQueueFactory", type(BoringOnChainQueueFactory).creationCode, constructorArgs);
        addrs[8]  = _computeAddress("BoringOnChainQueueWithTrackingFactory", type(BoringOnChainQueueWithTrackingFactory).creationCode, constructorArgs);
        addrs[9]  = _computeAddress("BoringSolverFactory", type(BoringSolverFactory).creationCode, constructorArgs);
        addrs[10] = _computeAddress("BoringVaultFactory", type(BoringVaultFactory).creationCode, constructorArgs);
        addrs[11] = _computeAddress("ChainlinkCCIPTellerFactory", type(ChainlinkCCIPTellerFactory).creationCode, constructorArgs);
        addrs[12] = _computeAddress("DeployerFactory", type(DeployerFactory).creationCode, constructorArgs);
        addrs[13] = _computeAddress("LayerZeroTellerFactory", type(LayerZeroTellerFactory).creationCode, constructorArgs);
        addrs[14] = _computeAddress("LayerZeroTellerWithRateLimitingFactory", type(LayerZeroTellerWithRateLimitingFactory).creationCode, constructorArgs);
        addrs[15] = _computeAddress("ManagerWithMerkleVerificationFactory", type(ManagerWithMerkleVerificationFactory).creationCode, constructorArgs);
        addrs[16] = _computeAddress("PauserFactory", type(PauserFactory).creationCode, constructorArgs);
        addrs[17] = _computeAddress("RolesAuthorityFactory", type(RolesAuthorityFactory).creationCode, constructorArgs);
        addrs[18] = _computeAddress("TellerWithMultiAssetSupportFactory", type(TellerWithMultiAssetSupportFactory).creationCode, constructorArgs);
        addrs[19] = _computeAddress("TellerWithRemediationFactory", type(TellerWithRemediationFactory).creationCode, constructorArgs);
        addrs[20] = _computeAddress("TellerWithYieldStreamingFactory", type(TellerWithYieldStreamingFactory).creationCode, constructorArgs);
        addrs[21] = _computeAddress("TimelockControllerFactory", type(TimelockControllerFactory).creationCode, constructorArgs);
    }

    /// @dev Return the creation code for a factory by index. Used by tests.
    function getCreationCode(uint256 index) external pure returns (bytes memory) {
        if (index == 0)  return type(AaveV3BufferHelperFactory).creationCode;
        if (index == 1)  return type(AaveV3BufferLensFactory).creationCode;
        if (index == 2)  return type(AccountantWithFixedRateFactory).creationCode;
        if (index == 3)  return type(AccountantWithRateProvidersFactory).creationCode;
        if (index == 4)  return type(AccountantWithYieldStreamingFactory).creationCode;
        if (index == 5)  return type(ArcticArchitectureLensFactory).creationCode;
        if (index == 6)  return type(BoringDroneFactory).creationCode;
        if (index == 7)  return type(BoringOnChainQueueFactory).creationCode;
        if (index == 8)  return type(BoringOnChainQueueWithTrackingFactory).creationCode;
        if (index == 9)  return type(BoringSolverFactory).creationCode;
        if (index == 10) return type(BoringVaultFactory).creationCode;
        if (index == 11) return type(ChainlinkCCIPTellerFactory).creationCode;
        if (index == 12) return type(DeployerFactory).creationCode;
        if (index == 13) return type(LayerZeroTellerFactory).creationCode;
        if (index == 14) return type(LayerZeroTellerWithRateLimitingFactory).creationCode;
        if (index == 15) return type(ManagerWithMerkleVerificationFactory).creationCode;
        if (index == 16) return type(PauserFactory).creationCode;
        if (index == 17) return type(RolesAuthorityFactory).creationCode;
        if (index == 18) return type(TellerWithMultiAssetSupportFactory).creationCode;
        if (index == 19) return type(TellerWithRemediationFactory).creationCode;
        if (index == 20) return type(TellerWithYieldStreamingFactory).creationCode;
        if (index == 21) return type(TimelockControllerFactory).creationCode;
        revert("Invalid index");
    }

    function _deployFactory(string memory name, bytes memory creationCode, bytes memory args)
        internal
        returns (address deployed)
    {
        bytes32 salt = keccak256(abi.encodePacked(SALT_NAMESPACE, name));
        bytes memory initCode = abi.encodePacked(creationCode, args);
        deployed = vm.computeCreate2Address(salt, keccak256(initCode), CREATE2_FACTORY);

        require(deployed.code.length == 0, string.concat("Already deployed: ", name));

        (bool ok,) = CREATE2_FACTORY.call(abi.encodePacked(salt, initCode));
        require(ok, string.concat("CREATE2 failed: ", name));
        require(deployed.code.length > 0, string.concat("No code at expected address: ", name));

        console.log(string.concat("  ", name, ": ", vm.toString(deployed)));
    }

    function _computeAddress(string memory name, bytes memory creationCode, bytes memory args)
        internal
        pure
        returns (address)
    {
        bytes32 salt = keccak256(abi.encodePacked(SALT_NAMESPACE, name));
        bytes memory initCode = abi.encodePacked(creationCode, args);
        return vm.computeCreate2Address(salt, keccak256(initCode), CREATE2_FACTORY);
    }

    function _logPrediction(string memory name, bytes memory creationCode, bytes memory args) internal view {
        address predicted = _computeAddress(name, creationCode, args);
        console.log(string.concat("  ", name, ": ", vm.toString(predicted)));
    }

    function _factoryNames() internal pure returns (string[22] memory) {
        return [
            "AaveV3BufferHelperFactory",
            "AaveV3BufferLensFactory",
            "AccountantWithFixedRateFactory",
            "AccountantWithRateProvidersFactory",
            "AccountantWithYieldStreamingFactory",
            "ArcticArchitectureLensFactory",
            "BoringDroneFactory",
            "BoringOnChainQueueFactory",
            "BoringOnChainQueueWithTrackingFactory",
            "BoringSolverFactory",
            "BoringVaultFactory",
            "ChainlinkCCIPTellerFactory",
            "DeployerFactory",
            "LayerZeroTellerFactory",
            "LayerZeroTellerWithRateLimitingFactory",
            "ManagerWithMerkleVerificationFactory",
            "PauserFactory",
            "RolesAuthorityFactory",
            "TellerWithMultiAssetSupportFactory",
            "TellerWithRemediationFactory",
            "TellerWithYieldStreamingFactory",
            "TimelockControllerFactory"
        ];
    }
}
