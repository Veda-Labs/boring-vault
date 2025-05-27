// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AtomicQueue} from "src/atomic-queue/AtomicQueue.sol";
import {
    OnlyAtomicQueueDecoderAndSanitizer,
    AtomicQueueDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/OnlyAtomicQueueDecoderAndSanitizer.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract AtomicQueueIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    AtomicQueue public queue;
    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    BoringVault public neophyteVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;
    ERC20 offer;
    ERC20 want;

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
        uint256 blockNumber = 22576432;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);
        neophyteVault = new BoringVault(address(this), "Neophyte Vault", "NV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new OnlyAtomicQueueDecoderAndSanitizer(0.9e4, 1.1e4));

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        queue = new AtomicQueue(address(this), rolesAuthority);
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );

        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MANGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        );
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        );

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);
        rolesAuthority.setPublicCapability(address(queue), AtomicQueue.updateAtomicRequest.selector, true);

        offer = ERC20(address(neophyteVault));
        want = getERC20(sourceChain, "WETH");
    }

    function testDecoderDeployRevert() external {
        vm.expectRevert(bytes("Max must be greater than min"));
        new OnlyAtomicQueueDecoderAndSanitizer(1.1e4, 0.9e4);
    }

    function testAtomicQueueIntegration() external {
        // Mint neophyte shares to our boring vault so we can withdraw them.
        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 1_000e18);

        // approve
        // Call updateAtomicRequest
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addAtomicQueueLeafs(leafs, address(queue), offer, want);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = address(neophyteVault);
        targets[1] = address(queue);

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", queue, type(uint256).max);
        AtomicQueue.AtomicRequest memory request = AtomicQueue.AtomicRequest({
            deadline: uint64(block.timestamp + 1 days), // Set deadline to 1 day from now
            atomicPrice: uint88(1e18), // Set atomic price (in want token decimals)
            offerAmount: uint96(1e18), // Amount of offer tokens
            inSolve: false // Should always be false for new requests
        });
        targetData[1] = abi.encodeWithSignature(
            "updateAtomicRequest(address,address,(uint64,uint88,uint96,bool))", offer, want, request
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testAtomicQueueDecoderPriceBoundsRevert() external {
        // Set up atomic request with price that's too low
        AtomicQueue.AtomicRequest memory lowPriceRequest = AtomicQueue.AtomicRequest({
            deadline: uint64(block.timestamp + 1 days),
            atomicPrice: uint88(0.5e18), // Price too low to pass the minAtomicPriceBps check
            offerAmount: uint96(1e18),
            inSolve: false
        });

        // Set up the call through manager
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addAtomicQueueLeafs(leafs, address(queue), offer, want);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = address(queue);

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature(
            "updateAtomicRequest(address,address,(uint64,uint88,uint96,bool))", offer, want, lowPriceRequest
        );

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](1);

        // Expect revert with BadAtomicPrice error
        vm.expectRevert(
            abi.encodeWithSelector(
                AtomicQueueDecoderAndSanitizer.AtomicQueueDecoderAndSanitizer__BadAtomicPrice.selector,
                0.9e4, // minAtomicPriceBps
                1.1e4, // maxAtomicPriceBps
                uint256(0.5e4) // actual
            )
        );

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Set up atomic request with price that's too high
        AtomicQueue.AtomicRequest memory highPriceRequest = AtomicQueue.AtomicRequest({
            deadline: uint64(block.timestamp + 1 days),
            atomicPrice: uint88(2e18), // Price too high to pass the maxAtomicPriceBps check
            offerAmount: uint96(1e18),
            inSolve: false
        });

        targetData[0] = abi.encodeWithSignature(
            "updateAtomicRequest(address,address,(uint64,uint88,uint96,bool))", offer, want, highPriceRequest
        );

        // Expect revert with BadAtomicPrice error
        vm.expectRevert(
            abi.encodeWithSelector(
                AtomicQueueDecoderAndSanitizer.AtomicQueueDecoderAndSanitizer__BadAtomicPrice.selector,
                0.9e4, // minAtomicPriceBps
                1.1e4, // maxAtomicPriceBps
                2e4 // actual
            )
        );

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
