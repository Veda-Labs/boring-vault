// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 * liquidMonadUSD — Monad strategy root.
 *
 *  source .env && forge script script/MerkleRootCreation/Monad/CreateLiquidMonadUSDMerkleRoot.s.sol --rpc-url $MONAD_RPC_URL
 *
 * Strategy leaves:
 *   - Upshift earnAUSD ERC4626 vault
 *   - Merkl claim (AUSD compound, WMON sell-through)
 *   - WMON wrap / unwrap
 *
 * Reverse-bridge leaves (Monad → Mainnet):
 *   - AUSD via LayerZero OFT
 *   - USDC via Circle CCTP V2
 */
contract CreateLiquidMonadUSDMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x525D01dBb0004565C80bF60E269122759672dAD2;
    address public managerAddress = 0x71F38f6e336791893916EDC50CE7292240D7b46d;
    address public accountantAddress = 0xBa814af88A9279386896E3aCFA685BFA7f093d14;
    address public rawDataDecoderAndSanitizer = 0xDd1169376E8fD99a7141043646cf903A7f4676A2;

    function setUp() external {}

    function run() external {
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(monad);
        setAddress(false, monad, "boringVault", boringVault);
        setAddress(false, monad, "managerAddress", managerAddress);
        setAddress(false, monad, "accountantAddress", accountantAddress);
        setAddress(false, monad, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Upshift earnAUSD ==========================
        // The Upshift earnAUSD proxy reverts on symbol()/name(), so the standard
        // _addERC4626Leafs helper can't be used. Inline the same 5 leaves with literal
        // descriptions instead.
        _addUpshiftEarnAUSDLeafs(leafs);

        // ========================== Merkl rewards ==========================
        _addMerklClaimLeaf(leafs, getAddress(sourceChain, "merklDistributor"));

        // ========================== WMON wrap / unwrap ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WMON"));

        // ========================== LayerZero OFT — AUSD → Mainnet ==========================
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "AUSD"),
            getAddress(sourceChain, "ausdOFTAdapter"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== CCTP V2 — USDC → Mainnet ==========================
        _addCCTPBridgeLeafs(leafs, cctpMainnetDomainId);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Monad/LiquidMonadUSDStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    // The Upshift earnAUSD proxy at 0x36eDbF0C…406aA does not expose ERC20 metadata view
    // functions, so we cannot rely on `_addERC4626Leafs` (which reads vault.symbol()).
    // This mirrors that helper's behavior with hardcoded asset / vault labels.
    function _addUpshiftEarnAUSDLeafs(ManageLeaf[] memory leafs) internal {
        address vault = getAddress(sourceChain, "upshiftEarnAUSDVault");
        address asset = getAddress(sourceChain, "AUSD");
        address bv = getAddress(sourceChain, "boringVault");
        address decoder = getAddress(sourceChain, "rawDataDecoderAndSanitizer");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            asset,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve earnAUSD to spend AUSD",
            decoder
        );
        leafs[leafIndex].argumentAddresses[0] = vault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit AUSD into earnAUSD",
            decoder
        );
        leafs[leafIndex].argumentAddresses[0] = bv;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            "Withdraw AUSD from earnAUSD",
            decoder
        );
        leafs[leafIndex].argumentAddresses[0] = bv;
        leafs[leafIndex].argumentAddresses[1] = bv;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "mint(uint256,address)",
            new address[](1),
            "Mint earnAUSD using AUSD",
            decoder
        );
        leafs[leafIndex].argumentAddresses[0] = bv;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "redeem(uint256,address,address)",
            new address[](2),
            "Redeem earnAUSD for AUSD",
            decoder
        );
        leafs[leafIndex].argumentAddresses[0] = bv;
        leafs[leafIndex].argumentAddresses[1] = bv;
    }
}
