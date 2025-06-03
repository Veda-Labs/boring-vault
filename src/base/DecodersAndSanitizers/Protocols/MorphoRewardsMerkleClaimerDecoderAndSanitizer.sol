// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract MorphoRewardsMerkleClaimerDecoderAndSanitizer {
    //============================== MORPHO MERKLE CLAIMER ===============================

    // We do't really need to sanitize the account since the rewards always go to the account that earned them,
    // but we do for consistency among other decoders.
    // Example claim tx: https://etherscan.io/tx/0xdc661d0871b40a7c39996c7c230739b4828050fccfa4fbd9d920c80ac9ffa0e0
    function claim(address account, address, /*reward*/ uint256, /*claimable*/ bytes32[] calldata /*proof*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(account);
    }
}
