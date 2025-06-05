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
 *  source .env && forge script script/MerkleRootCreation/Unichain/CreateUnichainEtherFiLiquidEthMerkleRoot.s.sol:CreateUnichainEtherFiLiquidEthMerkleRoot --rpc-url $UNICHAIN_RPC_URL
 */
contract CreateUnichainEtherFiLiquidEthMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public managerAddress = 0xDEa7AF4a96A762c9d43A7eE02acecD20A3C6D8B6;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;
    address public rawDataDecoderAndSanitizer = 0x3B552951238bCf38097c66b10fF02203162E35C4; 
    bytes32 public morphoMarketId = 0xdacbdd711936b4f4bd789f0f7111e36e925d730ebd41178e36e705efd78a4aa1;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault")
        );

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

        // ========================== Merkl ==========================
        // ERC20[] memory tokensToClaim = new ERC20[](1);
        // tokensToClaim[0] = getERC20(sourceChain, "UNI");
        // _addMerklLeafs(
        //     leafs,
        //     getAddress(sourceChain, "merklDistributor"),
        //     getAddress(sourceChain, "dev1Address"),
        //     tokensToClaim
        // );

        // ========================== Uniswap V4 ==========================
        address[] memory hooks = new address[](1);
        address[] memory token0 = new address[](1);
        address[] memory token1 = new address[](1);

        hooks[0] = address(0);
        token0[0] = address(0);
        token1[0] = getAddress(sourceChain, "WEETH");

        _addUniswapV4Leafs(
            leafs,
            token0,
            token1,
            hooks
        );

        //TODO: Need to finish deployment, then run merkle script. Then push the PR and create the txn, post in Admin channel

        _addMorphoBlueSupplyLeafs(leafs, morphoMarketId);

        _addMorphoBlueCollateralLeafs(leafs, morphoMarketId);

        _addERC4626Leafs(leafs, ERC4626(0x830898200F0E8Be8Dc1C9A836f4AB29ECEdf76eb));

        // ========================== Verify & Generate ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Unichain/EtherFiLiquidEth.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
