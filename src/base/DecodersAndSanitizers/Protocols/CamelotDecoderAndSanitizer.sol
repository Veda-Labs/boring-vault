// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {CamelotNonFungiblePositionManager} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";
import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract CamelotDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error CamelotDecoderAndSanitizer__BadTokenId();
    error CamelotDecoderAndSanitizer__BadPathFormat();

    //============================== IMMUTABLES ===============================

    /**
     * @notice The networks Camelot nonfungible position manager.
     * @notice Arbitrum 0x00c7f3082833e796A5b3e4Bd59f6642FF44DCD15
     * @notice
     */
    CamelotNonFungiblePositionManager internal immutable camelotNonFungiblePositionManager;

    constructor(address _camelotNonFungiblePositionManager) {
        camelotNonFungiblePositionManager = CamelotNonFungiblePositionManager(_camelotNonFungiblePositionManager);
    }

    //============================== CAMELOT V3 ===============================

    function exactInput(DecoderCustomTypes.ExactInputParams calldata params)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize
        // Return addresses found
        // Determine how many addresses are in params.path.
        uint256 chunkSize = 20; // 20 bytes for address token
        uint256 pathLength = params.path.length;
        if (pathLength % chunkSize != 0) revert CamelotDecoderAndSanitizer__BadPathFormat();
        uint256 pathAddressLength = pathLength / chunkSize;
        uint256 pathIndex;
        for (uint256 i; i < pathAddressLength; ++i) {
            addressesFound = abi.encodePacked(addressesFound, params.path[pathIndex:pathIndex + 20]);
            pathIndex += chunkSize;
        }
        addressesFound = abi.encodePacked(addressesFound, params.recipient);
    }

    function mint(DecoderCustomTypes.CamelotMintParams calldata params)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize
        // Return addresses found
        addressesFound = abi.encodePacked(params.token0, params.token1, params.recipient);
    }

    function increaseLiquidity(DecoderCustomTypes.IncreaseLiquidityParams calldata params)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        address owner = camelotNonFungiblePositionManager.ownerOf(params.tokenId);
        // Extract addresses from camelotNonFungiblePositionManager.positions(params.tokenId).
        (, address operator, address token0, address token1,,,,,,,) =
            camelotNonFungiblePositionManager.positions(params.tokenId);
        addressesFound = abi.encodePacked(operator, token0, token1, owner);
    }

    function decreaseLiquidity(DecoderCustomTypes.DecreaseLiquidityParams calldata params)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        // Sanitize raw data
        // NOTE ownerOf check is done in PositionManager contract as well, but it is added here
        // just for completeness.
        address owner = camelotNonFungiblePositionManager.ownerOf(params.tokenId);

        // No addresses in data
        return abi.encodePacked(owner);
    }

    function collect(DecoderCustomTypes.CollectParams calldata params)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        address owner = camelotNonFungiblePositionManager.ownerOf(params.tokenId);
        // Return addresses found
        addressesFound = abi.encodePacked(params.recipient, owner);
    }

    function burn(uint256 /*tokenId*/ ) external pure virtual returns (bytes memory addressesFound) {
        // positionManager.burn(tokenId) will verify that the tokenId has no liquidity, and no tokens owed.
        // Nothing to sanitize or return
        return addressesFound;
    }
}
