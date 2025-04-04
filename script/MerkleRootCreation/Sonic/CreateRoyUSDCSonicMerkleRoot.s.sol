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

    address public boringVault = 0x74D1fAfa4e0163b2f1035F1b052137F3f9baD5cC;
    address public managerAddress = 0xD4F870516a3B67b64238Bb803392Cd1A52D54Fb2;
    address public accountantAddress = 0x80f0B206B7E5dAa1b1ba4ea1478A33241ee6baC9;
    address public rawDataDecoderAndSanitizer = 0x9Ab7Fce3C2B0B409DC79706367659C1bd512F44d;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateMetaVaultSonicStrategistMerkleRoot();
    }

    function generateMetaVaultSonicStrategistMerkleRoot() public {
        setSourceChainName(sonicMainnet);
        setAddress(false, sonicMainnet, "boringVault", boringVault);
        setAddress(false, sonicMainnet, "managerAddress", managerAddress);
        setAddress(false, sonicMainnet, "accountantAddress", accountantAddress);
        setAddress(false, sonicMainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== SonicGateway ==========================
        address[] memory mainnetAssets = new address[](1);
        address[] memory sonicAssets = new address[](1);
        mainnetAssets[0] = getAddress(mainnet, "USDC"); //NOTE: this needs to be mainnet USDC
        sonicAssets[0] = getAddress(sonicMainnet, "USDC");
        _addSonicGatewayLeafsSonic(leafs, mainnetAssets, sonicAssets);

        // ========================== LayerZero ========================== //Using Stargate USDC Pool As OFT
        _addLayerZeroLeafs(leafs, getERC20(sonicMainnet, "USDC"), getAddress(sonicMainnet, "stargateUSDC"), layerZeroMainnetEndpointId);

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

        // ========================== Teller ==========================
    
        ERC20[] memory tellerTokens = new ERC20[](1);
        tellerTokens[0] = getERC20(sourceChain, "USDC");

        _addTellerLeafs(leafs, getAddress(sourceChain, "roysonicUSDCTeller"), tellerTokens, false, true);
        _addWithdrawQueueLeafs(
            leafs, getAddress(sourceChain, "roysonicUSDCQueue"), getAddress(sourceChain, "roysonicUSDC"), tellerTokens
        );

        // ========================== BoringChef ==========================
        _addBoringChefClaimLeaf(leafs, getAddress(sourceChain, "roysonicUSDC"));

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Sonic/RoyUSDCSonicStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
