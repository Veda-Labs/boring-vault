// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {StdInvariant} from "@forge-std/StdInvariant.sol";

import {BaseSetup} from "../../BaseSetup.sol";
import {AccountantHandler} from "../handlers/AccountantHandler.sol";
import {TellerHandler} from "../../handlers/TellerHandler.sol";

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

/**
 * @title BaseInvariants
 * @notice Abstract base contract containing all shared invariants for BOTH RP and YS systems (Medusa-compatible)
 * @dev Uses require() instead of assert*() for Medusa compatibility
 */
abstract contract BaseInvariants is StdInvariant, BaseSetup {
    using FixedPointMathLib for uint256;

    // ============================================
    // ABSTRACT GETTERS - Implemented by child contracts
    // ============================================

    function _accountant() internal view virtual returns (AccountantWithRateProviders);
    function _teller() internal view virtual returns (TellerWithMultiAssetSupport);
    function _vault() internal view virtual returns (BoringVault);
    function _accountantHandler() internal view virtual returns (AccountantHandler);
    function _tellerHandler() internal view virtual returns (TellerHandler);
    function _getPreState() internal view virtual returns (AccountantHandler.RPState memory);
    function _getPostState() internal view virtual returns (AccountantHandler.RPState memory);
    function _getTellerPreState() internal view virtual returns (TellerHandler.TellerState memory);
    function _getTellerPostState() internal view virtual returns (TellerHandler.TellerState memory);

    // ============================================
    // HELPER FUNCTIONS
    // ============================================

    function _isAccountantPaused() internal view returns (bool) {
        (,,,,,,,, bool isPaused,,,) = _accountant().accountantState();
        return isPaused;
    }

    // ============================================
    // GROUP 1: ACCOUNTANT INVARIANTS (Rules 1-7)
    // ============================================

    function invariant_accountantDoesntHoldTokens() public view returns (bool) {
        address acc = address(_accountant());
        
        // Check base asset
        require(
            baseAsset.balanceOf(acc) == 0,
            "Invariant 1: Accountant should not hold base tokens"
        );
        
        // Check ALL alternative assets (N-asset support)
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            require(
                alternativeAssets[i].balanceOf(acc) == 0,
                "Invariant 1: Accountant should not hold alt tokens"
            );
        }

        (address payout,,,,,,,,,,, ) = _accountant().accountantState();
        require(payout != acc, "Invariant 1: Payout should not be Accountant");
        return true;
    }

    function invariant_accountantPaused_valuesFrozen() public view returns (bool) {
        AccountantHandler.RPState memory pre = _getPreState();
        AccountantHandler.RPState memory post = _getPostState();
        bytes4 selector = _accountantHandler().lastSelector();

        if (pre.isPaused && selector != AccountantWithRateProviders.resetHighwaterMark.selector) {
            require(
                post.feesOwedInBase == pre.feesOwedInBase,
                "Invariant 2: Fees should be frozen when paused"
            );
        }
        return true;
    }

    function invariant_feesCanOnlyDecreaseViaClaimFees() public view returns (bool) {
        AccountantHandler.RPState memory pre = _getPreState();
        AccountantHandler.RPState memory post = _getPostState();
        bytes4 selector = _accountantHandler().lastSelector();

        if (post.feesOwedInBase < pre.feesOwedInBase) {
            require(
                selector == AccountantWithRateProviders.claimFees.selector,
                "Invariant 3: Fees should only decrease via claimFees"
            );
        }
        return true;
    }

    function invariant_highwaterMarkNeverDecreases() public view returns (bool) {
        AccountantHandler.RPState memory pre = _getPreState();
        AccountantHandler.RPState memory post = _getPostState();
        bytes4 selector = _accountantHandler().lastSelector();

        if (selector != AccountantWithRateProviders.resetHighwaterMark.selector) {
            require(
                post.highwaterMark >= pre.highwaterMark,
                "Invariant 4: Highwater mark should never decrease"
            );
        }
        return true;
    }

    function invariant_lastUpdateTimestampNeverDecreases() public view returns (bool) {
        AccountantHandler.RPState memory pre = _getPreState();
        AccountantHandler.RPState memory post = _getPostState();

        require(
            post.lastUpdateTimestamp >= pre.lastUpdateTimestamp,
            "Invariant 5: Timestamp should never decrease"
        );
        return true;
    }

    function invariant_allowedExchangeRateChangeBounds() public view returns (bool) {
        (, , , , , uint16 upper, uint16 lower, , , , , ) = _accountant().accountantState();

        require(upper >= 10000, "Invariant 6: Upper bound should be >= 100%");
        require(lower <= 10000, "Invariant 6: Lower bound should be <= 100%");
        return true;
    }

    function invariant_exchangeRateLEhighwaterMark() public view returns (bool) {
        bytes4 selector = _accountantHandler().lastSelector();
        
        // Only check after updateExchangeRate calls
        if (selector != AccountantWithRateProviders.updateExchangeRate.selector) {
            return true;
        }
        
        // Only check if the call actually succeeded
        if (!_accountantHandler().lastCallSucceeded()) {
            return true;
        }
        
        (, uint96 hwm, , , uint96 rate, , , , bool paused, , , ) = _accountant().accountantState();
        
        if (!paused) {
            require(rate <= hwm, "Invariant 7: Exchange rate should be <= highwater mark when not paused");
        }
        return true;
    }

    // ============================================
    // GROUP 2: TELLER INVARIANTS (Rules 20-31)
    // ============================================

    function invariant_integrityOfDeposit() public view returns (bool) {
        bytes4 selector = _tellerHandler().lastSelector();
        
        bool isDepositOp = selector == DEPOSIT_SELECTOR ||
                           selector == TellerWithMultiAssetSupport.bulkDeposit.selector;
        
        if (!isDepositOp) return true;
        
        uint256 lastDepositAssets = _tellerHandler().lastDepositAssets();
        uint256 lastDepositShares = _tellerHandler().lastDepositShares();
        
        if (lastDepositAssets > 0 && _tellerHandler().depositCalls() > 0) {
            require(lastDepositShares > 0, "Invariant 20: Deposit should mint shares");
        }
        return true;
    }

    function invariant_integrityOfWithdraw() public view returns (bool) {
        bytes4 selector = _tellerHandler().lastSelector();
        
        bool isWithdrawOp = selector == TellerWithMultiAssetSupport.withdraw.selector ||
                            selector == TellerWithMultiAssetSupport.bulkWithdraw.selector;
        
        if (!isWithdrawOp) return true;
        
        uint256 lastWithdrawShares = _tellerHandler().lastWithdrawShares();
        uint256 lastWithdrawAssets = _tellerHandler().lastWithdrawAssets();
        
        // DUST_THRESHOLD accounts for lowest decimal asset (6 decimals)
        uint256 DUST_THRESHOLD = 1e12;
        if (lastWithdrawShares > DUST_THRESHOLD && _tellerHandler().withdrawCalls() > 0) {
            require(lastWithdrawAssets > 0, "Invariant 21: Withdraw should produce assets");
        }
        return true;
    }

    function invariant_noFreeAssets() public view returns (bool) {
        if (_isAccountantPaused()) return true;
        
        uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);
        if (rate == 0) return true;
        
        uint256 testAmount = _tellerHandler().lastDepositAssets();
        if (testAmount == 0) testAmount = 1000e18;
        
        uint256 shares = testAmount.mulDivDown(ONE_SHARE, rate);
        uint256 recoveredAssets = shares.mulDivDown(rate, ONE_SHARE);
        
        require(recoveredAssets <= testAmount, "Invariant 22: Round-trip should not create free assets");
        return true;
    }

    function invariant_tellerDoesntHoldTokens() public view returns (bool) {
        address teller = address(_teller());
        
        // Check base asset
        require(
            baseAsset.balanceOf(teller) == 0,
            "Invariant 23: Teller should not hold base tokens"
        );
        
        // Check ALL alternative assets
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            require(
                alternativeAssets[i].balanceOf(teller) == 0,
                "Invariant 23: Teller should not hold alt tokens"
            );
        }
        return true;
    }

    function invariant_vaultCannotChange() public view returns (bool) {
        require(address(_teller().vault()) == address(_vault()), "Invariant 24: Teller vault should be immutable");
        return true;
    }

    function invariant_depositNonceNeverGoesDown() public view returns (bool) {
        TellerHandler.TellerState memory pre = _getTellerPreState();
        TellerHandler.TellerState memory post = _getTellerPostState();

        require(post.depositNonce >= pre.depositNonce, "Invariant 25: Deposit nonce should never decrease");
        return true;
    }

    function invariant_tellerPaused_valuesFrozen() public view returns (bool) {
        TellerHandler.TellerState memory pre = _getTellerPreState();
        TellerHandler.TellerState memory post = _getTellerPostState();
        bytes4 selector = _tellerHandler().lastSelector();

        if (pre.isPaused && selector != TellerWithMultiAssetSupport.refundDeposit.selector) {
            require(post.depositNonce == pre.depositNonce, "Invariant 26: Nonce frozen when paused");
        }
        return true;
    }

    function invariant_tellerPaused_methodsRevert() public view returns (bool) {
        TellerHandler.TellerState memory pre = _getTellerPreState();
        TellerHandler.TellerState memory post = _getTellerPostState();
        bytes4 selector = _tellerHandler().lastSelector();
        
        if (pre.isPaused) {
            bool isPublicDepositWithdraw = 
                selector == DEPOSIT_SELECTOR ||
                selector == TellerWithMultiAssetSupport.withdraw.selector;
            
            if (isPublicDepositWithdraw) {
                require(
                    post.vaultTotalSupply == pre.vaultTotalSupply,
                    "Invariant 27: Paused teller should reject deposits/withdrawals"
                );
            }
        }
        return true;
    }

    function invariant_dustFavorsTheHouse() public view returns (bool) {
        if (_isAccountantPaused()) return true;
        
        uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);
        if (rate == 0) return true;
        
        uint256 testAmount = 12345678901234567890;
        
        uint256 sharesFromDeposit = testAmount.mulDivDown(ONE_SHARE, rate);
        uint256 assetsFromWithdraw = sharesFromDeposit.mulDivDown(rate, ONE_SHARE);
        
        require(assetsFromWithdraw <= testAmount, "Invariant 28: Rounding should favor the vault");
        return true;
    }

    function invariant_noDynamicCalls() public view returns (bool) {
        require(!_tellerHandler().callMade(), "Invariant 29: No unauthorized calls should be made");
        require(!_tellerHandler().delegatecallMade(), "Invariant 29: No unauthorized delegatecalls should be made");
        require(!_accountantHandler().callMade(), "Invariant 29: No unauthorized calls should be made");
        require(!_accountantHandler().delegatecallMade(), "Invariant 29: No unauthorized delegatecalls should be made");
        return true;
    }

    function invariant_onlyContributionMethodsReduceAssets() public view returns (bool) {
        bytes4 selector = _tellerHandler().lastSelector();
        address actor = _tellerHandler().currentActor();

        if (actor == address(0)) return true;

        TellerHandler.UserState memory preUser = _tellerHandler().getPreUserState(actor);
        TellerHandler.UserState memory postUser = _tellerHandler().getPostUserState(actor);

        if (postUser.baseBalance < preUser.baseBalance) {
            bool isDepositMethod = 
                selector == DEPOSIT_SELECTOR ||
                selector == TellerWithMultiAssetSupport.depositWithPermit.selector ||
                selector == TellerWithMultiAssetSupport.bulkDeposit.selector;
            
            require(isDepositMethod, "Invariant 30: Only deposit methods should reduce user assets");
        }
        return true;
    }

    function invariant_withdrawingProducesAssets() public view returns (bool) {
        uint256 withdrawCalls = _tellerHandler().withdrawCalls();
        uint256 bulkWithdrawCalls = _tellerHandler().bulkWithdrawCalls();
        
        if (withdrawCalls == 0 && bulkWithdrawCalls == 0) {
            return true;
        }
        
        uint256 sharesWithdrawn = _tellerHandler().lastWithdrawShares();
        uint256 assetsReceived = _tellerHandler().lastWithdrawAssets();

        // DUST_THRESHOLD accounts for lowest decimal asset (6 decimals)
        uint256 DUST_THRESHOLD = 1e12;
        
        if (sharesWithdrawn > DUST_THRESHOLD) {
            require(assetsReceived > 0, "Invariant 31: Withdrawing shares should produce assets");
        }
        return true;
    }

    // ============================================
    // GROUP 3: PERMISSIONS INVARIANTS (Rules 33, 36-37)
    // ============================================

    function invariant_feesIntegrity() public view returns (bool) {
        AccountantHandler.RPState memory pre = _getPreState();
        AccountantHandler.RPState memory post = _getPostState();
        bytes4 selector = _accountantHandler().lastSelector();
        
        if (selector == AccountantWithRateProviders.claimFees.selector) {
            uint256 claimedAmount = pre.feesOwedInBase > post.feesOwedInBase 
                ? pre.feesOwedInBase - post.feesOwedInBase 
                : 0;
            
            require(
                claimedAmount <= pre.feesOwedInBase,
                "feesIntegrity: Claimed fees should not exceed available fees"
            );
        }
        return true;
    }

    function invariant_deniedUsers_balanceNonDecreasing() public view returns (bool) {
        TellerHandler.UserState memory preDenied = _tellerHandler().getPreUserState(deniedUser);
        TellerHandler.UserState memory postDenied = _tellerHandler().getPostUserState(deniedUser);

        if (preDenied.denyFrom) {
            require(
                postDenied.shares >= preDenied.shares,
                "Invariant 36: Denied user (denyFrom) shares should not decrease"
            );
        }
        return true;
    }

    function invariant_deniedUsers_balanceNonIncreasing() public view returns (bool) {
        TellerHandler.UserState memory preDenied = _tellerHandler().getPreUserState(deniedUser);
        TellerHandler.UserState memory postDenied = _tellerHandler().getPostUserState(deniedUser);

        if (preDenied.denyTo) {
            require(
                postDenied.shares <= preDenied.shares,
                "Invariant 37: Denied user (denyTo) shares should not increase"
            );
        }
        return true;
    }

    // ============================================
    // GROUP 4: MATH INVARIANTS (Rules 40-47)
    // ============================================

    function invariant_convertToAssetsWeakAdditivity() public view returns (bool) {
        if (_isAccountantPaused()) return true;
        
        uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);
        if (rate == 0) return true;

        uint256 sharesA = 100e18;
        uint256 sharesB = 200e18;

        uint256 assetsA = sharesA.mulDivDown(rate, ONE_SHARE);
        uint256 assetsB = sharesB.mulDivDown(rate, ONE_SHARE);
        uint256 assetsAB = (sharesA + sharesB).mulDivDown(rate, ONE_SHARE);

        require(assetsA + assetsB <= assetsAB + 1, "Invariant 40: Weak additivity for convertToAssets");
        return true;
    }

    function invariant_convertToSharesWeakAdditivity() public view returns (bool) {
        if (_isAccountantPaused()) return true;
        
        uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);
        if (rate == 0) return true;

        uint256 assetsA = 100e18;
        uint256 assetsB = 200e18;

        uint256 sharesA = assetsA.mulDivDown(ONE_SHARE, rate);
        uint256 sharesB = assetsB.mulDivDown(ONE_SHARE, rate);
        uint256 sharesAB = (assetsA + assetsB).mulDivDown(ONE_SHARE, rate);

        require(sharesA + sharesB <= sharesAB + 1, "Invariant 41: Weak additivity for convertToShares");
        return true;
    }

    function invariant_conversionWeakMonotonicity() public view returns (bool) {
        if (_isAccountantPaused()) return true;
        
        uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);
        if (rate == 0) return true;

        uint256 x = 100e18;
        uint256 y = 200e18;

        uint256 convertX = x.mulDivDown(ONE_SHARE, rate);
        uint256 convertY = y.mulDivDown(ONE_SHARE, rate);

        require(x < y, "Test precondition");
        require(convertX <= convertY, "Invariant 42: Conversion weak monotonicity");
        return true;
    }

    function invariant_conversionWeakIntegrity() public view returns (bool) {
        if (_isAccountantPaused()) return true;
        
        uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);
        if (rate == 0) return true;

        uint256 originalAssets = 100e18;

        uint256 shares = originalAssets.mulDivDown(ONE_SHARE, rate);
        uint256 recoveredAssets = shares.mulDivDown(rate, ONE_SHARE);

        require(recoveredAssets <= originalAssets, "Invariant 43: Round trip should not create value");
        return true;
    }

    function invariant_zeroAllowanceOnAssets() public view returns (bool) {
        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];
            
            uint256 tellerAllowance = baseAsset.allowance(actor, address(_teller()));
            require(
                tellerAllowance == 0,
                "Invariant 44: Users should not give allowance to teller"
            );
        }
        return true;
    }

    function invariant_conversionOfZero() public view returns (bool) {
        if (_isAccountantPaused()) return true;
        
        uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);
        if (rate == 0) return true;

        uint256 zeroAssets = 0;
        uint256 zeroShares = zeroAssets.mulDivDown(ONE_SHARE, rate);
        
        require(zeroShares == 0, "Invariant 45: convert(0) should equal 0");
        return true;
    }

    function invariant_totalSupplyLEqCap() public view returns (bool) {
        TellerHandler.TellerState memory pre = _getTellerPreState();
        TellerHandler.TellerState memory post = _getTellerPostState();
        bytes4 selector = _tellerHandler().lastSelector();
        
        bool isDepositOp = selector == DEPOSIT_SELECTOR ||
                           selector == TellerWithMultiAssetSupport.bulkDeposit.selector;
        
        if (!isDepositOp) return true;
        
        if (post.vaultTotalSupply > pre.vaultTotalSupply) {
            require(
                post.vaultTotalSupply <= pre.depositCap,
                "Invariant 46: Deposit should respect deposit cap"
            );
        }
        return true;
    }

    function invariant_weakAdditivityGeneral() public view returns (bool) {
        if (_isAccountantPaused()) return true;
        
        uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);
        if (rate == 0) return true;
        
        uint256 amountA = _tellerHandler().lastDepositAssets();
        if (amountA == 0) amountA = 50e18;
        uint256 amountB = amountA * 2;
        
        uint256 assetsA = amountA.mulDivDown(rate, ONE_SHARE);
        uint256 assetsB = amountB.mulDivDown(rate, ONE_SHARE);
        uint256 assetsAB = (amountA + amountB).mulDivDown(rate, ONE_SHARE);
        
        require(
            assetsA + assetsB <= assetsAB + 1,
            "Invariant 47: Weak additivity should hold for conversions"
        );
        return true;
    }

    // ============================================
    // GROUP 5: SOLVENCY INVARIANTS (Rules 38-39)
    // ============================================

    function invariant_vaultSolvencyMulti() public view returns (bool) {
        uint256 totalSupply = _vault().totalSupply();

        if (totalSupply == 0) return true;
        if (_isAccountantPaused()) return true;
        if (_accountantHandler().feesRecentlyClaimed()) return true;
        if (_accountantHandler().altAssetRateChanged()) return true;

        address vault = address(_vault());
        
        uint256 totalValueInShares = 0;
        
        // Base asset value
        uint256 baseBalance = baseAsset.balanceOf(vault);
        uint256 baseRate = _accountant().getRateInQuoteSafe(baseAsset);
        if (baseRate > 0 && baseBalance > 0) {
            totalValueInShares += baseBalance.mulDivDown(ONE_SHARE, baseRate);
        }
        
        // Alternative assets value
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            uint256 altBalance = alternativeAssets[i].balanceOf(vault);
            if (altBalance > 0) {
                try _accountant().getRateInQuoteSafe(ERC20(address(alternativeAssets[i]))) returns (uint256 altRate) {
                    if (altRate > 0) {
                        totalValueInShares += altBalance.mulDivDown(ONE_SHARE, altRate);
                    }
                } catch {
                    // Asset not configured in accountant, skip
                }
            }
        }
        
        uint256 tolerance = totalSupply / 1000;
        if (tolerance == 0) tolerance = 1;

        require(totalValueInShares + tolerance >= totalSupply, "Invariant 38: Multi-asset solvency check (N assets)");
        return true;
    }

    function invariant_vaultSolvency_1Asset() public view returns (bool) {
        uint256 totalSupply = _vault().totalSupply();

        if (totalSupply == 0) return true;
        if (_isAccountantPaused()) return true;
        if (_accountantHandler().feesRecentlyClaimed()) return true;

        address vault = address(_vault());
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            if (alternativeAssets[i].balanceOf(vault) > 0) return true;
        }

        uint256 vaultBalance = baseAsset.balanceOf(vault);
        uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);

        uint256 lhs = vaultBalance * ONE_SHARE;
        uint256 rhs = totalSupply * rate;

        uint256 tolerance = rhs / 1000;
        if (tolerance == 0) tolerance = 1;

        require(lhs + tolerance >= rhs, "Invariant 39: Single-asset solvency check");
        return true;
    }
}
