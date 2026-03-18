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

    address public rawDataDecoderAndSanitizer = 0xD834860459a89e609243f00C6fcb4861B351583f;
    address public manager01 = 0xa86b3Bf249478488B4304B50726c7D4689aD6320;
    address public manager02 = 0x0307AD25281C99F22A8F3Af9e272fE3968810239;
    address public manager03 = 0xe5C7cbAA926eAdf27d04A2e6CB4D2d192b8CBF65;

    function setUp() external {
        setSourceChainName(hyperevm);
        vm.createSelectFork(sourceChain);
    }

    function run() external {
        _generateMerkleRoot();
    }

    function _generateMerkleRoot() public {
        setAddress(true, hyperevm, "boringVault", boringVault);
        setAddress(true, hyperevm, "managerAddress", managerAddress);
        setAddress(true, hyperevm, "accountantAddress", accountantAddress);
        setAddress(true, hyperevm, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // BTC=0, ETH=1 (see HyperliquidAssetIds.sol for full list)
        uint32[] memory perpAssets = new uint32[](16);
        perpAssets[0] = 0; // BTC
        perpAssets[1] = 1; // ETH
        perpAssets[2] = 5; // SOL
        perpAssets[3] = 159; // HYPE
        perpAssets[4] = 10142; // SPOT BTC
        perpAssets[5] = 10151; // SPOT ETH
        perpAssets[6] = 10156; // SPOT SOL
        perpAssets[7] = 10107; // SPOT HYPE
        perpAssets[8] = 10235; // SPOT USDE
        perpAssets[9] = 10000 + (4 * 10000) + 0; // hyna:BTCUSDE
        perpAssets[10] = 10000 + (4 * 10000) + 1; // hyna:ETHUSDE
        perpAssets[11] = 10000 + (4 * 10000) + 2; // hyna:HYPEUSDE
        perpAssets[12] = 10000 + (4 * 10000) + 3; // hyna:SOLUSDE
        perpAssets[13] = 10000 + (4 * 10000) + 5; // hyna:ZECUSDE
        perpAssets[14] = 10000 + (4 * 10000) + 6; // hyna:XRPUSDE
        perpAssets[15] = 10000 + (4 * 10000) + 8; // hyna:BNBUSDE
        perpAssets[15] = 10000 + (4 * 10000) + 11; // hyna:PUMPUSDE

        address[] memory spotSendRecipients = new address[](1);
        spotSendRecipients[0] = boringVault; // Allow sending back to self

        // USDC=0, UBTC=197, UETH=221 (for spot sends on HyperCore)
        uint64[] memory spotTokens = new uint64[](2);
        spotTokens[0] = 0; // USDC
        spotTokens[1] = 150; // HYPE

        address[] memory vaults = new address[](0); // No vault transfers by default

        address[] memory validators = new address[](0); // No staking by default

        _addAllCoreWriterLeafs(leafs, perpAssets, spotSendRecipients, spotTokens, vaults, validators);
        _addCoreWriterUsdcDepositLeafs(leafs);

        address[] memory bridgeDestinations = new address[](1);
        bridgeDestinations[0] = boringVault;
        address[] memory bridgeSubAccounts = new address[](1);
        bridgeSubAccounts[0] = address(0); // Main account
        _addCoreWriterSendAssetLeafs(leafs, bridgeDestinations, bridgeSubAccounts);

        address[] memory apiWallets = new address[](3);
        apiWallets[0] = 0x0307AD25281C99F22A8F3Af9e272fE3968810239;
        apiWallets[1] = 0xe5C7cbAA926eAdf27d04A2e6CB4D2d192b8CBF65;
        apiWallets[2] = 0x1c9923509bcE34509B0A0f68d7Af52b69D690D49;
        _addCoreWriterAddApiWalletLeafs(leafs, apiWallets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/HyperEvm/HlCoreTestVaultStrategyLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(managerAddress);

        vm.startBroadcast(vm.envUint("PK"));

        if (!RolesAuthority(rolesAuthority)
                .doesRoleHaveCapability(
                    MANAGER_INTERNAL_ROLE,
                    address(manager),
                    ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector
                )) {
            RolesAuthority(rolesAuthority)
                .setRoleCapability(
                    MANAGER_INTERNAL_ROLE,
                    address(manager),
                    ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
                    true
                );
        }

        RolesAuthority(rolesAuthority).setUserRole(manager01, MANAGER_INTERNAL_ROLE, true);
        RolesAuthority(rolesAuthority).setUserRole(manager02, MANAGER_INTERNAL_ROLE, true);
        RolesAuthority(rolesAuthority).setUserRole(manager02, MANAGER_INTERNAL_ROLE, true);

        manager.setManageRoot(managerAddress, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(manager01, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(manager02, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(manager03, manageTree[manageTree.length - 1][0]);
        vm.stopBroadcast();
    }
}
