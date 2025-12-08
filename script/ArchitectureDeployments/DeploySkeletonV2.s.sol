// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault, Auth} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {
    EtherFiLiquidEthDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {TellerWithRemediation} from "src/base/Roles/TellerWithRemediation.sol";
import {
    ChainlinkCCIPTeller,
    CrossChainTellerWithGenericBridge
} from "src/base/Roles/CrossChain/Bridges/CCIP/ChainlinkCCIPTeller.sol";
import {LayerZeroTeller} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {
    LayerZeroTellerWithRateLimiting
} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTellerWithRateLimiting.sol";
import {TellerWithYieldStreaming} from "src/base/Roles/TellerWithYieldStreaming.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {AccountantWithFixedRate} from "src/base/Roles/AccountantWithFixedRate.sol";
import {AccountantWithYieldStreaming} from "src/base/Roles/AccountantWithYieldStreaming.sol";
import {AaveV3BufferHelper} from "src/base/Roles/AaveV3BufferHelper.sol";
import {AaveV3BufferLens} from "src/helper/AaveV3BufferLens.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {ArcticArchitectureLens} from "src/helper/ArcticArchitectureLens.sol";
import {BoringDrone} from "src/base/Drones/BoringDrone.sol";
import {ChainValues} from "test/resources/ChainValues.sol";
import {PaymentSplitter} from "src/helper/PaymentSplitter.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringOnChainQueueWithTracking} from "src/base/Roles/BoringQueue/BoringOnChainQueueWithTracking.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {Pauser} from "src/base/Roles/Pauser.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "@forge-std/Test.sol";
import {Roles} from "resources/Roles.sol";

/**
 *  To simulate the deployment on the RPC url defined in foundry.toml, use the following command:
 *  It will assume that deployer is `0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b` It is allowlisted(on mainnet) to call `deployContract` on `src/helper/Deployer.sol`
 *
 *  forge script script/ArchitectureDeployments/DeploySkeletonV2.s.sol:DeploySkeletonV2Script --sig "run(string)" Mainnet/Benjamin-test.json --slow -vvvvvv --sender 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b
 *
 *
 *  To deploy on Tenderly vnet, change the rpc url in foundry.toml to the vnet url of the fork for mainnet (because this is a mainnet deployment config) and use the following command:
 *  In this case, we don't have --sender, but we can use --account name (foundry keystore) --trezor --ledger for the deployment. It is much better than having private key somewhere in the ENV especially with AI reading everything everywhere.
 *
 *  Example with keystore and account name `ben-dev` in keystore
 *
 *  forge script script/ArchitectureDeployments/DeploySkeletonV2.s.sol:DeploySkeletonV2Script --sig "run(string)" Mainnet/Benjamin-test.json --with-gas-price 3000000000 --broadcast --slow --verify --account ben-dev
 *
 */
contract DeploySkeletonV2Script is Script, Roles, ChainValues {
    enum TellerKind {
        Teller,
        TellerWithRemediation,
        TellerWithCcip,
        TellerWithLayerZero,
        TellerWithLayerZeroRateLimiting,
        TellerWithYieldStreaming
    }

    enum QueueKind {
        BoringQueue,
        BoringQueueWithTracking
    }

    enum AccountantKind {
        VariableRate,
        FixedRate,
        YieldStreaming
    }

    struct AddressOrName {
        address address_;
        string name;
    }

    struct AccountantDeploymentParameters {
        uint16 allowedExchangeRateChangeLower;
        uint16 allowedExchangeRateChangeUpper;
        AddressOrName base;
        uint24 minimumUpateDelayInSeconds;
        uint16 performanceFee;
        uint16 platformFee;
        uint96 startingExchangeRate;
    }

    struct AccountantAsset {
        AddressOrName addressOrName;
        bool isPeggedToBase;
        address rateProvider;
    }

    struct WithdrawAsset {
        AddressOrName addressOrName;
        uint16 maxDiscount;
        uint16 minDiscount;
        uint24 minimumSecondsToDeadline;
        uint96 minimumShares;
        uint24 secondsToMaturity;
    }

    struct PaymentSplitterSplit {
        uint96 percent;
        address to;
    }

    struct TimelockParameters {
        address[] executors;
        uint256 minDelay;
        address[] proposers;
    }

    struct DepositAsset {
        AddressOrName addressOrName;
        bool allowDeposits;
        bool allowWithdraws;
        uint16 sharePremium;
    }

    struct TargetTellerOrSelf {
        address address_;
        bool self;
    }

    TellerKind internal tellerKind;
    AccountantKind internal accountantKind;

    // Contracts to deploy
    ArcticArchitectureLens public lens;
    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    RolesAuthority public rolesAuthority;
    AaveV3BufferHelper public aaveV3BufferHelper;
    AaveV3BufferLens public aaveV3BufferLens;
    TellerWithYieldStreaming public teller;
    AccountantWithYieldStreaming public accountant;
    PaymentSplitter public paymentSplitter;
    BoringOnChainQueue public queue;
    BoringSolver public queueSolver;
    Pauser public pauser;
    TimelockController public timelock;

    uint256 public droneCount;
    uint256 public safeGasToForwardNative;
    address[] internal droneAddresses;

    string finalJson;
    string coreOutput;
    string droneOutput;

    // Must be Public because it is used in the _saveContractAddresses function.
    string public accountantName;

    // Must be Public because it is used in the _saveContractAddresses function.
    string public tellerName;

    address internal baseAsset;

    Deployer.Tx[] internal txs;

    function getTxs() public view returns (Deployer.Tx[] memory) {
        return txs;
    }

    function _addTx(address target, bytes memory data, uint256 value) internal {
        txs.push(Deployer.Tx(target, data, value));
    }

    function _getAddressAndIfDeployed(string memory name) internal view returns (address, bool) {
        address deployedAt = deployer.getAddress(name);
        uint256 size;
        assembly {
            size := extcodesize(deployedAt)
        }
        return (deployedAt, size > 0);
    }

    function _getAddressIfDeployed(string memory name) internal view returns (address) {
        address deployedAt = deployer.getAddress(name);
        uint256 size;
        assembly {
            size := extcodesize(deployedAt)
        }
        if (size > 0) {
            return deployedAt;
        }
        return address(0);
    }

    bool internal deployContracts;
    Deployer internal deployer;

    error KeyNotFound(string key);
    error DeployError(string message);

    uint256 internal privateKey;

    string internal rawJson;
    string internal sourceChain;
    // 0 - off, 1 - error, 2 - warn, 3 - info, 4 - debug
    uint256 internal logLevel;
    string internal evmVersion;

    address internal deploymentOwner;

    string internal rolesAuthorityDeploymentName;
    string internal lensDeploymentName;
    string internal aaveV3BufferHelperDeploymentName;
    string internal aaveV3BufferLensDeploymentName;
    string internal boringVaultDeploymentName;
    string internal managerDeploymentName;
    string internal accountantDeploymentName;
    string internal tellerDeploymentName;
    string internal queueDeploymentName;
    string internal queueSolverDeploymentName;
    string internal droneBaseDeploymentName;
    string internal pauserDeploymentName;
    string internal timelockDeploymentName;

    bool internal rolesAuthorityExists;
    bool internal lensExists;
    bool internal boringVaultExists;
    bool internal managerExists;
    bool internal accountantExists;
    bool internal tellerExists;
    bool internal queueExists;
    bool internal queueSolverExists;
    bool internal pauserExists;
    bool internal timelockExists;
    bool internal paymentSplitterExists;

    function _log(string memory message, uint256 level) internal view {
        if (logLevel >= level) {
            if (level == 1) {
                revert DeployError(message);
            } else if (level == 2) {
                message = string.concat("[WARN]: ", message);
            } else if (level == 3) {
                message = string.concat("[INFO]: ", message);
            } else if (level == 4) {
                message = string.concat("[DEBUG]: ", message);
            }
            console.log(message);
        }
    }

    function _readConfigurationFile(string memory configurationFileName) internal virtual {
        string memory root = vm.projectRoot();
        string memory configurationPath =
            string.concat(root, "/deployments/skeletons/configurations/", configurationFileName);
        rawJson = vm.readFile(configurationPath);
    }

    function run(string memory configurationFileName) external virtual {
        _readConfigurationFile(configurationFileName);

        if (vm.keyExists(rawJson, ".deploymentParameters.logLevel")) {
            logLevel = vm.parseJsonUint(rawJson, ".deploymentParameters.logLevel");
            _log("Log level found in configuration file.", 3);
        } else {
            revert KeyNotFound(".deploymentParameters.logLevel");
        }

        // Allows config to have env variable `privateKeyEnvName` (NOT RECOMMENDED, use --private-key or --trezor or --ledger from foundry)
        if (vm.keyExists(rawJson, ".deploymentParameters.privateKeyEnvName")) {
            privateKey = vm.envUint(vm.parseJsonString(rawJson, ".deploymentParameters.privateKeyEnvName"));
            _log("Private key found in configuration file.", 3);
        }

        if (vm.keyExists(rawJson, ".deploymentParameters.chainName")) {
            string memory chainName = vm.parseJsonString(rawJson, ".deploymentParameters.chainName");
            vm.createSelectFork(chainName);
            sourceChain = chainName;
            _log(string.concat("Forked to chain: ", chainName), 3);
        } else {
            revert KeyNotFound(".deploymentParameters.chainName");
        }

        if (vm.keyExists(rawJson, ".deploymentParameters.evmVersion")) {
            evmVersion = vm.parseJsonString(rawJson, ".deploymentParameters.evmVersion");
            _log(string.concat("evm version found in configuration file: ", evmVersion), 3);
            // Read the foundry.toml file
            string memory toml = vm.readFile("foundry.toml");

            // Get the evm_version from foundry.toml
            string memory foundryEVMVersion = vm.parseTomlString(toml, ".profile.default.evm_version");

            // Check if the evm version in the configuration file is the same as the one in the foundry.toml file
            if (keccak256(abi.encode(evmVersion)) != keccak256(abi.encode(foundryEVMVersion))) {
                _log(string.concat("evm version mismatch: ", evmVersion, " vs ", foundryEVMVersion), 1);
            }
        } else {
            revert KeyNotFound(".deploymentParameters.evmVersion");
        }

        if (vm.keyExists(rawJson, ".deploymentParameters.deploymentOwnerAddressOrName")) {
            bytes memory addressOrNameRaw = vm.parseJson(rawJson, ".deploymentParameters.deploymentOwnerAddressOrName");
            AddressOrName memory addressOrName = abi.decode(addressOrNameRaw, (AddressOrName));
            deploymentOwner = addressOrName.address_ == address(0)
                ? getAddress(sourceChain, addressOrName.name)
                : addressOrName.address_;
            _log("Deployment owner found in configuration file.", 3);
        }

        // Read all names from configuration file.
        rolesAuthorityDeploymentName =
            vm.parseJsonString(rawJson, ".rolesAuthorityConfiguration.rolesAuthorityDeploymentName");
        lensDeploymentName = vm.parseJsonString(rawJson, ".lensConfiguration.lensDeploymentName");
        boringVaultDeploymentName = vm.parseJsonString(rawJson, ".boringVaultConfiguration.boringVaultDeploymentName");
        managerDeploymentName = vm.parseJsonString(rawJson, ".managerConfiguration.managerDeploymentName");
        accountantDeploymentName = vm.parseJsonString(rawJson, ".accountantConfiguration.accountantDeploymentName");
        tellerDeploymentName = vm.parseJsonString(rawJson, ".tellerConfiguration.tellerDeploymentName");
        queueDeploymentName = vm.parseJsonString(rawJson, ".boringQueueConfiguration.boringQueueDeploymentName");
        queueSolverDeploymentName = vm.parseJsonString(rawJson, ".boringQueueConfiguration.boringQueueSolverName");
        droneBaseDeploymentName = vm.parseJsonString(rawJson, ".droneConfiguration.droneDeploymentBaseName");
        pauserDeploymentName = vm.parseJsonString(rawJson, ".pauserConfiguration.pauserDeploymentName");
        timelockDeploymentName = vm.parseJsonString(rawJson, ".timelockConfiguration.timelockDeploymentName");
        aaveV3BufferHelperDeploymentName =
            vm.parseJsonString(rawJson, ".aaveV3BufferHelperConfiguration.aaveV3BufferHelperDeploymentName");
        aaveV3BufferLensDeploymentName =
            vm.parseJsonString(rawJson, ".aaveV3BufferLensConfiguration.aaveV3BufferLensDeploymentName");

        // Get Deployer address from configuration file.
        deployer = Deployer(_handleAddressOrName(".deploymentParameters.deployerContractAddressOrName"));

        // This will be true if private key is comming from the configuration file and environment variable (NOT RECOMMENDED)
        if (privateKey > 0) {
            _log(string.concat("Starting broadcast with private key: ", vm.toString(privateKey)), 3);
            vm.startBroadcast(privateKey);
        } else {
            _log("Starting broadcast without private key", 3);
            // Allows you to use Keystore file from foundry, --private-key or --trezor or --ledger from foundry
            vm.startBroadcast();
        }

        _deployRolesAuthority();
        _deployLens();
        _deployBoringVault();
        _deployManager();
        _deployAccountant();
        _deployTeller();
        _deployBoringOnChainQueue();
        _deployQueueSolver();
        _deployPauser();
        _deployTimelock();
        _deployDrones();
        _deployAaveV3BufferHelper();
        _deployAaveV3BufferLens();
        _saveContractAddresses();
    }

    function _deployRolesAuthority() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;

        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(rolesAuthorityDeploymentName);

        if (isDeployed) {
            rolesAuthorityExists = true;
            rolesAuthority = RolesAuthority(deployedAddress);
            return;
        }

        creationCode = type(RolesAuthority).creationCode;
        constructorArgs = abi.encode(deploymentOwner, Authority(address(0)));
        deployer.deployContract(rolesAuthorityDeploymentName, creationCode, constructorArgs, 0);
        rolesAuthority = RolesAuthority(deployer.getAddress(rolesAuthorityDeploymentName));
        rolesAuthorityExists = true;
        _log("Roles authority deployment TX added", 3);
    }

    function _deployLens() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;

        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(lensDeploymentName);

        if (isDeployed) {
            lens = ArcticArchitectureLens(deployedAddress);
            lensExists = true;
            return;
        }

        creationCode = type(ArcticArchitectureLens).creationCode;
        constructorArgs = hex"";
        deployer.deployContract(lensDeploymentName, creationCode, constructorArgs, 0);

        lens = ArcticArchitectureLens(deployer.getAddress(lensDeploymentName));
        lensExists = true;
        _log("Lens deployment TX added", 3);
    }

    function _deployAaveV3BufferHelper() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;

        (address deployedAddress) = _getAddressIfDeployed(aaveV3BufferHelperDeploymentName);
        aaveV3BufferHelper = AaveV3BufferHelper(deployedAddress);
        bool shouldDeploy = vm.parseJsonBool(rawJson, ".aaveV3BufferHelperConfiguration.shouldDeploy");

        if (deployedAddress == address(0) && shouldDeploy) {
            // Get aaveV3Pool from configuration file.
            address aaveV3Pool = _handleAddressOrName(".aaveV3BufferHelperConfiguration.aaveV3PoolAddressOrName");
            creationCode = type(AaveV3BufferHelper).creationCode;
            constructorArgs = abi.encode(aaveV3Pool, address(boringVault));
            deployer.deployContract(aaveV3BufferHelperDeploymentName, creationCode, constructorArgs, 0);
            aaveV3BufferHelper = AaveV3BufferHelper(deployer.getAddress(aaveV3BufferHelperDeploymentName));
            _log("AaveV3BufferHelper deployment TX added", 3);
        }
    }

    function _deployAaveV3BufferLens() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;

        (address deployedAddress) = _getAddressIfDeployed(aaveV3BufferLensDeploymentName);
        aaveV3BufferLens = AaveV3BufferLens(deployedAddress);
        bool shouldDeploy = vm.parseJsonBool(rawJson, ".aaveV3BufferLensConfiguration.shouldDeploy");

        if (deployedAddress == address(0) && shouldDeploy) {
            creationCode = type(AaveV3BufferLens).creationCode;
            constructorArgs = hex"";
            deployer.deployContract(aaveV3BufferLensDeploymentName, creationCode, constructorArgs, 0);
            aaveV3BufferLens = AaveV3BufferLens(deployer.getAddress(aaveV3BufferLensDeploymentName));
            _log("AaveV3BufferLens deployment TX added", 3);
        }
    }

    function _deployBoringVault() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;

        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(boringVaultDeploymentName);

        if (isDeployed) {
            _log(string.concat("Boring vault already deployed at address: ", vm.toString(deployedAddress)), 3);
            boringVault = BoringVault(payable(deployedAddress));
            boringVaultExists = true;
            return;
        }

        creationCode = type(BoringVault).creationCode;
        // Get boringVaultName, boringVaultSymbol, and boringVaultDecimals from configuration file.
        string memory boringVaultName = vm.parseJsonString(rawJson, ".boringVaultConfiguration.boringVaultName");
        string memory boringVaultSymbol = vm.parseJsonString(rawJson, ".boringVaultConfiguration.boringVaultSymbol");
        uint256 boringVaultDecimals = vm.parseJsonUint(rawJson, ".boringVaultConfiguration.boringVaultDecimals");
        constructorArgs = abi.encode(deploymentOwner, boringVaultName, boringVaultSymbol, boringVaultDecimals);
        deployer.deployContract(boringVaultDeploymentName, creationCode, constructorArgs, 0);

        boringVault = BoringVault(payable(deployer.getAddress(boringVaultDeploymentName)));
        boringVaultExists = true;

        _log("Boring vault deployment TX added", 3);
        _log(string.concat("Boring vault name: ", boringVaultName), 4);
        _log(string.concat("Boring vault symbol: ", boringVaultSymbol), 4);
        _log(string.concat("Boring vault decimals: ", vm.toString(boringVaultDecimals)), 4);
    }

    function _deployManager() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;

        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(managerDeploymentName);

        if (isDeployed) {
            manager = ManagerWithMerkleVerification(deployedAddress);
            managerExists = true;
            return;
        }

        // Read balancerVault from configuration file.
        bytes memory balancerVaultRaw = vm.parseJson(rawJson, ".managerConfiguration.balancerVaultAddressOrName");
        AddressOrName memory balancerVault = abi.decode(balancerVaultRaw, (AddressOrName));
        address balancerVaultAddress =
            balancerVault.address_ == address(0) ? getAddress(sourceChain, balancerVault.name) : balancerVault.address_;
        creationCode = type(ManagerWithMerkleVerification).creationCode;
        constructorArgs = abi.encode(deploymentOwner, address(boringVault), balancerVaultAddress);
        deployer.deployContract(managerDeploymentName, creationCode, constructorArgs, 0);

        manager = ManagerWithMerkleVerification(deployedAddress);
        managerExists = true;

        _log("Manager deployment TX added", 3);
        _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
        _log(string.concat("Balancer vault address: ", vm.toString(balancerVaultAddress)), 4);
    }

    function _deployPaymentSplitter() internal {
        // Need to deploy a payment splitter.
        string memory paymentSplitterDeploymentName = vm.parseJsonString(
            rawJson, ".accountantConfiguration.accountantParameters.payoutConfiguration.optionalPaymentSplitterName"
        );
        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(paymentSplitterDeploymentName);

        if (isDeployed) {
            paymentSplitter = PaymentSplitter(deployedAddress);
            paymentSplitterExists = true;
            return;
        }

        bytes memory creationCode = type(PaymentSplitter).creationCode;
        // Read the splits from the configuration file.
        bytes memory splitsRaw =
            vm.parseJson(rawJson, ".accountantConfiguration.accountantParameters.payoutConfiguration.splits");
        _log("Payment splitter deployment TX added", 3);
        PaymentSplitterSplit[] memory splits = abi.decode(splitsRaw, (PaymentSplitterSplit[]));
        uint256 totalPercent = 0;
        for (uint256 i = 0; i < splits.length; i++) {
            totalPercent += splits[i].percent;
            _log(
                string.concat(
                    "Split: {to: ", vm.toString(splits[i].to), " percent: ", vm.toString(splits[i].percent), "}"
                ),
                4
            );
        }
        _log(string.concat("Total percent: ", vm.toString(totalPercent)), 4);
        bytes memory constructorArgs = abi.encode(deploymentOwner, totalPercent, splits);
        deployer.deployContract(paymentSplitterDeploymentName, creationCode, constructorArgs, 0);

        paymentSplitter = PaymentSplitter(deployer.getAddress(paymentSplitterDeploymentName));
        paymentSplitterExists = true;

        _log(string.concat("Payment splitter address: ", vm.toString(address(paymentSplitter))), 4);
    }

    function _deployAccountant() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;
        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(accountantDeploymentName);

        if (isDeployed) {
            accountantExists = true;
            accountant = AccountantWithYieldStreaming(deployedAddress);
            accountantName = "Accountant-AlreadyDeployed"; // @todo figure if we want to hardcode something else?
            bytes memory accountantDeploymentParametersRawDeployed =
                vm.parseJson(rawJson, ".accountantConfiguration.accountantParameters.accountantDeploymentParameters");
            AccountantDeploymentParameters memory accountantDeploymentParametersDeployed =
                abi.decode(accountantDeploymentParametersRawDeployed, (AccountantDeploymentParameters));
            baseAsset = accountantDeploymentParametersDeployed.base.address_ == address(0)
                ? getAddress(sourceChain, accountantDeploymentParametersDeployed.base.name)
                : accountantDeploymentParametersDeployed.base.address_;
            return;
        }

        // Figure out the payout address and deploy payment splitter if needed.
        address payoutAddress =
            vm.parseJsonAddress(rawJson, ".accountantConfiguration.accountantParameters.payoutConfiguration.payoutTo");
        if (payoutAddress == address(0)) {
            _deployPaymentSplitter();
        }

        accountantKind = _handleAccountantSelection(vm.parseJsonString(rawJson, ".accountantConfiguration.type"));
        if (accountantKind == AccountantKind.VariableRate) {
            creationCode = type(AccountantWithRateProviders).creationCode;
            accountantName = "AccountantWithRateProviders";
            _log("Accountant with rate providers deployment TX added", 3);
        } else if (accountantKind == AccountantKind.FixedRate) {
            creationCode = type(AccountantWithFixedRate).creationCode;
            accountantName = "AccountantWithFixedRate";
            _log("Fixed rate accountant deployment TX added", 3);
        } else if (accountantKind == AccountantKind.YieldStreaming) {
            creationCode = type(AccountantWithYieldStreaming).creationCode;
            accountantName = "AccountantWithYieldStreaming";
            _log("Yield streaming accountant deployment TX added", 3);
        }

        // Get AccountantDeploymentParameters from configuration file.
        bytes memory accountantDeploymentParametersRaw =
            vm.parseJson(rawJson, ".accountantConfiguration.accountantParameters.accountantDeploymentParameters");
        AccountantDeploymentParameters memory accountantDeploymentParameters =
            abi.decode(accountantDeploymentParametersRaw, (AccountantDeploymentParameters));
        baseAsset = accountantDeploymentParameters.base.address_ == address(0)
            ? getAddress(sourceChain, accountantDeploymentParameters.base.name)
            : accountantDeploymentParameters.base.address_;
        constructorArgs = abi.encode(
            deploymentOwner,
            address(boringVault),
            payoutAddress,
            accountantDeploymentParameters.startingExchangeRate,
            baseAsset,
            accountantDeploymentParameters.allowedExchangeRateChangeUpper,
            accountantDeploymentParameters.allowedExchangeRateChangeLower,
            accountantDeploymentParameters.minimumUpateDelayInSeconds,
            accountantDeploymentParameters.platformFee,
            accountantDeploymentParameters.performanceFee
        );

        deployer.deployContract(accountantDeploymentName, creationCode, constructorArgs, 0);

        accountant = AccountantWithYieldStreaming(deployer.getAddress(accountantDeploymentName));
        accountantExists = true;

        _log(string.concat("Payout address: ", vm.toString(payoutAddress)), 4);
        _log(
            string.concat("Starting exchange rate: ", vm.toString(accountantDeploymentParameters.startingExchangeRate)),
            4
        );
        _log(string.concat("Base address: ", vm.toString(baseAsset)), 4);
        _log(
            string.concat(
                "Allowed exchange rate change upper: ",
                vm.toString(accountantDeploymentParameters.allowedExchangeRateChangeUpper)
            ),
            4
        );
        _log(
            string.concat(
                "Allowed exchange rate change lower: ",
                vm.toString(accountantDeploymentParameters.allowedExchangeRateChangeLower)
            ),
            4
        );
        _log(
            string.concat(
                "Minimum update delay in seconds: ",
                vm.toString(accountantDeploymentParameters.minimumUpateDelayInSeconds)
            ),
            4
        );
        _log(string.concat("Platform fee: ", vm.toString(accountantDeploymentParameters.platformFee)), 4);
        _log(string.concat("Performance fee: ", vm.toString(accountantDeploymentParameters.performanceFee)), 4);
    }

    function _deployTeller() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;

        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(tellerDeploymentName);

        if (isDeployed) {
            teller = TellerWithYieldStreaming(deployedAddress);
            tellerExists = true;
            tellerName = "Teller-AlreadyDeployed"; // @todo figure if we want to hardcode something else?
            return;
        }

        _log(string.concat("Teller deployment name: ", tellerDeploymentName), 4);
        address nativeWrapperAddress = _handleAddressOrName(".deploymentParameters.nativeWrapperAddressOrName");
        _log(string.concat("Native wrapper address: ", vm.toString(nativeWrapperAddress)), 4);
        string memory tellerType = vm.parseJsonString(rawJson, ".tellerConfiguration.type");
        _log(string.concat("Teller type: ", tellerType), 3);

        tellerKind = _handleTellerSelection(tellerType);
        if (tellerKind == TellerKind.Teller) {
            (creationCode, constructorArgs) = _getArgsForTellerWithMultiAssetSupport(nativeWrapperAddress);
        } else if (tellerKind == TellerKind.TellerWithYieldStreaming) {
            (creationCode, constructorArgs) = _getArgsForTellerWithYieldStreaming(nativeWrapperAddress);
        } else if (tellerKind == TellerKind.TellerWithRemediation) {
            (creationCode, constructorArgs) = _getArgsForTellerWithRemediation(nativeWrapperAddress);
        } else if (tellerKind == TellerKind.TellerWithCcip) {
            (creationCode, constructorArgs) = _getArgsForTellerWithCcip(nativeWrapperAddress);
        } else if (tellerKind == TellerKind.TellerWithLayerZero) {
            (creationCode, constructorArgs) = _getArgsForTellerWithLayerZero(nativeWrapperAddress);
        } else if (tellerKind == TellerKind.TellerWithLayerZeroRateLimiting) {
            (creationCode, constructorArgs) = _getArgsForTellerWithLayerZeroRateLimiting(nativeWrapperAddress);
        } else {
            revert DeployError("Invalid teller creation code");
        }

        deployer.deployContract(tellerDeploymentName, creationCode, constructorArgs, 0);

        teller = TellerWithYieldStreaming(deployer.getAddress(tellerDeploymentName));
        tellerExists = true;

        _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
        _log(string.concat("Accountant address: ", vm.toString(address(accountant))), 4);
        _log(string.concat("Native wrapper address: ", vm.toString(nativeWrapperAddress)), 4);

        _log("Teller deployment TX added", 3);
    }

    function _getArgsForTellerWithMultiAssetSupport(address nativeWrapperAddress)
        internal
        returns (bytes memory creationCode, bytes memory constructorArgs)
    {
        tellerName = "TellerWithMultiAssetSupport";
        creationCode = type(TellerWithMultiAssetSupport).creationCode;
        constructorArgs = abi.encode(deploymentOwner, address(boringVault), address(accountant), nativeWrapperAddress);
        _log("Normal Teller deployment TX added", 3);
    }

    function _getArgsForTellerWithYieldStreaming(address nativeWrapperAddress)
        internal
        returns (bytes memory creationCode, bytes memory constructorArgs)
    {
        tellerName = "TellerWithYieldStreaming";
        creationCode = type(TellerWithYieldStreaming).creationCode;
        constructorArgs = abi.encode(deploymentOwner, address(boringVault), address(accountant), nativeWrapperAddress);
        _log("Teller with Yield Streaming deployment TX added", 3);
    }

    function _getArgsForTellerWithRemediation(address nativeWrapperAddress)
        internal
        returns (bytes memory creationCode, bytes memory constructorArgs)
    {
        tellerName = "TellerWithRemediation";
        creationCode = type(TellerWithRemediation).creationCode;
        constructorArgs = abi.encode(deploymentOwner, address(boringVault), address(accountant), nativeWrapperAddress);
        _log("Teller with remediation deployment TX added", 3);
    }

    function _getArgsForTellerWithCcip(address nativeWrapperAddress)
        internal
        returns (bytes memory creationCode, bytes memory constructorArgs)
    {
        tellerName = "TellerWithCcip";
        creationCode = type(ChainlinkCCIPTeller).creationCode;
        // Get other config params from configuration file.
        address tellerWithCcipRouterAddress =
            _handleAddressOrName(".tellerConfiguration.tellerParameters.ccip.routerAddressOrName");

        constructorArgs = abi.encode(
            deploymentOwner,
            address(boringVault),
            address(accountant),
            nativeWrapperAddress,
            tellerWithCcipRouterAddress
        );
        _log("Teller with CCIP deployment TX added", 3);
        _log(string.concat("CCIP router address: ", vm.toString(tellerWithCcipRouterAddress)), 4);
    }

    function _getArgsForTellerWithLayerZero(address nativeWrapperAddress)
        internal
        returns (bytes memory creationCode, bytes memory constructorArgs)
    {
        tellerName = "TellerWithLayerZero";
        creationCode = type(LayerZeroTeller).creationCode;
        // Read the endpoint and lztoken from the configuration file.
        address layerZeroEndpointAddress =
            _handleAddressOrName(".tellerConfiguration.tellerParameters.layerZero.endpointAddressOrName");
        address layerZeroTokenAddress =
            _handleAddressOrName(".tellerConfiguration.tellerParameters.layerZero.lzTokenAddressOrName");
        constructorArgs = abi.encode(
            deploymentOwner,
            address(boringVault),
            address(accountant),
            nativeWrapperAddress,
            layerZeroEndpointAddress,
            deploymentOwner,
            layerZeroTokenAddress
        );
        _log("Teller with LayerZero deployment TX added", 3);
        _log(string.concat("LayerZero endpoint address: ", vm.toString(layerZeroEndpointAddress)), 4);
        _log(string.concat("LayerZero token address: ", vm.toString(layerZeroTokenAddress)), 4);
    }

    function _getArgsForTellerWithLayerZeroRateLimiting(address nativeWrapperAddress)
        internal
        returns (bytes memory creationCode, bytes memory constructorArgs)
    {
        tellerName = "TellerWithLayerZeroRateLimiting";
        creationCode = type(LayerZeroTellerWithRateLimiting).creationCode;
        // Read the endpoint and lztoken from the configuration file.
        address layerZeroEndpointAddress =
            _handleAddressOrName(".tellerConfiguration.tellerParameters.layerZero.endpointAddressOrName");
        address layerZeroTokenAddress =
            _handleAddressOrName(".tellerConfiguration.tellerParameters.layerZero.lzTokenAddressOrName");
        constructorArgs = abi.encode(
            deploymentOwner,
            address(boringVault),
            address(accountant),
            nativeWrapperAddress,
            layerZeroEndpointAddress,
            deploymentOwner,
            layerZeroTokenAddress
        );
        _log("Teller with LayerZero Rate Limiting deployment TX added", 3);
        _log(string.concat("LayerZero endpoint address: ", vm.toString(layerZeroEndpointAddress)), 4);
        _log(string.concat("LayerZero token address: ", vm.toString(layerZeroTokenAddress)), 4);
    }

    function _deployBoringOnChainQueue() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;

        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(queueDeploymentName);

        if (isDeployed) {
            queue = BoringOnChainQueue(deployedAddress);
            queueExists = true;
            return;
        }

        // Read configuration to determine type of queue to deploy.
        string memory boringQueueType = vm.parseJsonString(rawJson, ".boringQueueConfiguration.type");
        QueueKind queueKind = _handleBoringQueueSelection(boringQueueType);
        if (queueKind == QueueKind.BoringQueue) {
            (creationCode, constructorArgs) = _getArgsForBoringQueue();
        } else if (queueKind == QueueKind.BoringQueueWithTracking) {
            (creationCode, constructorArgs) = _getArgsForBoringQueueWithTracking();
        } else {
            revert DeployError("Invalid queue creation code");
        }

        deployer.deployContract(queueDeploymentName, creationCode, constructorArgs, 0);

        queue = BoringOnChainQueue(deployer.getAddress(queueDeploymentName));
        queueExists = true;

        _log("Queue deployment TX added", 3);
    }

    function _getArgsForBoringQueue() internal view returns (bytes memory creationCode, bytes memory constructorArgs) {
        creationCode = type(BoringOnChainQueue).creationCode;
        constructorArgs = abi.encode(deploymentOwner, address(0), address(boringVault), address(accountant));
        _log("Boring on chain queue deployment TX added", 3);
    }

    function _getArgsForBoringQueueWithTracking()
        internal
        view
        returns (bytes memory creationCode, bytes memory constructorArgs)
    {
        creationCode = type(BoringOnChainQueueWithTracking).creationCode;
        constructorArgs = abi.encode(deploymentOwner, address(0), address(boringVault), address(accountant), false);
        _log("Boring on chain queue with tracking deployment TX added", 3);
    }

    function _deployQueueSolver() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;

        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(queueSolverDeploymentName);

        if (isDeployed) {
            queueSolver = BoringSolver(deployedAddress);
            queueSolverExists = true;
            return;
        }

        creationCode = type(BoringSolver).creationCode;
        // Read config to determine excessToSolverNonSelfSolve constructor argument.
        bool excessToSolverNonSelfSolve =
            vm.parseJsonBool(rawJson, ".boringQueueConfiguration.excessToSolverNonSelfSolve");
        constructorArgs = abi.encode(deploymentOwner, address(0), address(queue), excessToSolverNonSelfSolve);
        _log("Boring solver deployment TX added", 3);
        _log(string.concat("Boring queue address: ", vm.toString(address(queue))), 4);
        deployer.deployContract(queueSolverDeploymentName, creationCode, constructorArgs, 0);
        queueSolver = BoringSolver(deployer.getAddress(queueSolverDeploymentName));
        queueSolverExists = true;
    }

    function _deployPauser() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;

        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(pauserDeploymentName);
        // Read config to determine if pauser should be deployed.
        bool shouldDeployPauser = vm.parseJsonBool(rawJson, ".pauserConfiguration.shouldDeploy");
        if (shouldDeployPauser) {
            pauser = Pauser(deployedAddress);
            if (!isDeployed) {
                // Create pausables array.
                address[] memory pausables = new address[](4);
                pausables[0] = address(teller);
                pausables[1] = address(queue);
                pausables[2] = address(accountant);
                pausables[3] = address(manager);
                creationCode = type(Pauser).creationCode;
                constructorArgs = abi.encode(deploymentOwner, address(0), pausables);

                _log("Pauser deployment TX added", 3);
                deployer.deployContract(pauserDeploymentName, creationCode, constructorArgs, 0);
            } else {
                pauserExists = true;
            }
        }
    }

    function _deployTimelock() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;
        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(timelockDeploymentName);
        // Read config to determine if timelock should be deployed.
        bool shouldDeployTimelock = vm.parseJsonBool(rawJson, ".timelockConfiguration.shouldDeploy");
        if (shouldDeployTimelock) {
            if (isDeployed) {
                timelockExists = true;
                timelock = TimelockController(payable(deployedAddress));
                return;
            }

            creationCode = type(TimelockController).creationCode;
            // Read timelock parameters from configuration file.
            bytes memory timelockParametersRaw = vm.parseJson(rawJson, ".timelockConfiguration.timelockParameters");
            TimelockParameters memory timelockParameters = abi.decode(timelockParametersRaw, (TimelockParameters));
            constructorArgs = abi.encode(
                timelockParameters.minDelay,
                timelockParameters.proposers,
                timelockParameters.executors,
                address(0) // Default super admin to zero address for timelock self management
            );
            _log("Timelock deployment TX added", 3);
            _log(string.concat("Min delay: ", vm.toString(timelockParameters.minDelay)), 4);
            for (uint256 i; i < timelockParameters.proposers.length; ++i) {
                _log(string.concat("Proposer: ", vm.toString(timelockParameters.proposers[i])), 4);
            }
            for (uint256 i; i < timelockParameters.executors.length; ++i) {
                _log(string.concat("Executor: ", vm.toString(timelockParameters.executors[i])), 4);
            }
            deployer.deployContract(timelockDeploymentName, creationCode, constructorArgs, 0);
            timelock = TimelockController(payable(deployer.getAddress(timelockDeploymentName)));
            timelockExists = true;
        }
    }

    function _deployDrones() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;

        droneCount = vm.parseJsonUint(rawJson, ".droneConfiguration.droneCount");
        safeGasToForwardNative = vm.parseJsonUint(rawJson, ".droneConfiguration.safeGasToForwardNative");

        for (uint256 i; i < droneCount; ++i) {
            string memory droneName = string.concat(droneBaseDeploymentName, "-", vm.toString(i));
            (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(droneName);
            droneAddresses.push(deployedAddress);
            if (!isDeployed) {
                creationCode = type(BoringDrone).creationCode;
                constructorArgs = abi.encode(address(boringVault), safeGasToForwardNative);
                deployer.deployContract(droneName, creationCode, constructorArgs, 0);
                _log(string.concat("Boring drone deployment TX added: ", droneName), 3);
            }
        }
    }

    function _saveContractAddresses() internal virtual {
        // Save deployment details.
        _log("Saving deployment details...", 3);
        // Read deployment file name from configuration file.
        string memory deploymentFileName = vm.parseJsonString(rawJson, ".deploymentParameters.deploymentFileName");
        string memory filePath = string.concat("./deployments/", deploymentFileName);
        _log(string.concat("Deployment file path: ", filePath), 3);
        if (vm.exists(filePath)) {
            // Need to delete it
            vm.removeFile(filePath);
        }

        {
            {
                string memory coreContracts = "core contracts key";
                vm.serializeAddress(coreContracts, "RolesAuthority", address(rolesAuthority));
                vm.serializeAddress(coreContracts, "Lens", address(lens));
                vm.serializeAddress(coreContracts, "BoringVault", address(boringVault));
                vm.serializeAddress(coreContracts, "ManagerWithMerkleVerification", address(manager));
                vm.serializeAddress(coreContracts, "Pauser", address(pauser));
                vm.serializeAddress(coreContracts, "Timelock", address(timelock));

                // There can be different accountant and teller names, so we serialize them by name.
                vm.serializeAddress(coreContracts, accountantName, address(accountant));
                vm.serializeAddress(coreContracts, tellerName, address(teller));

                if (address(aaveV3BufferHelper) != address(0)) {
                    vm.serializeAddress(coreContracts, "AaveV3BufferHelper", address(aaveV3BufferHelper));
                }
                if (address(aaveV3BufferLens) != address(0)) {
                    vm.serializeAddress(coreContracts, "AaveV3BufferLens", address(aaveV3BufferLens));
                }
                vm.serializeAddress(coreContracts, "BoringOnChainQueue", address(queue));
                coreOutput = vm.serializeAddress(coreContracts, "QueueSolver", address(queueSolver));
            }

            {
                string memory drones = "drone key";
                for (uint256 i; i < droneAddresses.length; i++) {
                    droneOutput =
                        vm.serializeAddress(drones, string.concat("drone-", vm.toString(i)), droneAddresses[i]);
                }
            }

            vm.serializeString(finalJson, "contractAddresses", coreOutput);
            finalJson = vm.serializeString(finalJson, "Drones", droneOutput);

            vm.writeJson(finalJson, filePath);
        }
    }

    function _handleAddressOrName(string memory key) internal view returns (address) {
        bytes memory addressOrNameRaw = vm.parseJson(rawJson, key);
        AddressOrName memory addressOrName = abi.decode(addressOrNameRaw, (AddressOrName));
        return
            addressOrName.address_ == address(0) ? getAddress(sourceChain, addressOrName.name) : addressOrName.address_;
    }

    function _handleTellerSelection(string memory value) internal pure returns (TellerKind) {
        if (keccak256(abi.encode(value)) == keccak256(abi.encode("teller"))) {
            return TellerKind.Teller;
        } else if (keccak256(abi.encode(value)) == keccak256(abi.encode("tellerWithRemediation"))) {
            return TellerKind.TellerWithRemediation;
        } else if (keccak256(abi.encode(value)) == keccak256(abi.encode("tellerWithCcip"))) {
            return TellerKind.TellerWithCcip;
        } else if (keccak256(abi.encode(value)) == keccak256(abi.encode("tellerWithLayerZero"))) {
            return TellerKind.TellerWithLayerZero;
        } else if (keccak256(abi.encode(value)) == keccak256(abi.encode("tellerWithLayerZeroRateLimiting"))) {
            return TellerKind.TellerWithLayerZeroRateLimiting;
        } else if (keccak256(abi.encode(value)) == keccak256(abi.encode("tellerWithYieldStreaming"))) {
            return TellerKind.TellerWithYieldStreaming;
        }
        revert DeployError("Invalid teller kind");
    }

    function _handleBoringQueueSelection(string memory value) internal pure returns (QueueKind) {
        if (keccak256(abi.encode(value)) == keccak256(abi.encode("boringQueue"))) {
            return QueueKind.BoringQueue;
        } else if (keccak256(abi.encode(value)) == keccak256(abi.encode("boringQueueWithTracking"))) {
            return QueueKind.BoringQueueWithTracking;
        }
        revert DeployError("Invalid boring queue kind");
    }

    function _handleAccountantSelection(string memory value) internal pure returns (AccountantKind) {
        if (keccak256(abi.encode(value)) == keccak256(abi.encode("variableRate"))) {
            return AccountantKind.VariableRate;
        } else if (keccak256(abi.encode(value)) == keccak256(abi.encode("fixedRate"))) {
            return AccountantKind.FixedRate;
        } else if (keccak256(abi.encode(value)) == keccak256(abi.encode("yieldStreaming"))) {
            return AccountantKind.YieldStreaming;
        }
        revert DeployError("Invalid accountant kind");
    }
}
