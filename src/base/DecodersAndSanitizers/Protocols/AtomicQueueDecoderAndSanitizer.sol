// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {AtomicQueue} from "src/atomic-queue/AtomicQueue.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

abstract contract AtomicQueueDecoderAndSanitizer is BaseDecoderAndSanitizer {
    using FixedPointMathLib for uint256;

    error AtomicQueueDecoderAndSanitizer__BadAtomicPrice(uint256 min, uint256 max, uint256 actual);

    uint32 internal immutable minAtomicPriceBps;
    uint32 internal immutable maxAtomicPriceBps;
    uint8 internal constant BPS_DECIMALS = 4;

    constructor(uint32 _minAtomicPriceBps, uint32 _maxAtomicPriceBps) {
        require(_maxAtomicPriceBps > _minAtomicPriceBps, "Max must be greater than min");
        minAtomicPriceBps = _minAtomicPriceBps;
        maxAtomicPriceBps = _maxAtomicPriceBps;
    }
    //============================== ATOMICQUEUE ===============================

    function updateAtomicRequest(ERC20 offer, ERC20 want, AtomicQueue.AtomicRequest memory userRequest)
        external
        view
        virtual
        returns (bytes memory restrictedData)
    {
        uint256 wantDecimals = want.decimals();
        // Convert requested atomic price to bps decimals.
        uint256 actual = uint256(userRequest.atomicPrice).mulDivDown(10 ** BPS_DECIMALS, 10 ** wantDecimals);
        if (actual < minAtomicPriceBps || actual > maxAtomicPriceBps) {
            revert AtomicQueueDecoderAndSanitizer__BadAtomicPrice(minAtomicPriceBps, maxAtomicPriceBps, actual);
        }

        restrictedData = abi.encodePacked(offer, want);
    }
}
