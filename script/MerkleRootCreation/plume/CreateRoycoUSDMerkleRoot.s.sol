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

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true);

        // ========================== Bridging USDC to Mainnet ==========================
        // Add LayerZero bridging functionality for USDC to Mainnet
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDC"), getAddress(sourceChain, "stargateUSDC"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));

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

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/plume/RoycoUSDStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
