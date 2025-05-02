pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

//  "accountantAssets": [
//     {
//       "addressOrName": {
//         "address": "0x0000000000000000000000000000000000000000",
//         "name": "USDT"
//       },
//       "isPeggedToBase": true,
//       "rateProvider": "0x0000000000000000000000000000000000000000"
//     },
//     {
//       "addressOrName": {
//         "address": "0x0000000000000000000000000000000000000000",
//         "name": "USR"
//         },
//       "isPeggedToBase": true,
//       "rateProvider": "0x0000000000000000000000000000000000000000"
//     },
//     {
//       "addressOrName": {
//         "address": "0x0000000000000000000000000000000000000000",
//         "name": "WSTUSR"
//       },
//       "isPeggedToBase": true,
//       "rateProvider": "0x0000000000000000000000000000000000000000"
//     }
//   ],
//   "depositAssets": [
//     {
//       "addressOrName": {
//         "address": "0x0000000000000000000000000000000000000000",
//         "name": "USDC"
//       },
//       "allowDeposits": true,
//       "allowWithdraws": true,
//       "sharePremium": 0
//     },
//     {
//       "addressOrName": {
//         "address": "0x0000000000000000000000000000000000000000",
//         "name": "USDT"
//       },
//       "allowDeposits": true,
//       "allowWithdraws": true,
//       "sharePremium": 0
//     },
//     {
//       "addressOrName": {
//         "address": "0x0000000000000000000000000000000000000000",
//         "name": "USR"
//       },
//       "allowDeposits": true,
//       "allowWithdraws": true,
//       "sharePremium": 0
//     },
//     {
//       "addressOrName": {
//         "address": "0x0000000000000000000000000000000000000000",
//         "name": "WSTUSR"
//       },
//       "allowDeposits": true,
//       "allowWithdraws": true,
//       "sharePremium": 0
//     }
//   ],
//   "withdrawAssets": [
//     {
//       "addressOrName": {
//         "address": "0x0000000000000000000000000000000000000000",
//         "name": "USDC"
//       },
//       "maxDiscount": 10,
//       "minDiscount": 1,
//       "minimumSecondsToDeadline": 259200,
//       "minimumShares": 0,
//       "secondsToMaturity": 172800
//     },
//     {
//       "addressOrName": {
//         "address": "0x0000000000000000000000000000000000000000",
//         "name": "USDT"
//       },
//       "maxDiscount": 10,
//       "minDiscount": 1,
//       "minimumSecondsToDeadline": 259200,
//       "minimumShares": 0,
//       "secondsToMaturity": 172800
//     },
//     {
//       "addressOrName": {
//         "address": "0x0000000000000000000000000000000000000000",
//         "name": "USR"
//       },
//       "maxDiscount": 10,
//       "minDiscount": 1,
//       "minimumSecondsToDeadline": 259200,
//       "minimumShares": 0,
//       "secondsToMaturity": 172800
//     },
//     {
//       "addressOrName": {
//         "address": "0x0000000000000000000000000000000000000000",
//         "name": "WSTUSR"
//       },
//       "maxDiscount": 10,
//       "minDiscount": 1,
//       "minimumSecondsToDeadline": 259200,
//       "minimumShares": 0,
//       "secondsToMaturity": 172800
//     }
//   ]

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateHyperUSDMerkleRoot.s.sol:CreateHyperUSDMerkleRoot --rpc-url $MAINNET_RPC_URL
 */
contract CreateHyperUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;
    address public boringVault = 0x340116F605Ca4264B8bC75aAE1b3C8E42AE3a3AB;
    address public managerAddress = 0x0Cb93E77ae97458b56F39F9A8735b57A210A65bc;
    address public accountantAddress = 0x9212cA0805D9fEAB6E02a9642f5df33bc970eC13;
    address public rawDataDecoderAndSanitizer = 0x84D988bA2f2838f6ccF61fDE77fe3EB70dFE284f;//!Wrong address

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateHyperUSDMerkleRoot();
    }

    function generateHyperUSDMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // ========================== RESOLV =============================
        _addResolvUsrExternalRequestsManagerLeafs(leafs);


        // ========================== LayerZero ==========================
        //_addLayerZeroLeafs(leafs, getERC20(mainnet, "USR"), getAddress(mainnet, "usrOFTAdapter"), hyperEVMEndpointId, <need vault address on HyperEVM>);
        // layerZeroMainnetEndpointId
        // ManageLeaf[] memory leafs, ERC20 asset, address oftAdapter, uint32 endpoint, bytes32 to
        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](4);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "DAI");
        feeAssets[2] = getERC20(sourceChain, "USDT");
        feeAssets[3] = getERC20(sourceChain, "USDE");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);


        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/HyperUSDStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
