// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";
import { Owned } from "lib/solmate/src/auth/Owned.sol";
import { BaseDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract OneInchOwnedDecoderAndSanitizer is Owned, BaseDecoderAndSanitizer {
    //============================== STORAGE ===============================

    address public oneInchExecutor;

    //============================== ERRORS ===============================

    error OneInchDecoderAndSanitizer__PermitNotSupported();
    error OneInchDecoderAndSanitizer__InvalidExecutor();

    //============================== EVENTS ===============================

    event OneInchExecutorSet(address oneInchExecutor);

    constructor(address _owner, address _oneInchExecutor) Owned(_owner) {
        oneInchExecutor = _oneInchExecutor;
    }

    function setOneInchExecutor(address _oneInchExecutor) external onlyOwner {
        if (_oneInchExecutor == address(0)) revert OneInchDecoderAndSanitizer__InvalidExecutor();
        oneInchExecutor = _oneInchExecutor;
        emit OneInchExecutorSet(_oneInchExecutor);
    }

    //============================== ONEINCH ===============================

    function swap(
        address executor,
        DecoderCustomTypes.SwapDescription calldata desc,
        bytes calldata permit,
        bytes calldata
    ) external view returns (bytes memory addressesFound) {
        if (permit.length > 0) revert OneInchDecoderAndSanitizer__PermitNotSupported();
        if (executor != oneInchExecutor || desc.srcReceiver != oneInchExecutor) {
            revert OneInchDecoderAndSanitizer__InvalidExecutor();
        }
        addressesFound = abi.encodePacked(desc.srcToken, desc.dstToken, desc.dstReceiver);
    }

    function uniswapV3Swap(uint256, uint256, uint256[] calldata pools)
        external
        pure
        returns (bytes memory addressesFound)
    {
        for (uint256 i; i < pools.length; ++i) {
            addressesFound = abi.encodePacked(addressesFound, uint160(pools[i]));
        }
    }
}
