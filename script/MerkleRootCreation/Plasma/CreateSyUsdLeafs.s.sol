// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

contract CreateSyUsdMultiChainMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    uint256 public privateKeyOwner;
    uint256 public privateKeyMorphoAgent;

    address public accountantAddress = 0x03D9a9cE13D16C7cFCE564f41bd7E85E5cde8Da6;
    address public boringVault = 0x279CAD277447965AF3d24a78197aad1B02a2c589;
    address public managerAddress = 0x9B3e565ffC70c4b72516BC2dbec4b3c790940CE8;
    address public rawDataDecoderAndSanitizer01 = 0x668B8b5537CBeDC7293D4cBC29B806C53b415b31;

    function setUp() external {
        setSourceChainName(plasma);
        vm.createSelectFork(sourceChain);
    }

    function run() external {
        _generateSyUsdMultiChainMerkleRoot();
    }

    function _generateSyUsdMultiChainMerkleRoot() public {
        setAddress(true, plasma, "boringVault", boringVault);
        setAddress(true, plasma, "managerAddress", managerAddress);
        setAddress(true, plasma, "accountantAddress", accountantAddress);
        setAddress(true, plasma, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer01);

        ManageLeaf[] memory leafs = new ManageLeaf[](1024);
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDT0");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        ERC20[] memory supplyAssets = new ERC20[](3);
        supplyAssets[0] = getERC20(sourceChain, "USDT0");
        supplyAssets[1] = getERC20(sourceChain, "USDe");
        supplyAssets[2] = getERC20(sourceChain, "sUSDe");

        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "USDT0");
        borrowAssets[1] = getERC20(sourceChain, "USDe");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fUSDT0"));

        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDT0"));

        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDT0"),
            getAddress(sourceChain, "USDT0_OFT_Adapter"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WXPL"),
            false,
            "transfer(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = 0x1b514df3413DA9931eB31f2Ab72e32c0A507Cad5;

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Plasma/SyUsdPlasmaStrategyLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(managerAddress);
        vm.startBroadcast(vm.envUint("BORING_OWNER"));
        manager.setManageRoot(managerAddress, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(vm.addr(vm.envUint("BORING_MORPHO_AGENT")), manageTree[manageTree.length - 1][0]);
        vm.stopBroadcast();
    }
}
