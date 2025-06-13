// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreatePlasmaUSDMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreatePlasmaUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0xd1074E0AE85610dDBA0147e29eBe0D8E5873a000;
    address public rawDataDecoderAndSanitizer = 0x13b65C19F43d6c3cfB7BB2a9c7F019Fcba20d2e8;
    address public managerAddress = 0xbFD60C2D4C1eee3307a2317529183e8045d0D7F3;
    address public accountantAddress = 0x737f2522d09E58a3Ea9dcCFDB127dD0dF5eB3F18;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](4);
        supplyAssets[0] = getERC20(sourceChain, "USDC");
        supplyAssets[1] = getERC20(sourceChain, "DAI");
        supplyAssets[2] = getERC20(sourceChain, "USDT");
        supplyAssets[3] = getERC20(sourceChain, "USDS");
        ERC20[] memory borrowAssets = new ERC20[](0);
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== Sky Money ==========================
        _addSkyDaiConverterLeafs(leafs);

        // ========================== sUSDs ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sUSDs")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sDAI")));

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/PlasmaUSDMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
