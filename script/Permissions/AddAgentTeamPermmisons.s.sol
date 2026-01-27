// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {console2} from "forge-std/console2.sol";


contract AddPermissions is Script { 

    uint8 constant STRATEGIST_ROLE = 7;
    address constant AGENT_TEAM = 0xeDa59131738210f4c380814FF8550bC1C37E61a4;

    uint256 privateKey;

    function setUp() external {
        privateKey = vm.envUint("LOCAL_DEPLOYER_PRIVATE_KEY");
        vm.createSelectFork("local");
    }
    
    
    function run() public {
        vm.startBroadcast(privateKey);

        //client vault
        string memory client_json = vm.readFile("leafs/LocalFork/FundMgmtUSDCLocalForkLeafs.json");
        bytes32 client_merkleRoot = vm.parseJsonBytes32(client_json, ".metadata.ManageRoot");

        ManagerWithMerkleVerification client_manager = ManagerWithMerkleVerification(0x5d6C866f873fCcFAe13aD75479cFbD606fE27b29);
        RolesAuthority client_auth = RolesAuthority(0xDc610203093f6B739d772654416e6a67B240948D);

        if (!client_auth.doesUserHaveRole(AGENT_TEAM, STRATEGIST_ROLE)) {
            client_auth.setUserRole(AGENT_TEAM, STRATEGIST_ROLE, true);
        }

        client_manager.setManageRoot(AGENT_TEAM, client_merkleRoot);

        // agent vault
        string memory agent_json = vm.readFile("leafs/LocalFork/FundMgmtUSDCAgentMainnetForkLeafs.json");
        bytes32 agent_merkleRoot = vm.parseJsonBytes32(agent_json, ".metadata.ManageRoot");

        ManagerWithMerkleVerification agent_manager = ManagerWithMerkleVerification(0x54a352BE658a9CDe86409b7281BFBCE0cA94dd81);
        RolesAuthority agent_auth = RolesAuthority(0x85aa8590E3f076aF23AF2cc29a743c481354A8cf);

        if (!agent_auth.doesUserHaveRole(AGENT_TEAM, STRATEGIST_ROLE)) {
            agent_auth.setUserRole(AGENT_TEAM, STRATEGIST_ROLE, true);
        }

        agent_manager.setManageRoot(AGENT_TEAM, agent_merkleRoot);

        vm.stopBroadcast();
    }
}