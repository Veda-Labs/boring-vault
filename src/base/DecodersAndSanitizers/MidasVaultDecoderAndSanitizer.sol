pragma solidity 0.8.21;

contract MidasVaultDecoderAndSanitizer {

    function depositInstant(address tokenIn, uint256 /*amountToken*/, uint256 /*minReceiveAmount*/, bytes32 /*referrerId*/) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(tokenIn);
    }

    function redeemRequest(address tokenOut, uint256 /*amountMTokenIn*/) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(tokenOut);
    }

    function redeemInstant(address tokenOut, uint256 /*amountMTokenIn*/, uint256 /*minReceiveAmount*/) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(tokenOut);
    }
}
