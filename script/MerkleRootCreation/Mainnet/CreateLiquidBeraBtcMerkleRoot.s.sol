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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidBeraBtcMerkleRoot.s.sol:CreateLiquidBeraBtcMerkleRoot --rpc-url $MAINNET_RPC_URL
 */
contract CreateLiquidBeraBtcMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xC673ef7791724f0dcca38adB47Fbb3AEF3DB6C80;
    address public managerAddress = 0x603064caAf2e76C414C5f7b6667D118322d311E6;
    address public accountantAddress = 0xF44BD12956a0a87c2C20113DdFe1537A442526B5;
    address public rawDataDecoderAndSanitizer = 0xf7301C2A56510814B88b024d7066b6B62acC704D;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](4);
        SwapKind[] memory kind = new SwapKind[](4);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "LBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "cbBTC");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "eBTC");
        kind[3] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Teller ==========================
        address eBTCTellerLZ = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268;

        ERC20[] memory tellerAssets = new ERC20[](3);
        tellerAssets[0] = getERC20(sourceChain, "WBTC");
        tellerAssets[1] = getERC20(sourceChain, "LBTC");
        tellerAssets[2] = getERC20(sourceChain, "cbBTC");
        _addTellerLeafs(leafs, eBTCTellerLZ, tellerAssets);

        // ========================== Royco ==========================
        {

            bytes32 wbtcMarketHash = 0xb36f14fd392b9a1d6c3fabedb9a62a63d2067ca0ebeb63bbc2c93b11cc8eb3a2; 
            address roycoFrontEndFeeRecipientTemp = 0x303907c6991B9058AB4aBd18B9c57B611FB81103; //this is what is used when there is no fee, I think, but waiting on confirmation from royco team on if they need us to use something specific  
            _addRoycoWeirollLeafs(leafs, getERC20(sourceChain, "WBTC"), wbtcMarketHash, roycoFrontEndFeeRecipientTemp);  


            bytes32 lbtcMarketHash = 0xabf4b2f17bc32faf4c3295b1347f36d21ec5629128d465b5569e600bf8d46c4f; 
            _addRoycoWeirollLeafs(leafs, getERC20(sourceChain, "LBTC"), lbtcMarketHash, roycoFrontEndFeeRecipientTemp);  

        } 

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/LiquidBeraBtcStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
