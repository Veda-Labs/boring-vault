/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import {CorkDecoderAndSanitizer} from "./CorkDecoderAndSanitizer.sol";
import {ITBPositionDecoderAndSanitizer} from "../ITBPositionDecoderAndSanitizer.sol";

contract FullCorkDecoderAndSanitizer is CorkDecoderAndSanitizer, ITBPositionDecoderAndSanitizer {}
