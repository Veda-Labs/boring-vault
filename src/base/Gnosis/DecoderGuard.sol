// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTransactionGuard, ITransactionGuard} from "./BaseTransactionGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {IMultiSend} from "src/interfaces/IMultiSend.sol";

contract DecoderGuard is BaseTransactionGuard, Auth {
    using Address for address;

    // ========================================= STRUCTS =========================================

    /**
     * @notice A struct representing a transaction in a multiSend call.
     */
    struct UnwrappedTransaction {
        address to;
        uint256 value;
        // We wanna deal in calldata slices. We return location, let invoker slice
        uint256 dataLocation;
        uint256 dataSize;
    }

    // ========================================= CONSTANTS =======================================

    /**
     * @notice The offset to the start of the transaction data of multiSend calls.
     */
    uint256 private constant OFFSET_START = 68;

    // ========================================= STATE ===========================================

    /**
     * @notice Mapping of digests to their validity.
     */
    mapping(bytes32 => bool) public isValidDigest;

    // ========================================= ERRORS ==========================================

    error DecoderGuard__UnsupportedMode();
    error DecoderGuard__MalformedHeader();
    error DecoderGuard__MalformedBody();
    error DecoderGuard__DigestNotValid(bytes32 digest);

    // ========================================= EVENTS ==========================================

    event DigestValidated(bytes32 digest, address to, bytes4 selector, uint256 value, bytes packedSensitiveArguments);
    event DigestInvalidated(bytes32 digest);

    // ========================================= IMMUTABLES ======================================

    /**
     * @notice The address of the decoder contract.
     */
    address immutable decoder;

    /**
     * @notice The address of the multiSend contract.
     */
    address immutable multiSendAddress;

    constructor(address _owner, Authority _authority, address _decoder, address _multiSendAddress)
        Auth(_owner, _authority)
    {
        decoder = _decoder;
        multiSendAddress = _multiSendAddress;
    }

    // ========================================= ADMIN ===========================================

    /**
     * @notice Makes the digest valid.
     */
    function makeDigestValid(address to, uint256 value, bytes memory exampleData)
        external
        requiresAuth
        returns (bytes32)
    {
        (bytes32 digest, bytes memory packedSensitiveArguments) = digestTransaction(to, value, exampleData);
        isValidDigest[digest] = true;

        emit DigestValidated(digest, to, bytes4(exampleData), value, packedSensitiveArguments);

        return digest;
    }

    /**
     * @notice Invalidates the digest.
     */
    function makeDigestInvalid(bytes32 digest) external requiresAuth {
        delete isValidDigest[digest];

        emit DigestInvalidated(digest);
    }

    // ========================================= ITRANSACTIONGUARD ===============================

    /**
     * @notice Enforces guard check on the transaction.
     */
    function checkTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        ITransactionGuard.Operation operation,
        uint256, /*safeTxGas*/
        uint256, /*baseGas*/
        uint256, /*gasPrice*/
        address, /*gasToken*/
        address payable, /*refundReceiver*/
        bytes memory, /*signatures*/
        address /*msgSender*/
    ) external view {
        if (to == multiSendAddress) {
            UnwrappedTransaction[] memory transactions = _unwrap(value, data, operation);

            for (uint256 i = 0; i < transactions.length; ++i) {
                _checkCall(
                    transactions[i].to,
                    transactions[i].value,
                    data[transactions[i].dataLocation:transactions[i].dataLocation + transactions[i].dataSize]
                );
            }
        } else {
            // Only support calls for single transactions
            if (operation != ITransactionGuard.Operation.Call) {
                revert DecoderGuard__UnsupportedMode();
            }
            _checkCall(to, value, data);
        }
    }

    /**
     * @notice No checks are enforced after execution.
     */
    function checkAfterExecution(bytes32 hash, bool success) external {}

    // ========================================= PUBLIC VIEW =====================================

    /**
     * @notice Digests the transaction.
     */
    function digestTransaction(address to, uint256 value, bytes memory data)
        public
        view
        returns (bytes32, bytes memory)
    {
        bytes memory packedSensitiveArguments = abi.decode(decoder.functionStaticCall(data), (bytes));

        bytes32 digest = keccak256(abi.encodePacked(to, bytes4(data), value > 0, packedSensitiveArguments));

        return (digest, packedSensitiveArguments);
    }

    // ========================================= INTERNAL ========================================

    /**
     * @notice Checks if the digest is valid.
     */
    function _checkCall(address to, uint256 value, bytes memory data) internal view {
        (bytes32 digest,) = digestTransaction(to, value, data);

        if (!isValidDigest[digest]) {
            revert DecoderGuard__DigestNotValid(digest);
        }
    }

    /**
     * @notice Unwraps the multiSend call.
     * @dev Logic based off implementation https://github.com/gnosisguild/zodiac-modifier-roles/blob/main/packages/evm/contracts/adapters/MultiSendUnwrapper.sol
     */
    function _unwrap(uint256 value, bytes calldata data, ITransactionGuard.Operation operation)
        internal
        pure
        returns (UnwrappedTransaction[] memory)
    {
        if (value != 0) {
            revert DecoderGuard__UnsupportedMode();
        }
        if (operation != ITransactionGuard.Operation.DelegateCall) {
            revert DecoderGuard__UnsupportedMode();
        }
        _validateHeader(data);
        uint256 count = _validateEntries(data);
        return _unwrapEntries(data, count);
    }

    /**
     * @notice Validates the header of the multiSend call.
     */
    function _validateHeader(bytes calldata data) private pure {
        // first 4 bytes are the selector for multiSend(bytes)
        if (bytes4(data) != IMultiSend.multiSend.selector) {
            revert DecoderGuard__MalformedHeader();
        }

        // the following 32 bytes are the offset to the bytes param
        // (always 0x20)
        if (bytes32(data[4:]) != bytes32(uint256(0x20))) {
            revert DecoderGuard__MalformedHeader();
        }

        // the following 32 bytes are the length of the bytes param
        uint256 length = uint256(bytes32(data[36:]));

        // validate that the total calldata length matches
        // it's the 4 + 32 + 32 bytes checked above + the <length> bytes
        // padded to a multiple of 32
        if (4 + _ceil32(32 + 32 + length) != data.length) {
            revert DecoderGuard__MalformedHeader();
        }
    }

    /**
     * @notice Validates the entries of the multiSend call.
     */
    function _validateEntries(bytes calldata data) private pure returns (uint256 count) {
        uint256 offset = OFFSET_START;

        // data is padded to 32 bytes we can't simply do offset < data.length
        for (; offset + 32 < data.length;) {
            // Per transaction:
            // Operation   1  bytes
            // To          20 bytes
            // Value       32 bytes
            // Length      32 bytes
            // Data        Length bytes
            uint8 operation = uint8(bytes1(data[offset:]));
            if (operation > 0) {
                revert DecoderGuard__MalformedBody();
            }

            uint256 length = uint256(bytes32(data[offset + 53:]));
            if (offset + 85 + length > data.length) {
                revert DecoderGuard__MalformedBody();
            }

            offset += 85 + length;
            count++;
        }

        if (count == 0) {
            revert DecoderGuard__MalformedBody();
        }
    }

    /**
     * @notice Unwraps the entries of the multiSend call.
     */
    function _unwrapEntries(bytes calldata data, uint256 count)
        private
        pure
        returns (UnwrappedTransaction[] memory result)
    {
        result = new UnwrappedTransaction[](count);

        uint256 offset = OFFSET_START;
        for (uint256 i; i < count;) {
            // Operation was already validated in _validateEntries, so we can just skip it.
            offset += 1;

            result[i].to = address(bytes20(data[offset:]));
            offset += 20;

            result[i].value = uint256(bytes32(data[offset:]));
            offset += 32;

            uint256 size = uint256(bytes32(data[offset:]));
            offset += 32;

            result[i].dataLocation = offset;
            result[i].dataSize = size;
            offset += size;

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Pads the length to the next multiple of 32.
     */
    function _ceil32(uint256 length) private pure returns (uint256) {
        // pad size. Source: http://www.cs.nott.ac.uk/~psarb2/G51MPC/slides/NumberLogic.pdf
        return ((length + 32 - 1) / 32) * 32;
    }
}
