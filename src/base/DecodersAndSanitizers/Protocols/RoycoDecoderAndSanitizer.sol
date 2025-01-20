// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;
import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract RoycoWeirollDecoderAndSanitizer is BaseDecoderAndSanitizer {
    function fillIPOffers(
        bytes32[] calldata, /*ipOfferHashes*/
        uint256[] calldata, /*fillAmounts*/
        address, /*fundingVault*/ //this might have to be zero always?
        address frontendFeeRecipient
    ) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(frontendFeeRecipient);
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
}

interface IWeirollWalletHelper {
    function owner() external view returns (address);
}
