// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AlgebraNonFungiblePositionManager} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract AlgebraV4DecoderAndSanitizer {
    //============================== ERRORS ===============================

    error AlgebraDecoderAndSanitizer__BadPathFormat();

    //============================== IMMUTABLES ===============================

    /**
     * @notice The networks Algebra nonfungible position manager.
     * @notice Arbitrum 0x00c7f3082833e796A5b3e4Bd59f6642FF44DCD15
     * @notice
     */
    AlgebraNonFungiblePositionManager internal immutable algebraNonFungiblePositionManager;

    constructor(address _algebraNonFungiblePositionManager) {
        algebraNonFungiblePositionManager = AlgebraNonFungiblePositionManager(_algebraNonFungiblePositionManager);
    }

    //============================== ALGEBRA V4 ===============================

    function exactInput(DecoderCustomTypes.ExactInputParams calldata params)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        bytes memory path = params.path;

        uint256 pathLength = path.length;
        if (pathLength < 60 || pathLength % 40 != 20) {
            revert AlgebraDecoderAndSanitizer__BadPathFormat();
        }
        
        // Extract first tokenIn outside the loop
        address tokenIn;
        assembly {
            tokenIn := shr(96, mload(add(path, 32)))
        }
        addressesFound = abi.encodePacked(addressesFound, tokenIn);
        
        // start at position 20 (after first tokenIn)
        uint256 i = 20;
        while (i + 40 <= pathLength) {
            address deployer;
            address tokenOut;
        
            assembly {
                deployer := shr(96, mload(add(add(path, 32), i)))
                tokenOut := shr(96, mload(add(add(path, 32), add(i, 20))))
            }
        
            addressesFound = abi.encodePacked(addressesFound, deployer, tokenOut);
            i += 40; // move to next deployer/tokenOut pair
        }
        
        // Append recipient
        addressesFound = abi.encodePacked(addressesFound, params.recipient);
    }

    function mint(DecoderCustomTypes.AlgebraMintParams calldata params)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize
        // Return addresses found
        addressesFound = abi.encodePacked(params.token0, params.token1, params.deployer, params.recipient);
    }

    function increaseLiquidity(DecoderCustomTypes.IncreaseLiquidityParams calldata params)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        address owner = algebraNonFungiblePositionManager.ownerOf(params.tokenId);
        // Extract addresses from algebraNonFungiblePositionManager.positions(params.tokenId).
        (, address operator, address token0, address token1, address deployer,,,,,,,) =
            algebraNonFungiblePositionManager.positions(params.tokenId);
        addressesFound = abi.encodePacked(operator, token0, token1, deployer, owner);
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
        address owner = algebraNonFungiblePositionManager.ownerOf(params.tokenId);

        // No addresses in data
        return abi.encodePacked(owner);
    }

    function collect(DecoderCustomTypes.CollectParams calldata params)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        address owner = algebraNonFungiblePositionManager.ownerOf(params.tokenId);
        // Return addresses found
        addressesFound = abi.encodePacked(params.recipient, owner);
    }

    function burn(uint256 /*tokenId*/ ) external pure virtual returns (bytes memory addressesFound) {
        // positionManager.burn(tokenId) will verify that the tokenId has no liquidity, and no tokens owed.
        // Nothing to sanitize or return
        return addressesFound;
    }
}
