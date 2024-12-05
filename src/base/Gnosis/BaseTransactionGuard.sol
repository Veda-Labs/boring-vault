// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ITransactionGuard, IERC165} from "src/interfaces/ITransactionGuard.sol";

abstract contract BaseTransactionGuard is ITransactionGuard {
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return interfaceId == type(ITransactionGuard).interfaceId // 0xe6d7a83a
            || interfaceId == type(IERC165).interfaceId; // 0x01ffc9a7
    }
}
