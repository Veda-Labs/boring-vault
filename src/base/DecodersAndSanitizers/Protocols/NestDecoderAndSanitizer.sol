// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {CamelotNonFungiblePositionManager} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract NestDecoderAndSanitizer {
    //============================== IMMUTABLES ===============================

    /**
     * @notice The Nest DEX nonfungible position manager (Algebra Integral periphery).
     */
    CamelotNonFungiblePositionManager internal immutable nestNonFungiblePositionManager;

    constructor(address _nestNonFungiblePositionManager) {
        nestNonFungiblePositionManager = CamelotNonFungiblePositionManager(_nestNonFungiblePositionManager);
    }

    //============================== NEST DEX LP ===============================

    function mint(DecoderCustomTypes.CamelotMintParams calldata params)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(params.token0, params.token1, params.recipient);
    }

    function increaseLiquidity(DecoderCustomTypes.IncreaseLiquidityParams calldata params)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        address owner = nestNonFungiblePositionManager.ownerOf(params.tokenId);
        (, address operator, address token0, address token1,,,,,,,) =
            nestNonFungiblePositionManager.positions(params.tokenId);
        addressesFound = abi.encodePacked(operator, token0, token1, owner);
    }

    function decreaseLiquidity(DecoderCustomTypes.DecreaseLiquidityParams calldata params)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        address owner = nestNonFungiblePositionManager.ownerOf(params.tokenId);
        return abi.encodePacked(owner);
    }

    function collect(DecoderCustomTypes.CollectParams calldata params)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        address owner = nestNonFungiblePositionManager.ownerOf(params.tokenId);
        addressesFound = abi.encodePacked(params.recipient, owner);
    }

    function burn(uint256 /*tokenId*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    //============================== NEST DEX REWARDS ===============================

    function claim(uint256, /*totalAmount*/ uint256, /*deadline*/ bytes calldata /*signature*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }
}
