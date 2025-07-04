// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract MockEndpoint {
    address public delegate;
    function setDelegate(address _delegate) external {
        delegate = _delegate;
    }
} 