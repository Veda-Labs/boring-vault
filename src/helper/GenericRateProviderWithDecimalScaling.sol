// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {GenericRateProvider} from "src/helper/GenericRateProvider.sol";

contract GenericRateProviderWithDecimalScaling is GenericRateProvider {
    //============================== STRUCTS ===============================
    struct ConstructorArgs {
        address target;
        bytes4 selector;
        bytes32 staticArgument0;
        bytes32 staticArgument1;
        bytes32 staticArgument2;
        bytes32 staticArgument3;
        bytes32 staticArgument4;
        bytes32 staticArgument5;
        bytes32 staticArgument6;
        bytes32 staticArgument7;
        bool signed;
        uint8 inputDecimals;
        uint8 outputDecimals;
    }

    //============================== ERRORS ===============================
    error GenericRateProviderWithDecimalScaling__DecimalsCannotBeZero();

    //============================== IMMUTABLES ===============================
    uint8 public immutable inputDecimals;
    uint8 public immutable outputDecimals;

    constructor(ConstructorArgs memory _args)
        GenericRateProvider(
            _args.target,
            _args.selector,
            _args.staticArgument0,
            _args.staticArgument1,
            _args.staticArgument2,
            _args.staticArgument3,
            _args.staticArgument4,
            _args.staticArgument5,
            _args.staticArgument6,
            _args.staticArgument7,
            _args.signed
        )
    {
        if (_args.inputDecimals == 0 || _args.outputDecimals == 0) {
            revert GenericRateProviderWithDecimalScaling__DecimalsCannotBeZero();
        }
        inputDecimals = _args.inputDecimals;
        outputDecimals = _args.outputDecimals;
    }

    function getRate() public view override returns (uint256) {
        uint256 rate = super.getRate();
        if (inputDecimals > outputDecimals) {
            return rate / 10 ** (inputDecimals - outputDecimals);
        } else if (inputDecimals < outputDecimals) {
            return rate * 10 ** (outputDecimals - inputDecimals);
        } else {
            return rate;
        }
    }
}
