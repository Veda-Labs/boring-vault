// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
// Last audited: boring-vault@4c9c671bb965899728167102a0e3ac22f4aabf7a — https://macroaudits.com/library/audits/sevenSeas-39
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {Owned} from "lib/solmate/src/auth/Owned.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

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

    //============================== ONEINCH V5 ===============================

    function swap(
        address executor,
        DecoderCustomTypes.SwapDescription calldata desc,
        bytes calldata permit,
        bytes calldata /*data*/
    ) external view returns (bytes memory addressesFound) {
        if (permit.length > 0) revert OneInchDecoderAndSanitizer__PermitNotSupported();
        if (executor != oneInchExecutor || desc.srcReceiver != oneInchExecutor) revert OneInchDecoderAndSanitizer__InvalidExecutor();
        addressesFound = abi.encodePacked(desc.srcToken, desc.dstToken, desc.dstReceiver);
    }

    function uniswapV3Swap(uint256 /*amount*/, uint256 /*minReturn*/, uint256[] calldata pools)
        external
        pure
        returns (bytes memory addressesFound)
    {
        for (uint256 i; i < pools.length; ++i) {
            addressesFound = abi.encodePacked(addressesFound, uint160(pools[i]));
        }
    }

    //============================== ONEINCH V6 ===============================

    function swap(
        address executor,
        DecoderCustomTypes.SwapDescription calldata desc,
        bytes calldata /*data*/
    ) external view returns (bytes memory addressesFound) {
        if (executor != oneInchExecutor || desc.srcReceiver != oneInchExecutor) revert OneInchDecoderAndSanitizer__InvalidExecutor();
        addressesFound = abi.encodePacked(desc.srcToken, desc.dstToken, desc.dstReceiver);
    }

    // V6 Address type is uint256 with the address in the lower 160 bits and flags in the upper 96 bits.
    function unoswap(uint256 token, uint256 /*amount*/, uint256 /*minReturn*/, uint256 dex)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(address(uint160(token)), address(uint160(dex)));
    }

    function unoswap2(uint256 token, uint256 /*amount*/, uint256 /*minReturn*/, uint256 dex, uint256 dex2)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound =
            abi.encodePacked(address(uint160(token)), address(uint160(dex)), address(uint160(dex2)));
    }

    function unoswap3(uint256 token, uint256 /*amount*/, uint256 /*minReturn*/, uint256 dex, uint256 dex2, uint256 dex3)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(
            address(uint160(token)), address(uint160(dex)), address(uint160(dex2)), address(uint160(dex3))
        );
    }

    function ethUnoswap(uint256 /*minReturn*/, uint256 dex) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(address(uint160(dex)));
    }

    function ethUnoswap2(uint256 /*minReturn*/, uint256 dex, uint256 dex2)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(address(uint160(dex)), address(uint160(dex2)));
    }

    function ethUnoswap3(uint256 /*minReturn*/, uint256 dex, uint256 dex2, uint256 dex3)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound =
            abi.encodePacked(address(uint160(dex)), address(uint160(dex2)), address(uint160(dex3)));
    }
}
