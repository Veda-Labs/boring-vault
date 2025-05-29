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
 *  source .env && forge script script/MerkleRootCreation/Base/CreateLBTCvMerkleRoot.s.sol:CreateLBTCvMerkleRootScript --rpc-url $BASE_RPC_URL
 */
contract CreateLBTCvMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x5401b8620E5FB570064CA9114fd1e135fd77D57c;
    address public managerAddress = 0xcf38e37872748E3b66741A42560672A6cef75e9B;
    address public accountantAddress = 0x28634D0c5edC67CF2450E74deA49B90a4FF93dCE;
    address public rawDataDecoderAndSanitizer = 0x967678F9E5E5a439ee4938738a6aa7b0c873CCeb;
    address public aerodromeDecoderAndSanitizer = 0xD657c2A871C467871b59d5992CD3bAb1634dd457;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(base);
        setAddress(false, base, "boringVault", boringVault);
        setAddress(false, base, "managerAddress", managerAddress);
        setAddress(false, base, "accountantAddress", accountantAddress);
        setAddress(false, base, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](3);
        feeAssets[0] = getERC20(sourceChain, "WBTC");
        feeAssets[1] = getERC20(sourceChain, "LBTC");
        feeAssets[2] = getERC20(sourceChain, "cbBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "cbBTC");
        token0[1] = getAddress(sourceChain, "cbBTC");
        token0[2] = getAddress(sourceChain, "LBTC");

        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "LBTC");
        token1[1] = getAddress(sourceChain, "WBTC");
        token1[2] = getAddress(sourceChain, "WBTC");

        _addUniswapV3Leafs(leafs, token0, token1, false, true);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](7); 
        SwapKind[] memory kind = new SwapKind[](7); 
        assets[0] = getAddress(sourceChain, "cbBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "LBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "WBTC");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "AERO");
        kind[3] = SwapKind.Sell;
        assets[4] = getAddress(sourceChain, "PENDLE");
        kind[4] = SwapKind.Sell;
        assets[5] = getAddress(sourceChain, "MORPHO");
        kind[5] = SwapKind.Sell;
        assets[6] = getAddress(sourceChain, "WETH");
        kind[6] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Odos ==========================
        _addOdosSwapLeafs(leafs, assets, kind);  

        // ========================== Native ==========================
        _addNativeLeafs(leafs); 

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_05_28_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_09_24_25"), true);

        // ========================== Morpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletCbBTCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletLBTCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "seamlessCbBTC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "moonwellCbBTC")));

        // ========================== LBTC Bridge Wrapper ==========================
        // Mainnet
        _addLBTCBridgeLeafs(leafs, 0x0000000000000000000000000000000000000000000000000000000000000001);  
        // BNB
        _addLBTCBridgeLeafs(leafs, 0x0000000000000000000000000000000000000000000000000000000000000038);  

        // ========================= Aerodrome ========================
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", aerodromeDecoderAndSanitizer);
        address[] memory _token0 = new address[](1);
        _token0[0] = getAddress(sourceChain, "LBTC");
        address[] memory _token1 = new address[](1);
        _token1[0] = getAddress(sourceChain, "cbBTC");

        address[] memory gauges = new address[](1);
        gauges[0] = getAddress(sourceChain, "aerodrome_LBTC_cbBTC_gauge"); 

        _addVelodromeV3Leafs(
            leafs, _token0, _token1, getAddress(sourceChain, "aerodromeNonFungiblePositionManager"), gauges
        );
        
        // ========================== Verify & Generate ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Base/LBTCvStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
