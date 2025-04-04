pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateRoyUSDCMainnetMerkleRoot.s.sol:CreateRoyUSDCMainnetMerkleRoot --rpc-url $MAINNET_RPC_URL
 */
contract CreateRoyUSDCMainnetMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;
    // TODO: CHECK the addresses
    address public boringVault = 0x74D1fAfa4e0163b2f1035F1b052137F3f9baD5cC;
    address public managerAddress = 0xD4F870516a3B67b64238Bb803392Cd1A52D54Fb2;
    address public accountantAddress = 0x80f0B206B7E5dAa1b1ba4ea1478A33241ee6baC9;
    address public rawDataDecoderAndSanitizer = 0x1a72667f90c33a2112C323f7a3484Efc1aE7e198;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateMetaVaultMainnetStrategistMerkleRoot();
    }

    function generateMetaVaultMainnetStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // ========================== SonicGateway ==========================
        ERC20[] memory mainnetAssets = new ERC20[](1);
        //address[] memory sonicAssets = new address[](1);
        mainnetAssets[0] = getERC20(mainnet, "USDC");
        //sonicAssets[0] = getAddress(sonicMainnet, "USDC");
        _addSonicGatewayLeafsEth(leafs, mainnetAssets);

        // ========================== LayerZero ========================== // Using stargate pool as OFT
        _addLayerZeroLeafs(leafs, getERC20(mainnet, "USDC"), getAddress(mainnet, "stargateUSDC"), layerZeroSonicMainnetEndpointId);

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

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/RoyUSDCMainnetStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
