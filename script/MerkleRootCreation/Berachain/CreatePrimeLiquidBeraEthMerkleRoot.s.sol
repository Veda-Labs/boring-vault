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
 *  source .env && forge script script/MerkleRootCreation/Berachain/CreatePrimeLiquidBeraEthMerkleRoot.s.sol:CreatePrimeLiquidBeraEthMerkleRoot --rpc-url $BERA_CHAIN_RPC_URL
 */
contract CreatePrimeLiquidBeraEthMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xB83742330443f7413DBD2aBdfc046dB0474a944e; 
    address public managerAddress = 0x58d32BCfa335B1EE9E25A291408409ceA890Be6b; 
    address public accountantAddress = 0x0B24A469d7c155a588C8a4ee24020F9f27090B0d;
    address public rawDataDecoderAndSanitizer = 0x661B04bF5C0D66F8D923fEC2FCD0C9b20C96c150;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](128);
        
        // ========================== Kodiak Swaps ==========================
        
        address[] memory token0 = new address[](3);  
        token0[0] = getAddress(sourceChain, "WETH");    
        token0[1] = getAddress(sourceChain, "WETH");    
        token0[2] = getAddress(sourceChain, "beraETH");    

        address[] memory token1 = new address[](3);  
        token1[0] = getAddress(sourceChain, "WEETH");    
        token1[1] = getAddress(sourceChain, "beraETH"); 
        token1[2] = getAddress(sourceChain, "WEETH");   
        
        _addUniswapV3Leafs(leafs, token0, token1, false); 

        // ========================== Kodiak Islands ==========================
        
        address[] memory islands = new address[](4);  
        islands[0] = getAddress(sourceChain, "kodiak_island_WETH_WEETH_005%"); 
        islands[1] = getAddress(sourceChain, "kodiak_island_WETH_beraETH_005%"); 
        islands[2] = getAddress(sourceChain, "kodiak_island_WEETH_WEETH_OT_005%"); 
        islands[3] = getAddress(sourceChain, "kodiak_island_beraETH_WEETH_005%"); 

        _addKodiakIslandLeafs(leafs, islands, false); //don't include native leaves

        // ========================== Dolomite Supply ==========================
        
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "WETH"), false);          
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "WEETH"), false);          

        // ========================== Dolomite Borrow ==========================
        
        _addDolomiteBorrowLeafs(leafs, getAddress(sourceChain, "WETH"));
        _addDolomiteBorrowLeafs(leafs, getAddress(sourceChain, "WEETH"));

        // ========================== dTokens ==========================
        
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "dWETH")));   
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "dWEETH")));   

        // ========================== Goldilocks ==========================

        address[] memory vaults = new address[](1); 
        vaults[0] = getAddress(sourceChain, "goldivault_weETH"); 

        _addGoldiVaultLeafs(leafs, vaults); 

        // ========================== beraETH ==========================
        _addBeraETHLeafs(leafs); 

        // ========================== Etherfi ==========================
        _addWeETHLeafs(leafs, getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"));  

        // ========================== Ooga Booga ==========================
        address[] memory assets = new address[](5); 
        SwapKind[] memory kind = new SwapKind[](5); 
        assets[0] = getAddress(sourceChain, "iBGT"); 
        kind[0] = SwapKind.Sell; 
        assets[1] = getAddress(sourceChain, "WETH"); 
        kind[1] = SwapKind.BuyAndSell; 
        assets[2] = getAddress(sourceChain, "WEETH"); 
        kind[2] = SwapKind.BuyAndSell; 
        assets[3] = getAddress(sourceChain, "beraETH"); 
        kind[3] = SwapKind.BuyAndSell; 
        assets[4] = getAddress(sourceChain, "BGT"); //just in case
        kind[4] = SwapKind.Sell; 
        
        _addOogaBoogaSwapLeafs(leafs, assets, kind); 

        // ========================== Infrared ==========================
        _addInfraredVaultLeafs(leafs, getAddress(sourceChain, "infrared_vault_weth_weeth")); 

        // ========================== Verify ==========================
        
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Berachain/PrimeLiquidBeraEth.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
