# Boring Vault Audit Scope

## Overview

This document outlines the contracts in scope for the Boring Vault audit. The codebase has undergone extensive previous auditing (30-50 different audits), with most contracts being well-tested and reviewed. The focus should be on newer, less audited contracts.

## Must-Have Contracts (Primary Audit Scope)

**Total Estimated Lines of Code: ~1,700**

### Core Vault Infrastructure

- **BoringVault** (120 LOC) - [Source](https://github.com/Veda-Labs/boring-vault/blob/main/src/base/BoringVault.sol)
  - Base vault implementation
  - Previously audited multiple times

### Role-Based Contracts

- **TellerWithMultiAssetSupport** (550 LOC) - [Source](https://github.com/Veda-Labs/boring-vault/blob/main/src/base/Roles/TellerWithMultiAssetSupport.sol)

  - Multi-asset withdrawal functionality
  - Previously audited multiple times

- **TellerWithBuffer** (40 LOC) - [Source](https://github.com/Veda-Labs/boring-vault/blob/490bc21b0d0e13567c0a810fb27c9d797f999bd2/src/base/Roles/TellerWithBuffer.sol)

  - **⚠️ HIGH PRIORITY: Under development, needs thorough review**
  - Instant withdrawals and auto-strategy functionality
  - New contract requiring detailed audit focus

- **AccountantWithRateProviders** (520 LOC) - [Source](https://github.com/Veda-Labs/boring-vault/blob/main/src/base/Roles/AccountantWithRateProviders.sol)

  - Rate provider integration for accounting
  - Previously audited multiple times

- **AccountantWithYieldStreaming** (250 LOC) - [Source](https://github.com/Veda-Labs/boring-vault/blob/54a085773ce48d91da8220beb75a95ca0a091075/src/base/Roles/AccountantWithYieldStreaming.sol)
  - **⚠️ HIGH PRIORITY: Under development, needs thorough review**
  - Yield streaming functionality
  - New contract requiring detailed audit focus

### Helper Contracts

- **GenericRateProvider** (100 LOC) - [Source](https://github.com/Veda-Labs/boring-vault/blob/main/src/helper/GenericRateProvider.sol)

  - Generic rate provider implementation
  - Previously audited multiple times

- **GenericRateProviderWithDecimalScaling** (60 LOC) - [Source](https://github.com/Veda-Labs/boring-vault/blob/main/src/helper/GenericRateProviderWithDecimalScaling.sol)
  - Decimal scaling for rate providers
  - Previously audited multiple times

## Nice-to-Have Contracts (Secondary Audit Scope)

**Additional Estimated Lines of Code: ~1,140**

### Cross-Chain Functionality

- **CrossChainTellerWithGenericBridge** (170 LOC) - [Source](https://github.com/Veda-Labs/boring-vault/blob/main/src/base/Roles/CrossChain/CrossChainTellerWithGenericBridge.sol)
- **MessageLib** (30 LOC) - [Source](https://github.com/Veda-Labs/boring-vault/blob/main/src/base/Roles/CrossChain/MessageLib.sol)
- **PairwiseRateLimiter** (170 LOC) - [Source](https://github.com/Veda-Labs/boring-vault/blob/main/src/base/Roles/CrossChain/PairwiseRateLimiter.sol)

### Layer Zero Integration

- **LayerZeroTeller** (250 LOC) - [Source](https://github.com/Veda-Labs/boring-vault/blob/main/src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol)
- **LayerZeroTellerWithRateLimiting** (270 LOC) - [Source](https://github.com/Veda-Labs/boring-vault/blob/main/src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTellerWithRateLimiting.sol)
- **LayerZeroTellerWithBuffer** (50 LOC) - Not yet implemented

### External Dependencies

- **OAppAuth** (200 LOC) - [Source](https://github.com/Se7en-Seas/OAppAuth)

## Contracts NOT in Scope

The following contracts and systems are explicitly excluded from this audit:

### Core Infrastructure (Excluded)

- All decoders
- Manager contracts
- Fixed rate accountant
- Boring queue
- Boring solver
- All atomic queues and solvers

### Utility Contracts (Excluded)

- Drone and dronelib
- Pauser functionality
- All micro managers
- Lens contracts
- Governance contracts
- Deployer contracts
- Payment splitter
- Incentive distributor

### Withdrawal Systems (Excluded)

- Delayed withdraw functionality
- Teller with remediation
- Withdraw queue

## Audit Priority Notes

### High Priority (New/Under Development)

1. **TellerWithBuffer** - New contract for instant withdrawals and auto-strategies
2. **AccountantWithYieldStreaming** - New contract for yield streaming functionality

### Medium Priority (Previously Audited)

- Most contracts in the "Must-Have" section have been audited 30-50 times
- Focus on integration points and recent modifications

### Lower Priority (Nice-to-Have)

- Cross-chain functionality and Layer Zero integration
- These can be audited separately or as an extension

## Request for Quotes

Please provide two separate quotes:

1. **Primary Quote**: Must-have contracts only (~1,700 LOC)
2. **Extended Quote**: Must-have + Nice-to-have contracts (~2,840 LOC total)

## Previous Audit Context

- Most of the architecture has been extensively audited (30-50 different audits)
- Focus should be on newer contracts and integration points
- Established contracts may only need cursory review for recent changes
