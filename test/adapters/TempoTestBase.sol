// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {TempoAdapter} from "src/base/Periphery/adapters/TempoAdapter.sol";
import {ITempoStablecoinDEX, ITIP20} from "src/interfaces/ITempoStablecoinDEX.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {FeeRegistry} from "src/base/Periphery/FeeRegistry.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import {Test} from "@forge-std/Test.sol";

// ============================ Tempo predeploy surfaces (test-only) ============================

interface ITIP20Factory {
    function createToken(string memory name, string memory symbol, string memory currency, address quoteToken, address admin, bytes32 salt)
        external
        returns (address);
}

interface ITIP20Test {
    function ISSUER_ROLE() external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function mint(address to, uint256 amount) external;
    function transferPolicyId() external view returns (uint64);
    function changeTransferPolicyId(uint64 newPolicyId) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface ITIP403Registry {
    function createPolicy(address admin, uint8 policyType) external returns (uint64);
    function modifyPolicyBlacklist(uint64 policyId, address account, bool restricted) external;
}

contract MockRateProvider is IRateProvider {
    function getRate() public pure override returns (uint256) {
        return 1e18; // all Tempo test stables are $1
    }
}

abstract contract TempoTestBase is Test {
    // Tempo predeploys
    ITempoStablecoinDEX internal constant DEX = ITempoStablecoinDEX(0xDEc0000000000000000000000000000000000000);
    ITIP20Factory internal constant FACTORY = ITIP20Factory(0x20Fc000000000000000000000000000000000000);
    ITIP403Registry internal constant REGISTRY_403 = ITIP403Registry(0x403c000000000000000000000000000000000000);
    address internal constant PATH_USD = 0x20C0000000000000000000000000000000000000;

    uint8 internal constant ADMIN_ROLE = 1;
    uint8 internal constant POLICY_BLACKLIST = 1;

    BoringVault public boringVault;
    BoringSwapper public swapper;
    AdapterRegistry public registry;
    PriceValidator public validator;
    RolesAuthority public rolesAuthority;
    FeeRegistry public feeRegistry;
    TempoAdapter public adapter;

    ERC20 internal BASE;
    ERC20 internal QUOTE;

    address internal lp = makeAddr("lp");
    address internal taker = makeAddr("taker");
    address internal keeper = makeAddr("keeper");

    function setUp() external virtual {
        vm.createSelectFork("tempo");

        // ---- TIP-20 tokens: QUOTE quoted in pathUSD, BASE quoted in QUOTE ----
        QUOTE = ERC20(FACTORY.createToken("Veda Quote USD", "vQUSD", "USD", PATH_USD, address(this), "vQUSD"));
        BASE = ERC20(FACTORY.createToken("Veda Base USD", "vBUSD", "USD", address(QUOTE), address(this), "vBUSD"));
        ITIP20Test(address(QUOTE)).grantRole(ITIP20Test(address(QUOTE)).ISSUER_ROLE(), address(this));
        ITIP20Test(address(BASE)).grantRole(ITIP20Test(address(BASE)).ISSUER_ROLE(), address(this));

        // ---- vault + swapper stack ----
        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);

        registry = new AdapterRegistry();
        feeRegistry = new FeeRegistry(address(this), 1000);
        validator = new PriceValidator();
        swapper = new BoringSwapper(address(this), registry, feeRegistry, boringVault, IPriceValidator(address(validator)));

        swapper.setAuthority(rolesAuthority);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setRouteConfig.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setApprovedAdapter.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setTokenOracle.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setBaseAssetOracle.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.swap.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.submitOrder.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.cancelOrder.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.releaseFee.selector, true);

        // ---- Tempo integration ----
        adapter = new TempoAdapter(address(DEX));
        registry.put(address(adapter), "TEMPO");
        swapper.setApprovedAdapter(address(adapter), true);

        // routes both directions, no rate limit
        swapper.setRouteConfig(BASE, QUOTE, 50, 0, 0);
        swapper.setRouteConfig(QUOTE, BASE, 50, 0, 0);

        // oracles: both tokens $1
        MockRateProvider one = new MockRateProvider();
        address usdQuoteAsset = address(QUOTE);
        swapper.setTokenOracle(BASE, usdQuoteAsset, _makeOracleConfig(address(one)));
        swapper.setTokenOracle(QUOTE, usdQuoteAsset, _makeOracleConfig(address(one)));
        swapper.setBaseAssetOracle(BASE, usdQuoteAsset, _toArray(address(one)));
        swapper.setBaseAssetOracle(QUOTE, usdQuoteAsset, _toArray(address(one)));

        // vault approves swapper to pull
        vm.startPrank(address(boringVault));
        BASE.approve(address(swapper), type(uint256).max);
        QUOTE.approve(address(swapper), type(uint256).max);
        vm.stopPrank();

        // balances
        ITIP20Test(address(BASE)).mint(address(boringVault), 10_000e6);
        ITIP20Test(address(QUOTE)).mint(address(boringVault), 10_000e6);
        ITIP20Test(address(BASE)).mint(lp, 10_000e6);
        ITIP20Test(address(QUOTE)).mint(lp, 10_000e6);
        ITIP20Test(address(BASE)).mint(taker, 10_000e6);
        ITIP20Test(address(QUOTE)).mint(taker, 10_000e6);

        // third parties approve the DEX directly
        vm.startPrank(lp);
        BASE.approve(address(DEX), type(uint256).max);
        QUOTE.approve(address(DEX), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(taker);
        BASE.approve(address(DEX), type(uint256).max);
        QUOTE.approve(address(DEX), type(uint256).max);
        vm.stopPrank();
    }

    function _marketConfig(ERC20 tokenIn, ERC20 tokenOut, bytes memory swapData) internal view returns (ISwapperTypes.SwapConfig memory) {
        return ISwapperTypes.SwapConfig({
            tokenRoute: ISwapperTypes.TokenRoute(tokenIn, tokenOut),
            adapter: address(adapter),
            quoteAsset: address(QUOTE),
            swapData: swapData,
            slippageBps: 10,
            receiver: boringVault
        });
    }

    function _makeOracleConfig(address rateProvider) internal pure returns (BoringSwapper.RateProviderConfig memory) {
        address[] memory rateProviders = new address[](1);
        rateProviders[0] = rateProvider;
        address[] memory intermediaries = new address[](1);
        intermediaries[0] = address(0);
        return BoringSwapper.RateProviderConfig(rateProviders, intermediaries, false);
    }

    function _toArray(address addr) internal pure returns (address[] memory) {
        address[] memory arr = new address[](1);
        arr[0] = addr;
        return arr;
    }
}
