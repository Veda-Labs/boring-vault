// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTransactionGuard, ITransactionGuard} from "./BaseTransactionGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";

contract DecoderGuard is BaseTransactionGuard, Auth {
    using Address for address;

    address immutable decoder;
    bool public skipDigestCheck;

    constructor(address _owner, Authority _authority, address _decoder) Auth(_owner, _authority) {
        decoder = _decoder;
    }

    error DecoderGuard__DigestNotValid(bytes32 digest);

    event DigestValidated(bytes32 digest, address to, bytes4 selector, uint256 value, bytes packedSensitiveArguments);
    event DigestInvalidated(bytes32 digest);

    mapping(bytes32 => bool) public isValidDigest;

    function toggleSkipDigestCheck() external requiresAuth {
        skipDigestCheck = !skipDigestCheck;
    }

    function makeDigestValid(address to, uint256 value, bytes memory exampleData) external requiresAuth {
        (bytes32 digest, bytes memory packedSensitiveArguments) = digestTransaction(to, value, exampleData);
        isValidDigest[digest] = true;

        emit DigestValidated(digest, to, bytes4(exampleData), value, packedSensitiveArguments);
    }

    function makeDigestInvalid(bytes32 digest) external requiresAuth {
        delete isValidDigest[digest];

        emit DigestInvalidated(digest);
    }

    // TODO
    // So this contract should accept the MultiSend contract address, as an immutable variable, then if making a call to this contract, we
    // need to unwrap the call to check every individual tx.
    // The input is a packed bytes value where
    // 1 byte for operation  has to be uint8(0)
    // 20 bytes for target
    // 32 bytes for value
    // 32 bytes for data length
    // data as bytes
    // Example packed data
    // 0x8d80ff0a (multiSend selector)
    // 0x0000000000000000000000000000000000000000000000000000000000000020 (offset to bytes data)
    // 0x00000000000000000000000000000000000000000000000000000000000001b2 (length of bytes data)
    // 00 ( operation 0 = call)
    // 794a61358d6845594f94dc1db02a252b5b4814ad (target)
    // 0000000000000000000000000000000000000000000000000000000000000000 (value)
    // 0000000000000000000000000000000000000000000000000000000000000084 (length of data)
    // 617ba037 (target selector, supply function)
    // 00000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1 (asset)
    // 000000000000000000000000000000000000000000000000000009184e72a000 (amount to supply)
    // 0000000000000000000000005061f6517591804391b38937c99057014b1edb78 (onBehalfOf)
    // 0000000000000000000000000000000000000000000000000000000000000000 (referral code)

    // 00 ( operation 0 = call)
    // 794a61358d6845594f94dc1db02a252b5b4814ad (target)
    // 0000000000000000000000000000000000000000000000000000000000000000 (value)
    // 0000000000000000000000000000000000000000000000000000000000000084 (length of data)
    // 617ba037 (target selector, supply function)
    // 00000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1 (asset)
    // 000000000000000000000000000000000000000000000000000009184e72a000 (amount to supply)
    // 0000000000000000000000005061f6517591804391b38937c99057014b1edb78 (onBehalfOf)
    // 0000000000000000000000000000000000000000000000000000000000000000 (referral code)
    // Remainder is padded to 32 bytes
    // 0000000000000000000000000000
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        ITransactionGuard.Operation, /*operation*/
        uint256, /*safeTxGas*/
        uint256, /*baseGas*/
        uint256, /*gasPrice*/
        address, /*gasToken*/
        address payable, /*refundReceiver*/
        bytes memory, /*signatures*/
        address /*msgSender*/
    ) external view {
        // Skip digest check if enabled
        if (skipDigestCheck) return;

        (bytes32 digest,) = digestTransaction(to, value, data);

        if (!isValidDigest[digest]) {
            revert DecoderGuard__DigestNotValid(digest);
        }
    }

    /**
     * @notice No checks are enforced after execution.
     */
    function checkAfterExecution(bytes32 hash, bool success) external {}

    function digestTransaction(address to, uint256 value, bytes memory data)
        public
        view
        returns (bytes32, bytes memory)
    {
        bytes memory packedSensitiveArguments = abi.decode(decoder.functionStaticCall(data), (bytes));

        bytes32 digest = keccak256(abi.encodePacked(to, bytes4(data), value > 0, packedSensitiveArguments));

        return (digest, packedSensitiveArguments);
    }

    // AI created this using this contract as an example https://vscode.blockscan.com/42161/0x9641d764fc13c8b624c04430c7356c1c7c8102e2
    // Just converted it to return the Transaction struct array instead of actually sending the txs.
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
    }

    error InvalidOperation();

    function multiSend(bytes memory transactionsData) public pure returns (Transaction[] memory) {
        // Count transactions first to size array
        uint256 txCount = 0;
        uint256 i = 32;
        uint256 length = transactionsData.length;

        while (i < length) {
            // Skip operation byte (1) + address (20) + value (32) + data length (32)
            uint256 dataLength;
            assembly {
                dataLength := mload(add(transactionsData, add(i, 0x35)))
            }
            i += 85 + dataLength; // 85 = 1 + 20 + 32 + 32
            txCount++;
        }

        Transaction[] memory parsedTxs = new Transaction[](txCount);
        i = 32;
        uint256 txIndex = 0;

        while (i < length) {
            uint8 operation;
            address to;
            uint256 value;
            uint256 dataLength;

            assembly {
                operation := shr(0xf8, mload(add(transactionsData, i)))
                to := shr(0x60, mload(add(transactionsData, add(i, 0x01))))
                value := mload(add(transactionsData, add(i, 0x15)))
                dataLength := mload(add(transactionsData, add(i, 0x35)))
            }

            if (operation != 0) {
                revert InvalidOperation();
            }

            // Copy data bytes
            bytes memory txData = new bytes(dataLength);
            uint256 dataStart = i + 85; // 85 = 1 + 20 + 32 + 32
            assembly {
                let txDataPtr := add(txData, 32)
                let sourceDataPtr := add(transactionsData, dataStart)
                for { let j := 0 } lt(j, dataLength) { j := add(j, 32) } {
                    mstore(add(txDataPtr, j), mload(add(sourceDataPtr, j)))
                }
            }

            parsedTxs[txIndex] = Transaction(to, value, txData);
            i += 85 + dataLength;
            txIndex++;
        }

        return parsedTxs;
    }
}
