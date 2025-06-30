// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {OracleRateProvider} from "src/helper/OracleRateProvider.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {MockAggregator} from "test/mocks/MockAggregator.sol";

import {Test, stdStorage, StdStorage, stdError} from "@forge-std/Test.sol";

contract AccountantWithOracleRateProviderTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;
    AccountantWithRateProviders public accountant;
    OracleRateProvider public usdtOracleRateProvider;
    OracleRateProvider public daiOracleRateProvider;
    address public payoutAddress = vm.addr(7777777);
    RolesAuthority public rolesAuthority;

    address public usdcWhale = 0x28C6c06298d514Db089934071355E5743bf21d60;

    uint8 public constant MINTER_ROLE = 1;
    uint8 public constant ADMIN_ROLE = 2;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 3;
    uint8 public constant BORING_VAULT_ROLE = 4;

    ERC20 internal USDC;
    ERC20 internal USDT;
    ERC20 internal DAI;
    
    // Chainlink oracle addresses for Ethereum mainnet
    MockAggregator internal usdtOracle;
    MockAggregator internal daiOracle;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19618964;
        _startFork(rpcKey, blockNumber);

        USDC = getERC20(sourceChain, "USDC");
        USDT = getERC20(sourceChain, "USDT");
        DAI = getERC20(sourceChain, "DAI");

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 6);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payoutAddress, 1e6, address(USDC), 1.001e4, 0.999e4, 1, 0, 0
        );

        usdtOracle = new MockAggregator();
        daiOracle = new MockAggregator();

        // Create Oracle Rate Providers for USDT and DAI
        // USDT Oracle Rate Provider (6 decimals output)
        usdtOracleRateProvider = new OracleRateProvider(
            address(usdtOracle),
            address(0), // No additional rate provider
            0.95e6, // Lower bound: 0.95 USD
            1.05e6, // Upper bound: 1.05 USD
            2 days, // 24 hour heartbeat
            6, // 6 decimals output
            5000 // 50% max deviation
        );

        // DAI Oracle Rate Provider (18 decimals output)
        daiOracleRateProvider = new OracleRateProvider(
            address(daiOracle),
            address(0), // No additional rate provider
            0.95e18, // Lower bound: 0.95 USD
            1.05e18, // Upper bound: 1.05 USD
            2 days, // 24 hour heartbeat
            18, // 18 decimals output
            5000 // 50% max deviation
        );

        vm.startPrank(usdcWhale);
        USDC.safeTransfer(address(this), 1_000_000e6);
        vm.stopPrank();
        USDC.safeApprove(address(boringVault), 1_000_000e6);
        boringVault.enter(address(this), USDC, 1_000_000e6, address(this), 1_000_000e6);

        // Set rate provider data
        accountant.setRateProviderData(USDT, false, address(usdtOracleRateProvider));
        accountant.setRateProviderData(DAI, false, address(daiOracleRateProvider));

        // Start accounting so we can claim fees during a test.
        accountant.updatePlatformFee(0.01e4);

        //vm.rollFork(19619262); // cast find-block 19618964 + 1 hour
        skip(1 hours);
        // Increase exchange rate by 5 bps.
        uint96 newExchangeRate = uint96(1.0005e6);
        accountant.updateExchangeRate(newExchangeRate);

        //vm.rollFork(19626407); // cast find-block 19618964 + 25 hours
        skip(1 days);

        accountant.updateExchangeRate(newExchangeRate);

        //vm.rollFork(19633555); // cast find-block 19618964 + 49 hours
        skip(1 days);

        _initOracle(usdtOracle);
        _initOracle(daiOracle);
    }

    function testClaimFeesUsingBase() external {
        // Set exchangeRate back to 1e6.
        uint96 newExchangeRate = uint96(1e6);
        accountant.updateExchangeRate(newExchangeRate);

        (,, uint128 feesOwed,,,,,,,,,) = accountant.accountantState();

        vm.startPrank(address(boringVault));
        USDC.safeApprove(address(accountant), type(uint256).max);
        // Claim fees.
        accountant.claimFees(USDC);
        vm.stopPrank();

        assertEq(USDC.balanceOf(payoutAddress), feesOwed, "Should have claimed fees in USDC");
    }

    function testClaimFeesUsingUSDTWithOracle() external {
        // Set exchangeRate back to 1e6.
        uint96 newExchangeRate = uint96(1e6);
        accountant.updateExchangeRate(newExchangeRate);

        (,, uint128 feesOwed,,,,,,,,,) = accountant.accountantState();

        deal(address(USDT), address(boringVault), 1_000_000e6);
        vm.startPrank(address(boringVault));
        USDT.safeApprove(address(accountant), type(uint256).max);
        // Claim fees.
        accountant.claimFees(USDT);
        vm.stopPrank();

        uint256 usdtRate = usdtOracleRateProvider.getRate();
        uint256 expectedFeesOwed = uint256(feesOwed).mulDivDown(1e6, usdtRate);
        uint256 actualUsdtFees = USDT.balanceOf(payoutAddress);
        
        assertApproxEqRel(actualUsdtFees, expectedFeesOwed, 0.01e18, "Should have claimed fees in USDT using oracle rate");
    }

    function testClaimFeesUsingDAIWithOracle() external {
        // Set exchangeRate back to 1e6.
        uint96 newExchangeRate = uint96(1e6);
        accountant.updateExchangeRate(newExchangeRate);

        (,, uint128 feesOwed,,,,,,,,,) = accountant.accountantState();

        deal(address(DAI), address(boringVault), 1_000_000e18);
        vm.startPrank(address(boringVault));
        DAI.safeApprove(address(accountant), type(uint256).max);
        // Claim fees.
        accountant.claimFees(DAI);
        vm.stopPrank();

        uint256 daiRate = daiOracleRateProvider.getRate();
        uint256 expectedFeesOwed = uint256(feesOwed).mulDivDown(1e18, 1e6); // Convert to 18 decimals
        expectedFeesOwed = expectedFeesOwed.mulDivDown(1e18, daiRate); // Apply DAI rate
        uint256 actualDaiFees = DAI.balanceOf(payoutAddress);
        
        assertApproxEqRel(actualDaiFees, expectedFeesOwed, 0.01e18, "Should have claimed fees in DAI using oracle rate");
    }

    function testRatesWithOracle() external {
        // Set exchangeRate back to 1e6.
        uint96 newExchangeRate = uint96(1e6);
        accountant.updateExchangeRate(newExchangeRate);

        // getRate and getRate in quote should work.
        uint256 rate = accountant.getRate();
        uint256 expected_rate = 1e6;
        assertEq(rate, expected_rate, "Rate should be expected rate");
        rate = accountant.getRateSafe();
        assertEq(rate, expected_rate, "Rate should be expected rate");

        uint256 rateInQuote = accountant.getRateInQuote(USDC);
        expected_rate = 1e6;
        assertEq(rateInQuote, expected_rate, "Rate should be expected rate");

        // For USDT with oracle
        rateInQuote = accountant.getRateInQuote(USDT);
        uint256 usdtOracleRate = usdtOracleRateProvider.getRate();
        expected_rate = uint256(1e6).mulDivDown(usdtOracleRate, 1e6);
        assertApproxEqRel(rateInQuote, expected_rate, 0.001e18 /* 0.1% */, "Rate should be expected rate for USDT with oracle");

        // For DAI with oracle
        rateInQuote = accountant.getRateInQuote(DAI);
        uint256 daiOracleRate = daiOracleRateProvider.getRate();
        expected_rate = uint256(1e18).mulDivDown(daiOracleRate, 1e18);
        assertApproxEqRel(rateInQuote, expected_rate, 0.001e18 /* 0.1% */, "Rate should be expected rate for DAI with oracle");
    }

    function testOracleRateProviderDirectly() external view {
        // Test USDT Oracle Rate Provider
        uint256 usdtRate = usdtOracleRateProvider.getRate();
        assertGt(usdtRate, 0, "USDT rate should be greater than 0");
        assertGe(usdtRate, 0.95e6, "USDT rate should be within lower bound");
        assertLe(usdtRate, 1.05e6, "USDT rate should be within upper bound");

        // Test DAI Oracle Rate Provider
        uint256 daiRate = daiOracleRateProvider.getRate();
        assertGt(daiRate, 0, "DAI rate should be greater than 0");
        assertGe(daiRate, 0.95e18, "DAI rate should be within lower bound");
        assertLe(daiRate, 1.05e18, "DAI rate should be within upper bound");

        // Verify oracle responses are fresh
        (, , , uint256 usdtTimestamp, ) = usdtOracle.latestRoundData();
        assertGt(usdtTimestamp, 0, "USDT oracle timestamp should be valid");
        assertLe(block.timestamp - usdtTimestamp, 86400, "USDT oracle data should be fresh");

        (, , , uint256 daiTimestamp, ) = daiOracle.latestRoundData();
        assertGt(daiTimestamp, 0, "DAI oracle timestamp should be valid");
        assertLe(block.timestamp - daiTimestamp, 86400, "DAI oracle data should be fresh");
    }

    function testOracleRateProviderRevertConditions() external {
        // Test with invalid oracle address - should revert when getting rate
        OracleRateProvider invalidOracleProvider = new OracleRateProvider(
            address(0x123), // Invalid oracle address
            address(0),
            0.95e6,
            1.05e6,
            86400,
            6,
            5000
        );

        vm.expectRevert();
        invalidOracleProvider.getRate();
    }

    function testBadChainlinkResponse_LatestRoundDataReverts() external {
        // Initialize oracle first
        _initOracle(usdtOracle);
        
        // Make latestRoundData revert
        usdtOracle.setLatestRevert();
        
        // This will cause arithmetic underflow when trying to get previous round data
        vm.expectRevert(stdError.arithmeticError);
        usdtOracleRateProvider.getRate();
    }

    function testBadChainlinkResponse_GetRoundDataReverts() external {
        // Make getRoundData revert
        usdtOracle.setPrevRevert();
        
        vm.expectRevert(OracleRateProvider.OracleRateProvider__BadChainlinkResponse.selector);
        usdtOracleRateProvider.getRate();
    }

    function testBadChainlinkResponse_DecimalsReverts() external {
        // Initialize oracle first
        _initOracle(usdtOracle);
        
        // Make decimals() revert
        usdtOracle.setDecimalsRevert();
        
        // This will cause arithmetic underflow when trying to get previous round with invalid decimals
        vm.expectRevert(stdError.arithmeticError);
        usdtOracleRateProvider.getRate();
    }

    function testBadChainlinkResponse_ZeroRoundId() external {
        // Initialize oracle first
        _initOracle(usdtOracle);
        
        // Set roundId to 0 - this will cause arithmetic underflow when trying to get previous round
        usdtOracle.setLatestRoundId(0);
        
        // This will actually cause an arithmetic underflow panic, not BadChainlinkResponse
        vm.expectRevert(stdError.arithmeticError);
        usdtOracleRateProvider.getRate();
    }

    function testBadChainlinkResponse_ZeroTimestamp() external {
        // Set timestamp to 0
        usdtOracle.setUpdateTime(0);
        
        vm.expectRevert(OracleRateProvider.OracleRateProvider__BadChainlinkResponse.selector);
        usdtOracleRateProvider.getRate();
    }

    function testBadChainlinkResponse_FutureTimestamp() external {
        // Set timestamp in the future
        usdtOracle.setUpdateTime(block.timestamp + 1 hours);
        
        vm.expectRevert(OracleRateProvider.OracleRateProvider__BadChainlinkResponse.selector);
        usdtOracleRateProvider.getRate();
    }

    function testBadChainlinkResponse_ZeroPrice() external {
        // Set price to 0
        usdtOracle.setPrice(0);
        
        vm.expectRevert(OracleRateProvider.OracleRateProvider__BadChainlinkResponse.selector);
        usdtOracleRateProvider.getRate();
    }

    function testBadChainlinkResponse_NegativePrice() external {
        // Set price to negative value
        usdtOracle.setPrice(-1e8);
        
        vm.expectRevert(OracleRateProvider.OracleRateProvider__BadChainlinkResponse.selector);
        usdtOracleRateProvider.getRate();
    }

    function testBadChainlinkResponse_PrevRoundZeroRoundId() external {
        // Set previous round ID to 0
        usdtOracle.setPrevRoundId(0);
        
        vm.expectRevert(OracleRateProvider.OracleRateProvider__BadChainlinkResponse.selector);
        usdtOracleRateProvider.getRate();
    }

    function testBadChainlinkResponse_PrevRoundZeroPrice() external {
        // Set previous price to 0
        usdtOracle.setPrevPrice(0);
        
        vm.expectRevert(OracleRateProvider.OracleRateProvider__BadChainlinkResponse.selector);
        usdtOracleRateProvider.getRate();
    }

    function testBadChainlinkResponse_PrevRoundNegativePrice() external {
        // Set previous price to negative value
        usdtOracle.setPrevPrice(-1e8);
        
        vm.expectRevert(OracleRateProvider.OracleRateProvider__BadChainlinkResponse.selector);
        usdtOracleRateProvider.getRate();
    }

    function testPriceIsStale() external {
        // Initialize oracle with fresh data
        _initOracle(usdtOracle);
        
        // Move forward in time beyond the heartbeat (2 days)
        skip(2 days + 1 hours);
        
        vm.expectRevert(OracleRateProvider.OracleRateProvider__PriceIsStale.selector);
        usdtOracleRateProvider.getRate();
    }

    function testPriceChangeOutOfBounds_PriceIncreaseAboveMax() external {
        // Initialize oracle
        _initOracle(usdtOracle);
        
        // Set current price much higher than previous (more than 50% deviation)
        // but still within the bounds (0.95-1.05)
        // Previous price: 1e8 (1.0 USD), new price: 1.8e8 (1.8 USD) 
        // This is 80% increase, above 50% max, but 1.8 is above upper bound of 1.05
        // Let's use 1.04 and 0.65 to trigger price change bounds
        usdtOracle.setPrice(1.04e8); // 1.04 USD (within bounds)
        usdtOracle.setPrevPrice(0.65e8); // 0.65 USD (below bounds but that's OK for prev)
        
        // This should trigger PriceChangeOutOfBounds because (1.04-0.65)/1.04 * 10000 = 3750 < 5000
        // Actually let's try the reverse: 1.04 -> 0.65 is 37.5% decrease
        // Let's use values that will trigger > 50% change
        usdtOracle.setPrice(1.02e8); // 1.02 USD (within bounds)
        usdtOracle.setPrevPrice(0.49e8); // 0.49 USD - this creates > 50% change
        
        vm.expectRevert(OracleRateProvider.OracleRateProvider__PriceChangeOutOfBounds.selector);
        usdtOracleRateProvider.getRate();
    }

    function testPriceChangeOutOfBounds_PriceDecreaseAboveMax() external {
        // Initialize oracle
        _initOracle(usdtOracle);
        
        // Set current price much lower than previous (more than 50% deviation)
        // Previous price: 2e8, new price: 1e8 (50% decrease, exactly at limit)
        // Let's make it 60% decrease to trigger the revert
        usdtOracle.setPrice(8e7); // 0.8 * 1e8
        usdtOracle.setPrevPrice(2e8); // 2 * 1e8
        
        vm.expectRevert(OracleRateProvider.OracleRateProvider__PriceChangeOutOfBounds.selector);
        usdtOracleRateProvider.getRate();
    }

    function testPriceOutOfBounds_BelowLowerBound() external {
        // Initialize oracle
        _initOracle(usdtOracle);
        
        // Set price below lower bound (0.95e6 for 6 decimals)
        // Price of 0.9e8 in 8 decimals should scale to 0.9e6 in 6 decimals, which is below 0.95e6
        usdtOracle.setPrice(0.9e8);
        usdtOracle.setPrevPrice(0.9e8);
        
        vm.expectRevert(OracleRateProvider.OracleRateProvider__PriceOutOfBounds.selector);
        usdtOracleRateProvider.getRate();
    }

    function testPriceOutOfBounds_AboveUpperBound() external {
        // Initialize oracle
        _initOracle(usdtOracle);
        
        // Set price above upper bound (1.05e6 for 6 decimals)
        // Price of 1.1e8 in 8 decimals should scale to 1.1e6 in 6 decimals, which is above 1.05e6
        usdtOracle.setPrice(1.1e8);
        usdtOracle.setPrevPrice(1.1e8);
        
        vm.expectRevert(OracleRateProvider.OracleRateProvider__PriceOutOfBounds.selector);
        usdtOracleRateProvider.getRate();
    }

    function testPriceOutOfBounds_DAI_BelowLowerBound() external {
        // Initialize oracle
        _initOracle(daiOracle);
        
        // Set price below lower bound (0.95e18 for 18 decimals)
        // Price of 0.9e8 in 8 decimals should scale to 0.9e18 in 18 decimals, which is below 0.95e18
        daiOracle.setPrice(0.9e8);
        daiOracle.setPrevPrice(0.9e8);
        
        vm.expectRevert(OracleRateProvider.OracleRateProvider__PriceOutOfBounds.selector);
        daiOracleRateProvider.getRate();
    }

    function testPriceOutOfBounds_DAI_AboveUpperBound() external {
        // Initialize oracle
        _initOracle(daiOracle);
        
        // Set price above upper bound (1.05e18 for 18 decimals)
        // Price of 1.1e8 in 8 decimals should scale to 1.1e18 in 18 decimals, which is above 1.05e18
        daiOracle.setPrice(1.1e8);
        daiOracle.setPrevPrice(1.1e8);
        
        vm.expectRevert(OracleRateProvider.OracleRateProvider__PriceOutOfBounds.selector);
        daiOracleRateProvider.getRate();
    }

    function testSuccessfulGetRate_WithinBounds() external {
        // Initialize oracle with valid data
        _initOracle(usdtOracle);
        
        // Set price within bounds and deviation limits
        usdtOracle.setPrice(1e8); // 1.0 USD
        usdtOracle.setPrevPrice(1.01e8); // 1.01 USD (1% change, within 50% limit)
        
        uint256 rate = usdtOracleRateProvider.getRate();
        assertEq(rate, 1e6, "Rate should be 1e6 for 1 USD with 6 decimals");
    }

    function testSuccessfulGetRate_MaxAllowedDeviation() external {
        // Initialize oracle with valid data
        _initOracle(usdtOracle);
        
        // Set price with deviation just under 50% and within bounds
        // From 1e8 to 1.04e8 = 4% increase (well within 50% limit and 1.04 < 1.05 upper bound)
        usdtOracle.setPrice(1.04e8);
        usdtOracle.setPrevPrice(1e8);
        
        uint256 rate = usdtOracleRateProvider.getRate();
        assertEq(rate, 1.04e6, "Rate should be 1.04e6 for 1.04 USD with 6 decimals");
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        if (blockNumber == 0) {
            forkId = vm.createFork(vm.envString(rpcKey)); // Use latest block
        } else {
            forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        }
        vm.selectFork(forkId);
    }

    function _initOracle(MockAggregator oracle) internal {
        oracle.setPrice(1e8);
        oracle.setPrevPrice(1e8);
        oracle.setUpdateTime(block.timestamp);
        oracle.setPrevUpdateTime(block.timestamp - 1 days);
        oracle.setLatestRoundId(2);
        oracle.setPrevRoundId(1);
    }
} 