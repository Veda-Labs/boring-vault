pragma solidity 0.8.21;

import {SonicDepositDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SonicDepositDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol"; 
//import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol"; 


contract SonicIncentivesHandlerDecoderAndSanitizer is 
    SonicDepositDecoderAndSanitizer,
    TellerDecoderAndSanitizer
{


}
