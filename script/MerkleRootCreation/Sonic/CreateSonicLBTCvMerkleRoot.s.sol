// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Sonic/CreateSonicLBTCvMerkleRoot.s.sol --rpc-url $SONIC_MAINNET_RPC_URL
 */
contract CreateSonicLBTCvMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x309f25d839A2fe225E80210e110C99150Db98AAF;
    address public rawDataDecoderAndSanitizer = 0xE9527EA95a383993b41EA7D3b0E50DDA7B13dE94;
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

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "LBTC");
        feeAssets[1] = getERC20(sourceChain, "EBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true);


        // ========================== BoringVaults ==========================
        {
            ERC20[] memory eBTCTellerAssets = new ERC20[](2);
            eBTCTellerAssets[0] = getERC20(sourceChain, "LBTC");
            eBTCTellerAssets[1] = getERC20(sourceChain, "WBTC");
            address eBTCTeller = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268;
            _addTellerLeafs(leafs, eBTCTeller, eBTCTellerAssets, false, true);

            ERC20[] memory sonicBTCTellerAssets = new ERC20[](3); 
            sonicBTCTellerAssets[0] = getERC20(sourceChain, "LBTC"); 
            sonicBTCTellerAssets[1] = getERC20(sourceChain, "EBTC");
            sonicBTCTellerAssets[2] = getERC20(sourceChain, "WBTC");

            address[] memory sonicBTCTellerAssetsAddresses = new address[](3);
            sonicBTCTellerAssetsAddresses[0] = getAddress(sourceChain, "LBTC");
            sonicBTCTellerAssetsAddresses[1] = getAddress(sourceChain, "EBTC");
            sonicBTCTellerAssetsAddresses[2] = getAddress(sourceChain, "WBTC");

            address[] memory _feeAssets = new address[](1); 
            _feeAssets[0] = getAddress(sourceChain, "ETH");

            address sonicBTCTeller = 0xAce7DEFe3b94554f0704d8d00F69F273A0cFf079;
            address scBTC = 0xBb30e76d9Bb2CC9631F7fC5Eb8e87B5Aff32bFbd; 
            address scBTCWithdrawQueue = 0x488000E6a0CfC32DCB3f37115e759aF50F55b48B; 
            _addTellerLeafs(leafs, sonicBTCTeller, sonicBTCTellerAssets, false, false);
            _addWithdrawQueueLeafs(leafs, scBTCWithdrawQueue, scBTC, sonicBTCTellerAssets); 
            _addCrossChainTellerLeafs(leafs, sonicBTCTeller, sonicBTCTellerAssetsAddresses, _feeAssets, abi.encode(layerZeroMainnetEndpointId));


            ERC20[] memory stkscBTCTellerAssets = new ERC20[](1); 
            stkscBTCTellerAssets[0] = getERC20(sourceChain, "scBTC"); 
            address stkscBTCTeller = 0x825254012306bB410b550631895fe58DdCE1f4a9;
            address stkscBTC = 0xD0851030C94433C261B405fEcbf1DEC5E15948d0; 
            address stkscBTCWithdrawQueue = 0x6dF97Ed8B28d9528cd34335c0a151F10E48b6eF3; 
            _addTellerLeafs(leafs, stkscBTCTeller, stkscBTCTellerAssets, false, false);
            _addWithdrawQueueLeafs(leafs, stkscBTCWithdrawQueue, stkscBTC, stkscBTCTellerAssets); 
        }


        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WBTC"), getAddress(sourceChain, "WBTC"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault")
        );

        // ========================== CCIP ==========================
        bytes32 toChain = 0x0000000000000000000000000000000000000000000000000000000000000001; //mainnet
        _addLBTCBridgeLeafs(leafs, toChain);
        
        // ========================== Balancer/Beets ==========================
        _addBalancerLeafs(leafs, getBytes32(sourceChain, "scBTC_LBTC_PoolId"), getAddress(sourceChain, "scBTC_LBTC_gauge"));

        // ========================== Silo ==========================
        address[] memory incentivesControllers = new address[](2); 
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_LBTC_scBTC_id32_config"), incentivesControllers); 


        // ========================== Verify ==========================
       
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Sonic/SonicLBTCvStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
