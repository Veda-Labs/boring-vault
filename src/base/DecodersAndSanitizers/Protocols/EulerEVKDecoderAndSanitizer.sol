// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";

contract EulerEVKDecoderAndSanitizer is ERC4626DecoderAndSanitizer {
    //============================== ERRORS ===============================

    error EulerEVKDecoderAndSanitizer__FunctionSelectorNotSupported();

    //============================== EthereumVaultConnector  ===============================

    function enableController(address account, address vault)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(account, vault);
    }

    function enableCollateral(address account, address vault)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(account, vault);
    }

    function disableController(address account) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(account);
    }

    //nothing to sanitize
    function disableController() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function disableCollateral(address account, address vault)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(account, vault);
    }

    function call(address targetContract, address onBehalfOfAccount, uint256, /*value*/ bytes calldata data)
        external
        pure
        returns (bytes memory addressesFound)
    {
        //target contract = vault
        //onBehalfOfAccount = subaccount
        //data will always be a function, so we can put the whitelisted function selectors in leaves
        //these should only need to be assets that pull funds to avoid sending anything to subaccounts mistakenly
        //afaik, the only ones would be borrow, withdraw, and redeem

        bytes4 selector = bytes4(data[:4]);

        if (selector == bytes4(keccak256("borrow(uint256,address)"))) {
            (, address receiver) = abi.decode(data[4:], (uint256, address));
            return abi.encodePacked(targetContract, onBehalfOfAccount, address(uint160(uint32(selector))), receiver);
        } else if (selector == bytes4(keccak256("withdraw(uint256,address,address)"))) {
            (, address receiver, address owner) = abi.decode(data[4:], (uint256, address, address));
            return
                abi.encodePacked(targetContract, onBehalfOfAccount, address(uint160(uint32(selector))), receiver, owner);
        } else if (selector == bytes4(keccak256("redeem(uint256,address,address)"))) {
            (, address receiver, address owner) = abi.decode(data[4:], (uint256, address, address));
            return
                abi.encodePacked(targetContract, onBehalfOfAccount, address(uint160(uint32(selector))), receiver, owner);
        } else {
            revert EulerEVKDecoderAndSanitizer__FunctionSelectorNotSupported();
        }
    }

    //============================== EVK Vaults ===============================

    function borrow(uint256, /*amount*/ address receiver) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(receiver);
    }

    function repay(uint256, /*amount*/ address receiver) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(receiver);
    }

    function repayWithShares(uint256, /*amount*/ address receiver)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(receiver);
    }
}
