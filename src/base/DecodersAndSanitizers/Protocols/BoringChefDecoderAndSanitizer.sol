// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {IBoringChef} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";

contract BoringChefDecoderAndSanitizer {
    //============================== BoringChef ===============================

    function claimRewards(uint256[] calldata /*rewardIds*/ )
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function claimRewardsOnBehalfOfUser(uint256[] calldata, /*rewardIds*/ address user)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(user);
    }

    function distributeRewards(
        address[] calldata tokens,
        uint256[] calldata, /*amounts*/
        uint48[] calldata, /*startEpochs*/
        uint48[] calldata /*endEpochs*/
    ) external view virtual returns (bytes memory addressesFound) {
        for (uint256 i = 0; i < tokens.length; i++) {
            addressesFound = abi.encodePacked(addressesFound, tokens[i]);
        }
    }
}
