// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateTurtleTacUSDMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateTurtleTacUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x699e04F98dE2Fc395a7dcBf36B48EC837A976490;
    address public rawDataDecoderAndSanitizer = 0x06b568723851a745fF7F6bf71924560A95229872;
    address public managerAddress = 0x2FA91E4eb6Ace724EfFbDD61bBC1B55EF8bD7aAc; 
    address public accountantAddress = 0x58cD5e97ffaeA62986C86ac44bB8EF7092c7ff5B;
    

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

        ManageLeaf[] memory leafs = new ManageLeaf[](128);


        // ========================== 1inch ==========================
        address[] memory assets = new address[](5);
        SwapKind[] memory kind = new SwapKind[](5);
        assets[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "USDT");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "DAI");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "sUSDS");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "USDS");
        kind[4] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Odos ==========================
        _addOdosSwapLeafs(leafs, assets, kind);  

        // ========================== Sky Money ==========================
        _addAllSkyMoneyLeafs(leafs);  

        // ========================== sUSDs ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sUSDs")));

        // ========================== Aave ==========================
        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "USDT");

        ERC20[] memory borrowAssets = new ERC20[](1);
        borrowAssets[0] = getERC20(sourceChain, "USDC");

        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== LayerZero ==========================
        // tacUSD
        bytes32 moveAddressInBytes = 0xaa039f027468929ecf1c2beac924c8a6dee030ea4b05d3c514d40376f703686a; // same as EQCqA58CdGiSns8cK-rJJMim3uAw6ksF08UU1AN29wNoagZt
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDT"), getAddress(sourceChain, "USDTOFTAdapter2"), layerZeroTONEndpointId, moveAddressInBytes);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);
        console.log("leafs length: %s", leafs.length);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/TurtleTacUSDStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }

}
