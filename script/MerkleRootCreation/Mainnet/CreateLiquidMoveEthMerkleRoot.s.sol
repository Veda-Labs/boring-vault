// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";
/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidMoveEthMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */

contract CreateLiquidMoveEthMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xca8711dAF13D852ED2121E4bE3894Dae366039E4;
    address public managerAddress = 0xb12FfF6512712ea3b30EeAB6F9dEA2fe903cA6ab;
    address public accountantAddress = 0xb53244f7716dC83811C8fB1a91971dC188C1C5aA;
    address public rawDataDecoderAndSanitizer = 0xB6e56b6c8f0BC8DD2B266554629100BB3BAB323D;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidMoveEthStrategistMerkleRoot();
    }

    function generateLiquidMoveEthStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== 1inch ==========================
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

        //Verify

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/LiquidMoveEthStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
