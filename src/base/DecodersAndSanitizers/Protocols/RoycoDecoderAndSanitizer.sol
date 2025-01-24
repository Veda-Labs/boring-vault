// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;
import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract RoycoWeirollDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error RoycoWeirollDecoderAndSanitizer__TooManyOfferHashes();

    function fillIPOffers(
        bytes32[] calldata ipOfferHashes,
        uint256[] calldata, /*fillAmounts*/
        address fundingVault, 
        address frontendFeeRecipient
    ) external pure virtual returns (bytes memory addressesFound) {
        if (ipOfferHashes.length != 1) revert RoycoWeirollDecoderAndSanitizer__TooManyOfferHashes(); 

        address offerHash0 = address(bytes20(bytes16(ipOfferHashes[0])));
        address offerHash1 = address(bytes20(bytes16(ipOfferHashes[0] << 128)));
        return abi.encodePacked(offerHash0, offerHash1, fundingVault, frontendFeeRecipient);
    }

    function executeWithdrawalScript(address weirollWallet)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        //WeirollWallet will check that the caller is owner (boring vault)
        //but we check here before delegating for safety.
        address owner = IWeirollWalletHelper(weirollWallet).owner();
        return abi.encodePacked(owner);
    }

    function forfeit(address weirollWallet, bool /*executeWithdraw*/ )
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        //WeirollWallet will check that the caller is owner (boring vault)
        //but we check here before delegating for safety.
        address owner = IWeirollWalletHelper(weirollWallet).owner();
        return abi.encodePacked(owner);
    }

    function claim(address weirollWallet, address to) external view virtual returns (bytes memory addressesFound) {
        address owner = IWeirollWalletHelper(weirollWallet).owner();
        return abi.encodePacked(owner, to);
    }
    
    function claim(address to) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(to); 
    }

    function merkleWithdraw() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }
}

interface IWeirollWalletHelper {
    function owner() external view returns (address);
}
