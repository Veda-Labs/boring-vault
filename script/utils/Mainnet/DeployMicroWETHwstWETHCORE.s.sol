// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {PrvlFlashloanAaveBorrowV5, TokenConfig} from "src/micro-managers/PrvlFlashloanAaveBorrowV5.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";

/*
 * source .env && forge script script/utils/Mainnet/DeployMicroWETHwstWETHCORE.s.sol:DeployPrvlFlashloanAaveBorrow --fork-url mainnet --broadcast -vv --verify
 */

contract DeployPrvlFlashloanAaveBorrow is Script, MerkleTreeHelper {
    uint256 public privateKey;
    
    address constant OWNER = 0xA45A9b2bC0230Fa78aF0C92031a2E4016aFA9B40; 
    address constant MANAGER = 0xF93C04915f69e95D9b8777609f07c969Ff24ee48;
    address constant BORING_VAULT = 0x8503B18b279Fd0f1EC35303D8db834619A12250f;
    address constant UNI_V3_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant UNI_V3_QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2; //core
    address constant BASE_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; //WETH
    address constant DEPOSIT_TOKEN = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; //wstETH
    address constant A_TOKEN = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371; //awstETH
    address constant DEBT_TOKEN = 0xeA51d7853EEFb32b6ee06b1C12E6dcCA88Be0fFE; //variableDebtEthWETH
    address constant BASEDECODER = 0xdda148b36E80d28EEF153c570891B628cb2540f1;
    
    address constant agent_manager = 0x7d88D1a033EdD20e80016Ba5e8868859AB019eB0;

    uint256 constant AAVE_VARIABLE_RATE = 2;
    uint8 public constant STRATEGIST_ROLE = 7;
    
    RolesAuthority public rolesAuthority = RolesAuthority(0x3282A25B08a775FBa2FC6dE3fEe7cB635dC6671e);
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

        //flashloanManager = PrvlFlashloanAaveBorrowV5(0x7baC3d958369618960d949725479E778cBea8811);
        
        console.log("PrvlFlashloanAaveBorrow deployed at:", address(flashloanManager));
        // Give micro-manager permission to manage the vault (roleSTRATEGIST_ROLE
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
        string memory json = vm.readFile("leafs/Mainnet/WETHAgent1CORE.json");
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
        string memory json = vm.readFile("leafs/Mainnet/WETHAgent1CORE.json");
        
         // Set up borrow inner operations proofs (3 operations: swap, supply, borrow)
        bytes32[][] memory borrowInnerManageProofs = new bytes32[][](3);
        borrowInnerManageProofs[0] = getMerkleProof(json, 0x5c04ecf2bc31ea0c84fc0d06953c8936116cf405a3ddb2c782215d06cae6c78d); // WETH -> wstETH
        borrowInnerManageProofs[1] = getMerkleProof(json, 0x8d4e2e04361f120b719337f49baaae18a73fa121107a6bfe95dc5ccf612e59d6); // Supply wstETH to Aave V3
        borrowInnerManageProofs[2] = getMerkleProof(json, 0x9bd50df63302adb2a85033e1a4db175bd159ca9e32d7b4f594eb4bc8e919b074); // Borrow WETH from Aave V3
        
        address[] memory borrowInnerDecodersAndSanitizers = new address[](3);
        borrowInnerDecodersAndSanitizers[0] = BASEDECODER;
        borrowInnerDecodersAndSanitizers[1] = BASEDECODER;
        borrowInnerDecodersAndSanitizers[2] = BASEDECODER;
        
        // Set up repay inner operations proofs (3 operations: repay, withdraw, swap)
        bytes32[][] memory repayInnerManageProofs = new bytes32[][](3);
        repayInnerManageProofs[0] = getMerkleProof(json, 0x9467cbbc7c3ad19cb8226609d5131d5c173e989828ef22d538f375abd4cca4ab); // Repay WETH to Aave V3
        repayInnerManageProofs[1] = getMerkleProof(json, 0x4697ea1e9d7a852542394d816fe897cb0822a6370c7166b63f45a58984662736); // Withdraw wstETH from Aave V3
        repayInnerManageProofs[2] = getMerkleProof(json, 0xf5f28dac4b94bbb47df4047f8f3263af3a68453d53b67eae359a258ab6e782db); // wstETH  -> WETH
        
        address[] memory repayInnerDecodersAndSanitizers = new address[](3);
        repayInnerDecodersAndSanitizers[0] = BASEDECODER;
        repayInnerDecodersAndSanitizers[1] = BASEDECODER;
        repayInnerDecodersAndSanitizers[2] = BASEDECODER;
        
        // Set up outer flashloan proof
        address[] memory outerDecodersAndSanitizers = new address[](1);
        outerDecodersAndSanitizers[0] = BASEDECODER;
        
        bytes32[][] memory outerManageProofs = new bytes32[][](1);
        outerManageProofs[0] = getMerkleProof(json, 0x8f6c77767bb4bb98591c3df12d951a468b693e28475b27ed8c1446b32cf352b9); // Flashloan WETH from Balancer Vault
        
        
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