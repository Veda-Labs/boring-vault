// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 * @notice Creates merkle root for wstHYPE looping strategy using Felix (Morpho) markets
 * source .env && forge script script/MerkleRootCreation/Hyperliquid/CreateWstHypeLoopingMerkleRoot.s.sol --rpc-url $HYPERLIQUID_RPC_URL
 */
contract CreateWstHypeLoopingMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    // Hyperliquid protocol contracts
    address public wHYPE     = 0x5555555555555555555555555555555555555555; 
    address public stHYPE    = 0xfFaa4a3D97fE9107Cef8a3F48c069F577Ff76cC1;
    address public wstHYPE   = 0x94e8396e0869c9F2200760aF0621aFd240E1CF38;
    address public HYPE      = 0x2222222222222222222222222222222222222222; // Native token
    address public overseer  = 0xB96f07367e69e86d6e9C3F29215885104813eeAE; 

    // Felix is built on Morpho
    address public Felix_Vanilla = 0x68e37dE8d93d3496ae143F2E900490f6280C57cD; // Felix Markets contract
    
    // Felix market parameters - these create the market ID for Morpho
    address public felixOracle = 0xD767818Ef397e597810cF2Af6b440B1b66f0efD3;
    address public felixIrm    = 0xD4a426F010986dCad727e8dd6eed44cA4A9b7483;
    uint256 public felixLltv   = 860000000000000000; // 86%

    uint256 internal leafIndex = 0;

    bytes32 public felixMarketId = bytes32(0xe9a9bb9ed3cc53f4ee9da4eea0370c2c566873d5de807e16559a99907c9ae227);

    function run() external {
        generateWstHypeLoopingStrategistMerkleRoot();
    }

    function generateWstHypeLoopingStrategistMerkleRoot() public {
        setSourceChainName("hyperliquid");
        
        // Set addresses for hyperliquid chain - you'll need to add these to ChainValues
        setAddress(false, "hyperliquid", "boringVault", 0x1111111111111111111111111111111111111111); // REPLACE
        setAddress(false, "hyperliquid", "managerAddress", 0x2222222222222222222222222222222222222222); // REPLACE
        setAddress(false, "hyperliquid", "accountantAddress", 0x3333333333333333333333333333333333333333); // REPLACE
        
        // Set protocol addresses
        setAddress(false, "hyperliquid", "Felix_Vanilla", Felix_Vanilla); // Felix uses Morpho
        setAddress(false, "hyperliquid", "overseer", overseer);
        setAddress(false, "hyperliquid", "wHYPE", wHYPE);
        setAddress(false, "hyperliquid", "stHYPE", stHYPE);
        setAddress(false, "hyperliquid", "wstHYPE", wstHYPE);
        setAddress(false, "hyperliquid", "HYPE", HYPE);
        
        setAddress(false, "hyperliquid", "rawDataDecoderAndSanitizer", address(new ERC20DecoderAndSanitizer()));
        setAddress(false, "hyperliquid", "overseerDecoderAndSanitizer", address(new OverseerDecoderAndSanitizer()));
        setAddress(false, "hyperliquid", "wHypeDecoderAndSanitizer", address(new WHypeDecoderAndSanitizer()));

        // Calculate total leafs needed
        uint256 totalLeafs = 20; // Increased to accommodate all operations
        ManageLeaf[] memory leafs = new ManageLeaf[](totalLeafs);
        
        leafIndex = 0; // Reset leaf index
        
        // Add Overseer operations (HYPE -> stHYPE AND unstaking functionality)
        _addOverseerLeafs(leafs);
        
        // Add wHYPE operations (wrap/unwrap)
        _addWHypeLeafs(leafs);
        
        // Add ERC20 operations (approvals for stHYPE, wstHYPE, wHYPE)
        _addERC20Leafs(leafs);
        
        // Add Felix/Morpho operations using the existing helper
        _addMorphoBlueCollateralLeafs(leafs, felixMarketId);

        // Trim unused leaves
        ManageLeaf[] memory finalLeafs = new ManageLeaf[](leafIndex);
        for (uint256 i = 0; i < leafIndex; i++) {
            finalLeafs[i] = leafs[i];
        }

        // Generate merkle root
        bytes32 merkleRoot = _generateMerkleTree(finalLeafs);
        string memory filePath = "./merkle_tree_data/WstHypeLoopingStrategistMerkleRoot.json";
        _generateMerkleTree(finalLeafs, filePath, "WstHype Looping Strategy with Unstaking");

        console.log("Merkle Root:", vm.toString(merkleRoot));
        console.log("Total leaves:", finalLeafs.length);
        console.log("Felix Market ID:", vm.toString(felixMarketId));
    }

    function _addOverseerLeafs(ManageLeaf[] memory leafs) internal {
        // ========== STAKING OPERATIONS ==========
        
        // Overseer mint (HYPE -> stHYPE) - without community code
        leafs[leafIndex] = ManageLeaf(
            overseer,
            true, // valueNonZero = true for native HYPE
            "mint(address)",
            new address[](1),
            "Mint stHYPE from Overseer",
            getAddress("hyperliquid", "overseerDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress("hyperliquid", "boringVault");
        leafIndex++;

        // Overseer mint (HYPE -> stHYPE) - with community code  
        leafs[leafIndex] = ManageLeaf(
            overseer,
            true, // valueNonZero = true for native HYPE
            "mint(address,string)",
            new address[](1),
            "Mint stHYPE from Overseer with community code",
            getAddress("hyperliquid", "overseerDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress("hyperliquid", "boringVault");
        leafIndex++;

        // ========== UNSTAKING OPERATIONS ==========
        
        // Burn and redeem if possible (stHYPE -> HYPE) - without community code
        leafs[leafIndex] = ManageLeaf(
            overseer,
            false, // No native value required for burning
            "burnAndRedeemIfPossible(address,uint256,string)",
            new address[](1),
            "Burn stHYPE and redeem HYPE if possible (no community code)",
            getAddress("hyperliquid", "overseerDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress("hyperliquid", "boringVault");
        leafIndex++;

        // Redeem completed burn (using burn ID)
        leafs[leafIndex] = ManageLeaf(
            overseer,
            false, // No native value required for redemption
            "redeem(uint256)",
            new address[](0),
            "Redeem completed burn using burn ID",
            getAddress("hyperliquid", "overseerDecoderAndSanitizer")
        );
        leafIndex++;
    }

    function _addWHypeLeafs(ManageLeaf[] memory leafs) internal {
        // wHYPE deposit (HYPE -> wHYPE)
        leafs[leafIndex] = ManageLeaf(
            wHYPE,
            true, // valueNonZero = true for native HYPE deposit
            "deposit()",
            new address[](0),
            "Wrap HYPE to wHYPE", 
            getAddress("hyperliquid", "wHypeDecoderAndSanitizer")
        );
        leafIndex++;

        // wHYPE withdraw (wHYPE -> HYPE)
        leafs[leafIndex] = ManageLeaf(
            wHYPE,
            false,
            "withdraw(uint256)",
            new address[](0),
            "Unwrap wHYPE to HYPE",
            getAddress("hyperliquid", "wHypeDecoderAndSanitizer")
        );
        leafIndex++;
    }

    function _addERC20Leafs(ManageLeaf[] memory leafs) internal {
        // wstHYPE approvals (needed for Felix collateral)
        leafs[leafIndex] = ManageLeaf(
            wstHYPE,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve wstHYPE for Felix collateral",
            getAddress("hyperliquid", "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress("hyperliquid", "Felix_Vanilla");
        leafIndex++;

        // wHYPE approvals (needed for Felix loan repayment)
        leafs[leafIndex] = ManageLeaf(
            wHYPE,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve wHYPE for loan repayment",
            getAddress("hyperliquid", "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress("hyperliquid", "Felix_Vanilla");
        leafIndex++;
    }
}