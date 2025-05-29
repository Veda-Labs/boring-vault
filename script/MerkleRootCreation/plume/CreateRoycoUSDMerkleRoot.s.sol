// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/plume/CreateRoycoUSDMerkleRoot.s.sol:CreateRoycoUSDMerkleRoot --rpc-url $PLUME_RPC_URL
 */
contract CreateRoycoUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    // RoycoUSD vault addresses
    address public boringVault = 0x74D1fAfa4e0163b2f1035F1b052137F3f9baD5cC;
    address public managerAddress = 0xD4F870516a3B67b64238Bb803392Cd1A52D54Fb2;
    address public accountantAddress = 0x80f0B206B7E5dAa1b1ba4ea1478A33241ee6baC9;
    address public tellerAddress = 0x60EBb5d1454Bb99aa35F63F609E79179b342B0b8;
    address public rawDataDecoderAndSanitizer = 0x716050EDC96fBB8b61d27dd830Ea9055558F7e44; 

    // RoycoPlumeUSDC vault for depositing
    address public roycoPlumeUSDCVault = 0x83A6F6034ee44De6648B1885e24D837D8D98698f;
    address public roycoPlumeUSDCTeller = 0x4Fc294112fD0b7226ecA095FEE9909E30882Cb11;

    function setUp() external {
        vm.createSelectFork("plume");
    }

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateRoycoUSDStrategistMerkleRoot();
    }

    function generateRoycoUSDStrategistMerkleRoot() public {
        setSourceChainName(plume);
        setAddress(false, plume, "boringVault", boringVault);
        setAddress(false, plume, "managerAddress", managerAddress);
        setAddress(false, plume, "accountantAddress", accountantAddress);
        setAddress(false, plume, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, plume, "tellerAddress", tellerAddress);
        setAddress(false, plume, "roycoPlumeUSDCVault", roycoPlumeUSDCVault);
        setAddress(false, plume, "roycoPlumeUSDCTeller", roycoPlumeUSDCTeller);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "plumeToken");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true);

        // ========================== Teller Deposits/Withdrawals ==========================
        ERC20[] memory tellerAssets = new ERC20[](1);
        tellerAssets[0] = getERC20(sourceChain, "USDC");
        _addTellerLeafs(leafs, tellerAddress, tellerAssets, false, true);

        // ========================== Bridging USDC to Mainnet ==========================
        // Add LayerZero bridging functionality for USDC to Mainnet
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDC"), getAddress(sourceChain, "USDC"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== Depositing into RoycoPlumeUSDC Vault ==========================
        // Add Teller functionality to deposit/withdraw from RoycoPlumeUSDC vault
        ERC20[] memory roycoPlumeAssets = new ERC20[](1);
        roycoPlumeAssets[0] = getERC20(sourceChain, "USDC");
        _addTellerLeafs(leafs, roycoPlumeUSDCTeller, roycoPlumeAssets, false, true);

        // ========================== Royco Functions ==========================
        // Add claimRewards and distributeRewards functionality for RoycoPlumeUSDC vault
        _addBoringChefClaimLeaf(leafs, roycoPlumeUSDCVault);

        // Add distributeRewards functionality
        {
            address[] memory rewardsTokens = new address[](1);
            rewardsTokens[0] = getAddress(sourceChain, "plumeToken");

            _addBoringChefApproveRewardsLeafs(
                leafs,
                roycoPlumeUSDCVault,
                rewardsTokens
            );

            _addBoringChefDistributeRewardsLeaf(
                leafs,
                roycoPlumeUSDCVault,
                rewardsTokens
            );
        }

        // ========================== Royco Recipe Markets ==========================
        // Add support for Royco recipe markets with USDC as input token
        bytes32[] memory marketHashes = new bytes32[](5);
        marketHashes[0] = 0x85c3ab928fdf01f9f53d4a776a9cdd9ab34d6e48a4ac2a111471f4425d5ce04c; 
        marketHashes[1] = 0xd7b4af5225fb14fc0f0f7e068faaa03c3d1530f695b60187f74ed7a0e259fa10; 
        marketHashes[2] = 0xf89bda68469012ebe5eecbdb60f3b0be88348cb4aa275af40c22f62c1326a773; 
        marketHashes[3] = 0x65734bff78f3adcf98f5dddfe4eb8d86782a4434f3e675131b3c7af0a918bfa4; 
        marketHashes[4] = 0x579faf40ca0f509b535552cf032c6b24030fa2c4b3e69f269f6c9520a7fffb1b; 

        address[] memory incentivesRequested = new address[](1);
        incentivesRequested[0] = getAddress(sourceChain, "plumeToken");

        address frontendFeeRecipient = 0x169C8c63aaC6433be8fdFE4AA116286329226E0a;

        // Add Royco market support for each market with USDC
        for (uint i = 0; i < marketHashes.length; i++) {
            _addRoycoRecipeAPOfferLeafs(leafs, getAddress(sourceChain, "USDC"), marketHashes[i], address(0), incentivesRequested);
            _addRoycoWeirollLeafs(leafs, getERC20(sourceChain, "USDC"), marketHashes[i], frontendFeeRecipient);
        }

        // ========================== Royco Vault Markets ==========================
        // Add vault market support for RoycoPlumeUSDC vault
        address[] memory vaultMarketTargets = new address[](1);
        vaultMarketTargets[0] = getAddress(sourceChain, "plumeToken");
        _addRoycoVaultMarketLeafs(leafs, getAddress(sourceChain, "USDC"), roycoPlumeUSDCVault, address(0), vaultMarketTargets);

        // ========================== Additional ERC20 Approvals ==========================
        // Add approvals for USDC to various contracts that might need it
        address[] memory additionalApproveTargets = new address[](2);
        additionalApproveTargets[0] = getAddress(sourceChain, "recipeMarketHub");
        additionalApproveTargets[1] = getAddress(sourceChain, "vaultMarketHub");
        
        for (uint i = 0; i < additionalApproveTargets.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "USDC"),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve ", "USDC", " to ", Strings.toHexString(additionalApproveTargets[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = additionalApproveTargets[i];
        }

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/plume/RoycoUSDStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
