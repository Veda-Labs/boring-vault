// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {PrvlFlashloanAaveBorrowV5, TokenConfig} from "src/micro-managers/PrvlFlashloanAaveBorrowV5.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";

/*
 * source .env && forge script script/utils/Mainnet/DeployMicroWETHwstWETHPRIME.s.sol:DeployPrvlFlashloanAaveBorrow --fork-url mainnet --broadcast -vv --verify
 */

contract DeployPrvlFlashloanAaveBorrow is Script, MerkleTreeHelper {
    uint256 public privateKey;
    
    address constant OWNER = 0xA45A9b2bC0230Fa78aF0C92031a2E4016aFA9B40; 
    address constant MANAGER = 0x618c13371DB671AdbCbA93e76f758E307E6A0871;
    address constant BORING_VAULT = 0x951f36b2F8Fd8B213AE999E53dF1c77749A6cDed;
    address constant UNI_V3_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant UNI_V3_QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    address constant AAVE_POOL = 0x4e033931ad43597d96D6bcc25c280717730B58B1; //Prime
    address constant BASE_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; //WETH
    address constant DEPOSIT_TOKEN = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; //wstETH prime specific
    address constant A_TOKEN = 0xC035a7cf15375cE2706766804551791aD035E0C2; //awstETH
    address constant DEBT_TOKEN = 0x91b7d78BF92db564221f6B5AeE744D1727d1Dd1e;
    address constant BASEDECODER = 0xdda148b36E80d28EEF153c570891B628cb2540f1;
    
    address constant agent_manager = 0x707045ec78EC57a4e46A5f0E17f83311B447725F; // Agent2 from Tony

    uint256 constant AAVE_VARIABLE_RATE = 2;
    uint8 public constant STRATEGIST_ROLE = 7;
    
    RolesAuthority public rolesAuthority = RolesAuthority(0x0951A4fa55DD8F20B1eab2021cD8693D32f410B5);
    PrvlFlashloanAaveBorrowV5 public flashloanManager;

    function setUp() external {
        privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
    }

    function run() external  returns (ManagerWithMerkleVerification){
        vm.startBroadcast(privateKey);

        TokenConfig memory tokens = TokenConfig({
            baseToken: BASE_TOKEN,
            depositToken: DEPOSIT_TOKEN,
            aToken: A_TOKEN,
            debtToken: DEBT_TOKEN
        });
        
        flashloanManager = new PrvlFlashloanAaveBorrowV5(
            OWNER,
            MANAGER,
            BORING_VAULT,
            UNI_V3_ROUTER,
            UNI_V3_QUOTER,
            AAVE_POOL,
            tokens,
            AAVE_VARIABLE_RATE
        );
        
        //flashloanManager = PrvlFlashloanAaveBorrowV5(0xD137e6eb8BceeEDea93501B68f4c2f9e5E941706);

        console.log("PrvlFlashloanAaveBorrow deployed at:", address(flashloanManager));
        // Give micro-manager permission to manage the vault (roleSTRATEGIST_ROLE
        if (!rolesAuthority.doesUserHaveRole(address(flashloanManager),STRATEGIST_ROLE)) {
            rolesAuthority.setUserRole(address(flashloanManager),STRATEGIST_ROLE, true);
            console.log("Granted role STRATEGIST_ROLE to micro-manager");
        }//borrow(uint256 collateralAmount, uint256 borrowAmount)
        if (rolesAuthority.doesRoleHaveCapability(STRATEGIST_ROLE, MANAGER, bytes4(keccak256("borrow(uint256, uint256)")))) {
            rolesAuthority.setRoleCapability(STRATEGIST_ROLE, MANAGER, bytes4(keccak256("borrow(uint256, uint256)")), false);
            console.log("Granted role STRATEGIST_ROLE capability to borrow");
        }
        if (rolesAuthority.doesRoleHaveCapability(STRATEGIST_ROLE, MANAGER, bytes4(keccak256("repay(uint256, uint256)")))) {
            rolesAuthority.setRoleCapability(STRATEGIST_ROLE, MANAGER, bytes4(keccak256("repay(uint256, uint256)")), false);
            console.log("Granted role STRATEGIST_ROLE capability to repay");
        }
            if (rolesAuthority.doesRoleHaveCapability(STRATEGIST_ROLE, MANAGER, PrvlFlashloanAaveBorrowV5.settle.selector)) {
            rolesAuthority.setRoleCapability(STRATEGIST_ROLE, MANAGER, PrvlFlashloanAaveBorrowV5.settle.selector, false);
            console.log("Granted role STRATEGIST_ROLE capability to settle");
        }

        // Give agent_manager permission to manage the vault (role 7)
        if (!rolesAuthority.doesRoleHaveCapability(STRATEGIST_ROLE,address(flashloanManager), PrvlFlashloanAaveBorrowV5.borrow.selector)) {
            rolesAuthority.setRoleCapability(STRATEGIST_ROLE,address(flashloanManager), PrvlFlashloanAaveBorrowV5.borrow.selector, true);
            console.log("Granted role STRATEGIST_ROLE capability to borrow");
        }
        if (!rolesAuthority.doesRoleHaveCapability(STRATEGIST_ROLE,address(flashloanManager), PrvlFlashloanAaveBorrowV5.repay.selector)) {
            rolesAuthority.setRoleCapability(STRATEGIST_ROLE,address(flashloanManager), PrvlFlashloanAaveBorrowV5.repay.selector, true);
            console.log("Granted role STRATEGIST_ROLE capability to repay");
        }
            if (!rolesAuthority.doesRoleHaveCapability(STRATEGIST_ROLE,address(flashloanManager), PrvlFlashloanAaveBorrowV5.settle.selector)) {
            rolesAuthority.setRoleCapability(STRATEGIST_ROLE,address(flashloanManager), PrvlFlashloanAaveBorrowV5.settle.selector, true);
            console.log("Granted role STRATEGIST_ROLE capability to settle");
        }




        
        if (!rolesAuthority.doesUserHaveRole(agent_manager,STRATEGIST_ROLE)) {
            rolesAuthority.setUserRole(address(agent_manager),STRATEGIST_ROLE, true);
            console.log("Granted role 7 to micro-manager");
        }
        

        flashloanManager.setAuthority(rolesAuthority);

        // Parse the Merkle root from JSON
        string memory json = vm.readFile("leafs/Mainnet/WETHAgent2PRIME.json");
        bytes32 merkleRoot = vm.parseJsonBytes32(json, ".metadata.ManageRoot");

        // Set the Merkle root for the micro-manager address
        ManagerWithMerkleVerification managerContract = ManagerWithMerkleVerification(MANAGER);
        managerContract.setManageRoot(address(flashloanManager), merkleRoot);
        managerContract.setManageRoot(MANAGER, merkleRoot);

        // Set up proofs for the micro-manager
        _setupMicroManagerProofs(flashloanManager);

        vm.stopBroadcast();
        return managerContract;
    }

    function _setupMicroManagerProofs(PrvlFlashloanAaveBorrowV5 microManager) internal {
        setSourceChainName("mainnet");
        string memory json = vm.readFile("leafs/Mainnet/WETHAgent2PRIME.json");
        
        bytes32[][] memory borrowInnerManageProofs = new bytes32[][](3);
        borrowInnerManageProofs[0] = getMerkleProof(json, 0x6587317e5d1d4e9c760b30de843ce2eb7e3815d2a48e163746c377bfdfae17e8); // WETH -> wstETH
        borrowInnerManageProofs[1] = getMerkleProof(json, 0x661ae837d31ec10aacfd4414ff89ec7d0399005b9bd116dd855de92461a52023); // Supply wstETH to Aave V3
        borrowInnerManageProofs[2] = getMerkleProof(json, 0x0c26e4ef190309a83a4d33ea97e7c8845e7153e2bf54be7a04c9fd28fbc9f7aa); // Borrow WETH from Aave V3
        
        address[] memory borrowInnerDecodersAndSanitizers = new address[](3);
        borrowInnerDecodersAndSanitizers[0] = BASEDECODER;
        borrowInnerDecodersAndSanitizers[1] = BASEDECODER;
        borrowInnerDecodersAndSanitizers[2] = BASEDECODER;
        
        // Set up repay inner operations proofs (3 operations: repay, withdraw, swap)
        bytes32[][] memory repayInnerManageProofs = new bytes32[][](3);
        repayInnerManageProofs[0] = getMerkleProof(json, 0xcf21fb56040229800a330988fea029ba8ef8dc168c3145d1e9bef4d9877b0703); // Repay WETH to Aave V3
        repayInnerManageProofs[1] = getMerkleProof(json, 0x37106ea765f4c13e68f9320478be22b3b72b1b28d94fd777efa904b916333dfc); // Withdraw wstETH from Aave V3
        repayInnerManageProofs[2] = getMerkleProof(json, 0xad3ec0c69ad631d9e048dfb2f3af83afe8419ec566e76c65739f59c97f1290ab); // wstETH  -> WETH
        
        address[] memory repayInnerDecodersAndSanitizers = new address[](3);
        repayInnerDecodersAndSanitizers[0] = BASEDECODER;
        repayInnerDecodersAndSanitizers[1] = BASEDECODER;
        repayInnerDecodersAndSanitizers[2] = BASEDECODER;
        
        // Set up outer flashloan proof
        address[] memory outerDecodersAndSanitizers = new address[](1);
        outerDecodersAndSanitizers[0] = BASEDECODER;
        
        bytes32[][] memory outerManageProofs = new bytes32[][](1);
        outerManageProofs[0] = getMerkleProof(json, 0x1ba29ceeba5f7c3e761e73ae4dab381786da4ecd2731675a7e07dd3fa0b2559e); // Flashloan WETH from Balancer Vault
        
        // Set all proofs and decoders
        microManager.setBorrowInnerManageProofs(borrowInnerManageProofs);
        microManager.setBorrowInnerDecodersAndSanitizers(borrowInnerDecodersAndSanitizers);
        microManager.setRepayInnerManageProofs(repayInnerManageProofs);
        microManager.setRepayInnerDecodersAndSanitizers(repayInnerDecodersAndSanitizers);
        microManager.setOuterDecodersAndSanitizers(outerDecodersAndSanitizers);
        microManager.setOuterManageProofs(outerManageProofs);
        
        console.log("Micro-manager proofs configured");
    }

    function getMerkleProof(string memory json, bytes32 leafDigest) internal view returns (bytes32[] memory) {
        uint256 capacity = vm.parseJsonUint(json, ".metadata.TreeCapacity");
        uint256 height = 0;
        uint256 temp = capacity;
        if (temp == 0) revert("Invalid capacity");
        while (temp > 1) {
            temp >>= 1;
            height++;
        }

        string memory leavesPath = string(abi.encodePacked(".MerkleTree.", vm.toString(height)));
        bytes32[] memory leaves = vm.parseJsonBytes32Array(json, leavesPath);

        uint256 index = type(uint256).max;
        for (uint256 i = 0; i < leaves.length; i++) {
            if (leaves[i] == leafDigest) {
                index = i;
                break;
            }
        }
        if (index == type(uint256).max) revert("Leaf not found");

        bytes32[] memory proof = new bytes32[](height);
        uint256 currentIndex = index;

        for (uint256 level = height; level > 0; level--) {
            string memory levelPath = string(abi.encodePacked(".MerkleTree.", vm.toString(level)));
            bytes32[] memory levelHashes = vm.parseJsonBytes32Array(json, levelPath);
            proof[height - level] = levelHashes[currentIndex ^ 1];
            currentIndex >>= 1;
        }

        return proof;
    }
}