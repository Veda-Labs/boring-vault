// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {BoringChefDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BoringChefDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract BoringChefIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    // TODO: DELETE MOCK, replace with real BoringVault using BoringChef
    address mockBoringChef = address(new MockBoringChef());

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    function setUp() external {
        setSourceChainName("sonicMainnet");
        // Setup forked environment.
        string memory rpcKey = "SONIC_MAINNET_RPC_URL";
        uint256 blockNumber = 4875362;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));


        // TODO: DELETE MOCK, replace with real BoringVault using BoringChef
        mockBoringChef = address(new MockBoringChef());
        rawDataDecoderAndSanitizer = address(new FullBoringChefDecoderAndSanitizer());

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
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

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testBoringChefClaimingIntegration() external {
        //deal(getAddress(sourceChain, "USDC"), address(boringVault), 100_000e6);

        // Set up mock test scenario
        // TODO: When a real vault with BoringChef is deployed, replace mocks with real data

        deal(getAddress(sourceChain, "BEETS"), mockBoringChef, 1e8);
        deal(getAddress(sourceChain, "wS"), mockBoringChef, 100_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);

        // address[] memory rewardTokens = new address[](2);
        // rewardTokens[0] = getAddress(sourceChain, "BEETS");
        // rewardTokens[1] = getAddress(sourceChain, "wS");

        _addBoringChefClaimLeaf(leafs, mockBoringChef);
        _addBoringChefClaimOnBehalfOfLeaf(leafs, mockBoringChef, address(this));


        //string memory filePath = "./TestTEST.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //claimRewards
        manageLeafs[1] = leafs[1]; //claimRewardsOnBehalfOfUser


        (bytes32[][] memory manageProofs) = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = mockBoringChef; //BoringVault inheriting from BoringChef
        targets[1] = mockBoringChef; //BoringVault inheriting from BoringChef

        uint256[] memory rewardIds = new uint256[](2);
        rewardIds[0] = 0;
        rewardIds[1] = 1;
        bytes[] memory targetData = new bytes[](2);
        targetData[0] =
            abi.encodeWithSignature("claimRewards(uint256[])", rewardIds);
        targetData[1] =
            abi.encodeWithSignature("claimRewardsOnBehalfOfUser(uint256[],address)", rewardIds, address(this)); // TODO test with real user

        uint256[] memory values = new uint256[](2);

        address[] memory decodersAndSanitizers = new address[](2);
        for (uint256 i = 0; i < decodersAndSanitizers.length; i++) {
            decodersAndSanitizers[i] = rawDataDecoderAndSanitizer;
        }

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testBoringChefDistributeRewardsIntegration() external {
        deal(getAddress(sourceChain, "BEETS"), address(boringVault), 1e8);
        deal(getAddress(sourceChain, "wS"), address(boringVault), 100_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);

        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = getAddress(sourceChain, "BEETS");
        rewardTokens[1] = getAddress(sourceChain, "wS");

        uint256[] memory rewardAmounts = new uint256[](2);
        rewardAmounts[0] = 1e8;
        rewardAmounts[1] = 100_000e18;

        // address[] memory rewardTokens0 = new address[](1);
        // rewardTokens0[0] = getAddress(sourceChain, "BEETS");
        // address[] memory rewardTokens1 = new address[](1);
        // rewardTokens1[0] = getAddress(sourceChain, "wS");

        _addBoringChefApproveRewardsLeafs(leafs, mockBoringChef, rewardTokens);
        _addBoringChefDistributeRewardsLeaf(leafs, mockBoringChef, rewardTokens);
        // _addBoringChefDistributeRewardsLeafs(leafs, boringVault, rewardTokens0);
        // _addBoringChefDistributeRewardsLeafs(leafs, boringVault, rewardTokens1);


        //string memory filePath = "./TestTEST.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0]; //approve Beets
        manageLeafs[1] = leafs[1]; //approve wS
        manageLeafs[2] = leafs[2]; //distribute Beets and wS


        (bytes32[][] memory manageProofs) = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "BEETS"); //First reward token
        targets[1] = getAddress(sourceChain, "wS"); //Second reward token
        targets[2] = mockBoringChef; //BoringVault inheriting from BoringChef

        bytes[] memory targetData = new bytes[](3);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", mockBoringChef, type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", mockBoringChef, type(uint256).max); // TODO test with real user
        targetData[2] =
            abi.encodeWithSignature("distributeRewards(address[],uint256[],uint48[],uint48[])", 
                rewardTokens, rewardAmounts, new uint48[](2), new uint48[](2));

        uint256[] memory values = new uint256[](3);

        address[] memory decodersAndSanitizers = new address[](3);
        for (uint256 i = 0; i < decodersAndSanitizers.length; i++) {
            decodersAndSanitizers[i] = rawDataDecoderAndSanitizer;
        }

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullBoringChefDecoderAndSanitizer is BoringChefDecoderAndSanitizer {
}

// Temporary Mock Contract for test until real BoringChef is deployed
contract MockBoringChef {
    using SafeTransferLib for ERC20;
    address beets = 0x2D0E0814E62D80056181F5cd932274405966e4f0;
    address wS = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
    address mockSafe = address(1);

    mapping (uint256 => DecoderCustomTypes.Reward) public rewards;

    constructor() {
        rewards[0] = DecoderCustomTypes.Reward(1, 2, beets, 10);
        rewards[1] = DecoderCustomTypes.Reward(1, 3, wS, 100);
    }

    function claimRewards(uint256[] calldata /*rewardIds*/) external {
        ERC20(beets).transfer(msg.sender, 1e7);
        ERC20(wS).transfer(msg.sender, 10_000e18);
    }

    function claimRewardsOnBehalfOfUser(uint256[] calldata /*rewardIds*/, address user) external {
        ERC20(beets).transfer(user, 2e7);
        ERC20(wS).transfer(user, 20_000e18);
    }

    function distributeRewards(address[] calldata tokens, uint256[] calldata amounts, uint48[] calldata startEpochs, uint48[] calldata endEpochs) external {
        ERC20(beets).safeTransferFrom(msg.sender, mockSafe, amounts[0]);
        ERC20(wS).safeTransferFrom(msg.sender, mockSafe, amounts[1]);
    }
}
