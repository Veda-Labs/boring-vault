// SPDX-License-Identifier: SEL-1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateSentayETHMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateSentayETHMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf15351A0d66743E09457C45EaE88dF34FcEe8CB7;
    address public managerAddress = 0xA44Ce1EAb82f99B3dc530734b9DcEaf14E7F2Af7;
    address public accountantAddress = 0xE803d9283450189f168c825AC462dfe035345114;
    address public rawDataDecoderAndSanitizer = 0x1f7dbFA46d7d150AEF6D3c8044C5c32aC71c0b6f;
    address public itbDecoderAndSanitizer = 0x51cDDE815429fb7Bce964601774018eA0Cc119f7;

    address public odosOwnedDecoderAndSanitizer = 0x6149c711434C54A48D757078EfbE0E2B2FE2cF6a;
    address public oneInchOwnedDecoderAndSanitizer = 0x42842201E199E6328ADBB98e7C2CbE77561FAC88;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== Native ==========================
        _addNativeLeafs(leafs);

        // ========================== Staking ==========================
        _addLidoLeafs(leafs);
        _addEtherFiLeafs(leafs);

        // ========================== OneInch/Odos  ==========================

        address[] memory assets = new address[](3);
        assets[0] = getAddress(sourceChain, "WETH");
        assets[1] = getAddress(sourceChain, "WSTETH");
        assets[2] = getAddress(sourceChain, "WEETH");
        SwapKind[] memory kind = new SwapKind[](3);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;
        kind[2] = SwapKind.BuyAndSell;

        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", oneInchOwnedDecoderAndSanitizer);
        _addLeafsFor1InchOwnedGeneralSwapping(leafs, assets, kind);
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", odosOwnedDecoderAndSanitizer);
        _addOdosOwnedSwapLeafs(leafs, assets, kind);
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        // ========================== SuperBridge ==========================
        
        {
            ERC20[] memory inkLocalTokens = new ERC20[](0);
            ERC20[] memory inkRemoteTokens = new ERC20[](0);

            _addStandardBridgeLeafs(
                leafs,
                ink,
                getAddress(ink, "crossDomainMessenger"),
                getAddress(sourceChain, "inkResolvedDelegate"),
                getAddress(sourceChain, "inkStandardBridge"),
                getAddress(sourceChain, "inkPortal"),
                inkLocalTokens,
                inkRemoteTokens
            );
        }

        // ========================== LayerZero ==========================
        
        _addLayerZeroLeafs(leafs, ERC20(getAddress(sourceChain, "WEETH")), getAddress(sourceChain, "EtherFiOFTAdapter"), layerZeroInkEndpointId, getBytes32(sourceChain, "boringVault"));

        // ============================ ITB ============================
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", itbDecoderAndSanitizer);
        {
            address weethSupervisedLoanPositionManager = 0x2A607b663cA63b8378666daa7fB251b24E43Ee70;
            ERC20[] memory tokensUsed = new ERC20[](2);
            tokensUsed[0] = getERC20(sourceChain, "WEETH");
            tokensUsed[1] = getERC20(sourceChain, "PYUSD");
            _addLeafsForITBPositionManager(leafs, weethSupervisedLoanPositionManager, tokensUsed, "WEETH/PYUSD Supervised Loan Position Manager");
        }
        {
            address weethPositionManager = 0x765fD4ea8792c91C9a8483EA04a577EDED229c89;
            ERC20[] memory tokensUsed = new ERC20[](2);
            tokensUsed[0] = getERC20(sourceChain, "WEETH");
            tokensUsed[1] = getERC20(sourceChain, "WETH");
            _addLeafsForITBPositionManager(leafs, weethPositionManager, tokensUsed, "WEETH/ETH Position Manager");
        }

        // ========================== Verification ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/SentayETHStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
