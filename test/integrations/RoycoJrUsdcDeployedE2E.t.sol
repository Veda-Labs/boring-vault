// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RoycoJrUsdcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoycoJrUsdcDecoderAndSanitizer.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, console} from "@forge-std/Test.sol";

contract RoycoJrUsdcDeployedE2ETest is Test, MerkleTreeHelper {
    // Deployed RoycoJrUsdcCluster architecture (deployments/addresses/Mainnet/RoycoJrUsdcCluster.json).
    address public constant BORING_VAULT = 0x71861827Aa95cA48148bdA0b40BC740d1c421070;
    address public constant MANAGER = 0x441973fAe7432a39d13bA4620ebc12Fa43c1C416;
    address public constant ACCOUNTANT = 0x0142d7E0787498c523c5E21c5BeCe9afDD82C6a3;
    address public constant ROLES_AUTHORITY = 0xAAfcF903C9E898155fB891c4121F3Ee54E8d716D;

    // Owner of the deployed RolesAuthority (0xAAfcF903...). Confirmed via cast owner().
    address public constant ADMIN = 0x1b514df3413DA9931eB31f2Ab72e32c0A507Cad5;

    // Royco Dawn — junior tranche of the syrupUSDC market.
    address public constant ROYCO_JR_SYRUP_USDC = 0x5f340B400F892bBFDed2e5c316369Dcbf05C282A;

    // Maple
    address public constant SYRUP_USDC = 0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Strategist role number on the deployed RolesAuthority. Confirmed via doesRoleHaveCapability().
    uint8 public constant STRATEGIST_ROLE = 7;

    address public strategist;
    address public rawDataDecoderAndSanitizer;

    function setUp() external {
        setSourceChainName("mainnet");
        _startFork("MAINNET_RPC_URL");

        strategist = makeAddr("roycoJrUsdcStrategist");

        rawDataDecoderAndSanitizer = address(new RoycoJrUsdcDecoderAndSanitizer());

        setAddress(false, sourceChain, "boringVault", BORING_VAULT);
        setAddress(false, sourceChain, "managerAddress", MANAGER);
        setAddress(false, sourceChain, "accountantAddress", ACCOUNTANT);
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "roycoJrSyrupUSDC", ROYCO_JR_SYRUP_USDC);
    }

    function test_E2E_directDepositOnRoycoJrSyrupUSDC() external {
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addRoycoDawnDirectLeafs(leafs, ROYCO_JR_SYRUP_USDC, SYRUP_USDC);
        bytes32[][] memory tree = _generateMerkleTree(leafs);
        bytes32 root = tree[tree.length - 1][0];

        vm.startPrank(ADMIN);
        RolesAuthority(ROLES_AUTHORITY).setUserRole(strategist, STRATEGIST_ROLE, true);
        ManagerWithMerkleVerification(MANAGER).setManageRoot(strategist, root);
        vm.stopPrank();

        uint256 depositAmount = 1_000 * (10 ** ERC20(SYRUP_USDC).decimals());
        deal(SYRUP_USDC, BORING_VAULT, depositAmount);

        // Leaves produced by _addRoycoDawnDirectLeafs:
        //   leaf[0] = approve(syrupUSDC, JT)
        //   leaf[1] = deposit(uint256, vault) on JT
        //   leaf[2] = redeem(uint256, vault, vault) on JT
        ManageLeaf[] memory used = new ManageLeaf[](2);
        used[0] = leafs[0];
        used[1] = leafs[1];
        bytes32[][] memory proofs = _getProofsUsingTree(used, tree);

        address[] memory targets = new address[](2);
        targets[0] = SYRUP_USDC;
        targets[1] = ROYCO_JR_SYRUP_USDC;

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSignature("approve(address,uint256)", ROYCO_JR_SYRUP_USDC, type(uint256).max);
        data[1] = abi.encodeWithSignature("deposit(uint256,address)", depositAmount, BORING_VAULT);

        address[] memory decoders = new address[](2);
        decoders[0] = rawDataDecoderAndSanitizer;
        decoders[1] = rawDataDecoderAndSanitizer;

        uint256 jtSharesBefore = ERC20(ROYCO_JR_SYRUP_USDC).balanceOf(BORING_VAULT);

        vm.prank(strategist);
        ManagerWithMerkleVerification(MANAGER).manageVaultWithMerkleVerification(
            proofs, decoders, targets, data, new uint256[](2)
        );

        // Vault should now hold JT shares.
        assertGt(
            ERC20(ROYCO_JR_SYRUP_USDC).balanceOf(BORING_VAULT),
            jtSharesBefore,
            "JT shares not minted to vault"
        );
    }

    function test_E2E_unauthorizedAction_reverts() external {
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addRoycoDawnDirectLeafs(leafs, ROYCO_JR_SYRUP_USDC, SYRUP_USDC);
        bytes32[][] memory tree = _generateMerkleTree(leafs);
        bytes32 root = tree[tree.length - 1][0];

        vm.startPrank(ADMIN);
        RolesAuthority(ROLES_AUTHORITY).setUserRole(strategist, STRATEGIST_ROLE, true);
        ManagerWithMerkleVerification(MANAGER).setManageRoot(strategist, root);
        vm.stopPrank();

        // USDT is not in the Royco junior tree — any proof we submit must fail proof verification.
        address usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

        bytes32[][] memory fakeProofs = new bytes32[][](1);
        fakeProofs[0] = new bytes32[](tree.length - 1);
        for (uint256 i; i < tree.length - 1; ++i) {
            fakeProofs[0][i] = tree[i][0];
        }

        address[] memory targets = new address[](1);
        targets[0] = usdt;

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSignature("approve(address,uint256)", strategist, type(uint256).max);

        address[] memory decoders = new address[](1);
        decoders[0] = rawDataDecoderAndSanitizer;

        vm.prank(strategist);
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
                usdt,
                data[0],
                0
            )
        );
        ManagerWithMerkleVerification(MANAGER).manageVaultWithMerkleVerification(
            fakeProofs, decoders, targets, data, new uint256[](1)
        );
    }

    function _startFork(string memory rpcKey) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey));
        vm.selectFork(forkId);
    }
}
