// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract AvalancheBridgeDecoderAndSanitizer {

    //============================== AVALANCHE BRIDGE ===============================
    //@dev specific to USDC only on ETH mainnet 
    function transferTokens(uint256 /*amount*/, uint32 destinationDomain, address mintRecipient, address burnToken) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(address(uint160(destinationDomain)), mintRecipient, burnToken); 
    }
    
    //function unwrap(uint256 /*amount*/, uint256 chainId) external pure virtual returns (bytes memory addressesFound) {
    //    addressesFound = abi.encodePacked(address(uint160(chainId))); 
    //}
}
