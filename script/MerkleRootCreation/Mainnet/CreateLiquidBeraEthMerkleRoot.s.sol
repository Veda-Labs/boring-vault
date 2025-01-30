// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidBeraEthMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */

contract CreateLiquidBeraEthMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x83599937c2C9bEA0E0E8ac096c6f32e86486b410;
    address public managerAddress = 0x62b283d4FeFB2a120e1120dba9f83bE6CA41bCD7;
    address public accountantAddress = 0x04B8136820598A4e50bEe21b8b6a23fE25Df9Bd8;
    address public rawDataDecoderAndSanitizer = 0xf7301C2A56510814B88b024d7066b6B62acC704D;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidBeraEthStrategistMerkleRoot();
    }

    function generateLiquidBeraEthStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== Lido ==========================
        address[] memory assets = new address[](5);
        SwapKind[] memory kind = new SwapKind[](5);
        assets[0] = getAddress(sourceChain, "WETH");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "WEETH");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "EETH");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "STETH");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "WSTETH");
        kind[4] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Lido ==========================
        _addLidoLeafs(leafs);

        // ========================== EtherFi ==========================
        /**
         * stake, unstake, wrap, unwrap
         */
        _addEtherFiLeafs(leafs);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        
        // ========================== Royco ==========================
        {
            
        bytes32 wethMarketHash = 0x0484203315d701daff0d6dbdd55c49c3f220c3c7b917892bed1badb8fdc0182e; 
        address roycoFrontEndFeeRecipientTemp = 0x303907c6991B9058AB4aBd18B9c57B611FB81103; //this is what is used when there is no fee, I think, but waiting on confirmation from royco team on if they need us to use something specific  
        _addRoycoWeirollLeafs(leafs, getERC20(sourceChain, "WETH"), wethMarketHash, roycoFrontEndFeeRecipientTemp);  


        bytes32 weethMarketHash = 0xff0182973d5f1e9a64392c413caaa75f364f24632a7de0fdd1a31fe30517fdd2; 
        _addRoycoWeirollLeafs(leafs, getERC20(sourceChain, "WEETH"), weethMarketHash, roycoFrontEndFeeRecipientTemp);  
        
        }

        //Verify

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/LiquidBeraEthStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
