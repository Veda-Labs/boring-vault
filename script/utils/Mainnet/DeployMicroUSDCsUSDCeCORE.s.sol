// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {PrvlFlashloanAaveBorrowV5, TokenConfig} from "src/micro-managers/PrvlFlashloanAaveBorrowV5.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";

/*
 * source .env && forge script script/utils/Mainnet/DeployMicroUSDCsUSDCeCORE.s.sol:DeployPrvlFlashloanAaveBorrow --fork-url mainnet --broadcast -vv --verify
 */

contract DeployPrvlFlashloanAaveBorrow is Script, MerkleTreeHelper {
    uint256 public privateKey;
    
    address constant OWNER = 0xA45A9b2bC0230Fa78aF0C92031a2E4016aFA9B40; 
    address constant MANAGER = 0x28d0D9C4553c24aBf55CBd0680B03524eeC966Aa;
    address constant BORING_VAULT = 0x7e68c279EA86FA49A49Eef2Cbb79B9cBfBc48025;
    address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address constant UNI_V3_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant UNI_V3_QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2; //core
    address constant BASE_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; //USDC
    address constant DEPOSIT_TOKEN = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497; // sUSDCe
    address constant A_TOKEN = 0x4579a27aF00A62C0EB156349f31B345c08386419; //awstETH
    address constant DEBT_TOKEN = 0x72E95b8931767C79bA4EeE721354d6E99a61D004; //variableDebtEthUSDC
    address constant BASEDECODER = 0xdda148b36E80d28EEF153c570891B628cb2540f1;

    address constant agent_manager = 0xa3e80F9703632E492eDdcE84cA1E415aed5C3487;

    uint256 constant AAVE_VARIABLE_RATE = 2;
    uint8 public constant STRATEGIST_ROLE = 7;

    RolesAuthority public rolesAuthority = RolesAuthority(0x58b25D1D07C5DB365a1686f6d824B585808b8dA2);
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
        
        /* flashloanManager = new PrvlFlashloanAaveBorrowV5(
            OWNER,
            MANAGER,
            BORING_VAULT,
            UNI_V3_ROUTER,
            UNI_V3_QUOTER,
            AAVE_POOL,
            tokens,
            AAVE_VARIABLE_RATE
        ); */
        flashloanManager = PrvlFlashloanAaveBorrowV5(0x693c5f56a4c91976165Bb042BB1ef7106c16304E);
        
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

        //flashloanManager.setAuthority(rolesAuthority);

        // Parse the Merkle root from JSON
        string memory json = vm.readFile("leafs/Mainnet/USDCAgent1CORE.json");
        bytes32 merkleRoot = vm.parseJsonBytes32(json, ".metadata.ManageRoot");

        // Set the Merkle root for the micro-manager address
        ManagerWithMerkleVerification managerContract = ManagerWithMerkleVerification(MANAGER);
       // managerContract.setManageRoot(address(flashloanManager), merkleRoot);
       // managerContract.setManageRoot(MANAGER, merkleRoot);

        // Set up proofs for the micro-manager
        //_setupMicroManagerProofs(flashloanManager);
        
        vm.stopBroadcast();
        return managerContract;
    }

    function _setupMicroManagerProofs(PrvlFlashloanAaveBorrowV5 microManager) internal {
        setSourceChainName("mainnet");
        string memory json = vm.readFile("leafs/Mainnet/USDCAgent1CORE.json");
        
        // Set up borrow inner operations proofs (3 operations: swap, supply, borrow)
        bytes32[][] memory borrowInnerManageProofs = new bytes32[][](3);
        borrowInnerManageProofs[0] = getMerkleProof(json, 0xb664af77824fc2b645f0f9578b94197a166507448cfc52583620d3a07aef5f7d); // USDC -> DAI -> USDT -> sUSDe
        borrowInnerManageProofs[1] = getMerkleProof(json, 0x0e59d6954eef6ba0fee471b029729555eed006c5b61a118689eba29af8956509); // Supply sUSDe to Aave V3
        borrowInnerManageProofs[2] = getMerkleProof(json, 0xeb4ff0b0bf28ad4e682fa54c4331d4759e525ec853f6551ec2f53091fa8340df); // Borrow USDC from Aave V3
        
        address[] memory borrowInnerDecodersAndSanitizers = new address[](3);
        borrowInnerDecodersAndSanitizers[0] = BASEDECODER;
        borrowInnerDecodersAndSanitizers[1] = BASEDECODER;
        borrowInnerDecodersAndSanitizers[2] = BASEDECODER;
        
        // Set up repay inner operations proofs (3 operations: repay, withdraw, swap)
        bytes32[][] memory repayInnerManageProofs = new bytes32[][](3);
        repayInnerManageProofs[0] = getMerkleProof(json, 0x5df6671c7839cb681877ab33e6b6651496579b45a6dd90feb513c4f8d7c5e859); // Repay USDC to Aave V3
        repayInnerManageProofs[1] = getMerkleProof(json, 0x8c5592606af03be2b78cc2846df14978d566e6dc904620ee7005f6696823e9c2); // Withdraw sUSDe from Aave V3
        repayInnerManageProofs[2] = getMerkleProof(json, 0x655f01d48b9f6bc990305c907702dc9ff214e4372e5ac7a8561dedb44b102a45); // sUSDe -> USDT -> DAI -> USDC
        
        address[] memory repayInnerDecodersAndSanitizers = new address[](3);
        repayInnerDecodersAndSanitizers[0] = BASEDECODER;
        repayInnerDecodersAndSanitizers[1] = BASEDECODER;
        repayInnerDecodersAndSanitizers[2] = BASEDECODER;
        
        // Set up outer flashloan proof
        address[] memory outerDecodersAndSanitizers = new address[](1);
        outerDecodersAndSanitizers[0] = BASEDECODER;
        
        bytes32[][] memory outerManageProofs = new bytes32[][](1);
        outerManageProofs[0] = getMerkleProof(json, 0x95cb82f29aeaa45ca6777a4d3b47c5dce8555016cde09ac67e016ef1d534333c); // Flashloan USDC from Balancer Vault
        
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