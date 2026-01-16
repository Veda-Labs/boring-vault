// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";

import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import {
    BaseStablecoinStrategyDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/BaseStablecoinStrategyDecoderAndSanitizer.sol";
import "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

contract CreateDnMonUsdcMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    uint256 public privateKeyOwner;
    uint256 public privateKeyMorphoAgent;

    uint8 public MANAGER_INTERNAL_ROLE = 4;

    address public accountantAddress = 0x5017ca1305C441A7d98DEEE71D48e3D80972C770;
    address public boringVault = 0x5Aa0d6Fc93B827cB0eCb34Dc7bbe78Cc18616f8f;
    address public managerAddress = 0xC9e0fcD928A37D794298275FfF4a22C15356B50A;
    address public rawDataDecoderAndSanitizer = address(0x5F2863EeF8854171F2AC4E07A0D056CFC8e13c3E);
    RolesAuthority public rolesAuthority = RolesAuthority(0x921f524740Dee566eFD71C7AA821F84f1e726E87);
    address public teller = 0x33E1Df8DF212A88a9514e4E166e315D0945Fd8fd;

    address public user1 = 0xa86b3Bf249478488B4304B50726c7D4689aD6320;
    address public user2 = 0x0307AD25281C99F22A8F3Af9e272fE3968810239;

    function setUp() external {
        setSourceChainName(monad);
        vm.createSelectFork(sourceChain);
    }

    function run() external {
        _generateDnMOnUsdcMultiChainMerkleRoot();
    }

    function _generateDnMOnUsdcMultiChainMerkleRoot() public {
        

        console.log("Address of decoder and sanitizer:", rawDataDecoderAndSanitizer);

        setAddress(true, monad, "boringVault", boringVault);
        setAddress(true, monad, "managerAddress", managerAddress);
        setAddress(true, monad, "accountantAddress", accountantAddress);
        setAddress(true, monad, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // 1inch assets;
        address[] memory oneInchAssets = new address[](2);
        oneInchAssets[0] = getAddress(sourceChain, "USDC");
        oneInchAssets[1] = getAddress(sourceChain, "WMON");
        SwapKind[] memory kind = new SwapKind[](2);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;


        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "WMON");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");

        _addUniswapV3Leafs(leafs, token0, token1, false, false);

        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);
        _addMagpieSwapLeafs(leafs, oneInchAssets, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Monad/DnMonUsdcStrategyLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(managerAddress);
        vm.startBroadcast(vm.envUint("PK"));

        if (!rolesAuthority.doesRoleHaveCapability(
                MANAGER_INTERNAL_ROLE,
                address(manager),
                ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector
            )) {
            rolesAuthority.setRoleCapability(
                MANAGER_INTERNAL_ROLE,
                address(manager),
                ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
                true
            );
        }
        rolesAuthority.setUserRole(user1, MANAGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(user2, MANAGER_INTERNAL_ROLE, true);

        manager.setManageRoot(managerAddress, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(user1, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(user2, manageTree[manageTree.length - 1][0]);
        vm.stopBroadcast();
    }
}
