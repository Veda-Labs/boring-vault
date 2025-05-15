pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {SonicVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicVaultDecoderAndSanitizer.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Sonic/CreateSonicUSDMerkleRoot.s.sol:CreateSonicUSDMerkleRoot --rpc-url $SONIC_MAINNET_RPC_URL
 */
contract CreateSonicUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE;
    address public managerAddress = 0x76fda7A02B616070D3eC5902Fa3C5683AC3cB8B6;
    address public accountantAddress = 0xA76E0F54918E39A63904b51F688513043242a0BE;
    address public rawDataDecoderAndSanitizer = 0xf99Ee09014D2f1B5FEFC3874a186fc9C5aB180c1; 
    address public siloDecoderAndSanitizer;

    function setUp() external {
        // Déployer ou définir l'adresse du décodeur Silo
        siloDecoderAndSanitizer = address(new SonicVaultDecoderAndSanitizer(getAddress(sonicMainnet, "odosRouterV2")));
    }

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public { setSourceChainName(sonicMainnet);
        setAddress(false, sonicMainnet, "boringVault", boringVault);
        setAddress(false, sonicMainnet, "managerAddress", managerAddress);
        setAddress(false, sonicMainnet, "accountantAddress", accountantAddress);
        setAddress(false, sonicMainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sonicMainnet, "siloDecoderAndSanitizer", siloDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== SonicGateway ==========================
        address[] memory mainnetAssets = new address[](2);
        address[] memory sonicAssets = new address[](2);
        mainnetAssets[0] = getAddress(mainnet, "USDC"); //NOTE: this needs to be mainnet USDC
        mainnetAssets[1] = getAddress(mainnet, "USDT"); //NOTE: this needs to be mainnet USDC
        sonicAssets[0] = getAddress(sonicMainnet, "USDC");
        sonicAssets[1] = getAddress(sonicMainnet, "USDT");
        _addSonicGatewayLeafsSonic(leafs, mainnetAssets, sonicAssets);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true); //add yield claiming

        // ========================== AaveV3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](3);
        supplyAssets[0] = getERC20(sourceChain, "USDC");
        supplyAssets[1] = getERC20(sourceChain, "USDT");
        supplyAssets[2] = getERC20(sourceChain, "wS");
        ERC20[] memory borrowAssets = new ERC20[](0);
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== SiloV2 ==========================
        { 
        address[] memory incentivesControllers = new address[](2); 

        incentivesControllers[0] = getAddress(sourceChain, "silo_wS_USDC_id8_USDC_IncentivesController"); 
        incentivesControllers[1] = getAddress(sourceChain, "silo_wS_USDC_id8_wS_IncentivesController"); 
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_wS_USDC_id8_config"), incentivesControllers);

        incentivesControllers[0] = getAddress(sourceChain, "silo_wS_USDC_id20_USDC_IncentivesController"); 
        incentivesControllers[1] = address(0);  
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_wS_USDC_id20_config"), incentivesControllers);

        incentivesControllers[0] = getAddress(sourceChain, "silo_USDC_wstkscUSD_id23_USDC_IncentivesController"); 
        incentivesControllers[1] = address(0);  
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_USDC_wstkscUSD_id23_config"), incentivesControllers);

        }

        // ========================== Silo Vault ==========================
        // Utilisation temporaire du décoder spécifique pour Silo
        address originalDecoder = getAddress(sourceChain, "rawDataDecoderAndSanitizer");
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", getAddress(sourceChain, "siloDecoderAndSanitizer"));
        _addSiloVaultLeafs(leafs, getAddress(sourceChain, "silo_USDC_vault"));
        // Restauration du décoder original
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", originalDecoder);

         // ========================== Odos ==========================
         address[] memory tokens = new address[](5);
         SwapKind[] memory kind = new SwapKind[](5);
         tokens[0] = getAddress(sourceChain, "USDC");
         kind[0] = SwapKind.BuyAndSell; 
         tokens[1] = getAddress(sourceChain, "USDT");
         kind[1] = SwapKind.BuyAndSell; 
         tokens[2] = getAddress(sourceChain, "wS");
         kind[2] = SwapKind.BuyAndSell; 
         tokens[3] = getAddress(sourceChain, "awS");
         kind[3] = SwapKind.Sell; 
         tokens[4] = getAddress(sourceChain, "SILO");
         kind[4] = SwapKind.Sell; 

         _addOdosSwapLeafs(leafs, tokens, kind);

        // ========================== Merkl ==========================
        ERC20[] memory tokensToClaim = new ERC20[](2); 
        tokensToClaim[0] = getERC20(sourceChain, "wS"); 
        tokensToClaim[1] = getERC20(sourceChain, "awS"); 
        _addMerklLeafs(leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "dev1Address"), tokensToClaim);    

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "frxUSD"), getAddress(sourceChain, "frxUSD"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault")); 
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDC"), getAddress(sourceChain, "stargateUSDC"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault")); 

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "wS")); //to pay for bridge fees

         // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Sonic/SonicUSDStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
