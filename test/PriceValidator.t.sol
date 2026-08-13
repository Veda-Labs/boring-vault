// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {FeeRegistry} from "src/base/Periphery/FeeRegistry.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {Test} from "@forge-std/Test.sol";

contract MockRateProvider is IRateProvider {
    uint256 internal _rate;
    constructor(uint256 rate_) { _rate = rate_; }
    function getRate() external view override returns (uint256) { return _rate; }
    function setRate(uint256 rate_) external { _rate = rate_; }
}

contract PriceValidatorTest is Test, MerkleTreeHelper {
    uint8 constant ADMIN_ROLE = 1;

    BoringSwapper swapper;
    PriceValidator validator;
    RolesAuthority rolesAuthority;

    ERC20 WETH;
    ERC20 USDC;
    ERC20 STETH;

    MockRateProvider wethRate;   // 2000e18  (WETH → USD)
    MockRateProvider usdcRate;   // 1e18     (USDC → USD)
    MockRateProvider stethRate;  // 1.1e18   (stETH → ETH, then ETH → USD via wethRate)

    function setUp() external {
        setSourceChainName("mainnet");
        uint256 forkId = vm.createFork(vm.envString("MAINNET_RPC_URL"), 24592183);
        vm.selectFork(forkId);

        WETH  = ERC20(getAddress(sourceChain, "WETH"));
        USDC  = ERC20(getAddress(sourceChain, "USDC"));
        STETH = ERC20(getAddress(sourceChain, "WSTETH"));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        AdapterRegistry registry = new AdapterRegistry();
        FeeRegistry feeRegistry = new FeeRegistry(address(this), 1000);
        swapper = new BoringSwapper(address(this), registry, feeRegistry, BoringVault(payable(address(0))), IPriceValidator(address(0)));
        swapper.setAuthority(rolesAuthority);

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setRouteConfig.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setMaxSlippageBps.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setTokenOracle.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setBaseAssetOracle.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setPriceValidator.selector, true);

        wethRate  = new MockRateProvider(2000e18);
        usdcRate  = new MockRateProvider(1e18);
        stethRate = new MockRateProvider(1.1e18);

        // WETH → USDC: 50 bps max, direct oracles
        // stETH → USDC: 50 bps max, two-hop via WETH intermediary
        swapper.setRouteConfig(WETH, USDC,  50, 0, 0);
        swapper.setRouteConfig(STETH, USDC, 50, 0, 0);

        address usdq = address(USDC);

        address[] memory providers = new address[](1);
        address[] memory intermediaries = new address[](1);

        providers[0] = address(wethRate); intermediaries[0] = address(0);
        swapper.setTokenOracle(WETH, usdq, BoringSwapper.RateProviderConfig(providers, intermediaries, false));

        providers[0] = address(usdcRate); intermediaries[0] = address(0);
        swapper.setTokenOracle(USDC, usdq, BoringSwapper.RateProviderConfig(providers, intermediaries, false));

        providers[0] = address(stethRate); intermediaries[0] = address(WETH);
        swapper.setTokenOracle(STETH, usdq, BoringSwapper.RateProviderConfig(providers, intermediaries, false));

        address[] memory baseProviders = new address[](1);
        baseProviders[0] = address(wethRate);
        swapper.setBaseAssetOracle(WETH, usdq, baseProviders);

        validator = new PriceValidator();
        swapper.setPriceValidator(IPriceValidator(address(validator)));
    }

    // ─────────────────────────────────────────────
    // Direct oracle — WETH → USDC
    // ─────────────────────────────────────────────

    // 1 WETH @ $2000 → 2000 USDC. Both sides value at 2000e18 USD units, no slippage.
    function testValidate_DirectOracle_HappyPath() external {
        vm.prank(address(swapper));
        validator.validate(WETH, USDC, 1e18, 2000e6, address(USDC), 0);
    }

    // Output exactly at the 50 bps boundary.
    // minValueOut = floor(2000e18 * 9950 / 10000) = 1990e18 == valuesOut(1990e6 USDC)
    function testValidate_DirectOracle_AtSlippageBoundary() external {
        vm.prank(address(swapper));
        validator.validate(WETH, USDC, 1e18, 1990e6, address(USDC), 50);
    }

    // 1989e6 USDC → 1989e18 USD value < 1990e18 min → revert
    function testValidate_DirectOracle_ExceedsSlippage() external {
        vm.expectRevert(PriceValidator.PriceValidator__ExceedsMaxSlippage.selector);
        vm.prank(address(swapper));
        validator.validate(WETH, USDC, 1e18, 1989e6, address(USDC), 50);
    }

    // ─────────────────────────────────────────────
    // Route-level slippage cap
    // ─────────────────────────────────────────────

    // Route max is 50 bps — requesting 51 reverts before any oracle lookup.
    function testValidate_ExceedsRouteMaxSlippage() external {
        vm.expectRevert(PriceValidator.PriceValidator__ExceedsRouteMaxSlippage.selector);
        vm.prank(address(swapper));
        validator.validate(WETH, USDC, 1e18, 2000e6, address(USDC), 51);
    }

    // ─────────────────────────────────────────────
    // skipValidation flag
    // ─────────────────────────────────────────────

    // skip=true on tokenIn — catastrophically bad output is ignored entirely.
    function testValidate_Skip_TokenIn() external {
        address[] memory providers = new address[](1);
        address[] memory intermediaries = new address[](1);
        providers[0] = address(wethRate); intermediaries[0] = address(0);
        swapper.setTokenOracle(WETH, address(USDC), BoringSwapper.RateProviderConfig(providers, intermediaries, true));

        vm.prank(address(swapper));
        validator.validate(WETH, USDC, 1e18, 0, address(USDC), 0);
    }

    // skip=true on tokenOut — same, no check fires.
    function testValidate_Skip_TokenOut() external {
        address[] memory providers = new address[](1);
        address[] memory intermediaries = new address[](1);
        providers[0] = address(usdcRate); intermediaries[0] = address(0);
        swapper.setTokenOracle(USDC, address(USDC), BoringSwapper.RateProviderConfig(providers, intermediaries, true));

        vm.prank(address(swapper));
        validator.validate(WETH, USDC, 1e18, 0, address(USDC), 0);
    }

    // ─────────────────────────────────────────────
    // Two-hop oracle — stETH → ETH → USD
    // ─────────────────────────────────────────────

    // 1 stETH @ 1.1 ETH @ $2000 = $2200. 2200e6 USDC out passes with 0 slippage.
    function testValidate_TwoHop_HappyPath() external {
        vm.prank(address(swapper));
        validator.validate(STETH, USDC, 1e18, 2200e6, address(USDC), 0);
    }

    // Exactly at 50 bps boundary.
    // minValueOut = floor(2200e18 * 9950 / 10000) = 2189e18 == valuesOut(2189e6 USDC)
    function testValidate_TwoHop_AtSlippageBoundary() external {
        vm.prank(address(swapper));
        validator.validate(STETH, USDC, 1e18, 2189e6, address(USDC), 50);
    }

    // 2188e6 USDC → 2188e18 < 2189e18 min → revert
    function testValidate_TwoHop_ExceedsSlippage() external {
        vm.expectRevert(PriceValidator.PriceValidator__ExceedsMaxSlippage.selector);
        vm.prank(address(swapper));
        validator.validate(STETH, USDC, 1e18, 2188e6, address(USDC), 50);
    }

    // WETH base oracle explicitly set to address(0) — second hop provider is zero → revert
    function testValidate_TwoHop_BaseOracleZeroed() external {
        address[] memory baseProviders = new address[](1);
        baseProviders[0] = address(0);
        swapper.setBaseAssetOracle(WETH, address(USDC), baseProviders);

        vm.expectRevert(PriceValidator.PriceValidator__OracleNotConfigured.selector);
        vm.prank(address(swapper));
        validator.validate(STETH, USDC, 1e18, 2200e6, address(USDC), 0);
    }

    // Intermediary points to an address with no base oracle ever configured — empty array
    // → baseOracleLength check reverts cleanly instead of panicking with OOB
    function testValidate_TwoHop_BaseOracleNeverSet() external {
        address[] memory providers = new address[](1);
        address[] memory intermediaries = new address[](1);
        providers[0] = address(stethRate);
        intermediaries[0] = address(0x420); // never registered in setBaseAssetOracle
        swapper.setTokenOracle(STETH, address(USDC), BoringSwapper.RateProviderConfig(providers, intermediaries, false));

        vm.expectRevert(PriceValidator.PriceValidator__OracleNotConfigured.selector);
        vm.prank(address(swapper));
        validator.validate(STETH, USDC, 1e18, 2200e6, address(USDC), 0);
    }

    // ─────────────────────────────────────────────
    // Oracle misconfig errors
    // ─────────────────────────────────────────────

    // rate provider = address(0) on tokenIn side
    function testValidate_OracleNotConfigured_TokenIn() external {
        address[] memory providers = new address[](1);
        address[] memory intermediaries = new address[](1);
        providers[0] = address(0); intermediaries[0] = address(0);
        swapper.setTokenOracle(WETH, address(USDC), BoringSwapper.RateProviderConfig(providers, intermediaries, false));

        vm.expectRevert(PriceValidator.PriceValidator__OracleNotConfigured.selector);
        vm.prank(address(swapper));
        validator.validate(WETH, USDC, 1e18, 2000e6, address(USDC), 0);
    }

    // rate provider = address(0) on tokenOut side
    function testValidate_OracleNotConfigured_TokenOut() external {
        address[] memory providers = new address[](1);
        address[] memory intermediaries = new address[](1);
        providers[0] = address(0); intermediaries[0] = address(0);
        swapper.setTokenOracle(USDC, address(USDC), BoringSwapper.RateProviderConfig(providers, intermediaries, false));

        vm.expectRevert(PriceValidator.PriceValidator__OracleNotConfigured.selector);
        vm.prank(address(swapper));
        validator.validate(WETH, USDC, 1e18, 2000e6, address(USDC), 0);
    }

    // rateProviders.length (2) != intermediaries.length (1)
    function testValidate_OracleLengthMismatch() external {
        address[] memory providers = new address[](2);
        address[] memory intermediaries = new address[](1);
        providers[0] = address(wethRate);
        providers[1] = address(wethRate);
        intermediaries[0] = address(0);
        swapper.setTokenOracle(WETH, address(USDC), BoringSwapper.RateProviderConfig(providers, intermediaries, false));

        vm.expectRevert(PriceValidator.PriceValidator__OracleLengthMismatch.selector);
        vm.prank(address(swapper));
        validator.validate(WETH, USDC, 1e18, 2000e6, address(USDC), 0);
    }

    // ─────────────────────────────────────────────
    // Multiple rate providers — cross-product behavior
    // ─────────────────────────────────────────────

    // Two oracles for tokenIn: 2000e18 and 2100e18. With 500 bps slippage the highest
    // input value (2100e18) still clears the output (2000e18):
    //   min = floor(2100e18 * 9500 / 10000) = 1995e18 < 2000e18 ✓
    function testValidate_MultipleProviders_AllPairsPass() external {
        MockRateProvider wethRate2 = new MockRateProvider(2100e18);
        address[] memory providers = new address[](2);
        address[] memory intermediaries = new address[](2);
        providers[0] = address(wethRate);
        providers[1] = address(wethRate2);
        swapper.setTokenOracle(WETH, address(USDC), BoringSwapper.RateProviderConfig(providers, intermediaries, false));
        swapper.setMaxSlippageBps(swapper.getRouteId(WETH, USDC), 500);

        vm.prank(address(swapper));
        validator.validate(WETH, USDC, 1e18, 2000e6, address(USDC), 500);
    }

    // Two oracles on tokenOut: usdcRate (1e18) and lowerUsdcRate (0.99e18).
    // The first oracle alone would pass (2000e18 >= 1990e18 min), but the lower oracle
    // produces 1980e18 < 1990e18 → revert. Confirms the inner j loop runs and the lowest
    // tokenOut value is the binding constraint.
    function testValidate_MultipleProviders_LowestOutputBinds() external {
        MockRateProvider lowerUsdcRate = new MockRateProvider(0.99e18);
        address[] memory providers = new address[](2);
        address[] memory intermediaries = new address[](2);
        providers[0] = address(usdcRate);      // 1e18   → valuesOut[0] = 2000e18
        providers[1] = address(lowerUsdcRate); // 0.99e18 → valuesOut[1] = 1980e18
        swapper.setTokenOracle(USDC, address(USDC), BoringSwapper.RateProviderConfig(providers, intermediaries, false));

        // minValueOut = floor(2000e18 * 9950 / 10000) = 1990e18
        // 1980e18 < 1990e18 → revert
        vm.expectRevert(PriceValidator.PriceValidator__ExceedsMaxSlippage.selector);
        vm.prank(address(swapper));
        validator.validate(WETH, USDC, 1e18, 2000e6, address(USDC), 50);
    }

    // Same two oracles, slippage = 0. The highest tokenIn value (2100e18) is the binding
    // constraint — valuesOut (2000e18) falls short → revert. A single failing (i, j) pair
    // causes a revert regardless of the others passing.
    function testValidate_MultipleProviders_HighestInputBinds() external {
        MockRateProvider wethRate2 = new MockRateProvider(2100e18);
        address[] memory providers = new address[](2);
        address[] memory intermediaries = new address[](2);
        providers[0] = address(wethRate);
        providers[1] = address(wethRate2);
        swapper.setTokenOracle(WETH, address(USDC), BoringSwapper.RateProviderConfig(providers, intermediaries, false));

        vm.expectRevert(PriceValidator.PriceValidator__ExceedsMaxSlippage.selector);
        vm.prank(address(swapper));
        validator.validate(WETH, USDC, 1e18, 2000e6, address(USDC), 0);
    }

    // ─────────────────────────────────────────────
    // Two-hop with multiple intermediary oracles
    // ─────────────────────────────────────────────

    // Both intermediary oracles agree at 2000e18.
    // values: [1.1 * 2000, 1.1 * 2000] = [2200e18, 2200e18]. 2200e6 USDC passes.
    function testValidate_TwoHop_TwoIntermediary_HappyPath() external {
        MockRateProvider wethRate2 = new MockRateProvider(2000e18);
        address[] memory baseProviders = new address[](2);
        baseProviders[0] = address(wethRate);
        baseProviders[1] = address(wethRate2);
        swapper.setBaseAssetOracle(WETH, address(USDC), baseProviders);

        vm.prank(address(swapper));
        validator.validate(STETH, USDC, 1e18, 2200e6, address(USDC), 0);
    }

    // One intermediary oracle is inflated (3000e18 vs 2000e18).
    // values: [1.1*2000=2200e18, 1.1*3000=3300e18]
    // Pair (3300e18 in, 2200e18 out): min = 3300e18*9950/10000 = 3283.5e18 > 2200e18 → revert.
    // A compromised inflated oracle is caught even when the swap itself is fair.
    function testValidate_TwoHop_TwoIntermediary_InflatedIntermediaryBlocks() external {
        MockRateProvider wethRateInflated = new MockRateProvider(3000e18);
        address[] memory baseProviders = new address[](2);
        baseProviders[0] = address(wethRate);
        baseProviders[1] = address(wethRateInflated);
        swapper.setBaseAssetOracle(WETH, address(USDC), baseProviders);

        vm.expectRevert(PriceValidator.PriceValidator__ExceedsMaxSlippage.selector);
        vm.prank(address(swapper));
        validator.validate(STETH, USDC, 1e18, 2200e6, address(USDC), 0);
    }

    // One intermediary oracle is deflated (100e18 vs 2000e18).
    // values: [1.1*2000=2200e18, 1.1*100=110e18]
    // Pair (2200e18 in, 110e18 out): min = 2200e18*9950/10000 = 2189e18 > 110e18 → revert.
    // The healthy oracle provides the binding constraint — a deflated oracle cannot let a bad swap through.
    function testValidate_TwoHop_TwoIntermediary_DeflatedIntermediaryCannotBypass() external {
        MockRateProvider wethRateDeflated = new MockRateProvider(100e18);
        address[] memory baseProviders = new address[](2);
        baseProviders[0] = address(wethRate);
        baseProviders[1] = address(wethRateDeflated);
        swapper.setBaseAssetOracle(WETH, address(USDC), baseProviders);

        vm.expectRevert(PriceValidator.PriceValidator__ExceedsMaxSlippage.selector);
        vm.prank(address(swapper));
        validator.validate(STETH, USDC, 1e18, 110e6, address(USDC), 0);
    }

    // Second intermediary oracle returns 0 → ZeroOracleRate revert.
    function testValidate_TwoHop_TwoIntermediary_ZeroBaseRate() external {
        MockRateProvider zeroRate = new MockRateProvider(0);
        address[] memory baseProviders = new address[](2);
        baseProviders[0] = address(wethRate);
        baseProviders[1] = address(zeroRate);
        swapper.setBaseAssetOracle(WETH, address(USDC), baseProviders);

        vm.expectRevert(PriceValidator.PriceValidator__ZeroOracleRate.selector);
        vm.prank(address(swapper));
        validator.validate(STETH, USDC, 1e18, 2200e6, address(USDC), 0);
    }
}
