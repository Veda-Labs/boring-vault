// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {GenericRateProviderWithStalenessCheck} from "src/helper/GenericRateProviderWithStalenessCheck.sol";
import {Test} from "@forge-std/Test.sol";

contract MockOracle {
    uint256 public rate;
    uint256 public lastUpdate;

    function setRate(uint256 _rate) external {
        rate = _rate;
    }

    function setLastUpdate(uint256 _ts) external {
        lastUpdate = _ts;
    }

    function getRate() external view returns (uint256) {
        return rate;
    }

    function getLastUpdate() external view returns (uint256) {
        return lastUpdate;
    }
}

contract GenericRateProviderWithStalenessCheckTest is Test {
    MockOracle oracle;

    uint256 constant BASE_RATE = 1_000_000_000_000_000_000; // 1e18

    function setUp() external {
        oracle = new MockOracle();
        oracle.setRate(BASE_RATE);
        oracle.setLastUpdate(block.timestamp);
    }

    function testGetRate_SameDecimals() external {
        GenericRateProviderWithStalenessCheck provider = _deploy(18, 18);
        assertEq(provider.getRate(), BASE_RATE);
    }

    function testGetRate_ScalesDown_18To8() external {
        GenericRateProviderWithStalenessCheck provider = _deploy(18, 8);
        assertEq(provider.getRate(), BASE_RATE / 1e10);
    }

    function testGetRate_ScalesUp_8To18() external {
        oracle.setRate(1e8);
        GenericRateProviderWithStalenessCheck provider = _deploy(8, 18);
        assertEq(provider.getRate(), 1e8 * 1e10);
    }

    function testGetRate_ScalesDown_18To6() external {
        GenericRateProviderWithStalenessCheck provider = _deploy(18, 6);
        assertEq(provider.getRate(), BASE_RATE / 1e12);
    }

    function testGetRate_ScalesUp_6To18() external {
        oracle.setRate(1e6);
        GenericRateProviderWithStalenessCheck provider = _deploy(6, 18);
        assertEq(provider.getRate(), 1e6 * 1e12);
    }

    function testGetRate_RevertsOnStalePrice() external {
        GenericRateProviderWithStalenessCheck provider = _deploy(18, 18);

        vm.warp(block.timestamp + 2 hours);
        vm.expectRevert(
            GenericRateProviderWithStalenessCheck.GenericRateProviderWithStalenessCheck__StalePrice.selector
        );
        provider.getRate();
    }

    function testConstructor_RevertsOnZeroInputDecimals() external {
        vm.expectRevert(
            GenericRateProviderWithStalenessCheck.GenericRateProviderWithStalenessCheck__DecimalsCannotBeZero.selector
        );
        _deploy(0, 18);
    }

    function testConstructor_RevertsOnZeroOutputDecimals() external {
        vm.expectRevert(
            GenericRateProviderWithStalenessCheck.GenericRateProviderWithStalenessCheck__DecimalsCannotBeZero.selector
        );
        _deploy(18, 0);
    }

    function _deploy(uint8 inputDecimals, uint8 outputDecimals)
        internal
        returns (GenericRateProviderWithStalenessCheck)
    {
        return new GenericRateProviderWithStalenessCheck(
            GenericRateProviderWithStalenessCheck.ConstructorArgs({
                target: address(oracle),
                selector: MockOracle.getRate.selector,
                staticArgument0: bytes32(0),
                staticArgument1: bytes32(0),
                staticArgument2: bytes32(0),
                staticArgument3: bytes32(0),
                staticArgument4: bytes32(0),
                staticArgument5: bytes32(0),
                staticArgument6: bytes32(0),
                staticArgument7: bytes32(0),
                signed: false,
                inputDecimals: inputDecimals,
                outputDecimals: outputDecimals,
                maxStaleness: 1 hours,
                lastUpdateSelector: MockOracle.getLastUpdate.selector,
                lastUpdateOffset: 0
            })
        );
    }
}
