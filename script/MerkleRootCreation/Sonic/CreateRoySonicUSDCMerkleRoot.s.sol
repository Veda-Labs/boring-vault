pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Sonic/CreateRoySonicUSDCMerkleRoot.s.sol:CreateRoySonicUSDCMerkleRoot --rpc-url $SONIC_MAINNET_RPC_URL
 */
contract CreateRoySonicUSDCMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x45088fb2FfEBFDcf4dFf7b7201bfA4Cd2077c30E;
    address public managerAddress = 0x0413986C24A254191c2D3fA8F0661789DE9B073B;
    address public accountantAddress = 0x8301294E84cA5a2644E7F3CD47A86369F1b0416e;
    address public rawDataDecoderAndSanitizer = 0xe4B958cc989EB9Bb47179D406279767b675e33FC;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateSonicNativeStrategistMerkleRoot();
    }

    function generateSonicNativeStrategistMerkleRoot() public {
        setSourceChainName(sonicMainnet);
        setAddress(false, sonicMainnet, "boringVault", boringVault);
        setAddress(false, sonicMainnet, "managerAddress", managerAddress);
        setAddress(false, sonicMainnet, "accountantAddress", accountantAddress);
        setAddress(false, sonicMainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true); //add yield claiming

         // ========================== Odos ==========================
         address[] memory tokens = new address[](1);
         SwapKind[] memory kind = new SwapKind[](1);
         tokens[0] = getAddress(sourceChain, "USDC");
         kind[0] = SwapKind.BuyAndSell;

         _addOdosSwapLeafs(leafs, tokens, kind);

        // ========================== Royco ==========================
        bytes32 marketHash0 = 0x7d1f2a66eabf9142dd30d1355efcbfd4cfbefd2872d24ca9855641434816a525;
        bytes32 marketHash1 = 0x4db7f85fc602e994e4043b98abecfeda8acab06bcc186ab266a07a508c8fc92f;

        address[] memory incentivesRequested0 = new address[](1);
        incentivesRequested0[0] = 0x5e75334F4270FfE07a80b28FC831BfAb2d83706e; //RP Points Wrapper Token

        address[] memory incentivesRequested1 = new address[](1);
        incentivesRequested1[0] = 0xD152f4C29fB0db011c8a5503Aee3Ce60C44F8985; //SJP Points Wrapper Token
        
        _addRoycoRecipeAPOfferLeafs(leafs, getAddress(sonicMainnet, "USDC"), marketHash0, address(0), incentivesRequested0);
        _addRoycoRecipeAPOfferLeafs(leafs, getAddress(sonicMainnet, "USDC"), marketHash1, address(0), incentivesRequested1);
        
        address frontendFeeRecipient = 0x169C8c63aaC6433be8fdFE4AA116286329226E0a;
        
        _addRoycoWeirollLeafs(leafs, getERC20(sonicMainnet, "USDC"), marketHash0, frontendFeeRecipient);
        _addRoycoWeirollLeafs(leafs, getERC20(sonicMainnet, "USDC"), marketHash1, frontendFeeRecipient);

        // ========================== BoringChef ==========================
        address[] memory allRewardsTokens = new address[](2);
        allRewardsTokens[0] = 0x5e75334F4270FfE07a80b28FC831BfAb2d83706e; //RP Points Wrapper Token
        allRewardsTokens[1] = 0xD152f4C29fB0db011c8a5503Aee3Ce60C44F8985; //SJP Points Wrapper Token

        address[] memory rewardsTokensCombo0 = new address[](1);
        rewardsTokensCombo0[0] = 0x5e75334F4270FfE07a80b28FC831BfAb2d83706e; //RP Points Wrapper Token

        address[] memory rewardsTokensCombo1 = new address[](1);
        rewardsTokensCombo1[0] = 0xD152f4C29fB0db011c8a5503Aee3Ce60C44F8985; //SJP Points Wrapper Token

        _addBoringChefApproveRewardsLeafs(
            leafs,
            boringVault,
            allRewardsTokens
        );

        _addBoringChefDistributeRewardsLeaf(
            leafs,
            boringVault,
            allRewardsTokens
        );
        _addBoringChefDistributeRewardsLeaf(
            leafs,
            boringVault,
            rewardsTokensCombo0
        );
        _addBoringChefDistributeRewardsLeaf(
            leafs,
            boringVault,
            rewardsTokensCombo1
        );

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Sonic/RoySonicUSDCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
