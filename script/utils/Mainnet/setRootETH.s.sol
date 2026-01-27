// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {console2} from "forge-std/console2.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";

/**
 *  source .env && forge script script/utils/Mainnet/setRootETH.s.sol:setRoot --rpc-url $MAINNET_RPC_URL -vvvv --broadcast
 */

contract setRoot is Script {
    uint8 public constant STRATEGIST_ROLE = 7;

    function run() external {
        // MoveFundsUSDC
        uint256 privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(privateKey);
        string memory json = vm.readFile(
            "leafs/Mainnet/FundMgmtWETHMainnetLeafs.json"
        );
        address strategistETH = 0x35e451b3A2931128dD42Ee3C9bc8C1455F0943e3;
        address managerAddressETH = 0x493Fe36C7B88aa6316F3C5B0e5dfBe7E49ECf652;
        RolesAuthority rolesAuthorityETH = RolesAuthority(
            0x5105361E4078F5d0AAce57B4e3539b7b1Cdee446
        );
        setRootTree(strategistETH, managerAddressETH, json);

     
        
         // stop previous broadcast to avoid nonce issues
        //setRootTree(strategistWETH, managerAddressWETH, json);
        if (
            !rolesAuthorityETH.doesUserHaveRole(
                strategistETH,
                STRATEGIST_ROLE
            )
        ) {
            rolesAuthorityETH.setUserRole(
                strategistETH,
                STRATEGIST_ROLE,
                true
            );
            console.log("Granted STRATEGIST_ROLE to", strategistETH);
        } else {
            console.log("Address already has STRATEGIST_ROLE");
        }

        vm.stopBroadcast();
    }

    function setRootTree(
        address strategist,
        address managerAddress,
        string memory json
    ) internal {
        bytes32 merkleRoot = vm.parseJsonBytes32(json, ".metadata.ManageRoot");//bytes32(0); 

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(
            managerAddress
        );
        manager.setManageRoot(strategist, merkleRoot);
    }
}
