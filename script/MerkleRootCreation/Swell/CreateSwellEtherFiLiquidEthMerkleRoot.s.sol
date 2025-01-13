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
 *  source .env && forge script script/MerkleRootCreation/Swell/CreateSwellEtherFiLiquidEthMerkleRoot.s.sol:CreateSwellEtherFiLiquidEthMerkleRoot --rpc-url $SWELL_CHAIN_RPC_URL
 */
contract CreateSwellEtherFiLiquidEthMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public managerAddress = 0xDEa7AF4a96A762c9d43A7eE02acecD20A3C6D8B6;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;
    address public rawDataDecoderAndSanitizer = 0x5a0Bb1395661BDF781cF0Fcc2a6cc72f56Ed40a7;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMerkleRoot();
    }

    function generateMerkleRoot() public {
        setSourceChainName(swell);
        setAddress(false, swell, "boringVault", boringVault);
        setAddress(false, swell, "managerAddress", managerAddress);
        setAddress(false, swell, "accountantAddress", accountantAddress);
        setAddress(false, swell, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroMainnetEndpointId
        );

        // ========================== Verify & Generate ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Swell/EtherFiLiquidEth.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
