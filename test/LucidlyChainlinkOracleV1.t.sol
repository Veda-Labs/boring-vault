// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {Test, console} from "@forge-std/Test.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {LucidlyChainlinkOracleV1} from "src/adapters/oracle/LucidlyChainlinkOracleV1.sol";
import {AggregatorV3Interface} from "src/adapters/libraries/ChainlinkDataFeedLib.sol";

contract LucidlyChainlinkOracleV1Test is Test {
    address constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address constant USDE_USD_FEED = 0xa569d910839Ae8865Da8F8e70FfFb0cBA869F961;
    address constant USDC_USD_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address constant USDS_USD_FEED = 0xfF30586cD0F29eD462364C7e81375FC0C71219b1;
    address constant SYRUP_USDC = 0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b;

    LucidlyChainlinkOracleV1 public syrupUsdcOracle;
    LucidlyChainlinkOracleV1 public plainUsdcOracle;
    LucidlyChainlinkOracleV1 public susdeOracle;
    LucidlyChainlinkOracleV1 public susdsOracle;

    function setUp() public {
        vm.createSelectFork("mainnet");

        syrupUsdcOracle = new LucidlyChainlinkOracleV1(
            ERC4626(SYRUP_USDC),
            1e6,
            AggregatorV3Interface(USDC_USD_FEED),
            AggregatorV3Interface(address(0)),
            6,
            8,
            "syrupUSDC/USD"
        );

        plainUsdcOracle = new LucidlyChainlinkOracleV1(
            ERC4626(address(0)),
            1,
            AggregatorV3Interface(USDC_USD_FEED),
            AggregatorV3Interface(address(0)),
            6,
            8,
            "USDC/USD"
        );

        susdeOracle = new LucidlyChainlinkOracleV1(
            ERC4626(SUSDE),
            1e18,
            AggregatorV3Interface(USDE_USD_FEED),
            AggregatorV3Interface(address(0)),
            18,
            8,
            "sUSDE/USD"
        );

        susdsOracle = new LucidlyChainlinkOracleV1(
            ERC4626(SUSDS),
            1e18,
            AggregatorV3Interface(USDS_USD_FEED),
            AggregatorV3Interface(address(0)),
            18,
            8,
            "sUSDS/USD"
        );
    }

    function test_syrupUsdc_price_gt_usdc() public view {
        (, int256 syrupPrice,,,) = syrupUsdcOracle.latestRoundData();
        (, int256 usdcPrice,,,) = plainUsdcOracle.latestRoundData();
        assertGe(syrupPrice, usdcPrice, "syrupUSDC should be >= USDC");
    }

    function test_susde_price_gt_usde() public view {
        (, int256 susdePrice,,,) = susdeOracle.latestRoundData();
        (, int256 usdePrice,,,) = AggregatorV3Interface(USDE_USD_FEED).latestRoundData();

        console.log("sUSDE/USD:", uint256(susdePrice));
        console.log("USDe/USD: ", uint256(usdePrice));

        // sUSDE should be worth >= USDe (it accrues yield)
        assertGe(susdePrice, usdePrice, "sUSDE should be >= USDe");
    }

    function test_susds_price_gt_usds() public view {
        (, int256 susdsPrice,,,) = susdsOracle.latestRoundData();
        (, int256 usdsPrice,,,) = AggregatorV3Interface(USDS_USD_FEED).latestRoundData();

        console.log("sUSDS/USD:", uint256(susdsPrice));
        console.log("USDS/USD: ", uint256(usdsPrice));

        assertGe(susdsPrice, usdsPrice, "sUSDS should be >= USDS");
    }

    function test_decimals() public view {
        assertEq(syrupUsdcOracle.decimals(), 8);
    }

    function test_price_positive() public view {
        (, int256 price,,,) = syrupUsdcOracle.latestRoundData();
        assertGt(price, 0, "price should be positive");
    }

    function test_updatedAt_is_current() public view {
        (,,, uint256 updatedAt,) = syrupUsdcOracle.latestRoundData();
        assertEq(updatedAt, block.timestamp);
    }

    function test_plain_feed_passthrough() public view {
        (, int256 oraclePrice,,,) = plainUsdcOracle.latestRoundData();
        (, int256 directPrice,,,) = AggregatorV3Interface(USDC_USD_FEED).latestRoundData();

        assertEq(oraclePrice, directPrice, "passthrough should match direct feed");
    }
}
