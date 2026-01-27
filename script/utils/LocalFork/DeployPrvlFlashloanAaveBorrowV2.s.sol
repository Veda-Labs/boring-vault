// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {PrvlFlashloanAaveBorrowV2} from "src/micro-managers/PrvlFlashloanAaveBorrowV2.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";

/*
 * source .env && forge script script/utils/LocalFork/DeployPrvlFlashloanAaveBorrowV2.s.sol:DeployPrvlFlashloanAaveBorrowV2 --fork-url local --broadcast -vv
 */

contract DeployPrvlFlashloanAaveBorrowV2 is Script, MerkleTreeHelper {
    uint256 public privateKey;
    
    address constant OWNER = 0x6f4e539E6B28097F9aF8aFbc7BA78B715F0127fF;
    address constant MANAGER = 0x54a352BE658a9CDe86409b7281BFBCE0cA94dd81;
    address constant BORING_VAULT = 0x3A29E2a5Ddb20C56D62a9D9Fa29b606833C4bf1d;
    address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address constant UNI_V3_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant UNI_V3_QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant BASEDECODER = 0x078AF49028bDfC2a2247B76d170022a9C98308D0;

    uint24 constant UNI_FEE_TIER = 3000;
    uint256 constant AAVE_VARIABLE_RATE = 2;
    
    RolesAuthority public rolesAuthority = RolesAuthority(0x85aa8590E3f076aF23AF2cc29a743c481354A8cf);
    PrvlFlashloanAaveBorrowV2 public flashloanManagerV2;

    function setUp() external {
        privateKey = vm.envUint("LOCAL_DEPLOYER_PRIVATE_KEY");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        // Deploy the V2 micro-manager
        flashloanManagerV2 = new PrvlFlashloanAaveBorrowV2(
            OWNER,
            MANAGER,
            BORING_VAULT,
            BALANCER_VAULT,
            UNI_V3_ROUTER,
            UNI_V3_QUOTER
        );

        console.log("PrvlFlashloanAaveBorrowV2 deployed at:", address(flashloanManagerV2));

        // Give micro-manager permission to manage the vault (role 7)
        if (!rolesAuthority.doesUserHaveRole(address(flashloanManagerV2), 7)) {
            rolesAuthority.setUserRole(address(flashloanManagerV2), 7, true);
            console.log("Granted role 7 to micro-manager V2");
        }

        flashloanManagerV2.setAuthority(rolesAuthority);

        // Parse the Merkle root from JSON
        string memory json = vm.readFile("leafs/LocalFork/FundMgmtUSDCAgentMainnetForkLeafs.json");
        bytes32 merkleRoot = vm.parseJsonBytes32(json, ".metadata.ManageRoot");

        // Set the Merkle root for the micro-manager address
        ManagerWithMerkleVerification managerContract = ManagerWithMerkleVerification(MANAGER);
        managerContract.setManageRoot(address(flashloanManagerV2), merkleRoot);
        managerContract.setManageRoot(MANAGER, merkleRoot);

        console.log("Merkle root configured for micro-manager V2");
        console.log("Note: This V2 contract has been simplified");
        console.log("- Use borrow() for leveraged borrowing");
        console.log("- Use repay() for partial repayment");
        console.log("- Use settle() for full position settlement");

        vm.stopBroadcast();
    }
}