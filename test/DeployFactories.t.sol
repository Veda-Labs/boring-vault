// SPDX-License-Identifier: SEL-1.0
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {DeployFactories} from "script/DeployFactories.s.sol";
import {IFactory} from "factories/IFactory.sol";

contract DeployFactoriesTest is Test {
    DeployFactories deployer;

    // Factory deterministic deployer
    address constant CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    string constant SALT_NAMESPACE = "veda.factories.v1";

    // Deterministic deployer bytecode (well-known)
    bytes constant CREATE2_FACTORY_CODE =
        hex"7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3";

    bytes32 commitHash = bytes32(hex"acad413dcfa614586f2bd24ecfd3a641c771a5d6000000000000000000000000");
    string version = "1.0";

    string[22] factoryNames = [
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

    function setUp() public {
        // Etch Factory bytecode so we don't need a fork
        vm.etch(CREATE2_FACTORY, CREATE2_FACTORY_CODE);
        deployer = new DeployFactories();

        // Set env vars the script reads
        vm.setEnv("COMMIT_HASH", vm.toString(commitHash));
        vm.setEnv("VERSION", version);
    }

    function test_deployAll_addressesMatchPredictions() public {
        // Predict addresses before deploying
        bytes memory constructorArgs = abi.encode(commitHash, version);
        address[] memory predicted = deployer.computeAddresses(constructorArgs);
        assertEq(predicted.length, 22, "should predict 22 addresses");

        // Deploy
        deployer.run();

        // Verify each predicted address has code
        for (uint256 i; i < predicted.length; i++) {
            assertTrue(
                predicted[i].code.length > 0,
                string.concat("No code at predicted address for ", factoryNames[i])
            );
        }
    }

    function test_deployAll_commitHashAndVersion() public {
        bytes memory constructorArgs = abi.encode(commitHash, version);
        address[] memory predicted = deployer.computeAddresses(constructorArgs);

        deployer.run();

        for (uint256 i; i < predicted.length; i++) {
            IFactory factory = IFactory(predicted[i]);
            assertEq(factory.commitHash(), commitHash, string.concat("commitHash mismatch: ", factoryNames[i]));
            assertEq(
                keccak256(bytes(factory.version())),
                keccak256(bytes(version)),
                string.concat("version mismatch: ", factoryNames[i])
            );
        }
    }

    function test_redeployReverts() public {
        deployer.run();

        // Second deploy with identical inputs should revert (CREATE2 collision)
        vm.expectRevert();
        deployer.run();
    }

    function test_computeAddresses_deterministic() public view {
        bytes memory constructorArgs = abi.encode(commitHash, version);

        address[] memory first = deployer.computeAddresses(constructorArgs);
        address[] memory second = deployer.computeAddresses(constructorArgs);

        for (uint256 i; i < first.length; i++) {
            assertEq(first[i], second[i], "addresses should be deterministic");
        }
    }

    function test_computeAddresses_differentVersionProducesDifferentAddresses() public view {
        bytes memory args1 = abi.encode(commitHash, "1.0");
        bytes memory args2 = abi.encode(commitHash, "2.0");

        address[] memory addrs1 = deployer.computeAddresses(args1);
        address[] memory addrs2 = deployer.computeAddresses(args2);

        for (uint256 i; i < addrs1.length; i++) {
            assertTrue(addrs1[i] != addrs2[i], "different version should produce different addresses");
        }
    }

    function test_predictAddresses_matchesComputeAddresses() public {
        bytes memory constructorArgs = abi.encode(commitHash, version);
        address[] memory computed = deployer.computeAddresses(constructorArgs);

        // predictAddresses just logs, but we can verify the underlying computation is the same
        // by checking computeAddresses output against manual calculation
        for (uint256 i; i < 22; i++) {
            bytes32 salt = keccak256(abi.encodePacked(SALT_NAMESPACE, factoryNames[i]));
            bytes memory initCode = abi.encodePacked(deployer.getCreationCode(i), constructorArgs);
            address expected = vm.computeCreate2Address(salt, keccak256(initCode), CREATE2_FACTORY);
            assertEq(computed[i], expected, string.concat("manual vs computed mismatch: ", factoryNames[i]));
        }
    }
}
