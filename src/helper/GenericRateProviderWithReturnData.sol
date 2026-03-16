// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {GenericRateProvider} from "src/helper/GenericRateProvider.sol"; 
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract GenericRateProviderWithStalenessCheck is GenericRateProvider {
    using Address for address;

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
        uint256 maxStaleness;
        bytes4 lastUpdateSelector;
        uint8 lastUpdateOffset;
    }

    //============================== ERRORS ===============================
    error GenericRateProviderWithStalenessCheck__DecimalsCannotBeZero(); 
    error GenericRateProviderWithStalenessCheck__StalePrice(); 

    //============================== IMMUTABLES ===============================
    
    uint8 public immutable inputDecimals;
    uint8 public immutable outputDecimals;

    uint256 public immutable maxStaleness;

    /**
     * @notice The read selector returning the timestamp of last price update timestamp
     */
    bytes4 public immutable lastUpdateSelector;

    /**
     * @notice the offset for the return paramater of the lastUpdateSelector 
     */
    uint8 public immutable lastUpdateOffset;

    constructor(
        ConstructorArgs memory _args
    ) GenericRateProvider(
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
    ) {
        if (_args.inputDecimals == 0 || _args.outputDecimals == 0) {
            revert GenericRateProviderWithStalenessCheck__DecimalsCannotBeZero();
        }
        inputDecimals = _args.inputDecimals;
        outputDecimals = _args.outputDecimals;

        maxStaleness = _args.maxStaleness;     
        lastUpdateSelector = _args.lastUpdateSelector;
        lastUpdateOffset = _args.lastUpdateOffset;
    }

    // ========================================= RATE FUNCTION =========================================

    /**
     * @notice Get the rate of some generic asset.
     * @dev This function only supports selectors that only contain static arguments, dynamic arguments will not be encoded correctly,
     *      and calls will likely fail.
     * @dev If staticArgumentN is not used, it can be left as 0.
     */
    function getRate() public override view returns (uint256) {
        bytes memory callData = abi.encodeWithSelector(
            selector,
            staticArgument0,
            staticArgument1,
            staticArgument2,
            staticArgument3,
            staticArgument4,
            staticArgument5,
            staticArgument6,
            staticArgument7
        );
        bytes memory result = target.functionStaticCall(callData);

        bytes memory updatedData = abi.encodeWithSelector(
            lastUpdateSelector
        );
        bytes memory lastUpdateBytes = target.functionStaticCall(updatedData);

        uint256 lastUpdate;
        uint256 _lastUpdateOffset = lastUpdateOffset;
        assembly {
            lastUpdate := mload(add(lastUpdateBytes, add(32, mul(_lastUpdateOffset, 32))))
        }
        if (lastUpdate + maxStaleness < block.timestamp) revert GenericRateProviderWithStalenessCheck__StalePrice();

        if (signed) {
            //if target func() returns an int, we get the result and then cast it to a uint256
            int256 res = abi.decode(result, (int256)); 
            if (res < 0) revert GenericRateProvider__PriceCannotBeLtZero(); 

            return uint256(res); 
        
        } else {

            return abi.decode(result, (uint256));
        }
    }
}
