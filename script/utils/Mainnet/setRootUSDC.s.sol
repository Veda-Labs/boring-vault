// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {console2} from "forge-std/console2.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";

/**
 *  source .env && forge script script/utils/Mainnet/setRootUSDC.s.sol:setRoot --rpc-url $MAINNET_RPC_URL -vvvv --broadcast
 */

contract setRoot is Script {
    uint8 public constant STRATEGIST_ROLE = 7;

    function run() external {
        // MoveFundsUSDC
        uint256 privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(privateKey);
        string memory json = vm.readFile(
            "leafs/Mainnet/FundMgmtUSDCMainnetLeafs.json"
        );
        address strategistUSDC = 0xa67268e35952A90C500304616F5c41C5B79f0BE8;
        address managerAddressUSDC = 0x4693621DD1248D2c9b64090824f7FF588cfAc1d9;
        RolesAuthority rolesAuthorityUSDC = RolesAuthority(
            0x5fac892A947296eDf36f6dBe199F2689e9bEc9D2
        );
        setRootTree(strategistUSDC, managerAddressUSDC, json);

        json = vm.readFile("leafs/Mainnet/FundMgmtUSDCMainnetLeafs.json");
        address strategistWETH = 0x35e451b3A2931128dD42Ee3C9bc8C1455F0943e3;
        address managerAddressWETH = 0x493Fe36C7B88aa6316F3C5B0e5dfBe7E49ECf652;
        
         // stop previous broadcast to avoid nonce issues
        //setRootTree(strategistWETH, managerAddressWETH, json);
        if (
            !rolesAuthorityUSDC.doesUserHaveRole(
                strategistUSDC,
                STRATEGIST_ROLE
            )
        ) {
            rolesAuthorityUSDC.setUserRole(
                strategistUSDC,
                STRATEGIST_ROLE,
                true
            );
            console.log("Granted STRATEGIST_ROLE to", strategistUSDC);
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
