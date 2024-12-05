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

    // TODO could maybe use msg.sender to see if its the boring vault calling to this?
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
}
