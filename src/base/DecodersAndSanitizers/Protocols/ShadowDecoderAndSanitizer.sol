// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {INonFungiblePositionManagerShadow} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";
import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract ShadowDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error ShadowDecoderAndSanitizer__BadTokenId();

    //============================== IMMUTABLES ===============================

    /**
     * @notice The Shadow Exchange nonfungible position manager.
     */
    INonFungiblePositionManagerShadow internal immutable shadowNonFungiblePositionManager;

    constructor(address _shadowNonFungiblePositionManager) {
        shadowNonFungiblePositionManager = INonFungiblePositionManagerShadow(_shadowNonFungiblePositionManager);
    }

    //============================== SHADOW EXCHANGE ===============================

    function mint(DecoderCustomTypes.MintParamsShadow calldata params)
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
        // Sanitize raw data
        address owner = shadowNonFungiblePositionManager.ownerOf(params.tokenId);
        // Extract addresses from shadowNonFungiblePositionManager.positions(params.tokenId).
        // Note: Shadow positions function returns different parameters than Uniswap V3
        (address token0, address token1,,,,,,,) =
            shadowNonFungiblePositionManager.positions(params.tokenId);
        addressesFound = abi.encodePacked(token0, token1, owner);
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
        address owner = shadowNonFungiblePositionManager.ownerOf(params.tokenId);

        // No addresses in data
        return abi.encodePacked(owner);
    }
} 