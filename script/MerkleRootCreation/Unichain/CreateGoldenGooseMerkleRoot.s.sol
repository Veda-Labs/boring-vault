// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Unichain/CreateGoldenGooseMerkleRoot.s.sol --rpc-url $UNICHAIN_RPC_URL
 */
contract CreateGoldenGooseMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09;
    address public managerAddress = 0x5F341B1cf8C5949d6bE144A725c22383a5D3880B;
    address public accountantAddress = 0xc873F2b7b3BA0a7faA2B56e210E3B965f2b618f5;
    address public rawDataDecoderAndSanitizer = 0x597A6471A3f6d279DE56D618E378DAde55383608; 

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMerkleRoot();
    }

    function generateMerkleRoot() public {
        setSourceChainName(unichain);
        setAddress(false, unichain, "boringVault", boringVault);
        setAddress(false, unichain, "managerAddress", managerAddress);
        setAddress(false, unichain, "accountantAddress", accountantAddress);
        setAddress(false, unichain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs);

        // ========================== Standard Bridge ==========================
        ERC20[] memory localTokens = new ERC20[](1);
        ERC20[] memory remoteTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "WETH");
        remoteTokens[0] = getERC20(mainnet, "WETH");
        _addStandardBridgeLeafs(
            leafs,
            mainnet,
            address(0),
            address(0),
            getAddress(sourceChain, "standardBridge"),
            address(0),
            localTokens,
            remoteTokens
        );

        _addLidoStandardBridgeLeafs(
            leafs,
            mainnet,
            address(0),
            address(0),
            getAddress(sourceChain, "standardBridge"),
            address(0)
        );

        // ========================== Uniswap V4 ==========================
        address[] memory hooks = new address[](1);
        address[] memory token0 = new address[](1);
        address[] memory token1 = new address[](1);

        hooks[0] = address(0);
        token0[0] = address(0);
        token1[0] = getAddress(sourceChain, "WSTETH");

        _addUniswapV4Leafs(
            leafs,
            token0,
            token1,
            hooks
        );

        // Euler wstETH market integration
        // _addEulerLeafs(leafs, wstETHMarketAddress); HOLDING FOR NOW

        // Morpho wstETH market integration
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "morphowstETHmarket"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "morphowstETHmarket"));

        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "morphoSmokehouseWSTETH")));

        // ========================== Verify & Generate ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Unichain/GoldenGooseStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
