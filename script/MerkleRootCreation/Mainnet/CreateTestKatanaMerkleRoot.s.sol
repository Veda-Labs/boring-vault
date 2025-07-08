// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateTestKatanaMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateTestKatanaMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x00007EDa736C6CdF973BDefF2191bbCfE6175db7;
    address public rawDataDecoderAndSanitizer = 0x770B3AAA48096b3fB36876b8dD55789372775bf0;
    address public managerAddress = 0x999999e868Fb298c6EDbf0060f7cE077f01ad782;
    address public accountantAddress = 0x5555559e499d2107aBb035a5feA1235b7f942E6D;

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
        address[] memory assets = new address[](4);
        SwapKind[] memory kind = new SwapKind[](4);
        assets[0] = getAddress(sourceChain, "WETH");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "WEETH");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "EETH");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "WSTETH");
        kind[3] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);
        _addOdosSwapLeafs(leafs, assets, kind);

        // ========================== NativeWrapper ==========================
        _addNativeLeafs(leafs);

        // ========================== Lido ==========================
        _addLidoLeafs(leafs);

        // ========================== EtherFi ==========================
        _addEtherFiLeafs(leafs);

        // ========================== AtomicQueue ==========================
        _addAtomicQueueLeafs(leafs, 0xD45884B592E316eB816199615A95C182F75dea07, getERC20(sourceChain, "liquidMove"), getERC20(sourceChain, "WETH"));
        _addAtomicQueueLeafs(leafs, 0xD45884B592E316eB816199615A95C182F75dea07, getERC20(sourceChain, "liquidMove"), getERC20(sourceChain, "WEETH"));
        _addAtomicQueueLeafs(leafs, 0xD45884B592E316eB816199615A95C182F75dea07, getERC20(sourceChain, "liquidMove"), getERC20(sourceChain, "EETH"));
        
        // ========================== Teller ==========================
        ERC20[] memory liquidMoveAssets = new ERC20[](3);
        liquidMoveAssets[0] = getERC20(sourceChain, "WETH");
        liquidMoveAssets[1] = getERC20(sourceChain, "WEETH");
        liquidMoveAssets[2] = getERC20(sourceChain, "EETH");
        _addTellerLeafs(leafs, 0x63ede83cbB1c8D90bA52E9497e6C1226a673e884, liquidMoveAssets, false, true);

        // ========================== vbVault ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "vbETH")));

        // ========================== Agglayer ==========================
        _addAgglayerTokenLeafs(
            leafs,
            getAddress(sourceChain, "agglayerBridgeKatana"),
            getAddress(sourceChain, "vbETH"),
            0,
            20
        );
        _addAgglayerTokenLeafs(
            leafs,
            getAddress(sourceChain, "agglayerBridgeKatana"),
            getAddress(sourceChain, "WEETH"),
            0,
            20
        );

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "WETH");
        feeAssets[1] = getERC20(sourceChain, "WEETH");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);


        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/TestKatanaMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
