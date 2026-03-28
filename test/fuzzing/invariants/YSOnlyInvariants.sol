// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseInvariants} from "./BaseInvariants.sol";
import {AccountantHandler} from "../handlers/AccountantHandler.sol";

import {AccountantWithYieldStreaming} from "src/base/Roles/AccountantWithYieldStreaming.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

/**
 * @title YSOnlyInvariants
 * @notice Abstract contract containing YS-ONLY invariants
 */
abstract contract YSOnlyInvariants is BaseInvariants {
    using FixedPointMathLib for uint256;

    bytes4 constant YS_UPDATE_EXCHANGE_RATE_SELECTOR = bytes4(keccak256("updateExchangeRate()"));

    function _accountantYS() internal view virtual returns (AccountantWithYieldStreaming);
    function _getPreYS() internal view virtual returns (AccountantHandler.YSState memory);
    function _getPostYS() internal view virtual returns (AccountantHandler.YSState memory);

    // ============================================
    // HELPER FUNCTIONS
    // ============================================

    function _isAccountantYSPaused() internal view returns (bool) {
        (,,,,,,,, bool isPaused,,,) = _accountantYS().accountantState();
        return isPaused;
    }

    // ============================================
    // YS-ONLY INVARIANTS (Rules 8-19, 32, 34, 35)
    // ============================================

    function invariant_cumulativeSupplyBounded() public view returns (bool) {
        (uint256 cumSupply, uint256 cumSupplyLast, ) = _accountantYS().supplyObservation();
        
        assertGe(cumSupply, cumSupplyLast, "Invariant 8: Cumulative supply last should be <= cumulative supply");
        return true;
    }

    function invariant_exchangeRateEqlastSharePrice() public view returns (bool) {
        (, , , , uint96 rate, , , , bool isPaused, , , ) = _accountantYS().accountantState();
        (uint128 lastSharePrice, , , , ) = _accountantYS().vestingState();

        if (isPaused) return true;

        bytes4 selector = _accountantHandler().lastSelector();
        bool isSyncOp = selector == AccountantWithYieldStreaming.vestYield.selector ||
                        selector == AccountantWithYieldStreaming.postLoss.selector ||
                        selector == YS_UPDATE_EXCHANGE_RATE_SELECTOR;
        
        if (!isSyncOp) return true;

        if (lastSharePrice <= type(uint96).max) {
            assertEq(rate, uint96(lastSharePrice), "Invariant 9: Exchange rate should equal last share price");
        }
        return true;
    }

    function invariant_sharePriceBoundedUpper() public view returns (bool) {
        if (_isAccountantYSPaused()) return true;

        uint256 totalSupply = _vault().totalSupply();

        if (totalSupply > 0) {
            uint256 rate = _accountantYS().getRate();
            uint256 totalAssets = _accountantYS().totalAssets();
            
            uint256 lhs = rate.mulDivUp(totalSupply, ONE_SHARE);
            assertLe(lhs, totalAssets + 1, "Invariant 10: Share price upper bound violated");
        }
        return true;
    }

    function invariant_sharePriceBoundedLower() public view returns (bool) {
        if (_isAccountantYSPaused()) return true;

        uint256 totalSupply = _vault().totalSupply();

        if (totalSupply > 0) {
            uint256 rate = _accountantYS().getRate();
            uint256 totalAssets = _accountantYS().totalAssets();
            
            uint256 lhs = rate.mulDivDown(totalSupply, ONE_SHARE);
            
            uint256 tolerance = totalAssets / 1e6;
            if (tolerance == 0) tolerance = 1;
            
            assertGe(lhs + tolerance, totalAssets, "Invariant 11: Share price lower bound violated");
        }
        return true;
    }

    function invariant_sharePriceMoreThanOne() public view returns (bool) {
        if (_isAccountantYSPaused()) return true;
        if (_vault().totalSupply() == 0) return true;

        uint256 rate = _accountantYS().getRate();
        uint256 vaultBalance = baseAsset.balanceOf(address(_vault()));
        
        if (vaultBalance > 0) {
            assertGt(rate, 0, "Invariant 12: Share price should be non-zero when assets exist");
        }
        return true;
    }

    function invariant_totalAssetsCovered() public view returns (bool) {
        if (_isAccountantYSPaused()) return true;
        if (_accountantHandler().feesRecentlyClaimed()) return true;

        uint256 vaultBalance = baseAsset.balanceOf(address(_vault()));
        uint256 totalAssets = _accountantYS().totalAssets();
        
        uint256 tolerance = totalAssets / 10000;
        if (tolerance == 0) tolerance = 1;
        
        assertLe(
            totalAssets,
            vaultBalance + tolerance,
            "Invariant 13: Total assets should be covered by vault balance"
        );
        return true;
    }

    function invariant_startVestingTimeLEendVestingTime() public view returns (bool) {
        (, uint128 vestingGains, , uint64 startTime, uint64 endTime) = _accountantYS().vestingState();
        uint256 totalSupply = _vault().totalSupply();
        
        if (vestingGains == 0 || totalSupply == 0) return true;
        
        assertLe(startTime, endTime, "Invariant 14: Start vesting time should be <= end vesting time");
        return true;
    }

    function invariant_vestingGainsIntegrity() public view returns (bool) {
        (, uint128 vestingGains, , uint64 startTime, uint64 endTime) = _accountantYS().vestingState();
        uint256 totalSupply = _vault().totalSupply();

        if (vestingGains > 0 && totalSupply > 0) {
            assertLt(startTime, endTime, "Invariant 15: If vesting gains > 0, start must be < end");
        }
        return true;
    }

    function invariant_lastVestingUpdateNeverDecreases() public view returns (bool) {
        AccountantHandler.YSState memory preYS = _getPreYS();
        AccountantHandler.YSState memory postYS = _getPostYS();

        assertGe(
            postYS.lastVestingUpdate,
            preYS.lastVestingUpdate,
            "Invariant 16: Last vesting update should never decrease"
        );
        return true;
    }

    function invariant_integrityOfVestYield() public view returns (bool) {
        bytes4 selector = _accountantHandler().lastSelector();
        
        if (selector == AccountantWithYieldStreaming.vestYield.selector && _accountantHandler().lastCallSucceeded()) {
            (, , uint128 lastVestingUpdate, uint64 startTime, ) = _accountantYS().vestingState();
            assertGe(lastVestingUpdate, startTime, "Invariant 17: Vesting update should be >= start time");
        }
        return true;
    }

    function invariant_exchangeRatePostLoss() public view returns (bool) {
        bytes4 selector = _accountantHandler().lastSelector();
        
        if (selector == AccountantWithYieldStreaming.postLoss.selector && _accountantHandler().lastCallSucceeded()) {
            (, uint96 hwm, , , uint96 rate, , , , , , , ) = _accountantYS().accountantState();
            
            assertLe(
                rate,
                hwm,
                "Invariant 18: After postLoss, rate should be <= HWM"
            );
        }
        return true;
    }

    function invariant_vaultSolvency_1Asset_Vesting() public view returns (bool) {
        uint256 totalSupply = _vault().totalSupply();

        if (totalSupply == 0) return true;
        if (_isAccountantYSPaused()) return true;
        if (_accountantHandler().feesRecentlyClaimed()) return true;

        uint256 vaultBalance = baseAsset.balanceOf(address(_vault()));
        uint256 pendingVest = _accountantYS().getPendingVestingGains();
        uint256 rate = _accountantYS().getRateInQuoteSafe(baseAsset);

        uint256 lhs = vaultBalance * ONE_SHARE;
        uint256 rhs = totalSupply.mulDivUp(rate, 1) + pendingVest * ONE_SHARE;
        
        uint256 tolerance = rhs / 1000;
        if (tolerance == 0) tolerance = 1;
        
        assertGe(lhs + tolerance, rhs, "Invariant 19: Vesting solvency check");
        return true;
    }

    function invariant_yieldIntegrity() public view returns (bool) {
        AccountantHandler.YSState memory preYS = _getPreYS();
        AccountantHandler.YSState memory postYS = _getPostYS();
        bytes4 selector = _accountantHandler().lastSelector();
        
        bool isYieldRealizingOp = selector == AccountantWithYieldStreaming.vestYield.selector ||
                                  selector == AccountantWithYieldStreaming.postLoss.selector ||
                                  selector == YS_UPDATE_EXCHANGE_RATE_SELECTOR ||
                                  selector == DEPOSIT_SELECTOR ||
                                  selector == TellerWithMultiAssetSupport.bulkDeposit.selector ||
                                  selector == TellerWithMultiAssetSupport.withdraw.selector ||
                                  selector == TellerWithMultiAssetSupport.bulkWithdraw.selector;
        
        if (!isYieldRealizingOp) return true;
        if (!_accountantHandler().lastCallSucceeded()) return true;
        
        uint256 totalSupply = preYS.totalSupply;
        if (totalSupply == 0) return true;
        
        uint256 realizedYieldPerShare = postYS.lastSharePrice > preYS.lastSharePrice
            ? postYS.lastSharePrice - preYS.lastSharePrice
            : 0;
        
        uint256 lhs = realizedYieldPerShare.mulDivUp(totalSupply, ONE_SHARE);
        uint256 rhs = preYS.pendingGains;
        
        uint256 tolerance = totalSupply / ONE_SHARE + 1;
        
        assertLe(
            lhs,
            rhs + tolerance,
            "Invariant 33: Realized yield (in assets) cannot exceed pending vested gains"
        );
        
        assertLe(
            postYS.pendingGains,
            uint256(postYS.vestingGains),
            "Invariant 33: Pending gains cannot exceed total vesting pool"
        );
        return true;
    }

    function invariant_yieldAccrualsMonotonic() public view returns (bool) {
        AccountantHandler.YSState memory preYS = _getPreYS();
        AccountantHandler.YSState memory postYS = _getPostYS();
        bytes4 selector = _accountantHandler().lastSelector();
        
        bool isReducingOp = selector == AccountantWithYieldStreaming.vestYield.selector ||
                            selector == AccountantWithYieldStreaming.postLoss.selector ||
                            selector == YS_UPDATE_EXCHANGE_RATE_SELECTOR;
        
        if (!isReducingOp) {
            assertGe(
                postYS.lastVestingUpdate,
                preYS.lastVestingUpdate,
                "Invariant 32: Yield accrual timestamp should be monotonic"
            );
        }
        return true;
    }

    function invariant_streamingRateConsistency() public view returns (bool) {
        (, uint128 vestingGains, , , uint64 endTime) = _accountantYS().vestingState();
        
        uint256 pendingGains = _accountantYS().getPendingVestingGains();
        
        assertLe(
            pendingGains,
            uint256(vestingGains),
            "Invariant 34: Pending gains should not exceed total vesting gains"
        );
        
        if (block.timestamp >= endTime && vestingGains > 0) {
            assertEq(
                pendingGains,
                uint256(vestingGains),
                "Invariant 34: Past end time, pending should equal all remaining gains"
            );
        }
        return true;
    }

    function invariant_accessControlYieldParams() public view returns (bool) {
        uint64 minVest = _accountantYS().minimumVestingTime();
        uint64 maxVest = _accountantYS().maximumVestingTime();
        
        assertLe(minVest, maxVest, "Invariant 35: min vesting time should be <= max vesting time");
        return true;
    }

    // ============================================
    // VIRTUAL SHARE PRICE INVARIANTS (Rules 36-38)
    // ============================================

    uint256 constant RAY = 1e27;

    function invariant_virtualPriceUpperBound() public view returns (bool) {
        // Skip when totalSupply == 0 - virtual price state is not updated when no shares exist
        uint256 totalSupply = _vault().totalSupply();
        if (totalSupply == 0) return true;
        
        // Skip when paused - state may be stale
        if (_isAccountantYSPaused()) return true;
        
        uint256 virtualPrice = _accountantYS().lastVirtualSharePrice();
        (uint128 lastSharePrice, , , , ) = _accountantYS().vestingState();
        
        // Skip if virtual price is 0 (not yet initialized or edge case)
        if (virtualPrice == 0) return true;
        
        uint256 convertedPrice = virtualPrice.mulDivDown(ONE_SHARE, RAY);
        
        // FINDING: Skip when converted price exceeds uint128 max - the protocol's 
        // _calculateSharePriceFromVirtual() silently truncates via uint128 cast.
        // This is a known limitation when lastVirtualSharePrice gets extremely large
        // (e.g., after large yield vests with few shares). See FINDINGS.md Finding 2.
        if (convertedPrice > type(uint128).max) return true;
        
        // Allow for truncation tolerance when uint128 cast loses precision
        // The uint128 cast in _calculateSharePriceFromVirtual can cause up to 1 wei difference
        // due to mulDivDown rounding combined with truncation
        assertLe(
            convertedPrice, 
            uint256(lastSharePrice) + 1, 
            "Invariant 36: Virtual price conversion should be <= lastSharePrice + 1"
        );
        return true;
    }

    function invariant_virtualPriceLowerBound() public view returns (bool) {
        // Skip when totalSupply == 0 - virtual price state is not updated when no shares exist
        uint256 totalSupply = _vault().totalSupply();
        if (totalSupply == 0) return true;
        
        // Skip when paused - state may be stale
        if (_isAccountantYSPaused()) return true;
        
        uint256 virtualPrice = _accountantYS().lastVirtualSharePrice();
        (uint128 lastSharePrice, , , , ) = _accountantYS().vestingState();
        
        // Skip if virtual price is 0 (not yet initialized or edge case)
        if (virtualPrice == 0) return true;
        
        uint256 convertedPrice = virtualPrice.mulDivDown(ONE_SHARE, RAY);
        
        // Skip when converted price exceeds uint128 max - truncation already occurred
        // See invariant_virtualPriceUpperBound for details on this known limitation
        if (convertedPrice > type(uint128).max) return true;
        
        assertLe(
            lastSharePrice, 
            convertedPrice,
            "Invariant 37: lastSharePrice should be <= converted virtual price"
        );
        return true;
    }

    function invariant_pendingGainsRateRelationship() public view returns (bool) {
        uint256 pendingGains = _accountantYS().getPendingVestingGains();
        uint256 rate = _accountantYS().getRate();
        (uint128 lastSharePrice, , , , ) = _accountantYS().vestingState();
        uint256 totalSupply = _vault().totalSupply();
        
        if (totalSupply == 0) {
            assertEq(rate, lastSharePrice, "Invariant 38: With 0 shares, rate == lastSharePrice");
            return true;
        }
        
        if (pendingGains == 0) {
            uint256 diff = rate > lastSharePrice ? rate - lastSharePrice : uint256(lastSharePrice) - rate;
            assertLe(diff, 1, "Invariant 38: Zero pending gains implies rate == lastSharePrice (+/-1)");
        }
        
        if (rate <= uint256(lastSharePrice) + 1 && rate >= uint256(lastSharePrice)) {
            uint256 maxNegligibleGains = (2 * totalSupply) / ONE_SHARE + 1;
            assertLe(
                pendingGains, 
                maxNegligibleGains, 
                "Invariant 38: Rate approx lastSharePrice implies negligible pending gains"
            );
        }
        return true;
    }
}
