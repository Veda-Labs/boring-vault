// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";

/// @notice Base contract for adapters that provides access to the appended SwapConfig.
/// @dev The swapper appends data after the original calldata in the format:
///      [original swapData (N bytes)] [abi.encode(SwapConfig)] [uint256(N)]
///      The last 32 bytes are always the original calldata length, used as a boundary marker.
abstract contract BaseAdapter {

    /// @notice Extracts the appended SwapConfig from the trailing calldata.
    function _getAppendedSwapConfig() internal pure returns (ISwapperTypes.SwapConfig memory) {
        bytes memory appended;
        assembly {
            // last 32 bytes = original calldata length
            let originalLen := calldataload(sub(calldatasize(), 0x20))
            // appended data sits between originalLen and calldatasize() - 32
            let appendedLen := sub(sub(calldatasize(), 0x20), originalLen)

            // allocate memory and copy
            appended := mload(0x40)
            mstore(0x40, add(appended, add(appendedLen, 0x20)))
            mstore(appended, appendedLen)
            calldatacopy(add(appended, 0x20), originalLen, appendedLen)
        }
        return abi.decode(appended, (ISwapperTypes.SwapConfig));
    }
}
