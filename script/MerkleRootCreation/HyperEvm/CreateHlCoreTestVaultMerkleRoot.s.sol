// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";

import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

contract CreateHlCoreTestVaultMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    uint256 public privateKeyOwner;
    uint256 public privateKeyMorphoAgent;

    uint8 public MANAGER_INTERNAL_ROLE = 4;

    address public accountantAddress = 0xdBCaB4E98AC33f1E23fD5893d72196A0443f96fE;
    address public boringVault = 0xfA3188103105Ca533fC8401dFe2e70420D5E6A1f;
    address public queue = 0x5e0FBeB3b935c5d5abaa0ba18dF7D74e55a2c6b6;
    address public managerAddress = 0xdFD1bF16A9763C4ecB6B02155d7697cc22A13086;
    address public rolesAuthority = 0xf37d11401897FD1114A1B7816BD923264cB11050;
    address public teller = 0x5C0d2f6cF8a237669FB6d07511a1Ff4D9eB819E1;

    address public rawDataDecoderAndSanitizer = 0x29fFc74Ed4f0b12A9673623f8270C79FB0BAF0C0;
    address public user1 = 0xa86b3Bf249478488B4304B50726c7D4689aD6320;
    address public user2 = 0x0307AD25281C99F22A8F3Af9e272fE3968810239;

    function setUp() external {
        setSourceChainName(base);
        vm.createSelectFork(sourceChain);
    }

    function run() external {
        _generateMerkleRoot();
    }

    function _generateMerkleRoot() public {
        setAddress(true, base, "boringVault", boringVault);
        setAddress(true, base, "managerAddress", managerAddress);
        setAddress(true, base, "accountantAddress", accountantAddress);
        setAddress(true, base, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        ERC20[] memory assets = new ERC20[](1);
        assets[0] = ERC20(getAddress(sourceChain, "USDC"));
        _addTellerLeafs(leafs, address(syusdTeller), assets, false, true);
        _addWithdrawQueueLeafs(leafs, syusdQueue, syusd, assets);

        _addSendUsdcHyperEvmToCoreLeafs(leafs);
        _addCoreWriterLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/HyperEvm/HlCoreTestVaultStrategyLeafs.json";
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
