// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {PrvlFlashloanAaveBorrowV5, TokenConfig} from "src/micro-managers/PrvlFlashloanAaveBorrowV5.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";

/*
 * source .env && forge script script/utils/Mainnet/DeployMicroUSDCsUSDCePRIME.s.sol:DeployPrvlFlashloanAaveBorrow --fork-url mainnet --broadcast -vv --verify
 */

contract DeployPrvlFlashloanAaveBorrow is Script, MerkleTreeHelper {
    uint256 public privateKey;
    
    address constant OWNER = 0xA45A9b2bC0230Fa78aF0C92031a2E4016aFA9B40; 
    address constant MANAGER = 0x8f15C3f376f53b3406c1640135204944baA9c00D;
    address constant BORING_VAULT = 0x6638968ACBA85A6445D3909F4d0520F7D2501061;
    address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address constant UNI_V3_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant UNI_V3_QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    address constant AAVE_POOL = 0x4e033931ad43597d96D6bcc25c280717730B58B1; //Prime
    address constant BASE_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; //USDC
    address constant DEPOSIT_TOKEN = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497; // sUSDe
    address constant A_TOKEN = 0xc2015641564a5914A17CB9A92eC8d8feCfa8f2D0; //
    address constant DEBT_TOKEN = 0xeD90dE2D824Ee766c6Fd22E90b12e598f681dc9F; //variableDebtEthUSDC
    address constant BASEDECODER = 0xdda148b36E80d28EEF153c570891B628cb2540f1;
    
    address constant agent_manager = 0x02B5f0fafA419C5227A1de9777585ACA048a309d;

    uint256 constant AAVE_VARIABLE_RATE = 2;
    uint8 public constant STRATEGIST_ROLE = 7;
    
    RolesAuthority public rolesAuthority = RolesAuthority(0xf84B1eF921D7aA21609C5f09E65C8067a048793C);
    PrvlFlashloanAaveBorrowV5 public flashloanManager;

    function setUp() external {
        privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
    }

    function run() external returns (ManagerWithMerkleVerification) {
        vm.startBroadcast(privateKey);

        TokenConfig memory tokens = TokenConfig({
            baseToken: BASE_TOKEN,
            depositToken: DEPOSIT_TOKEN,
            aToken: A_TOKEN,
            debtToken: DEBT_TOKEN
        });
        
        /*flashloanManager = new PrvlFlashloanAaveBorrowV5(
            OWNER,
            MANAGER,
            BORING_VAULT,
            UNI_V3_ROUTER,
            UNI_V3_QUOTER,
            AAVE_POOL,
            tokens,
            AAVE_VARIABLE_RATE
        ); */

        flashloanManager = PrvlFlashloanAaveBorrowV5(0xB8461be4483850D49503840110ec43d56702e13F);
        
        console.log("PrvlFlashloanAaveBorrow deployed at:", address(flashloanManager));
        // Give micro-manager permission to manage the vault (role 7)
        if (!rolesAuthority.doesUserHaveRole(address(flashloanManager),STRATEGIST_ROLE)) {
            rolesAuthority.setUserRole(address(flashloanManager),STRATEGIST_ROLE, true);
            console.log("Granted role STRATEGIST_ROLE to micro-manager");
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
        string memory json = vm.readFile("leafs/Mainnet/USDCAgent2PRIME.json");
        bytes32 merkleRoot = vm.parseJsonBytes32(json, ".metadata.ManageRoot");

        // Set the Merkle root for the micro-manager address
        ManagerWithMerkleVerification managerContract = ManagerWithMerkleVerification(MANAGER);
        //managerContract.setManageRoot(address(flashloanManager), merkleRoot);
        //managerContract.setManageRoot(MANAGER, merkleRoot);

        // Set up proofs for the micro-manager
        _setupMicroManagerProofs(flashloanManager);

        vm.stopBroadcast();
        return managerContract;
    }

    function _setupMicroManagerProofs(PrvlFlashloanAaveBorrowV5 microManager) internal {
        setSourceChainName("mainnet");
        string memory json = vm.readFile("leafs/Mainnet/USDCAgent2PRIME.json");
        
        // Set up borrow inner operations proofs (3 operations: swap, supply, borrow)
        bytes32[][] memory borrowInnerManageProofs = new bytes32[][](3);
        borrowInnerManageProofs[0] = getMerkleProof(json, 0xc3e3a1c485c45e8a69bb59c81ec893b4b50f86bd8288f9c9e9ff18733d526d9a); // USDC -> DAI -> USDT -> sUSDe
        borrowInnerManageProofs[1] = getMerkleProof(json, 0x05e9663954dac5b84ead108a24c1d4f29560f1df13f26d9da5e1007c6087e1e4); // Supply sUSDe to Aave V3
        borrowInnerManageProofs[2] = getMerkleProof(json, 0xf4b2a922db3056f538cf5ae548b75787baab27bcf563f4d77e28d1de1ba2eeab); // Borrow USDC from Aave V3
        
        address[] memory borrowInnerDecodersAndSanitizers = new address[](3);
        borrowInnerDecodersAndSanitizers[0] = BASEDECODER;
        borrowInnerDecodersAndSanitizers[1] = BASEDECODER;
        borrowInnerDecodersAndSanitizers[2] = BASEDECODER;
        
        // Set up repay inner operations proofs (3 operations: repay, withdraw, swap)
        bytes32[][] memory repayInnerManageProofs = new bytes32[][](3);
        repayInnerManageProofs[0] = getMerkleProof(json, 0x119790c0f550bb849b00fc0ca0f5a62d8b1262cb28eb7531759a6109e11597df); // Repay USDC to Aave V3
        repayInnerManageProofs[1] = getMerkleProof(json, 0x7980bde9ba28a2381377a0505f18261b3d0a29593a927c9e99d61273f89e9c8d); // Withdraw sUSDe from Aave V3
        repayInnerManageProofs[2] = getMerkleProof(json, 0x026f237edccbf6bb6baa76e14aa165657adf29ff8aae60849f0f671aec2efa5f); // sUSDe -> USDT -> DAI -> USDC
        
        address[] memory repayInnerDecodersAndSanitizers = new address[](3);
        repayInnerDecodersAndSanitizers[0] = BASEDECODER;
        repayInnerDecodersAndSanitizers[1] = BASEDECODER;
        repayInnerDecodersAndSanitizers[2] = BASEDECODER;
        
        // Set up outer flashloan proof
        address[] memory outerDecodersAndSanitizers = new address[](1);
        outerDecodersAndSanitizers[0] = BASEDECODER;
        
        bytes32[][] memory outerManageProofs = new bytes32[][](1);
        outerManageProofs[0] = getMerkleProof(json, 0x95064f62999ba1a5584998a102b84ae991421dd2ee402d2cdd171699e2d94212); // Flashloan USDC from Balancer Vault
        
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