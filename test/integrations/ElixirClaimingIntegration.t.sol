// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    ElixirClaimingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/ElixirClaimingDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract EthenaWithdrawIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 22024506;

        _startFork(rpcKey, blockNumber);

        boringVault = BoringVault(payable(0xbc0f3B23930fff9f4894914bD745ABAbA9588265)); //UltraUSD

        manager = ManagerWithMerkleVerification(0x4f81c27e750A453d6206C2d10548d6566F60886C);

        rawDataDecoderAndSanitizer = address(new FullElxDecoderAndSanitizer());

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        //rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        rolesAuthority = RolesAuthority(address(boringVault.authority()));

        //boringVault.setAuthority(rolesAuthority);
        //manager.setAuthority(rolesAuthority);

        // Setup roles authority.
        //rolesAuthority.setRoleCapability(
        //    MANAGER_ROLE,
        //    address(boringVault),
        //    bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
        //    true
        //);
        //rolesAuthority.setRoleCapability(
        //    MANAGER_ROLE,
        //    address(boringVault),
        //    bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
        //    true
        //);

        //rolesAuthority.setRoleCapability(
        //    STRATEGIST_ROLE,
        //    address(manager),
        //    ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
        //    true
        //);
        //rolesAuthority.setRoleCapability(
        //    MANGER_INTERNAL_ROLE,
        //    address(manager),
        //    ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
        //    true
        //);
        //rolesAuthority.setRoleCapability(
        //    ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        //);
        //rolesAuthority.setRoleCapability(
        //    BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        //);
        //rolesAuthority.setRoleCapability(
        //    BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        //);

        //// Grant roles
        //rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        //rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        //rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        //rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        //rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        //rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);
    }

    function testElixirClaiming() external {
        address ultraUSDStrategist = 0xFBc847FA8AFA576c43dc85afE84edD637bc0A904;

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addELXClaimingLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        vm.prank(boringVault.owner());
        manager.setManageRoot(ultraUSDStrategist, manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0]; //claim

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "elxTokenDistributor");

        //merkle proof
        bytes32[] memory merkleProofs = new bytes32[](16);
        merkleProofs[0] = 0x7cbf6c032f0a9e16bbf4485c234806204e0c0c2c55eefbedcf46c631f81a2bdf;
        merkleProofs[1] = 0x1932ace9f0868efbc9dfe5847387a3913c936855a54e1a7a038d7e7a73236f2a;
        merkleProofs[2] = 0x03aa0a5ca1d41d5f006c26ce41f2f7350419e9f24e930a17731c71cd179dc127;
        merkleProofs[3] = 0x90d2f83a46efc28d6b2e75dac85dbab8733f1c7c05fa99cc8c1be9647a5ecab2;
        merkleProofs[4] = 0x31c68598f1c85a4f82e58d117cc77416e1fa8c1a682a094e5b57a92152ee8796;
        merkleProofs[5] = 0x3e6b819c400bfd69a98f863775fb5f9c27f9074d3f739736c9d36984563d18ad;
        merkleProofs[6] = 0x554fc1399bc1c16c91eec2fce3e493b1abfc9e58c44bb73726269e4ded645734;
        merkleProofs[7] = 0x391095297d1c3808306350961f0dac58e83f279ae94a244fef7f3a7578d126fc;
        merkleProofs[8] = 0x113d2920cc750f870106b78d0747a96c1147831a6afa7ca8a1146cfe2829fa0b;
        merkleProofs[9] = 0xa319f38297d5e4d7398ab66a9cba21a8cf62fb288a9710914e50c99e02dfa4bd;
        merkleProofs[10] = 0x7f5865a6daee94617c19bc18df20832f5f58b9d9b9cc59e366d96ddc54c9d40f;
        merkleProofs[11] = 0xd6f1016f1315b0a6cdeaf98dc728542869dac47102a44e595b4f032f60f98744;
        merkleProofs[12] = 0xb787d5c4ee3daf92f754a0d09905bd4b157ccb305d230ad36e00d94c6991c19c;
        merkleProofs[13] = 0x76a6af0464b1bcb4885c79f5fec9cc90b1eb2b64531d95b67a8f5e0df8ab60be;
        merkleProofs[14] = 0x68c1a707e1cfd1455b08ae4e78968aae753a84b63cca9e602e4d19443fd51201;
        merkleProofs[15] = 0xc869131cd48425d0df2a4a7b527891ab52b9e26fdedaa27cb053f46fb8fb35a1;

        bytes memory signature =
            hex"eb0748848725cbc35cbe170d438626fd014784227138e103ffc08e26dc7f02932d46deb785b0962923b2220dab0a401592f589d59ddb2be56683dbc2e6da14931b";

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            abi.encodeWithSignature("claim(uint256,bytes32[],bytes)", 8973715174000000000000, merkleProofs, signature);

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](1);

        // NOTE: without a way to generate the proofs or signature for the vault, this is going to fail.
        // The above proofs and signatures were taken from a passing TX for a user, but the vaults proofs and sig are unknown as this appears
        // to be generated on the FE for claims.
        // At this point, I am unable to find any SDK or FE code that will do this for the vault addresses we need.
        // The signature can be obtained from pranking the wallet on Rabby, but in order to generate the proofs this requires a siganture to be sent.
        //
        // We could bastardize the state of the contract for the sake of a passing test, but that would defeat the purpose of the test.
        // In this case, we are testing that the boring vault CAN call the claim function, which the revert below indicates.
        //vm.expectRevert(); //use -vvvv to verify this is erroring with: InvalidSignature() or 0x8baa579f;
        vm.prank(ultraUSDStrategist);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 ELXBalanace =
            getERC20(sourceChain, "ELX").balanceOf(address(0xbc0f3B23930fff9f4894914bD745ABAbA9588265));

        uint256 claimable =
            (8973715174000000000000 / 2) + ((8973715174000000000000 / 2) * (block.timestamp - 1741341600) / 7776000);

        //after forfeiting claim, claim amount is 4697531591687134387860;
        assertEq(ELXBalanace, claimable);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullElxDecoderAndSanitizer is ElixirClaimingDecoderAndSanitizer {}

