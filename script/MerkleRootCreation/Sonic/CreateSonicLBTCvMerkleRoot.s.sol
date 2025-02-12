// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLombardMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateSonicLBTCvMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x309f25d839A2fe225E80210e110C99150Db98AAF;
    address public rawDataDecoderAndSanitizer = 0x30e9601Fc65f12360A92f5bFebE133662A7E49Cb;
    address public managerAddress = 0x9D828035dd3C95452D4124870C110E7866ea6bb7;
    address public accountantAddress = 0x0639e239E417Ab9D1f0f926Fd738a012153930A7;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateSonicLBTCvStrategistMerkleRoot();
    }

    function generateSonicLBTCvStrategistMerkleRoot() public {
        setSourceChainName(sonicMainnet);
        setAddress(false, sonicMainnet, "boringVault", boringVault);
        setAddress(false, sonicMainnet, "managerAddress", managerAddress);
        setAddress(false, sonicMainnet, "accountantAddress", accountantAddress);
        setAddress(false, sonicMainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        leafIndex = type(uint256).max;

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "LBTC");
        feeAssets[1] = getERC20(sourceChain, "eBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true);

        // ========================== BoringVaults ==========================
        {
            ERC20[] memory eBTCTellerAssets = new ERC20[](1);
            eBTCTellerAssets[0] = getERC20(sourceChain, "LBTC");
            address eBTCTeller = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268;
            _addTellerLeafs(leafs, eBTCTeller, eBTCTellerAssets, false);

            ERC20[] memory sonicBTCTellerAssets = new ERC20[](2); 
            sonicBTCTellerAssets[0] = getERC20(sourceChain, "LBTC"); 
            sonicBTCTellerAssets[1] = getERC20(sourceChain, "eBTC");
            address sonicBTCTeller = 0xAce7DEFe3b94554f0704d8d00F69F273A0cFf079;
            _addTellerLeafs(leafs, sonicBTCTeller, sonicBTCTellerAssets, false);
        }

        // ========================== LayerZero ==========================
        address LBTCOFTAdapter = 0x630e12D53D4E041b8C5451aD035Ea841E08391d7;
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "LBTC"), LBTCOFTAdapter, layerZeroMainnetEndpointId
        );

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Sonic/SonicLBTCvStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}