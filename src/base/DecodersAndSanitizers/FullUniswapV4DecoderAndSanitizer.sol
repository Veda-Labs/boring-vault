import {UniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";

contract FullUniswapV4DecoderAndSanitizer is UniswapV4DecoderAndSanitizer {
    constructor(address _posm) UniswapV4DecoderAndSanitizer(_posm) {}
}
