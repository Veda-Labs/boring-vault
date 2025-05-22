// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault, Auth} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {TellerWithRemediation} from "src/base/Roles/TellerWithRemediation.sol";
import {
    ChainlinkCCIPTeller,
    CrossChainTellerWithGenericBridge
} from "src/base/Roles/CrossChain/Bridges/CCIP/ChainlinkCCIPTeller.sol";
import {LayerZeroTeller} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {LayerZeroTellerWithRateLimiting} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTellerWithRateLimiting.sol";
import {AccountantWithRateProviders, IRateProvider} from "src/base/Roles/AccountantWithRateProviders.sol";
import {AccountantWithFixedRate} from "src/base/Roles/AccountantWithFixedRate.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {ArcticArchitectureLens} from "src/helper/ArcticArchitectureLens.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {GenericRateProvider} from "src/helper/GenericRateProvider.sol";
import {DelayedWithdraw} from "src/base/Roles/DelayedWithdraw.sol";
import {BoringDrone} from "src/base/Drones/BoringDrone.sol";
import {ChainValues} from "test/resources/ChainValues.sol";
import {PaymentSplitter} from "src/helper/PaymentSplitter.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringOnChainQueueWithTracking} from "src/base/Roles/BoringQueue/BoringOnChainQueueWithTracking.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {Pauser} from "src/base/Roles/Pauser.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {console} from "@forge-std/Test.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/DeployArcticArchitectureWithConfig.s.sol:DeployArcticArchitectureWithConfigScript --sig "run(string)" config.json --with-gas-price 3000000000 --broadcast --slow --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 * @dev for non etherscan explorers, pass in the verifier and verifier url:
 *      --verifier blockscout --verifier-url https://explorer.swellnetwork.io/api/
 *  source .env && forge script script/ArchitectureDeployments/DeployArcticArchitectureWithConfig.s.sol:DeployArcticArchitectureWithConfigScript --sig "run(string)" "config.json" --with-gas-price 3000000000
 * @dev If getting `exceeds block gas limit` error, try passing in --block-gas-limit <BLOCK_GAS_LIMIT_FOR_CHAIN>
 */
contract DeployArcticArchitectureWithConfigScript is Script, ChainValues {
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

    struct CCIPChain {
        bool allowMessagesFrom;
        bool allowMessagesTo;
        uint64 chainSelector;
        uint64 messageGasLimit;
        TargetTellerOrSelf targetTellerOrSelf;
    }

    struct LayerZeroChain {
        bool allowMessagesFrom;
        bool allowMessagesTo;
        uint32 chainId;
        uint128 messageGasLimit;
        TargetTellerOrSelf targetTellerOrSelf;
    }

    struct SenderToPausable {
        address pausable;
        address sender;
    }

    // Contracts to deploy
    ArcticArchitectureLens public lens;
    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    RolesAuthority public rolesAuthority;
    address public rawDataDecoderAndSanitizer;
    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    DelayedWithdraw public delayedWithdrawer;
    PaymentSplitter public paymentSplitter;
    BoringOnChainQueue public queue;
    BoringSolver public queueSolver;
    Pauser public pauser;
    TimelockController public timelock;

    // Roles
    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant MINTER_ROLE = 2;
    uint8 public constant BURNER_ROLE = 3;
    uint8 public constant MANAGER_INTERNAL_ROLE = 4;
    uint8 public constant PAUSER_ROLE = 5;
    uint8 public constant SOLVER_ROLE = 12;
    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant MULTISIG_ROLE = 9;
    uint8 public constant STRATEGIST_MULTISIG_ROLE = 10;
    uint8 public constant STRATEGIST_ROLE = 7;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 11;
    uint8 public constant GENERIC_PAUSER_ROLE = 14;
    uint8 public constant GENERIC_UNPAUSER_ROLE = 15;
    uint8 public constant PAUSE_ALL_ROLE = 16;
    uint8 public constant UNPAUSE_ALL_ROLE = 17;
    uint8 public constant SENDER_PAUSER_ROLE = 18;
    uint8 public constant SENDER_UNPAUSER_ROLE = 19;
    uint8 public constant CAN_SOLVE_ROLE = 31;
    uint8 public constant ONLY_QUEUE_ROLE = 32;
    uint8 public constant SOLVER_ORIGIN_ROLE = 33;

    uint256 public droneCount;
    uint256 public safeGasToForwardNative;
    address[] internal droneAddresses;

    bytes public boringCreationCode;

    string finalJson;
    string coreOutput;
    string depositAssetConfigurationOutput;
    string withdrawAssetConfigurationOutput;
    string accountantConfigurationOutput;
    string depositConfigurationOutput;
    string droneOutput;

    enum AccountantKind {
        VariableRate,
        FixedRate
    }

    AccountantKind internal accountantKind;

    enum TellerKind {
        Teller,
        TellerWithRemediation,
        TellerWithCcip,
        TellerWithLayerZero,
        TellerWithLayerZeroRateLimiting
    }

    TellerKind internal tellerKind;

    bool internal allowPublicDeposits;
    bool internal allowPublicWithdrawals;
    bool internal allowPublicSelfWithdraws;
    bool internal setupDepositAssets;
    bool internal setupWithdrawAssets;
    bool internal finishSetup;
    bool internal setupTestUser;
    bool internal saveDeploymentDetails;

    address internal baseAsset;

    Deployer.Tx[] internal txs;

    mapping(ERC20 => bool) internal isAccountantAsset;

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

    function run(string memory configurationFileName) external {
        {
            string memory root = vm.projectRoot();
            string memory configurationPath = string.concat(root, "/deployments/configurations/", configurationFileName);
            rawJson = vm.readFile(configurationPath);
        }

        if (vm.keyExists(rawJson, ".deploymentParameters.logLevel")) {
            logLevel = vm.parseJsonUint(rawJson, ".deploymentParameters.logLevel");
            _log("Log level found in configuration file.", 3);
        } else {
            revert KeyNotFound(".deploymentParameters.logLevel");
        }
        if (vm.keyExists(rawJson, ".deploymentParameters.privateKeyEnvName")) {
            privateKey = vm.envUint(vm.parseJsonString(rawJson, ".deploymentParameters.privateKeyEnvName"));
            _log("Private key found in configuration file.", 3);
        } else {
            revert KeyNotFound(".deploymentParameters.privateKeyEnvName");
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
        } else {
            revert KeyNotFound(".deploymentParameters.deploymentOwnerAddressOrName");
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

        // Get Deployer address from configuration file.
        deployer = Deployer(_handleAddressOrName(".deploymentParameters.deployerContractAddressOrName"));

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
        _setupRoles();
        _setupAccountantAssets();
        _setupDepositAssets();
        _setupWithdrawAssets();
        _setupCrossChainTeller();
        _setupPausers();
        _finalizeSetup();
        _setupTestUser();
        _saveContractAddresses();
        _bundleTxs();
    }

    function _deployRolesAuthority() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;
        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(rolesAuthorityDeploymentName);
        rolesAuthority = RolesAuthority(deployedAddress);
        if (!isDeployed) {
            creationCode = type(RolesAuthority).creationCode;
            constructorArgs = abi.encode(deploymentOwner, Authority(address(0)));
            _addTx(
                address(deployer),
                abi.encodeWithSelector(
                    deployer.deployContract.selector, rolesAuthorityDeploymentName, creationCode, constructorArgs, 0
                ),
                uint256(0)
            );
            _log("Roles authority deployment TX added", 3);
        } else {
            rolesAuthorityExists = true;
        }
    }

    function _deployLens() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;
        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(lensDeploymentName);
        lens = ArcticArchitectureLens(deployedAddress);
        if (!isDeployed) {
            creationCode = type(ArcticArchitectureLens).creationCode;
            constructorArgs = hex"";
            _addTx(
                address(deployer),
                abi.encodeWithSelector(
                    deployer.deployContract.selector, lensDeploymentName, creationCode, constructorArgs, 0
                ),
                uint256(0)
            );
            _log("Lens deployment TX added", 3);
        }
    }

    function _deployBoringVault() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;
        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(boringVaultDeploymentName);
        boringVault = BoringVault(payable(deployedAddress));
        if (!isDeployed) {
            creationCode = type(BoringVault).creationCode;
            // Get boringVaultName, boringVaultSymbol, and boringVaultDecimals from configuration file.
            string memory boringVaultName = vm.parseJsonString(rawJson, ".boringVaultConfiguration.boringVaultName");
            string memory boringVaultSymbol = vm.parseJsonString(rawJson, ".boringVaultConfiguration.boringVaultSymbol");
            uint256 boringVaultDecimals = vm.parseJsonUint(rawJson, ".boringVaultConfiguration.boringVaultDecimals");
            constructorArgs = abi.encode(deploymentOwner, boringVaultName, boringVaultSymbol, boringVaultDecimals);
            _addTx(
                address(deployer),
                abi.encodeWithSelector(
                    deployer.deployContract.selector, boringVaultDeploymentName, creationCode, constructorArgs, 0
                ),
                uint256(0)
            );
            _log("Boring vault deployment TX added", 3);
            _log(string.concat("Boring vault name: ", boringVaultName), 4);
            _log(string.concat("Boring vault symbol: ", boringVaultSymbol), 4);
            _log(string.concat("Boring vault decimals: ", vm.toString(boringVaultDecimals)), 4);
        } else {
            boringVaultExists = true;
        }
    }

    function _deployManager() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;
        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(managerDeploymentName);
        manager = ManagerWithMerkleVerification(deployedAddress);
        if (!isDeployed) {
            // Read balancerVault from configuration file.
            bytes memory balancerVaultRaw = vm.parseJson(rawJson, ".managerConfiguration.balancerVaultAddressOrName");
            AddressOrName memory balancerVault = abi.decode(balancerVaultRaw, (AddressOrName));
            address balancerVaultAddress = balancerVault.address_ == address(0)
                ? getAddress(sourceChain, balancerVault.name)
                : balancerVault.address_;
            creationCode = type(ManagerWithMerkleVerification).creationCode;
            constructorArgs = abi.encode(deploymentOwner, address(boringVault), balancerVaultAddress);
            _addTx(
                address(deployer),
                abi.encodeWithSelector(
                    deployer.deployContract.selector, managerDeploymentName, creationCode, constructorArgs, 0
                ),
                uint256(0)
            );
            _log("Manager deployment TX added", 3);
            _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
            _log(string.concat("Balancer vault address: ", vm.toString(balancerVaultAddress)), 4);
        } else {
            managerExists = true;
        }
    }

    function _deployAccountant() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;
        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(accountantDeploymentName);
        accountant = AccountantWithRateProviders(deployedAddress);
        if (!isDeployed) {
            // Figure out the payout address.
            address payoutAddress = vm.parseJsonAddress(
                rawJson, ".accountantConfiguration.accountantParameters.payoutConfiguration.payoutTo"
            );
            if (payoutAddress == address(0)) {
                // Need to deploy a payment splitter.
                string memory paymentSplitterDeploymentName = vm.parseJsonString(
                    rawJson,
                    ".accountantConfiguration.accountantParameters.payoutConfiguration.optionalPaymentSplitterName"
                );
                (payoutAddress, isDeployed) = _getAddressAndIfDeployed(paymentSplitterDeploymentName);
                paymentSplitter = PaymentSplitter(payoutAddress);
                if (!isDeployed) {
                    creationCode = type(PaymentSplitter).creationCode;
                    // Read the splits from the configuration file.
                    bytes memory splitsRaw = vm.parseJson(
                        rawJson, ".accountantConfiguration.accountantParameters.payoutConfiguration.splits"
                    );
                    _log("Payment splitter deployment TX added", 3);
                    PaymentSplitterSplit[] memory splits = abi.decode(splitsRaw, (PaymentSplitterSplit[]));
                    uint256 totalPercent = 0;
                    for (uint256 i = 0; i < splits.length; i++) {
                        totalPercent += splits[i].percent;
                        _log(
                            string.concat(
                                "Split: {to: ",
                                vm.toString(splits[i].to),
                                " percent: ",
                                vm.toString(splits[i].percent),
                                "}"
                            ),
                            4
                        );
                    }
                    _log(string.concat("Total percent: ", vm.toString(totalPercent)), 4);
                    constructorArgs = abi.encode(deploymentOwner, totalPercent, splits);
                    _addTx(
                        address(deployer),
                        abi.encodeWithSelector(
                            deployer.deployContract.selector,
                            paymentSplitterDeploymentName,
                            creationCode,
                            constructorArgs,
                            0
                        ),
                        uint256(0)
                    );
                }
            }
            // Figure out what kind of accountant to deploy.
            bool variableRate =
                vm.parseJsonBool(rawJson, ".accountantConfiguration.accountantParameters.kind.variableRate");
            bool fixedRate = vm.parseJsonBool(rawJson, ".accountantConfiguration.accountantParameters.kind.fixedRate");
            if (variableRate && fixedRate) {
                _log("Invalid accountant kind", 1);
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
            if (variableRate) {
                // Deploy VariableRateAccountant.
                creationCode = type(AccountantWithRateProviders).creationCode;
                accountantKind = AccountantKind.VariableRate;
                _log("Accountant with rate providers deployment TX added", 3);
            } else if (fixedRate) {
                // Deploy FixedRateAccountant.
                creationCode = type(AccountantWithFixedRate).creationCode;
                accountantKind = AccountantKind.FixedRate;
                _log("Fixed rate accountant deployment TX added", 3);
            } else {
                _log("Accountant kind not set in configuration file", 1);
            }
            _addTx(
                address(deployer),
                abi.encodeWithSelector(
                    deployer.deployContract.selector, accountantDeploymentName, creationCode, constructorArgs, 0
                ),
                uint256(0)
            );
            _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
            _log(string.concat("Payout address: ", vm.toString(payoutAddress)), 4);
            _log(
                string.concat(
                    "Starting exchange rate: ", vm.toString(accountantDeploymentParameters.startingExchangeRate)
                ),
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
        } else {
            bytes memory accountantDeploymentParametersRaw =
                vm.parseJson(rawJson, ".accountantConfiguration.accountantParameters.accountantDeploymentParameters");
            AccountantDeploymentParameters memory accountantDeploymentParameters =
                abi.decode(accountantDeploymentParametersRaw, (AccountantDeploymentParameters));
            baseAsset = accountantDeploymentParameters.base.address_ == address(0)
                ? getAddress(sourceChain, accountantDeploymentParameters.base.name)
                : accountantDeploymentParameters.base.address_;
            accountantExists = true;
        }
    }

    function _deployTeller() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;
        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(tellerDeploymentName);
        teller = TellerWithMultiAssetSupport(deployedAddress);
        if (!isDeployed) {
            // Get native wrapper address from configuration file.
            address nativeWrapperAddress = _handleAddressOrName(".deploymentParameters.nativeWrapperAddressOrName");
            // Figure out what kind of teller to deploy.
            bool tellerKindSet;
            bool normalTeller = vm.parseJsonBool(rawJson, ".tellerConfiguration.tellerParameters.kind.teller");
            if (normalTeller) {
                creationCode = type(TellerWithMultiAssetSupport).creationCode;
                tellerKind = TellerKind.Teller;
                constructorArgs =
                    abi.encode(deploymentOwner, address(boringVault), address(accountant), nativeWrapperAddress);
                tellerKindSet = true;
                _log("Normal Teller deployment TX added", 3);
                _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
                _log(string.concat("Accountant address: ", vm.toString(address(accountant))), 4);
                _log(string.concat("Native wrapper address: ", vm.toString(nativeWrapperAddress)), 4);
            }
            bool tellerWithRemediation =
                vm.parseJsonBool(rawJson, ".tellerConfiguration.tellerParameters.kind.tellerWithRemediation");
            if (tellerWithRemediation) {
                if (tellerKindSet) {
                    _log("Teller kind already set", 1);
                }
                creationCode = type(TellerWithRemediation).creationCode;
                tellerKind = TellerKind.TellerWithRemediation;
                constructorArgs =
                    abi.encode(deploymentOwner, address(boringVault), address(accountant), nativeWrapperAddress);
                tellerKindSet = true;
                _log("Teller with remediation deployment TX added", 3);
                _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
                _log(string.concat("Accountant address: ", vm.toString(address(accountant))), 4);
                _log(string.concat("Native wrapper address: ", vm.toString(nativeWrapperAddress)), 4);
            }
            bool tellerWithCcip = vm.parseJsonBool(rawJson, ".tellerConfiguration.tellerParameters.kind.tellerWithCcip");
            if (tellerWithCcip) {
                if (tellerKindSet) {
                    _log("Teller kind already set", 1);
                }
                creationCode = type(ChainlinkCCIPTeller).creationCode;
                tellerKind = TellerKind.TellerWithCcip;
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
                tellerKindSet = true;
                _log("Teller with CCIP deployment TX added", 3);
                _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
                _log(string.concat("Accountant address: ", vm.toString(address(accountant))), 4);
                _log(string.concat("Native wrapper address: ", vm.toString(nativeWrapperAddress)), 4);
                _log(string.concat("CCIP router address: ", vm.toString(tellerWithCcipRouterAddress)), 4);
            }
            bool tellerWithLayerZero =
                vm.parseJsonBool(rawJson, ".tellerConfiguration.tellerParameters.kind.tellerWithLayerZero");
            if (tellerWithLayerZero) {
                if (tellerKindSet) {
                    _log("Teller kind already set", 1);
                }
                creationCode = type(LayerZeroTeller).creationCode;
                tellerKind = TellerKind.TellerWithLayerZero;
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
                tellerKindSet = true;
                _log("Teller with LayerZero deployment TX added", 3);
                _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
                _log(string.concat("Accountant address: ", vm.toString(address(accountant))), 4);
                _log(string.concat("Native wrapper address: ", vm.toString(nativeWrapperAddress)), 4);
                _log(string.concat("LayerZero endpoint address: ", vm.toString(layerZeroEndpointAddress)), 4);
                _log(string.concat("LayerZero token address: ", vm.toString(layerZeroTokenAddress)), 4);
            }
            bool tellerWithLayerZeroRateLimiting =
                vm.parseJsonBool(rawJson, ".tellerConfiguration.tellerParameters.kind.tellerWithLayerZeroRateLimiting");
            if (tellerWithLayerZeroRateLimiting) {
                if (tellerKindSet) {
                    _log("Teller kind already set", 1);
                }
                creationCode = type(LayerZeroTellerWithRateLimiting).creationCode;
                tellerKind = TellerKind.TellerWithLayerZeroRateLimiting;
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
                tellerKindSet = true;
                _log("Teller with LayerZero Rate Limiting deployment TX added", 3);
                _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
                _log(string.concat("Accountant address: ", vm.toString(address(accountant))), 4);
                _log(string.concat("Native wrapper address: ", vm.toString(nativeWrapperAddress)), 4);
                _log(string.concat("LayerZero endpoint address: ", vm.toString(layerZeroEndpointAddress)), 4);
                _log(string.concat("LayerZero token address: ", vm.toString(layerZeroTokenAddress)), 4);
            }

            _addTx(
                address(deployer),
                abi.encodeWithSelector(
                    deployer.deployContract.selector, tellerDeploymentName, creationCode, constructorArgs, 0
                ),
                uint256(0)
            );
        } else {
            tellerExists = true;
        }
    }

    function _setupCrossChainTeller() internal {
        bool tellerWithCcip = vm.parseJsonBool(rawJson, ".tellerConfiguration.tellerParameters.kind.tellerWithCcip");
        bool tellerWithLayerZero =
            vm.parseJsonBool(rawJson, ".tellerConfiguration.tellerParameters.kind.tellerWithLayerZero");
        bool tellerWithLayerZeroRateLimiting = 
            vm.parseJsonBool(rawJson, ".tellerConfiguration.tellerParameters.kind.tellerWithLayerZeroRateLimiting");
        if (tellerWithCcip || tellerWithLayerZero || tellerWithLayerZeroRateLimiting) {
            _log("Setting up cross chain teller", 3);
            if (tellerWithCcip) {
                // Set CCIP chains.
                bytes memory ccipChainsRaw =
                    vm.parseJson(rawJson, ".tellerConfiguration.tellerParameters.ccip.ccipChains");
                CCIPChain[] memory ccipChains = abi.decode(ccipChainsRaw, (CCIPChain[]));
                for (uint256 i; i < ccipChains.length; ++i) {
                    _addTx(
                        address(teller),
                        abi.encodeWithSelector(
                            ChainlinkCCIPTeller.addChain.selector,
                            ccipChains[i].chainSelector,
                            ccipChains[i].allowMessagesFrom,
                            ccipChains[i].allowMessagesTo,
                            ccipChains[i].targetTellerOrSelf.self
                                ? address(teller)
                                : ccipChains[i].targetTellerOrSelf.address_,
                            ccipChains[i].messageGasLimit
                        ),
                        uint256(0)
                    );
                }
            } else if (tellerWithLayerZero || tellerWithLayerZeroRateLimiting) {
                // Set LayerZero chains.
                bytes memory lzChainsRaw =
                    vm.parseJson(rawJson, ".tellerConfiguration.tellerParameters.layerZero.lzChains");
                LayerZeroChain[] memory lzChains = abi.decode(lzChainsRaw, (LayerZeroChain[]));
                for (uint256 i; i < lzChains.length; ++i) {
                    _addTx(
                        address(teller),
                        abi.encodeWithSelector(
                            LayerZeroTeller.addChain.selector,
                            lzChains[i].chainId,
                            lzChains[i].allowMessagesFrom,
                            lzChains[i].allowMessagesTo,
                            lzChains[i].targetTellerOrSelf.self
                                ? address(teller)
                                : lzChains[i].targetTellerOrSelf.address_,
                            lzChains[i].messageGasLimit
                        ),
                        uint256(0)
                    );
                }
            }
        } // else do nothing
    }

    function _deployBoringOnChainQueue() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;
        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(queueDeploymentName);
        queue = BoringOnChainQueue(deployedAddress);
        if (!isDeployed) {
            // Read configuration to determine kind.
            bool boringQueue = vm.parseJsonBool(rawJson, ".boringQueueConfiguration.queueParameters.kind.boringQueue");
            bool boringQueueWithTracking =
                vm.parseJsonBool(rawJson, ".boringQueueConfiguration.queueParameters.kind.boringQueueWithTracking");
            if (boringQueue && boringQueueWithTracking) {
                _log("Invalid boring queue kind", 1);
            } else if (boringQueue) {
                constructorArgs = abi.encode(deploymentOwner, address(0), address(boringVault), address(accountant));
                creationCode = type(BoringOnChainQueue).creationCode;
                _log("Boring on chain queue deployment TX added", 3);
            } else if (boringQueueWithTracking) {
                constructorArgs =
                    abi.encode(deploymentOwner, address(0), address(boringVault), address(accountant), false);
                creationCode = type(BoringOnChainQueueWithTracking).creationCode;
                _log("Boring on chain queue with tracking deployment TX added", 3);
            }
            _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
            _log(string.concat("Accountant address: ", vm.toString(address(accountant))), 4);
            _addTx(
                address(deployer),
                abi.encodeWithSelector(
                    deployer.deployContract.selector, queueDeploymentName, creationCode, constructorArgs, 0
                ),
                uint256(0)
            );
        } else {
            queueExists = true;
        }
    }

    function _deployQueueSolver() internal {
        bytes memory constructorArgs;
        bytes memory creationCode;
        (address deployedAddress, bool isDeployed) = _getAddressAndIfDeployed(queueSolverDeploymentName);
        queueSolver = BoringSolver(deployedAddress);
        if (!isDeployed) {
            creationCode = type(BoringSolver).creationCode;
            // Read config to determine excessToSolverNonSelfSolve constructor argument.
            bool excessToSolverNonSelfSolve = vm.parseJsonBool(rawJson, ".boringQueueConfiguration.excessToSolverNonSelfSolve");
            constructorArgs = abi.encode(deploymentOwner, address(0), address(queue), excessToSolverNonSelfSolve);
            _log("Boring solver deployment TX added", 3);
            _log(string.concat("Boring queue address: ", vm.toString(address(queue))), 4);
            _addTx(
                address(deployer),
                abi.encodeWithSelector(
                    deployer.deployContract.selector, queueSolverDeploymentName, creationCode, constructorArgs, 0
                ),
                uint256(0)
            );
        } else {
            queueSolverExists = true;
        }
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
                _addTx(
                    address(deployer),
                    abi.encodeWithSelector(
                        deployer.deployContract.selector, pauserDeploymentName, creationCode, constructorArgs, 0
                    ),
                    uint256(0)
                );
            } else {
                pauserExists = true;
            }
        }
    }

    function _setupPausers() internal {
        bool shouldDeployPauser = vm.parseJsonBool(rawJson, ".pauserConfiguration.shouldDeploy");
        if (shouldDeployPauser) {
            // Read the configuration for pauser roles
            address[] memory genericPausers =
                vm.parseJsonAddressArray(rawJson, ".pauserConfiguration.makeGenericPauser");
            address[] memory genericUnpausers =
                vm.parseJsonAddressArray(rawJson, ".pauserConfiguration.makeGenericUnpauser");
            address[] memory pauseAll = vm.parseJsonAddressArray(rawJson, ".pauserConfiguration.makePauseAll");
            address[] memory unpauseAll = vm.parseJsonAddressArray(rawJson, ".pauserConfiguration.makeUnpauseAll");
            bytes memory senderToPausableRaw = vm.parseJson(rawJson, ".pauserConfiguration.senderToPausable");
            SenderToPausable[] memory senderToPausables = abi.decode(senderToPausableRaw, (SenderToPausable[]));

            // Assign roles to generic pausers
            for (uint256 i = 0; i < genericPausers.length; i++) {
                _grantRoleIfNotGranted(GENERIC_PAUSER_ROLE, genericPausers[i]);
            }

            // Assign roles to generic unpausers
            for (uint256 i = 0; i < genericUnpausers.length; i++) {
                _grantRoleIfNotGranted(GENERIC_UNPAUSER_ROLE, genericUnpausers[i]);
            }

            // Assign roles to pause all
            for (uint256 i = 0; i < pauseAll.length; i++) {
                _grantRoleIfNotGranted(PAUSE_ALL_ROLE, pauseAll[i]);
            }

            // Assign roles to unpause all
            for (uint256 i = 0; i < unpauseAll.length; i++) {
                _grantRoleIfNotGranted(UNPAUSE_ALL_ROLE, unpauseAll[i]);
            }

            // Assign sender pauser roles
            for (uint256 i = 0; i < senderToPausables.length; i++) {
                _log(
                    string.concat(
                        "Pauables Sender: ",
                        vm.toString(senderToPausables[i].sender),
                        " to Pausable: ",
                        vm.toString(senderToPausables[i].pausable)
                    ),
                    4
                );
                _addTx(
                    address(pauser),
                    abi.encodeWithSelector(
                        Pauser.updateSenderToPausable.selector,
                        senderToPausables[i].sender,
                        senderToPausables[i].pausable
                    ),
                    0
                );
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
            timelock = TimelockController(payable(deployedAddress));
            if (!isDeployed) {
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
                _addTx(
                    address(deployer),
                    abi.encodeWithSelector(
                        deployer.deployContract.selector, timelockDeploymentName, creationCode, constructorArgs, 0
                    ),
                    uint256(0)
                );
            } else {
                timelockExists = true;
            }
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
                _addTx(
                    address(deployer),
                    abi.encodeWithSelector(
                        deployer.deployContract.selector, droneName, creationCode, constructorArgs, 0
                    ),
                    uint256(0)
                );
                _log(string.concat("Boring drone deployment TX added: ", droneName), 3);
            }
        }
    }

    function _setupRoles() internal {
        // Check if we are setting up roles.
        bool setupRoles = vm.parseJsonBool(rawJson, ".deploymentParameters.setupRoles");
        if (setupRoles) {
            // Setup roles for boring vault.
            _addRoleCapabilityIfNotPresent(
                MANAGER_ROLE, address(boringVault), bytes4(abi.encodeWithSignature("manage(address,bytes,uint256)"))
            );
            _addRoleCapabilityIfNotPresent(
                MANAGER_ROLE,
                address(boringVault),
                bytes4(abi.encodeWithSignature("manage(address[],bytes[],uint256[])"))
            );
            _addRoleCapabilityIfNotPresent(MINTER_ROLE, address(boringVault), BoringVault.enter.selector);
            _addRoleCapabilityIfNotPresent(BURNER_ROLE, address(boringVault), BoringVault.exit.selector);
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(boringVault), BoringVault.setBeforeTransferHook.selector);
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(boringVault), Auth.setAuthority.selector);
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(boringVault), Auth.transferOwnership.selector);

            // Setup roles for manager.
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector
            );
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(manager), Auth.setAuthority.selector);
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(manager), Auth.transferOwnership.selector);
            _addRoleCapabilityIfNotPresent(
                MANAGER_INTERNAL_ROLE,
                address(manager),
                ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector
            );
            _addRoleCapabilityIfNotPresent(PAUSER_ROLE, address(manager), ManagerWithMerkleVerification.pause.selector);
            _addRoleCapabilityIfNotPresent(
                PAUSER_ROLE, address(manager), ManagerWithMerkleVerification.unpause.selector
            );
            _addRoleCapabilityIfNotPresent(
                STRATEGIST_ROLE,
                address(manager),
                ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector
            );

            // Setup roles for accountant.
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(accountant), AccountantWithRateProviders.setRateProviderData.selector
            );
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateDelay.selector
            );
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateUpper.selector
            );
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateLower.selector
            );
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(accountant), AccountantWithRateProviders.updatePlatformFee.selector
            );
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(accountant), AccountantWithRateProviders.updatePerformanceFee.selector
            );
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(accountant), AccountantWithRateProviders.updatePayoutAddress.selector
            );
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(accountant), Auth.setAuthority.selector);
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(accountant), Auth.transferOwnership.selector);
            if (accountantKind == AccountantKind.VariableRate) {
                _addRoleCapabilityIfNotPresent(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.resetHighwaterMark.selector
                );
            } else if (accountantKind == AccountantKind.FixedRate) {
                _addRoleCapabilityIfNotPresent(
                    OWNER_ROLE, address(accountant), AccountantWithFixedRate.setYieldDistributor.selector
                );
            }
            _addRoleCapabilityIfNotPresent(PAUSER_ROLE, address(accountant), AccountantWithRateProviders.pause.selector);
            _addRoleCapabilityIfNotPresent(
                PAUSER_ROLE, address(accountant), AccountantWithRateProviders.unpause.selector
            );
            _addRoleCapabilityIfNotPresent(
                UPDATE_EXCHANGE_RATE_ROLE, address(accountant), AccountantWithRateProviders.updateExchangeRate.selector
            );

            // Setup roles for teller.
            _addRoleCapabilityIfNotPresent(
                SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector
            );
            _addRoleCapabilityIfNotPresent(
                SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector
            );
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(teller), TellerWithMultiAssetSupport.updateAssetData.selector
            );
            _addRoleCapabilityIfNotPresent(
                STRATEGIST_MULTISIG_ROLE, address(teller), TellerWithMultiAssetSupport.updateAssetData.selector
            );
            _addRoleCapabilityIfNotPresent(PAUSER_ROLE, address(teller), TellerWithMultiAssetSupport.pause.selector);
            _addRoleCapabilityIfNotPresent(PAUSER_ROLE, address(teller), TellerWithMultiAssetSupport.unpause.selector);
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(teller), TellerWithMultiAssetSupport.setShareLockPeriod.selector
            );
            _addRoleCapabilityIfNotPresent(
                STRATEGIST_MULTISIG_ROLE, address(teller), TellerWithMultiAssetSupport.refundDeposit.selector
            );
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(teller), Auth.setAuthority.selector);
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(teller), Auth.transferOwnership.selector);
            allowPublicDeposits = vm.parseJsonBool(rawJson, ".tellerConfiguration.tellerParameters.allowPublicDeposits");
            if (tellerKind == TellerKind.TellerWithCcip) {
                _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(teller), ChainlinkCCIPTeller.addChain.selector);
                _addRoleCapabilityIfNotPresent(MULTISIG_ROLE, address(teller), ChainlinkCCIPTeller.removeChain.selector);
                _addRoleCapabilityIfNotPresent(
                    OWNER_ROLE, address(teller), ChainlinkCCIPTeller.allowMessagesFromChain.selector
                );
                _addRoleCapabilityIfNotPresent(
                    OWNER_ROLE, address(teller), ChainlinkCCIPTeller.allowMessagesToChain.selector
                );
                _addRoleCapabilityIfNotPresent(
                    MULTISIG_ROLE, address(teller), ChainlinkCCIPTeller.stopMessagesFromChain.selector
                );
                _addRoleCapabilityIfNotPresent(
                    MULTISIG_ROLE, address(teller), ChainlinkCCIPTeller.stopMessagesToChain.selector
                );
                _addRoleCapabilityIfNotPresent(
                    OWNER_ROLE, address(teller), ChainlinkCCIPTeller.setChainGasLimit.selector
                );
            }
            if (tellerKind == TellerKind.TellerWithLayerZero || tellerKind == TellerKind.TellerWithLayerZeroRateLimiting) {
                _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(teller), LayerZeroTeller.addChain.selector);
                _addRoleCapabilityIfNotPresent(MULTISIG_ROLE, address(teller), LayerZeroTeller.removeChain.selector);
                _addRoleCapabilityIfNotPresent(
                    OWNER_ROLE, address(teller), LayerZeroTeller.allowMessagesFromChain.selector
                );
                _addRoleCapabilityIfNotPresent(
                    OWNER_ROLE, address(teller), LayerZeroTeller.allowMessagesToChain.selector
                );
                _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(teller), LayerZeroTeller.setChainGasLimit.selector);
                _addRoleCapabilityIfNotPresent(
                    MULTISIG_ROLE, address(teller), LayerZeroTeller.stopMessagesFromChain.selector
                );
                _addRoleCapabilityIfNotPresent(
                    MULTISIG_ROLE, address(teller), LayerZeroTeller.stopMessagesToChain.selector
                );
            }
            if (allowPublicDeposits) {
                _setPublicCapabilityIfNotPresent(address(teller), TellerWithMultiAssetSupport.deposit.selector);
                _setPublicCapabilityIfNotPresent(
                    address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector
                );
                if (tellerKind == TellerKind.TellerWithCcip || tellerKind == TellerKind.TellerWithLayerZero || tellerKind == TellerKind.TellerWithLayerZeroRateLimiting) {
                    _setPublicCapabilityIfNotPresent(
                        address(teller), CrossChainTellerWithGenericBridge.depositAndBridge.selector
                    );
                    _setPublicCapabilityIfNotPresent(
                        address(teller), CrossChainTellerWithGenericBridge.depositAndBridgeWithPermit.selector
                    );
                    _setPublicCapabilityIfNotPresent(address(teller), CrossChainTellerWithGenericBridge.bridge.selector);
                }
            }

            // Setup roles for queue.
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(queue), BoringOnChainQueue.rescueTokens.selector);
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(queue), Auth.setAuthority.selector);
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(queue), Auth.transferOwnership.selector);
            _addRoleCapabilityIfNotPresent(
                MULTISIG_ROLE, address(queue), BoringOnChainQueue.updateWithdrawAsset.selector
            );
            _addRoleCapabilityIfNotPresent(
                MULTISIG_ROLE, address(queue), BoringOnChainQueue.stopWithdrawsInAsset.selector
            );
            _addRoleCapabilityIfNotPresent(
                MULTISIG_ROLE, address(queue), BoringOnChainQueue.setWithdrawCapacity.selector
            );
            _addRoleCapabilityIfNotPresent(
                STRATEGIST_MULTISIG_ROLE, address(queue), BoringOnChainQueue.stopWithdrawsInAsset.selector
            );
            _addRoleCapabilityIfNotPresent(
                STRATEGIST_MULTISIG_ROLE, address(queue), BoringOnChainQueue.cancelUserWithdraws.selector
            );
            _addRoleCapabilityIfNotPresent(
                CAN_SOLVE_ROLE, address(queue), BoringOnChainQueue.solveOnChainWithdraws.selector
            );
            _addRoleCapabilityIfNotPresent(
                SOLVER_ORIGIN_ROLE, address(queue), BoringOnChainQueue.solveOnChainWithdraws.selector
            );
            _addRoleCapabilityIfNotPresent(
                STRATEGIST_MULTISIG_ROLE, address(queue), BoringOnChainQueue.setWithdrawCapacity.selector
            );
            _addRoleCapabilityIfNotPresent(ONLY_QUEUE_ROLE, address(queueSolver), BoringSolver.boringSolve.selector);

            allowPublicWithdrawals =
                vm.parseJsonBool(rawJson, ".boringQueueConfiguration.queueParameters.allowPublicWithdrawals");
            if (allowPublicWithdrawals) {
                _setPublicCapabilityIfNotPresent(address(queue), BoringOnChainQueue.requestOnChainWithdraw.selector);
                _setPublicCapabilityIfNotPresent(
                    address(queue), BoringOnChainQueue.requestOnChainWithdrawWithPermit.selector
                );
                _setPublicCapabilityIfNotPresent(address(queue), BoringOnChainQueue.cancelOnChainWithdraw.selector);
                _setPublicCapabilityIfNotPresent(address(queue), BoringOnChainQueue.replaceOnChainWithdraw.selector);
            }

            // Setup roles for Queue Solver.
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(queueSolver), Auth.setAuthority.selector);
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(queueSolver), Auth.transferOwnership.selector);
            _addRoleCapabilityIfNotPresent(
                SOLVER_ORIGIN_ROLE, address(queueSolver), BoringSolver.boringRedeemSolve.selector
            );
            _addRoleCapabilityIfNotPresent(
                SOLVER_ORIGIN_ROLE, address(queueSolver), BoringSolver.boringRedeemMintSolve.selector
            );

            allowPublicSelfWithdraws =
                vm.parseJsonBool(rawJson, ".boringQueueConfiguration.queueParameters.allowPublicSelfWithdrawals");
            if (allowPublicSelfWithdraws) {
                _setPublicCapabilityIfNotPresent(address(queueSolver), BoringSolver.boringRedeemSelfSolve.selector);
                _setPublicCapabilityIfNotPresent(address(queueSolver), BoringSolver.boringRedeemMintSelfSolve.selector);
            }

            // Setup roles for pauser.
            _addRoleCapabilityIfNotPresent(PAUSE_ALL_ROLE, address(pauser), Pauser.pauseAll.selector);
            _addRoleCapabilityIfNotPresent(UNPAUSE_ALL_ROLE, address(pauser), Pauser.unpauseAll.selector);
            _addRoleCapabilityIfNotPresent(SENDER_PAUSER_ROLE, address(pauser), Pauser.senderPause.selector);
            _addRoleCapabilityIfNotPresent(SENDER_UNPAUSER_ROLE, address(pauser), Pauser.senderUnpause.selector);
            _addRoleCapabilityIfNotPresent(GENERIC_PAUSER_ROLE, address(pauser), Pauser.pauseSingle.selector);
            _addRoleCapabilityIfNotPresent(GENERIC_PAUSER_ROLE, address(pauser), Pauser.pauseMultiple.selector);
            _addRoleCapabilityIfNotPresent(GENERIC_UNPAUSER_ROLE, address(pauser), Pauser.unpauseSingle.selector);
            _addRoleCapabilityIfNotPresent(GENERIC_UNPAUSER_ROLE, address(pauser), Pauser.unpauseMultiple.selector);

            // No roles to setup for timelock.
        }
    }

    function _setupAccountantAssets() internal {
        isAccountantAsset[ERC20(baseAsset)] = true;
        bytes memory accountantAssetsRaw = vm.parseJson(rawJson, ".accountantAssets");
        AccountantAsset[] memory accountantAssets = abi.decode(accountantAssetsRaw, (AccountantAsset[]));
        for (uint256 i; i < accountantAssets.length; i++) {
            AccountantAsset memory accountantAsset = accountantAssets[i];
            ERC20 asset = accountantAsset.addressOrName.address_ == address(0)
                ? getERC20(sourceChain, accountantAsset.addressOrName.name)
                : ERC20(accountantAsset.addressOrName.address_);
            isAccountantAsset[asset] = true;
            // Check if the accountant supports it.
            if (accountantExists) {
                (bool isPeggedToBase, IRateProvider rateProvider) = accountant.rateProviderData(asset);
                if (isPeggedToBase || address(rateProvider) != address(0)) {
                    continue;
                }
            }
            _log(string.concat("Adding asset to accountant: ", accountantAsset.addressOrName.name), 3);
            _addTx(
                address(accountant),
                abi.encodeWithSelector(
                    accountant.setRateProviderData.selector,
                    asset,
                    accountantAsset.isPeggedToBase,
                    accountantAsset.rateProvider
                ),
                0
            );
        }
    }

    function _setupDepositAssets() internal {
        // Read deposit assets from configuration file.
        bytes memory depositAssetsRaw = vm.parseJson(rawJson, ".depositAssets");
        DepositAsset[] memory depositAssets = abi.decode(depositAssetsRaw, (DepositAsset[]));
        for (uint256 i; i < depositAssets.length; i++) {
            DepositAsset memory depositAsset = depositAssets[i];
            // See if teller already supports it.
            ERC20 asset = depositAsset.addressOrName.address_ == address(0)
                ? getERC20(sourceChain, depositAsset.addressOrName.name)
                : ERC20(depositAsset.addressOrName.address_);
            if (tellerExists) {
                (bool allowDeposits,,) = teller.assetData(asset);
                if (allowDeposits) continue;
            }
            if (!isAccountantAsset[asset]) {
                // We are missing rate provider data so revert.
                _log(
                    string.concat(
                        "Asset is not supported but attempting to add it to teller: ", depositAsset.addressOrName.name
                    ),
                    1
                );
            }

            _log(string.concat("Adding asset to teller: ", depositAsset.addressOrName.name), 3);
            _log(string.concat("allowDeposits: ", vm.toString(depositAsset.allowDeposits)), 3);
            _log(string.concat("allowWithdraws: ", vm.toString(depositAsset.allowWithdraws)), 3);
            _log(string.concat("sharePremium: ", vm.toString(depositAsset.sharePremium)), 3);
            _addTx(
                address(teller),
                abi.encodeWithSelector(
                    teller.updateAssetData.selector,
                    asset,
                    depositAsset.allowDeposits,
                    depositAsset.allowWithdraws,
                    depositAsset.sharePremium
                ),
                0
            );
        }
    }

    function _setupWithdrawAssets() internal {
        // Read withdraw assets from configuration file.
        bytes memory withdrawAssetsRaw = vm.parseJson(rawJson, ".withdrawAssets");
        WithdrawAsset[] memory withdrawAssets = abi.decode(withdrawAssetsRaw, (WithdrawAsset[]));
        for (uint256 i; i < withdrawAssets.length; i++) {
            WithdrawAsset memory withdrawAsset = withdrawAssets[i];
            // See if teller already supports it.
            ERC20 asset = withdrawAsset.addressOrName.address_ == address(0)
                ? getERC20(sourceChain, withdrawAsset.addressOrName.name)
                : ERC20(withdrawAsset.addressOrName.address_);
            // Check if the asset is already supported by the queue.
            if (queueExists) {
                (bool allowWithdraws,,,,,,) = queue.withdrawAssets(address(asset));
                if (allowWithdraws) continue;
            }

            if (!isAccountantAsset[asset]) {
                // We are missing rate provider data so revert.
                _log(
                    string.concat(
                        "Asset is not supported by accountant but attempting to add it to queue: ",
                        withdrawAsset.addressOrName.name
                    ),
                    1
                );
            }

            _log(string.concat("Adding asset to queue: ", withdrawAsset.addressOrName.name), 3);
            _addTx(
                address(queue),
                abi.encodeWithSelector(
                    queue.updateWithdrawAsset.selector,
                    asset,
                    withdrawAsset.secondsToMaturity,
                    withdrawAsset.minimumSecondsToDeadline,
                    withdrawAsset.minDiscount,
                    withdrawAsset.maxDiscount,
                    withdrawAsset.minimumShares
                ),
                0
            );
        }
    }

    function _finalizeSetup() internal {
        _log("Finalizing setup...", 3);
        uint256 shareLockPeriod = vm.parseJsonUint(rawJson, ".tellerConfiguration.tellerParameters.shareLockPeriod");
        if (tellerExists) {
            // Get sharelock period from configuration file.
            if (teller.shareLockPeriod() != shareLockPeriod) {
                _addTx(
                    address(teller),
                    abi.encodeWithSelector(teller.setShareLockPeriod.selector, uint64(shareLockPeriod)),
                    0
                );
            }
            if (teller.authority() != rolesAuthority) {
                _addTx(address(teller), abi.encodeWithSelector(teller.setAuthority.selector, rolesAuthority), 0);
            }
            if (teller.owner() != address(0)) {
                _addTx(address(teller), abi.encodeWithSelector(teller.transferOwnership.selector, address(0)), 0);
            }
        } else {
            _addTx(
                address(teller), abi.encodeWithSelector(teller.setShareLockPeriod.selector, uint64(shareLockPeriod)), 0
            );
            _addTx(address(teller), abi.encodeWithSelector(teller.setAuthority.selector, rolesAuthority), 0);
            _addTx(address(teller), abi.encodeWithSelector(teller.transferOwnership.selector, address(0)), 0);
        }

        if (boringVaultExists) {
            if (boringVault.authority() != rolesAuthority) {
                _addTx(
                    address(boringVault), abi.encodeWithSelector(boringVault.setAuthority.selector, rolesAuthority), 0
                );
            }
            if (address(boringVault.hook()) != address(teller)) {
                _addTx(
                    address(boringVault),
                    abi.encodeWithSelector(boringVault.setBeforeTransferHook.selector, address(teller)),
                    0
                );
            }
            if (boringVault.owner() != address(0)) {
                _addTx(
                    address(boringVault), abi.encodeWithSelector(boringVault.transferOwnership.selector, address(0)), 0
                );
            }
        } else {
            _addTx(address(boringVault), abi.encodeWithSelector(boringVault.setAuthority.selector, rolesAuthority), 0);
            _addTx(
                address(boringVault),
                abi.encodeWithSelector(boringVault.setBeforeTransferHook.selector, address(teller)),
                0
            );
            _addTx(address(boringVault), abi.encodeWithSelector(boringVault.transferOwnership.selector, address(0)), 0);
        }

        if (managerExists) {
            if (manager.authority() != rolesAuthority) {
                _addTx(address(manager), abi.encodeWithSelector(manager.setAuthority.selector, rolesAuthority), 0);
            }
            if (manager.owner() != address(0)) {
                _addTx(address(manager), abi.encodeWithSelector(manager.transferOwnership.selector, address(0)), 0);
            }
        } else {
            _addTx(address(manager), abi.encodeWithSelector(manager.setAuthority.selector, rolesAuthority), 0);
            _addTx(address(manager), abi.encodeWithSelector(manager.transferOwnership.selector, address(0)), 0);
        }

        if (accountantExists) {
            if (accountant.authority() != rolesAuthority) {
                _addTx(address(accountant), abi.encodeWithSelector(accountant.setAuthority.selector, rolesAuthority), 0);
            }
            if (accountant.owner() != address(0)) {
                _addTx(
                    address(accountant), abi.encodeWithSelector(accountant.transferOwnership.selector, address(0)), 0
                );
            }
        } else {
            _addTx(address(accountant), abi.encodeWithSelector(accountant.setAuthority.selector, rolesAuthority), 0);
            _addTx(address(accountant), abi.encodeWithSelector(accountant.transferOwnership.selector, address(0)), 0);
        }

        if (queueExists) {
            if (queue.authority() != rolesAuthority) {
                _addTx(address(queue), abi.encodeWithSelector(queue.setAuthority.selector, rolesAuthority), 0);
            }
            if (queue.owner() != address(0)) {
                _addTx(address(queue), abi.encodeWithSelector(queue.transferOwnership.selector, address(0)), 0);
            }
        } else {
            _addTx(address(queue), abi.encodeWithSelector(queue.setAuthority.selector, rolesAuthority), 0);
            _addTx(address(queue), abi.encodeWithSelector(queue.transferOwnership.selector, address(0)), 0);
        }

        if (queueSolverExists) {
            if (queueSolver.authority() != rolesAuthority) {
                _addTx(
                    address(queueSolver), abi.encodeWithSelector(queueSolver.setAuthority.selector, rolesAuthority), 0
                );
            }
            if (queueSolver.owner() != address(0)) {
                _addTx(
                    address(queueSolver), abi.encodeWithSelector(queueSolver.transferOwnership.selector, address(0)), 0
                );
            }
        } else {
            _addTx(address(queueSolver), abi.encodeWithSelector(queueSolver.setAuthority.selector, rolesAuthority), 0);
            _addTx(address(queueSolver), abi.encodeWithSelector(queueSolver.transferOwnership.selector, address(0)), 0);
        }

        bool shouldDeployPauser = vm.parseJsonBool(rawJson, ".pauserConfiguration.shouldDeploy");
        if (shouldDeployPauser) {
            if (pauserExists) {
                if (pauser.authority() != rolesAuthority) {
                    _addTx(address(pauser), abi.encodeWithSelector(pauser.setAuthority.selector, rolesAuthority), 0);
                }
                if (pauser.owner() != address(0)) {
                    _addTx(address(pauser), abi.encodeWithSelector(pauser.transferOwnership.selector, address(0)), 0);
                }
            } else {
                _addTx(address(pauser), abi.encodeWithSelector(pauser.setAuthority.selector, rolesAuthority), 0);
                _addTx(address(pauser), abi.encodeWithSelector(pauser.transferOwnership.selector, address(0)), 0);
            }
        }

        // Setup roles.
        _grantRoleIfNotGranted(MANAGER_ROLE, address(manager));
        _grantRoleIfNotGranted(MANAGER_INTERNAL_ROLE, address(manager));
        _grantRoleIfNotGranted(MINTER_ROLE, address(teller));
        _grantRoleIfNotGranted(BURNER_ROLE, address(teller));
        _grantRoleIfNotGranted(SOLVER_ROLE, address(queueSolver));
        _grantRoleIfNotGranted(CAN_SOLVE_ROLE, address(queueSolver));
    }

    function _setupTestUser() internal {
        // Setup test user.
        _log("Setting up test user...", 3);
        address testUser = _handleAddressOrName(".deploymentParameters.testUserAddressOrName");
        _grantRoleIfNotGranted(OWNER_ROLE, testUser);
        _grantRoleIfNotGranted(STRATEGIST_ROLE, testUser);
        if (rolesAuthorityExists) {
            address currentOwner = rolesAuthority.owner();
            if (currentOwner != testUser) {
                _addTx(
                    address(rolesAuthority),
                    abi.encodeWithSelector(rolesAuthority.transferOwnership.selector, testUser),
                    0
                );
            }
        } else {
            _addTx(
                address(rolesAuthority), abi.encodeWithSelector(rolesAuthority.transferOwnership.selector, testUser), 0
            );
        }
    }

    function _saveContractAddresses() internal {
        // Save deployment details.
        _log("Saving deployment details...", 3);
        // Read deployment file name from configuration file.
        string memory deploymentFileName = vm.parseJsonString(rawJson, ".deploymentParameters.deploymentFileName");
        string memory filePath = string.concat("./deployments/", deploymentFileName);
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
                if (accountantKind == AccountantKind.VariableRate) {
                    vm.serializeAddress(coreContracts, "AccountantWithRateProviders", address(accountant));
                } else if (accountantKind == AccountantKind.FixedRate) {
                    vm.serializeAddress(coreContracts, "AccountantWithFixedRate", address(accountant));
                }
                if (tellerKind == TellerKind.Teller) {
                    vm.serializeAddress(coreContracts, "TellerWithMultiAssetSupport", address(teller));
                } else if (tellerKind == TellerKind.TellerWithRemediation) {
                    vm.serializeAddress(coreContracts, "TellerWithRemediation", address(teller));
                } else if (tellerKind == TellerKind.TellerWithCcip) {
                    vm.serializeAddress(coreContracts, "TellerWithCcip", address(teller));
                } else if (tellerKind == TellerKind.TellerWithLayerZero) {
                    vm.serializeAddress(coreContracts, "TellerWithLayerZero", address(teller));
                } else if (tellerKind == TellerKind.TellerWithLayerZeroRateLimiting) {
                    vm.serializeAddress(coreContracts, "TellerWithLayerZeroRateLimiting", address(teller));
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

    function _bundleTxs() internal {
        Deployer.Tx[] memory txsToSend = getTxs();
        uint256 txsLength = txsToSend.length;

        if (txsLength == 0) {
            _log("No txs to bundle", 3);
            return;
        }

        // Determine how many txs to send
        uint256 desiredNumberOfDeploymentTxs =
            vm.parseJsonUint(rawJson, ".deploymentParameters.desiredNumberOfDeploymentTxs");
        if (desiredNumberOfDeploymentTxs == 0) {
            _log("Desired number of deployment txs is 0", 1);
        }
        desiredNumberOfDeploymentTxs =
            desiredNumberOfDeploymentTxs > txsLength ? txsLength : desiredNumberOfDeploymentTxs;
        uint256 txsPerBundle = txsLength / desiredNumberOfDeploymentTxs;
        uint256 lastIndexDeployed;
        Deployer.Tx[][] memory txBundles = new Deployer.Tx[][](desiredNumberOfDeploymentTxs);

        _log(string.concat("Tx bundles to send: ", vm.toString(desiredNumberOfDeploymentTxs)), 4);
        _log(string.concat("Total txs: ", vm.toString(txsLength)), 4);

        for (uint256 i; i < desiredNumberOfDeploymentTxs; i++) {
            uint256 txsInBundle;
            if (i == desiredNumberOfDeploymentTxs - 1 && txsLength % txsPerBundle != 0) {
                txsInBundle = txsLength - lastIndexDeployed;
            } else {
                txsInBundle = txsPerBundle;
            }
            txBundles[i] = new Deployer.Tx[](txsInBundle);
            for (uint256 j; j < txBundles[i].length; j++) {
                txBundles[i][j] = txsToSend[lastIndexDeployed + j];
            }
            lastIndexDeployed += txsInBundle;
        }

        // Read tx bundler address from configuration file.
        address txBundler = _handleAddressOrName(".deploymentParameters.txBundlerAddressOrName");

        // TODO maybe I could have this save the txs to a json if it fails?
        vm.startBroadcast(privateKey);
        for (uint256 i; i < desiredNumberOfDeploymentTxs; i++) {
            _log(string.concat("Sending bundle: ", vm.toString(i)), 4);
            Deployer(txBundler).bundleTxs(txBundles[i]);
        }
        vm.stopBroadcast();
    }

    function _grantRoleIfNotGranted(uint8 role, address user) internal {
        if (rolesAuthorityExists) {
            if (rolesAuthority.doesUserHaveRole(user, role)) return;
        }
        _addTx(
            address(rolesAuthority), abi.encodeWithSelector(rolesAuthority.setUserRole.selector, user, role, true), 0
        );
    }

    function _setPublicCapabilityIfNotPresent(address target, bytes4 selector) internal {
        if (rolesAuthorityExists) {
            if (rolesAuthority.isCapabilityPublic(target, selector)) return;
        }
        _addTx(
            address(rolesAuthority),
            abi.encodeWithSelector(rolesAuthority.setPublicCapability.selector, target, selector, true),
            0
        );
    }

    function _addRoleCapabilityIfNotPresent(uint8 role, address target, bytes4 selector) internal {
        if (rolesAuthorityExists) {
            if (rolesAuthority.doesRoleHaveCapability(role, target, selector)) return;
        }
        _addTx(
            address(rolesAuthority),
            abi.encodeWithSelector(rolesAuthority.setRoleCapability.selector, role, target, selector, true),
            0
        );
    }

    function _handleAddressOrName(string memory key) internal view returns (address) {
        bytes memory addressOrNameRaw = vm.parseJson(rawJson, key);
        AddressOrName memory addressOrName = abi.decode(addressOrNameRaw, (AddressOrName));
        return
            addressOrName.address_ == address(0) ? getAddress(sourceChain, addressOrName.name) : addressOrName.address_;
    }
}
