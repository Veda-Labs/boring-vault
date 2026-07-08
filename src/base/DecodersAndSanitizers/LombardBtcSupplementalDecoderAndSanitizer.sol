// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {UniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";
import {BTCbDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BTCbDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {SyrupDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SyrupDecoderAndSanitizer.sol";
import {SpectraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SpectraDecoderAndSanitizer.sol";
import {SkyMoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SkyMoneyDecoderAndSanitizer.sol";
import {BTCNMinterDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BTCNMinterDecoderAndSanitizer.sol";
import {DeriveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DeriveDecoderAndSanitizer.sol";
import {AgglayerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AgglayerDecoderAndSanitizer.sol";
import {LBTCBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LBTCBridgeDecoderAndSanitizer.sol";
import {ResolvDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ResolvDecoderAndSanitizer.sol";
import {MorphoRewardsDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/MorphoRewardsDecoderAndSanitizer.sol";
import {LombardBTCMinterDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LombardBtcMinterDecoderAndSanitizer.sol";

contract LombardBtcSupplementalDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    UniswapV4DecoderAndSanitizer,
    BTCbDecoderAndSanitizer,
    SyrupDecoderAndSanitizer,
    SpectraDecoderAndSanitizer,
    SkyMoneyDecoderAndSanitizer,
    LombardBTCMinterDecoderAndSanitizer,
    BTCNMinterDecoderAndSanitizer,
    DeriveDecoderAndSanitizer,
    AgglayerDecoderAndSanitizer,
    LBTCBridgeDecoderAndSanitizer,
    ResolvDecoderAndSanitizer,
    MorphoRewardsDecoderAndSanitizer
{
    constructor(address _uniswapV4PositionManager)
        BaseDecoderAndSanitizer()
        UniswapV4DecoderAndSanitizer(_uniswapV4PositionManager)
        BTCbDecoderAndSanitizer()
    {}

    //============================== Conflict Resolution ===============================
    // The functions below share identical selectors/parameter types across multiple
    // inherited protocol decoders. In each case the underlying implementations return
    // functionally equivalent results (either empty bytes or the same packed addresses),
    // so a single overriding implementation satisfies all base contracts.

    // BTCbDecoderAndSanitizer (LBTC deposit) vs ResolvDecoderAndSanitizer (stUSR deposit)
    function deposit(uint256 /*amount*/ )
        external
        pure
        override(BTCbDecoderAndSanitizer, ResolvDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    // BTCbDecoderAndSanitizer (LBTC mint) vs LombardBTCMinterDecoderAndSanitizer (LBTC mint)
    function mint(bytes calldata payload, bytes calldata /*proof*/ )
        external
        pure
        override(BTCbDecoderAndSanitizer, LombardBTCMinterDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        (,,,,, bytes memory msgBody) = abi.decode(payload[4:], (bytes32, uint256, bytes32, address, address, bytes));
        bytes32 recipientWord;
        assembly {
            recipientWord := mload(add(msgBody, 0x44))
        }
        addressesFound = abi.encodePacked(address(uint160(uint256(recipientWord))));
    }

    // ResolvDecoderAndSanitizer (stUSR/UsrExternalRequestManager redeem) vs SpectraDecoderAndSanitizer (Principal Token redeem)
    function redeem(uint256, /*amount/shares*/ address secondAddress, address thirdAddress, uint256 /*minAmount*/ )
        external
        pure
        override(ResolvDecoderAndSanitizer, SpectraDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(secondAddress, thirdAddress);
    }
}
