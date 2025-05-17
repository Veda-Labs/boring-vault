pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Sonic/CreateRoyUSDCSonicMerkleRoot.s.sol:CreateRoyUSDCSonicMerkleRoot --rpc-url $SONIC_MAINNET_RPC_URL
 */
contract CreateRoyUSDCSonicMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = ;
    address public managerAddress = ;
    address public accountantAddress = ;
    address public rawDataDecoderAndSanitizer = ;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(plume); 
        setAddress(false, plume, "boringVault", boringVault);
        setAddress(false, plume, "managerAddress", managerAddress);
        setAddress(false, plume, "accountantAddress", accountantAddress);
        setAddress(false, plume, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true); //add yield claiming

        //Need a way to get pUSD
        //Need to enter all boring Vaults + withdraw
        //Need to get all lps  
        //Need to get AaveV3 fork tokens
        
        // ========================== BoringVaults ==========================
        _addTellerLeafs(leafs, getAddress(sourceChain, "pUSD"), 

        // ========================== Royco ==========================
        bytes32 marketHash0 = 0x85c3ab928fdf01f9f53d4a776a9cdd9ab34d6e48a4ac2a111471f4425d5ce04c; //nINSTO market
        bytes32 marketHash1 = 0xd7b4af5225fb14fc0f0f7e068faaa03c3d1530f695b60187f74ed7a0e259fa10; //nCREDIT market 
        bytes32 marketHash2 = 0xf89bda68469012ebe5eecbdb60f3b0be88348cb4aa275af40c22f62c1326a773; //op-nALPHA market
        bytes32 marketHash3 = 0x65734bff78f3adcf98f5dddfe4eb8d86782a4434f3e675131b3c7af0a918bfa4; //mystic pUSD lending
        bytes32 marketHash4 = 0x579faf40ca0f509b535552cf032c6b24030fa2c4b3e69f269f6c9520a7fffb1b; //solera pUSD lending 

        address[] memory incentivesRequested = new address[](1);
        incentivesRequested[0] = getAddress(sourceChain, "WPLUME"); 

        _addRoycoRecipeAPOfferLeafs(leafs, getAddress(sourceChain, "pUSD"), marketHash0, address(0), incentivesRequested0);

        address frontendFeeRecipient = 0x169C8c63aaC6433be8fdFE4AA116286329226E0a; 

        _addRoycoWeirollLeafs(leafs, getERC20(plume, "nINSTO"), marketHash0, frontendFeeRecipient);
        _addRoycoWeirollLeafs(leafs, getERC20(plume, "nCREDIT"), marketHash1, frontendFeeRecipient);
        _addRoycoWeirollLeafs(leafs, getERC20(plume, "op-nALPHA"), marketHash2, frontendFeeRecipient);
        _addRoycoWeirollLeafs(leafs, getERC20(plume, "pUSD"), marketHash3, frontendFeeRecipient);
        _addRoycoWeirollLeafs(leafs, getERC20(plume, "pUSD"), marketHash4, frontendFeeRecipient);

        // ========================== BoringChef ==========================
        address[] memory rewardsTokens = new address[](1);  
        rewardsTokens[0] = getAddress(sourceChain, "WPLUME"); 
 
        _addBoringChefApproveRewardsLeafs(
            leafs,
            boringVault,
            rewardsTokens
        );

        _addBoringChefDistributeRewardsLeaf(
            leafs,
            boringVault,
            rewardsTokens
        );

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Sonic/RoyUSDCSonicStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
