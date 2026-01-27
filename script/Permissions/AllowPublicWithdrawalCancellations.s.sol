// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";

/*
 * source .env && forge script script/Permissions/AllowPublicWithdrawalCancellations.s.sol:AllowPublicWithdrawalCancellations --rpc-url $MAINNET_RPC_URL -vvvv --broadcast
 */

contract AllowPublicWithdrawalCancellations is Script {
    function run() external {
        uint256 privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(privateKey);
        RolesAuthority rolesAuthorityETH = RolesAuthority(
            0x5105361E4078F5d0AAce57B4e3539b7b1Cdee446
        );
        RolesAuthority rolesAuthorityUSD = RolesAuthority(
            0x5fac892A947296eDf36f6dBe199F2689e9bEc9D2
        );
        BoringOnChainQueue queueETH = BoringOnChainQueue(
            0x66Afbd5b2558B34af02c9Cbe61bfc409C909F375
        );
        BoringOnChainQueue queueUSD = BoringOnChainQueue(
            0x7D2b993CfC4048b85EC44B95Dc01a4C6B4E47b25
        );

        if (
            !rolesAuthorityETH.isCapabilityPublic(
                address(queueETH),
                BoringOnChainQueue.cancelOnChainWithdraw.selector
            )
        ) {
            console2.log(
                "Enabling public withdrawal cancellations on ETH Teller"
            );
            rolesAuthorityETH.setPublicCapability(
                address(queueETH),
                BoringOnChainQueue.cancelOnChainWithdraw.selector,
                true
            );
        } else {
            console2.log(
                "Public withdrawal cancellations already enabled on ETH Teller"
            );
        }

        if (
            !rolesAuthorityUSD.isCapabilityPublic(
                address(queueUSD),
                BoringOnChainQueue.cancelOnChainWithdraw.selector
            )
        ) {
            console2.log(
                "Enabling public withdrawal cancellations on USD Teller"
            );
            rolesAuthorityUSD.setPublicCapability(
                address(queueUSD),
                BoringOnChainQueue.cancelOnChainWithdraw.selector,
                true
            );
        } else {
            console2.log(
                "Public withdrawal cancellations already enabled on USD Teller"
            );
        }

        vm.stopBroadcast();
    }
}
