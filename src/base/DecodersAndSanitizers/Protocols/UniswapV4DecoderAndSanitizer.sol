// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {IUniswapV4PositionManager} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";
import {Actions, Commands} from "src/interfaces/UniswapV4Actions.sol";

contract UniswapV4DecoderAndSanitizer {
    //============================== ERRORS ===============================

    error UniswapV4DecoderAndSanitizer__NotSwapInput();
    error UniswapV4DecoderAndSanitizer__NotSwapSubAction();
    error UniswapV4DecoderAndSanitizer__SwapActionLength();
    error UniswapV4DecoderAndSanitizer__UnsupportedAction();
    error UniswapV4DecoderAndSanitizer__UnsupportedSubAction();
    error UniswapV4DecoderAndSanitizer__SubActionLength();
    error UniswapV4DecoderAndSanitizer__MustBeSweep();

    //============================== Immutables ===============================
    IUniswapV4PositionManager posm;

    //============================== Constructor ===============================
    constructor(address _posm) {
        posm = IUniswapV4PositionManager(_posm);
    }

    //============================== Universal Router ===============================

    // @dev in order to sanitize we require that only command be passed in a time. This defeats the ability to batch commands together, but is necessary to avoid having a gajillion leaves for all possible orders that can be used here
    // @dev inputs can be grouped together based on common things, ie. swaps will always be swap, settle, take, etc.
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 /*deadline*/ )
        external
        pure
        returns (bytes memory addressesFound)
    {
        // Verify exactly 1 byte
        require(commands.length <= 2, "Invalid commands length");
        // Extract and verify command
        uint8 command = uint8(commands[0]);
        if (command == uint8(Commands.V4_SWAP)) {
            // Extract the path from PoolKey
            (bytes memory actions, bytes[] memory params) = abi.decode(inputs[0], (bytes, bytes[]));
            if (actions.length > 3) revert UniswapV4DecoderAndSanitizer__SwapActionLength();

            if (
                uint8(actions[0]) == uint8(Actions.SWAP_EXACT_IN_SINGLE)
                    || uint8(actions[0]) == uint8(Actions.SWAP_EXACT_OUT_SINGLE)
            ) {
                // Decode the first param which should be our ExactInputSingleParams/ExactOutputSingleParams struct (same fields)
                DecoderCustomTypes.ExactInputSingleParams memory swapParams =
                    abi.decode(params[0], (DecoderCustomTypes.ExactInputSingleParams));

                // Extract addresses from poolKey
                address currency0 = address(swapParams.poolKey.currency0);
                address currency1 = address(swapParams.poolKey.currency1);
                address hook = address(swapParams.poolKey.hooks);

                //verify we are SETTLING, and then TAKING
                if (uint8(actions[1]) != uint8(Actions.SETTLE_ALL)) {
                    revert UniswapV4DecoderAndSanitizer__NotSwapSubAction();
                }
                if (uint8(actions[2]) != uint8(Actions.TAKE_ALL)) {
                    revert UniswapV4DecoderAndSanitizer__NotSwapSubAction();
                }

                (address currencyToSpend,) = abi.decode(params[1], (address, uint128));
                (address currencyToReceive,) = abi.decode(params[2], (address, uint128));

                addressesFound = abi.encodePacked(currency0, currency1, hook, currencyToSpend, currencyToReceive);

                if (commands.length == 1) return addressesFound;

                //otherwise, we have a sweep

                uint8 command1 = uint8(commands[1]);
                if (command1 != uint8(Commands.SWEEP)) revert UniswapV4DecoderAndSanitizer__NotSwapSubAction();

                (address currencyToSweep, address recipient,) = abi.decode(inputs[1], (address, address, uint256));
                addressesFound = abi.encodePacked(addressesFound, currencyToSweep, recipient);
            } else {
                revert UniswapV4DecoderAndSanitizer__UnsupportedAction();
            }
        } else {
            //only support v4 swaps via the universal router
            revert UniswapV4DecoderAndSanitizer__NotSwapInput();
        }
    }

    //============================== Permit2 ===============================

    function approve(address token, address spender, uint160, /*amount*/ uint48 /*expiraton*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(token, spender);
    }

    //============================== Position Manager ===============================

    function modifyLiquidities(bytes calldata unlockData, uint256 /*deadline*/ )
        external
        view
        returns (bytes memory addressesFound)
    {
        // First decode the outer tuple (actions, params)
        (bytes memory actions, bytes[] memory params) = abi.decode(unlockData, (bytes, bytes[]));

        //only support 1 action at a time (which can have up to 4 subactions, so 3 actions total)
        if (actions.length > 4) revert UniswapV4DecoderAndSanitizer__SubActionLength();

        uint8 action = uint8(bytes1(actions[0]));
        if (action == uint8(Actions.MINT_POSITION)) {
            if (actions.length > 3) revert UniswapV4DecoderAndSanitizer__SubActionLength();

            (
                DecoderCustomTypes.PoolKey memory poolKey,
                /*int24 tickLower*/
                ,
                /*int24 tickUpper*/
                ,
                /*uint256 liquidity*/
                ,
                /*uint128 amount0Max*/
                ,
                /*uint128 amount1Max*/
                ,
                address recipient,
                /*bytes memory hookData*/
            ) = abi.decode(
                params[0], (DecoderCustomTypes.PoolKey, int24, int24, uint256, uint128, uint128, address, bytes)
            );

            // Ensure we're settling next, and then settling the correct pair
            uint8 subAction = uint8(bytes1(actions[1]));
            if (subAction != uint8(Actions.SETTLE_PAIR)) revert UniswapV4DecoderAndSanitizer__UnsupportedSubAction();

            (address currency0Settle, address currency1Settle) = abi.decode(params[1], (address, address));

            addressesFound = abi.encodePacked(
                poolKey.currency0, poolKey.currency1, poolKey.hooks, recipient, currency0Settle, currency1Settle
            );

            //expected sweep index would be 2 here (if any) -> mint, settle, sweep
            addressesFound = _processSweepIfPresent(actions, params, 2, addressesFound);

            return addressesFound;

            // @dev if increasing liquidity, we can either SETTLE_PAIR, CLOSE_CURRENCY, or CLEAR_OR_TAKE. If using ETH, we can also include an optional SWEEP
        } else if (action == uint8(Actions.INCREASE_LIQUIDITY)) {
            (
                uint256 tokenId,
                /*uint256 liquidity*/
                ,
                /*uint128 amount0Max*/
                ,
                /*uint128 amount1Max*/
                ,
                /*bytes memory hookData*/
            ) = abi.decode(params[0], (uint256, uint256, uint128, uint128, bytes));

            (DecoderCustomTypes.PoolKey memory poolKey,) = posm.getPoolAndPositionInfo(tokenId);

            uint8 subAction = uint8(bytes1(actions[1]));

            uint8 subAction1;
            if (actions.length > 2) {
                subAction1 = uint8(bytes1(actions[2]));
            }

            if (subAction == uint8(Actions.SETTLE_PAIR)) {
                if (actions.length > 3) revert UniswapV4DecoderAndSanitizer__SubActionLength();

                (address currency0Settle, address currency1Settle) = abi.decode(params[1], (address, address));

                addressesFound = abi.encodePacked(
                    poolKey.currency0, poolKey.currency1, poolKey.hooks, currency0Settle, currency1Settle
                );

                //expected sweep index would be 2 here (if any) -> increase, settle, sweep
                addressesFound = _processSweepIfPresent(actions, params, 2, addressesFound);
                return addressesFound;
            } else if (subAction == uint8(Actions.CLOSE_CURRENCY)) {
                //if the length is too short, we revert w/ unsupported
                if (actions.length <= 2) revert UniswapV4DecoderAndSanitizer__SubActionLength();

                //if the first subaction is CLOSE_CURRENCY, we decode that param
                //NOTE: The second subaction does not need to be CLOSE_CURRENCY, so we have to check both paths
                //both result in the same sanitization, but are decoded differently

                (address currency0Settle) = abi.decode(params[1], (address));
                address currency1Settle;
                if (subAction1 == uint8(Actions.CLOSE_CURRENCY)) {
                    (currency1Settle) = abi.decode(params[2], (address));
                } else if (subAction1 == uint8(Actions.CLEAR_OR_TAKE)) {
                    (currency1Settle,) = abi.decode(params[2], (address, uint256));
                } else {
                    // If somehow anything else is passed here, we revert
                    revert UniswapV4DecoderAndSanitizer__UnsupportedSubAction();
                }

                // Return currency0, currency1
                addressesFound = abi.encodePacked(
                    poolKey.currency0, poolKey.currency1, poolKey.hooks, currency0Settle, currency1Settle
                );
                addressesFound = _processSweepIfPresent(actions, params, 3, addressesFound);
                return addressesFound;
            } else if (subAction == uint8(Actions.CLEAR_OR_TAKE)) {
                if (actions.length <= 2) revert UniswapV4DecoderAndSanitizer__SubActionLength();

                (address currency0Settle,) = abi.decode(params[1], (address, uint256));
                address currency1Settle;

                if (subAction1 == uint8(Actions.CLOSE_CURRENCY)) {
                    (currency1Settle) = abi.decode(params[2], (address));
                } else if (subAction1 == uint8(Actions.CLEAR_OR_TAKE)) {
                    (currency1Settle,) = abi.decode(params[2], (address, uint256));
                } else {
                    // If somehow anything else is passed here, we revert
                    revert UniswapV4DecoderAndSanitizer__UnsupportedSubAction();
                }

                // Return currency0, currency1
                addressesFound = abi.encodePacked(
                    poolKey.currency0, poolKey.currency1, poolKey.hooks, currency0Settle, currency1Settle
                );
                addressesFound = _processSweepIfPresent(actions, params, 3, addressesFound);
                return addressesFound;
            } else {
                revert UniswapV4DecoderAndSanitizer__UnsupportedSubAction();
            }
        } else if (action == uint8(Actions.DECREASE_LIQUIDITY)) {
            (
                uint256 tokenId,
                /*uint256 liquidity*/
                ,
                /*uint128 amount0Max*/
                ,
                /*uint128 amount1Max*/
                ,
                /*bytes memory hookData*/
            ) = abi.decode(params[0], (uint256, uint256, uint128, uint128, bytes));

            (DecoderCustomTypes.PoolKey memory poolKey,) = posm.getPoolAndPositionInfo(tokenId);

            // Get the subaction
            uint8 subAction = uint8(bytes1(actions[1]));

            // Check the length
            uint8 subAction1;
            if (actions.length > 2) {
                subAction1 = uint8(bytes1(actions[2]));
            }

            if (subAction == uint8(Actions.TAKE_PAIR)) {
                if (actions.length > 3) revert UniswapV4DecoderAndSanitizer__SubActionLength();

                (address currency0Settle, address currency1Settle, address recipient) =
                    abi.decode(params[1], (address, address, address));

                addressesFound = abi.encodePacked(
                    poolKey.currency0, poolKey.currency1, poolKey.hooks, currency0Settle, currency1Settle, recipient
                );

                //if sweep, would be decrease, take, sweep
                addressesFound = _processSweepIfPresent(actions, params, 2, addressesFound);
                return addressesFound;

                // Supported but not recommended
            } else if (subAction == uint8(Actions.CLOSE_CURRENCY)) {
                //if the length is too short, we revert w/ unsupported
                if (actions.length <= 2) revert UniswapV4DecoderAndSanitizer__SubActionLength();

                //if the first subaction is CLOSE_CURRENCY, we decode that param
                //NOTE: The second subaction does not need to be CLOSE_CURRENCY, so we have to check both paths

                (address currency0Settle) = abi.decode(params[1], (address));
                address currency1Settle;

                if (subAction1 == uint8(Actions.CLOSE_CURRENCY)) {
                    (currency1Settle) = abi.decode(params[2], (address));
                } else if (subAction1 == uint8(Actions.CLEAR_OR_TAKE)) {
                    (currency1Settle,) = abi.decode(params[2], (address, uint256));
                } else {
                    revert UniswapV4DecoderAndSanitizer__UnsupportedSubAction();
                }

                addressesFound = abi.encodePacked(
                    poolKey.currency0, poolKey.currency1, poolKey.hooks, currency0Settle, currency1Settle
                );
                addressesFound = _processSweepIfPresent(actions, params, 3, addressesFound);
                return addressesFound;
            } else if (subAction == uint8(Actions.CLEAR_OR_TAKE)) {
                if (actions.length <= 2) revert UniswapV4DecoderAndSanitizer__SubActionLength();

                (address currency0Settle,) = abi.decode(params[1], (address, uint256));
                address currency1Settle;

                if (subAction1 == uint8(Actions.CLOSE_CURRENCY)) {
                    (currency1Settle) = abi.decode(params[2], (address));
                } else if (subAction1 == uint8(Actions.CLEAR_OR_TAKE)) {
                    (currency1Settle,) = abi.decode(params[2], (address, uint256));
                } else {
                    revert UniswapV4DecoderAndSanitizer__UnsupportedSubAction();
                }

                addressesFound = abi.encodePacked(
                    poolKey.currency0, poolKey.currency1, poolKey.hooks, currency0Settle, currency1Settle
                );
                addressesFound = _processSweepIfPresent(actions, params, 3, addressesFound);
                return addressesFound;
            } else {
                revert UniswapV4DecoderAndSanitizer__UnsupportedSubAction();
            }
        } else if (action == uint8(Actions.BURN_POSITION)) {
            if (actions.length > 3) revert UniswapV4DecoderAndSanitizer__SubActionLength();

            (
                uint256 tokenId,
                /*uint128 amount0Max*/
                ,
                /*uint128 amount1Max*/
                ,
                /*bytes memory hookData*/
            ) = abi.decode(params[0], (uint256, uint128, uint128, bytes));

            (DecoderCustomTypes.PoolKey memory poolKey,) = posm.getPoolAndPositionInfo(tokenId);

            uint8 subAction = uint8(bytes1(actions[1]));
            if (subAction == uint8(Actions.TAKE_PAIR)) {
                (address currency0Settle, address currency1Settle, address recipient) =
                    abi.decode(params[1], (address, address, address));
                addressesFound = abi.encodePacked(
                    poolKey.currency0, poolKey.currency1, poolKey.hooks, currency0Settle, currency1Settle, recipient
                );
                addressesFound = _processSweepIfPresent(actions, params, 2, addressesFound);
                return addressesFound;
            } else {
                revert UniswapV4DecoderAndSanitizer__UnsupportedSubAction();
            }
        } else {
            revert UniswapV4DecoderAndSanitizer__UnsupportedAction();
        }
    }

    //============================== Helper Functions ===============================

    // Helper function to check for and process SWEEP action
    function _processSweepIfPresent(
        bytes memory actions,
        bytes[] memory params,
        uint256 sweepActionIndex,
        bytes memory currentAddressesFound
    ) internal pure returns (bytes memory updatedAddressesFound) {
        // Check if there's another action and it's SWEEP
        if (actions.length > sweepActionIndex) {
            if (uint8(bytes1(actions[sweepActionIndex])) == uint8(Actions.SWEEP)) {
                (address currencyToSweep, address recipient) = abi.decode(params[sweepActionIndex], (address, address));

                // Append the sweep addresses to existing addresses
                updatedAddressesFound = abi.encodePacked(currentAddressesFound, currencyToSweep, recipient);

                return updatedAddressesFound;
            } else {
                //additional actions MUST be sweep or else they are unsanitized
                revert UniswapV4DecoderAndSanitizer__MustBeSweep();
            }
        }

        // If no SWEEP action, return the original addresses
        return currentAddressesFound;
    }
}
