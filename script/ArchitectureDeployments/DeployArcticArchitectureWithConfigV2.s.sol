// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault, Auth} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
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
import {AccountantWithRateProviders, IRateProvider} from "src/base/Roles/AccountantWithRateProviders.sol";
import {AccountantWithFixedRate} from "src/base/Roles/AccountantWithFixedRate.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {Pauser} from "src/base/Roles/Pauser.sol";
import "forge-std/Script.sol";
import {Roles} from "resources/Roles.sol";
import {DeploySkeletonV2Script} from "./DeploySkeletonV2.s.sol";
import {Deployer} from "src/helper/Deployer.sol";

/**
 * 
 * To do the simulation run the following command:
 * NOTE: It looks at the RPC url defined in foundry.toml
 * 
 * forge script script/ArchitectureDeployments/DeployArcticArchitectureWithConfigV2.s.sol:DeployArcticArchitectureWithConfigV2Script --sig "run(string)" configurations/Mainnet/InkedBTCNewConfig.json --slow -vvvvvv --sender 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b
 * 
 *  source .env && script/ArchitectureDeployments/DeployArcticArchitectureWithConfigV2.s.sol:DeployArcticArchitectureWithConfigV2Script --sig "run(string)" configurations/Mainnet/InkedBTCNewConfig.json --with-gas-price 3000000000 --broadcast --slow --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 * @dev for non etherscan explorers, pass in the verifier and verifier url:
 *      --verifier blockscout --verifier-url https://explorer.swellnetwork.io/api/
 *  source .env && script/ArchitectureDeployments/DeployArcticArchitectureWithConfigV2.s.sol:DeployArcticArchitectureWithConfigV2Script --sig "run(string)" configurations/Mainnet/InkedBTCNewConfig.json --with-gas-price 3000000000
 * @dev If getting `exceeds block gas limit` error, try passing in --block-gas-limit <BLOCK_GAS_LIMIT_FOR_CHAIN>
 */
contract DeployArcticArchitectureWithConfigV2Script is DeploySkeletonV2Script {
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

    Deployer.Tx[] internal txs;

    bool internal allowPublicDeposits;
    bool internal allowPublicWithdrawals;
    bool internal allowPublicSelfWithdraws;
    bool internal setupDepositAssets;
    bool internal setupWithdrawAssets;
    bool internal setupTestUser;

    Deployer internal txBundler;

    mapping(ERC20 => bool) internal isAccountantAsset;

    function run(string memory configurationFileName) public override {
        super.run(configurationFileName);

        if (vm.keyExists(rawJson, ".deploymentParameters.txBundlerAddressOrName")) {
            txBundler = Deployer(_handleAddressOrName(".deploymentParameters.txBundlerAddressOrName"));
            _log(string.concat("Tx bundler address: ", vm.toString(address(txBundler))), 3);
        }

        _setupRoles();
        _setupAccountantAssets();
        _setupDepositAssets();
        _setupWithdrawAssets();
        _setupCrossChainTeller();
        _setupPausers();
        _finalizeSetup();
        _setupTestUser();
        _bundleTxs();
    }

    function _addTx(address target, bytes memory data, uint256 value) internal {
        txs.push(Deployer.Tx(target, data, value));
    }

    function _bundleTxs() internal {
        uint256 txsLength = txs.length;

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
                txBundles[i][j] = txs[lastIndexDeployed + j];
            }
            lastIndexDeployed += txsInBundle;
        }

        for (uint256 i; i < desiredNumberOfDeploymentTxs; i++) {
            _log(string.concat("Sending bundle: ", vm.toString(i)), 4);
            Deployer(txBundler).bundleTxs(txBundles[i]);
        }
    }

    function _setupCrossChainTeller() internal {
        bool tellerWithCcip = tellerKind == TellerKind.TellerWithCcip;
        bool tellerWithLayerZero = tellerKind == TellerKind.TellerWithLayerZero;
        bool tellerWithLayerZeroRateLimiting = tellerKind == TellerKind.TellerWithLayerZeroRateLimiting;

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
            if (
                tellerKind == TellerKind.TellerWithLayerZero || tellerKind == TellerKind.TellerWithLayerZeroRateLimiting
            ) {
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
                if (
                    tellerKind == TellerKind.TellerWithCcip || tellerKind == TellerKind.TellerWithLayerZero
                        || tellerKind == TellerKind.TellerWithLayerZeroRateLimiting
                ) {
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

    function _saveContractAddresses() internal override {
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

    function _grantRoleIfNotGranted(uint8 role, address user) internal {
        if (rolesAuthorityExists) {
            if (rolesAuthority.doesUserHaveRole(user, role)) return;
        }
        _addTx({
            target: address(rolesAuthority),
            data: abi.encodeCall(rolesAuthority.setUserRole, (user, role, true)),
            value: 0
        });
    }

    function _setPublicCapabilityIfNotPresent(address target, bytes4 selector) internal {
        if (rolesAuthorityExists) {
            if (rolesAuthority.isCapabilityPublic(target, selector)) return;
        }
        _addTx({
            target: address(rolesAuthority),
            data: abi.encodeCall(rolesAuthority.setPublicCapability, (target, selector, true)),
            value: 0
        });
    }

    function _addRoleCapabilityIfNotPresent(uint8 role, address target, bytes4 selector) internal {
        if (rolesAuthorityExists) {
            if (rolesAuthority.doesRoleHaveCapability(role, target, selector)) return;
        }
        _addTx({
            target: address(rolesAuthority),
            data: abi.encodeCall(rolesAuthority.setRoleCapability, (role, target, selector, true)),
            value: 0
        });
    }
}
