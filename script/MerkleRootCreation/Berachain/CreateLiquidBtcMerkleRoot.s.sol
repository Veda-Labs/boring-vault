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
 *  source .env && forge script script/MerkleRootCreation/Berachain/CreateLiquidBtcMerkleRoot.s.sol:CreateLiquidBtcMerkleRoot --rpc-url $BERA_CHAIN_RPC_URL
 */
contract CreateLiquidBtcMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x5f46d540b6eD704C3c8789105F30E075AA900726; 
    address public managerAddress = 0xaFa8c08bedB2eC1bbEb64A7fFa44c604e7cca68d;
    address public accountantAddress = 0xEa23aC6D7D11f6b181d6B98174D334478ADAe6b0;
    address public rawDataDecoderAndSanitizer = 0x4Ab8cCC0412497D27fD1A982DECb76B9963f448C;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(berachain);
        setAddress(false, berachain, "boringVault", boringVault);
        setAddress(false, berachain, "managerAddress", managerAddress);
        setAddress(false, berachain, "accountantAddress", accountantAddress);
        setAddress(false, berachain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);
        

        // ========================== Kodiak Swaps ==========================

        address[] memory token0 = new address[](1);  
        token0[0] = getAddress(sourceChain, "WBTC");    

        address[] memory token1 = new address[](1);  
        token1[0] = getAddress(sourceChain, "solvBTC");    

        _addUniswapV3Leafs(leafs, token0, token1, false); 

        // ========================== Kodiak Islands ==========================

        address[] memory islands = new address[](2);  
        islands[0] = getAddress(sourceChain, "kodiak_island_WBTC_solvBTC_005%");
        islands[1] = getAddress(sourceChain, "kodiak_island_rUSD_HONEY_005%");

        _addKodiakIslandLeafs(leafs, islands); 

        // ========================== Dolomite Supply ==========================
        
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "srUSD"), false);
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "USDC"), false);
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "eBTC"), false); 
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "HONEY"), false);
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "rUSD"), false);
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "solvBTC"), false);
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "WBTC"), false);

        // ========================== Dolomite Borrow ==========================
        
        _addDolomiteBorrowLeafs(leafs, getAddress(sourceChain, "srUSD"));
        _addDolomiteBorrowLeafs(leafs, getAddress(sourceChain, "USDC"));
        _addDolomiteBorrowLeafs(leafs, getAddress(sourceChain, "HONEY"));
        _addDolomiteBorrowLeafs(leafs, getAddress(sourceChain, "rUSD"));
        _addDolomiteBorrowLeafs(leafs, getAddress(sourceChain, "eBTC"));
        _addDolomiteBorrowLeafs(leafs, getAddress(sourceChain, "solvBTC"));
        _addDolomiteBorrowLeafs(leafs, getAddress(sourceChain, "WBTC"));

        // ========================== Ooga Booga ==========================
        address[] memory assets = new address[](11);
        SwapKind[] memory kind = new SwapKind[](11);
        assets[0] = getAddress(sourceChain, "iBGT");
        kind[0] = SwapKind.Sell;
        assets[1] = getAddress(sourceChain, "WBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "solvBTC");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "BGT"); //just in case
        kind[3] = SwapKind.Sell;
        assets[4] = getAddress(sourceChain, "USDC");
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "srUSD");
        kind[5] = SwapKind.BuyAndSell;
        assets[6] = getAddress(sourceChain, "rUSD");
        kind[6] = SwapKind.BuyAndSell;
        assets[7] = getAddress(sourceChain, "eBTC");
        kind[7] = SwapKind.BuyAndSell;
        assets[8] = getAddress(sourceChain, "LBTC");
        kind[8] = SwapKind.BuyAndSell;
        assets[9] = getAddress(sourceChain, "HONEY");
        kind[9] = SwapKind.BuyAndSell;
        assets[10] = getAddress(sourceChain, "WBERA");
        kind[10] = SwapKind.Sell;

        _addOogaBoogaSwapLeafs(leafs, assets, kind);

        // ========================== Infrared ==========================
        _addInfraredVaultLeafs(leafs, getAddress(sourceChain, "infrared_vault_wbtc_solvbtc"));
        _addInfraredVaultLeafs(leafs, getAddress(sourceChain, "infrared_vault_rUSD_honey"));

        // ========================== LayerZero/Stargate ==========================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WBTC"), getAddress(sourceChain, "WBTC"), layerZeroMainnetEndpointId, bytes32(uint256(uint160(address(boringVault)))));   
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "solvBTC"), getAddress(sourceChain, "solvBTC_OFT"), layerZeroMainnetEndpointId, bytes32(uint256(uint160(address(boringVault)))));   
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "srUSD"), getAddress(sourceChain, "stargatesrUSD"), layerZeroMainnetEndpointId, bytes32(uint256(uint160(address(boringVault)))));   
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDC"), getAddress(sourceChain, "stargateUSDC"), layerZeroMainnetEndpointId, bytes32(uint256(uint160(address(boringVault)))));   

        // ========================== Honey ==========================
        _addHoneyLeafs(leafs);

        // ========================== Tellers ==========================
        ERC20[] memory eBTCAssets = new ERC20[](2);
        eBTCAssets[0] = getERC20(sourceChain, "WBTC");
        eBTCAssets[1] = getERC20(sourceChain, "LBTC");

        address[] memory eBTCAssetsAddresses = new address[](2);
        eBTCAssetsAddresses[0] = getAddress(sourceChain, "WBTC");
        eBTCAssetsAddresses[1] = getAddress(sourceChain, "LBTC");

        address[] memory feeAssets = new address[](1);
        feeAssets[0] = getAddress(sourceChain, "ETH");

        _addTellerLeafs(leafs, getAddress(sourceChain, "eBTCTeller"), eBTCAssets, false, true);
        _addWithdrawQueueLeafs(leafs, getAddress(sourceChain, "eBTCQueue"), getAddress(sourceChain, "eBTC"), eBTCAssets);
        _addCrossChainTellerLeafs(leafs, getAddress(sourceChain, "eBTCTeller"), eBTCAssetsAddresses, feeAssets, abi.encode(layerZeroMainnetEndpointId));

        // =============================== Native Wrapper ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WBERA"));

        // ========================== Verify ==========================
        
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Berachain/LiquidBtcStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
