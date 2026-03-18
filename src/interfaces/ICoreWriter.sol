// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface ICoreWriter {
    function sendRawAction(bytes calldata data) external;
}
