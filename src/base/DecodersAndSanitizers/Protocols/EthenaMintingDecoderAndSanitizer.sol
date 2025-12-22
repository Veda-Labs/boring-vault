// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";

contract EthenaMintingDecoderAndSanitizer {
    //============================== Ethena Minting V2 ===============================

    function mint(
        DecoderCustomTypes.EthenaOrder calldata order,
        DecoderCustomTypes.EthenaRoute calldata,
        /*route*/
        DecoderCustomTypes.EthenaSignature calldata /*signature*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(order.benefactor, order.beneficiary, order.collateral_asset);
    }

    function redeem(
        DecoderCustomTypes.EthenaOrder calldata order,
        DecoderCustomTypes.EthenaSignature calldata /*signature*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(order.benefactor, order.beneficiary, order.collateral_asset);
    }

    function setDelegatedSigner(address _delegateTo) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_delegateTo);
    }

    function removeDelegatedSigner(address _removedSigner) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_removedSigner);
    }
}
