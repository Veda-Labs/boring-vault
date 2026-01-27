// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {PrvlFlashloanAaveBorrowV2} from "src/micro-managers/PrvlFlashloanAaveBorrowV2.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

/*
 * source .env && forge script script/utils/LocalFork/TestPrvlFlashloanAaveBorrowV2.s.sol:TestPrvlFlashloanAaveBorrowV2 --fork-url local --broadcast -vv
 */

interface IAavePool {
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
}

contract TestPrvlFlashloanAaveBorrowV2 is Script, MerkleTreeHelper {
    uint256 public privateKey;
    
    address constant MICRO_MANAGER_V2 = 0xd25108f19177684E335Ba5787702B8B7154f0b15;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant AWETH = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;
    address constant BORING_VAULT = 0x3A29E2a5Ddb20C56D62a9D9Fa29b606833C4bf1d;
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant BASEDECODER = 0x078AF49028bDfC2a2247B76d170022a9C98308D0;
    
    uint24 constant UNI_FEE_TIER = 3000;
    uint256 constant AAVE_VARIABLE_RATE = 2;

    function setUp() external {
        privateKey = vm.envUint("LOCAL_DEPLOYER_PRIVATE_KEY");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        PrvlFlashloanAaveBorrowV2 microManager = PrvlFlashloanAaveBorrowV2(MICRO_MANAGER_V2);
        
        // Setup merkle proofs
        setSourceChainName("mainnet");
        
        // === Test Borrow Operation ===
        testBorrow(microManager);
        
        // === Test Partial Repay ===
        testPartialRepay(microManager);
        
        // === Test Full Settle ===
        testSettle(microManager);
        
        console.log("=== V2 Test Complete ===");
        console.log("All operations successful!");
        
        // Show final Aave position
        console.log("=== Final Aave Position ===");
        (uint256 totalCollateralBase, uint256 totalDebtBase, , , , uint256 healthFactor) = IAavePool(AAVE_POOL).getUserAccountData(BORING_VAULT);
        console.log("Total collateral (USD, 8 decimals):", totalCollateralBase);
        console.log("Total debt (USD, 8 decimals):", totalDebtBase);
        console.log("Health factor (18 decimals):", healthFactor);

        vm.stopBroadcast();
    }
    
    function testBorrow(PrvlFlashloanAaveBorrowV2 microManager) internal {
        string memory json = vm.readFile("leafs/LocalFork/FundMgmtUSDCAgentMainnetForkLeafs.json");
        
        uint256 collateralAmount = 1000e6; // 1000 USDC collateral  
        uint256 borrowAmount = 4000e6;     // 4000 USDC borrow (5x leverage total)

        console.log("=== Before Borrow ===");
        console.log("Vault USDC balance:", ERC20(USDC).balanceOf(BORING_VAULT));
        console.log("Vault WETH balance:", ERC20(WETH).balanceOf(BORING_VAULT));
        console.log("Vault aWETH balance:", ERC20(AWETH).balanceOf(BORING_VAULT));

        // Prepare inner proofs for borrow operation
        bytes32[][] memory innerProofs = new bytes32[][](3);
        innerProofs[0] = getMerkleProof(json, 0x5d74981162e16fcc0a27ef26a25f75d14f92dab54a218cefadf61f0d7ce87fff); // USDC->WETH swap
        innerProofs[1] = getMerkleProof(json, 0x3be8fa59f72de7230cb781231e183e937feabbcab6ec516d621cfa7033c3663b); // AAVE WETH supply
        innerProofs[2] = getMerkleProof(json, 0x04bf67c02da44dec7fdd56251cd0be0c7ecea9b9927f5939b10f85e38e0f9a72); // AAVE USDC borrow
        
        address[] memory innerDecoders = new address[](3);
        innerDecoders[0] = BASEDECODER;
        innerDecoders[1] = BASEDECODER;
        innerDecoders[2] = BASEDECODER;
        
        // Prepare outer proofs for flashloan
        bytes32[][] memory outerProofs = new bytes32[][](1);
        outerProofs[0] = getMerkleProof(json, 0xa50c6593a1f7b746bf2006dba902573c35f62005b0510921070ae8f234cad304); // Flashloan USDC
        
        address[] memory outerDecoders = new address[](1);
        outerDecoders[0] = BASEDECODER;

        // Create PositionUpdate struct
        PrvlFlashloanAaveBorrowV2.PositionUpdate memory positionUpdate = PrvlFlashloanAaveBorrowV2.PositionUpdate({
            innerManageProofs: innerProofs,
            innerDecodersAndSanitizers: innerDecoders,
            outerManageProofs: outerProofs,
            outerDecodersAndSanitizers: outerDecoders,
            collateralAmount: collateralAmount,
            collateralToken: WETH,
            borrowAmount: borrowAmount,
            borrowToken: USDC,
            uniFeeTier: UNI_FEE_TIER,
            aaveVariableRate: AAVE_VARIABLE_RATE,
            aToken: AWETH
        });

        console.log("Executing 5x leverage borrow...");
        console.log("Collateral:", collateralAmount);
        console.log("Borrow amount:", borrowAmount);
        
        microManager.borrow(positionUpdate);

        console.log("=== After Borrow ===");
        console.log("Vault USDC balance:", ERC20(USDC).balanceOf(BORING_VAULT));
        console.log("Vault WETH balance:", ERC20(WETH).balanceOf(BORING_VAULT));
        console.log("Vault aWETH balance:", ERC20(AWETH).balanceOf(BORING_VAULT));
    }
    
    function testPartialRepay(PrvlFlashloanAaveBorrowV2 microManager) internal {
        string memory json = vm.readFile("leafs/LocalFork/FundMgmtUSDCAgentMainnetForkLeafs.json");
        
        uint256 partialRepayAmount = 2000e6; // 2000 USDC repay
        uint256 partialWithdrawAmount = ERC20(AWETH).balanceOf(BORING_VAULT) / 4; // Quarter of collateral
        
        console.log("=== Testing Partial Repay ===");
        console.log("Partial repay amount:", partialRepayAmount);
        console.log("Partial withdraw amount:", partialWithdrawAmount);
        
        // Prepare inner proofs for repay operation
        bytes32[][] memory innerProofs = new bytes32[][](3);
        innerProofs[0] = getMerkleProof(json, 0xda35826a8a1013fe5cf9b4c1005d856050d7edf0e4cb69f1baaf16059b3f318b); // AAVE USDC repay
        innerProofs[1] = getMerkleProof(json, 0x539b50ed42eb794ee242cf23ea2b8e0840cd40c8e533b36b93d25121ae4a2af0); // AAVE WETH withdraw
        innerProofs[2] = getMerkleProof(json, 0x94a4799f727108873b3c1d4347a2798a7ae5417955389c0320deac3245385fec); // WETH->USDC swap
        
        address[] memory innerDecoders = new address[](3);
        innerDecoders[0] = BASEDECODER;
        innerDecoders[1] = BASEDECODER;
        innerDecoders[2] = BASEDECODER;
        
        // Prepare outer proofs for flashloan
        bytes32[][] memory outerProofs = new bytes32[][](1);
        outerProofs[0] = getMerkleProof(json, 0xa50c6593a1f7b746bf2006dba902573c35f62005b0510921070ae8f234cad304); // Flashloan USDC
        
        address[] memory outerDecoders = new address[](1);
        outerDecoders[0] = BASEDECODER;

        // Create PositionUpdate struct for repay
        PrvlFlashloanAaveBorrowV2.PositionUpdate memory positionUpdate = PrvlFlashloanAaveBorrowV2.PositionUpdate({
            innerManageProofs: innerProofs,
            innerDecodersAndSanitizers: innerDecoders,
            outerManageProofs: outerProofs,
            outerDecodersAndSanitizers: outerDecoders,
            collateralAmount: partialWithdrawAmount,
            collateralToken: WETH,
            borrowAmount: partialRepayAmount,
            borrowToken: USDC,
            uniFeeTier: UNI_FEE_TIER,
            aaveVariableRate: AAVE_VARIABLE_RATE,
            aToken: AWETH
        });

        microManager.repay(positionUpdate);

        console.log("=== After Partial Repay ===");
        console.log("Vault USDC balance:", ERC20(USDC).balanceOf(BORING_VAULT));
        console.log("Vault WETH balance:", ERC20(WETH).balanceOf(BORING_VAULT));
        console.log("Vault aWETH balance:", ERC20(AWETH).balanceOf(BORING_VAULT));
    }
    
    function testSettle(PrvlFlashloanAaveBorrowV2 microManager) internal {
        string memory json = vm.readFile("leafs/LocalFork/FundMgmtUSDCAgentMainnetForkLeafs.json");
        
        console.log("=== Testing Full Settle ===");
        
        // Prepare inner proofs for settle operation
        bytes32[][] memory innerProofs = new bytes32[][](3);
        innerProofs[0] = getMerkleProof(json, 0xda35826a8a1013fe5cf9b4c1005d856050d7edf0e4cb69f1baaf16059b3f318b); // AAVE USDC repay
        innerProofs[1] = getMerkleProof(json, 0x539b50ed42eb794ee242cf23ea2b8e0840cd40c8e533b36b93d25121ae4a2af0); // AAVE WETH withdraw
        innerProofs[2] = getMerkleProof(json, 0x94a4799f727108873b3c1d4347a2798a7ae5417955389c0320deac3245385fec); // WETH->USDC swap
        
        address[] memory innerDecoders = new address[](3);
        innerDecoders[0] = BASEDECODER;
        innerDecoders[1] = BASEDECODER;
        innerDecoders[2] = BASEDECODER;
        
        // Prepare outer proofs for flashloan
        bytes32[][] memory outerProofs = new bytes32[][](1);
        outerProofs[0] = getMerkleProof(json, 0xa50c6593a1f7b746bf2006dba902573c35f62005b0510921070ae8f234cad304); // Flashloan USDC
        
        address[] memory outerDecoders = new address[](1);
        outerDecoders[0] = BASEDECODER;

        // Create PositionUpdate struct for settle - values don't matter as settle calculates them
        PrvlFlashloanAaveBorrowV2.PositionUpdate memory positionUpdate = PrvlFlashloanAaveBorrowV2.PositionUpdate({
            innerManageProofs: innerProofs,
            innerDecodersAndSanitizers: innerDecoders,
            outerManageProofs: outerProofs,
            outerDecodersAndSanitizers: outerDecoders,
            collateralAmount: 0, // Not used in settle
            collateralToken: WETH,
            borrowAmount: 0, // Not used in settle
            borrowToken: USDC,
            uniFeeTier: UNI_FEE_TIER,
            aaveVariableRate: AAVE_VARIABLE_RATE,
            aToken: AWETH
        });

        microManager.settle(positionUpdate);

        console.log("=== After Settle (Final) ===");
        console.log("Vault USDC balance:", ERC20(USDC).balanceOf(BORING_VAULT));
        console.log("Vault WETH balance:", ERC20(WETH).balanceOf(BORING_VAULT));
        console.log("Vault aWETH balance:", ERC20(AWETH).balanceOf(BORING_VAULT));
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