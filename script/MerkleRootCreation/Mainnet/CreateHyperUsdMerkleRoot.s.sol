// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateHyperUsdMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 18446744073709551615 --memory-limit 671100000
 */
contract CreateHyperUsdMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x340116F605Ca4264B8bC75aAE1b3C8E42AE3a3AB;
    address public rawDataDecoderAndSanitizer = 0x6a2352fcE90CD91DFc66eFc048ea42cc7d3729b1;
    address public managerAddress = 0x0Cb93E77ae97458b56F39F9A8735b57A210A65bc;
    address public accountantAddress = 0x9212cA0805D9fEAB6E02a9642f5df33bc970eC13;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateHyperUsdStrategistMerkleRoot();
    }

    function generateHyperUsdStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](4);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "USDT");
        feeAssets[2] = getERC20(sourceChain, "USR");
        feeAssets[3] = getERC20(sourceChain, "WSTUSR");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ========================== 1inch Swaps ==========================
        address[] memory oneInchAssets = new address[](4);
        SwapKind[] memory oneInchKind = new SwapKind[](4);
        
        // USR <-> USDC swaps
        oneInchAssets[0] = getAddress(sourceChain, "USR");
        oneInchKind[0] = SwapKind.BuyAndSell;
        
        // USDC <-> USR swaps (already covered above with BuyAndSell)
        oneInchAssets[1] = getAddress(sourceChain, "USDC");
        oneInchKind[1] = SwapKind.BuyAndSell;
        
        // USR <-> USDT swaps  
        oneInchAssets[2] = getAddress(sourceChain, "USDT");
        oneInchKind[2] = SwapKind.BuyAndSell;
        
        // WSTUSR for potential swaps
        oneInchAssets[3] = getAddress(sourceChain, "WSTUSR");
        oneInchKind[3] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, oneInchAssets, oneInchKind);

        // ========================== Resolv USR Protocol ==========================
        // USR uses Resolv protocol for minting and burning (redeeming)
        _addAllResolvLeafs(leafs);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== Teller ==========================
        ERC20[] memory tellerAssets = new ERC20[](4);
        tellerAssets[0] = getERC20(sourceChain, "USDC");
        tellerAssets[1] = getERC20(sourceChain, "USDT");
        tellerAssets[2] = getERC20(sourceChain, "USR");
        tellerAssets[3] = getERC20(sourceChain, "WSTUSR");
        
        // Find the teller address from the deployment
        address hyperUsdTeller = 0xbC08eF3368615Be8495EB394a0b7d8d5FC6d1A55; // TellerWithLayerZero from HyperUSD deployment
        _addTellerLeafs(leafs, hyperUsdTeller, tellerAssets, false, false);

        // Comment out verification for now since decoder hasn't been deployed yet
        // _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/HyperUsdStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}