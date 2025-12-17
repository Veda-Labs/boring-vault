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

contract CreateMonUsdcLpVaultMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public accountantAddress = 0xcbEa6c591d9B373a67aC3292CeD592550e63c9dE;
    address public boringVault = 0x3F28BE0867F3A4504C769A54e2E6a7443381811B;
    address public managerAddress = 0x524631b72A942fa8Ede58f629F1e60B117ae4F0C;
    address public rawDataDecoderAndSanitizer01 = 0xf220c6614DAe7d52dCef1e6E60f50F669BcC24c1;

    function setUp() external {
        setSourceChainName(monad);
        vm.createSelectFork(sourceChain);
    }

    function run() external {
        _generateMonUsdcLpVaultMerkleRoot();
    }

    function _generateMonUsdcLpVaultMerkleRoot() public {
        setAddress(true, sourceChain, "boringVault", boringVault);
        setAddress(true, sourceChain, "managerAddress", managerAddress);
        setAddress(true, sourceChain, "accountantAddress", accountantAddress);
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer01);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "ETH");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        address[] memory hooks = new address[](1);
        hooks[0] = address(0);

        _addUniswapV4Leafs(leafs, token0, token1, hooks);

        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Monad/MonUsdcLpStrategyLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(managerAddress);
        vm.startBroadcast(vm.envUint("PRIVATE_KEY_1"));
        manager.setManageRoot(0xa86b3Bf249478488B4304B50726c7D4689aD6320, manageTree[manageTree.length - 1][0]);
        vm.stopBroadcast();
    }
}
