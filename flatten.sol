// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.21 ^0.8.0 ^0.8.20;

// lib/openzeppelin-contracts/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

// src/interfaces/IRateProvider.sol

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

interface IRateProvider {
    function getRate() external view returns (uint256);
}

// src/helper/GenericRateProvider.sol

contract GenericRateProvider is IRateProvider {
    using Address for address;

    //============================== ERRORS ===============================
    error GenericRateProvider__PriceCannotBeLtZero(); 

    //============================== IMMUTABLES ===============================

    /**
     * @notice The address to make rate calls to.
     */
    address public immutable target;

    /**
     * @notice The selector to call on the target.
     */
    bytes4 public immutable selector;

    /**
     * @notice boolean indicating if we need to check for a signed return value.
     * @dev if true, this indicates an int256 return value or similar signed number
     */
    bool public immutable signed; 

    /**
     * @notice Static arguments to pass to the target.
     */
    bytes32 public immutable staticArgument0;
    bytes32 public immutable staticArgument1;
    bytes32 public immutable staticArgument2;
    bytes32 public immutable staticArgument3;
    bytes32 public immutable staticArgument4;
    bytes32 public immutable staticArgument5;
    bytes32 public immutable staticArgument6;
    bytes32 public immutable staticArgument7;

    constructor(
        address _target,
        bytes4 _selector,
        bytes32 _staticArgument0,
        bytes32 _staticArgument1,
        bytes32 _staticArgument2,
        bytes32 _staticArgument3,
        bytes32 _staticArgument4,
        bytes32 _staticArgument5,
        bytes32 _staticArgument6,
        bytes32 _staticArgument7,
        bool _signed
    ) {
        target = _target;
        selector = _selector;
        staticArgument0 = _staticArgument0;
        staticArgument1 = _staticArgument1;
        staticArgument2 = _staticArgument2;
        staticArgument3 = _staticArgument3;
        staticArgument4 = _staticArgument4;
        staticArgument5 = _staticArgument5;
        staticArgument6 = _staticArgument6;
        staticArgument7 = _staticArgument7;
        signed = _signed; 

        // Make sure getRate succeeds.
        getRate();
    }

    // ========================================= RATE FUNCTION =========================================

    /**
     * @notice Get the rate of some generic asset.
     * @dev This function only supports selectors that only contain static arguments, dynamic arguments will not be encoded correctly,
     *      and calls will likely fail.
     * @dev If staticArgumentN is not used, it can be left as 0.
     */
    function getRate() public virtual view returns (uint256) {
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

// src/helper/GenericRateProviderWithDecimalScaling.sol

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
            revert GenericRateProviderWithDecimalScaling__DecimalsCannotBeZero();
        }
        inputDecimals = _args.inputDecimals;
        outputDecimals = _args.outputDecimals;
    }

    function getRate() public override view returns (uint256) {
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

