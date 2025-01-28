// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {SymbioticLRTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SymbioticLRTDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {
    SymbioticVaultDecoderAndSanitizerFull,
    SymbioticVaultDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/SymbioticVaultDecoderAndSanitizerFull.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract SymbioticVaultIntegrationTest is Test, MerkleTreeHelper {
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

    function _setUpHolesky() internal {
        setSourceChainName("holesky");
        // Setup forked environment.
        string memory rpcKey = "HOLESKY_RPC_URL";
        uint256 blockNumber = 3200468;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), address(0));

        rawDataDecoderAndSanitizer = address(new SymbioticVaultDecoderAndSanitizerFull());

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
        rolesAuthority.setUserRole(address(0), BALANCER_VAULT_ROLE, true);

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function _setUpMainnet() internal {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21683743;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), address(0));

        rawDataDecoderAndSanitizer = address(new SymbioticVaultDecoderAndSanitizerFull());

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
        rolesAuthority.setUserRole(address(0), BALANCER_VAULT_ROLE, true);

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testSymbioticVaultIntegration() external {
        _setUpHolesky(); 

        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 100e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        address[] memory vaults = new address[](1);
        vaults[0] = getAddress(sourceChain, "wstETHSymbioticVault");
        ERC20[] memory assets = new ERC20[](1);
        assets[0] = ERC20(getAddress(sourceChain, "WSTETH"));
        address[] memory rewards = new address[](1); 
        rewards[0] = address(1); 
        _addSymbioticVaultLeafs(leafs, vaults, assets, rewards);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "WSTETH");
        targets[1] = getAddress(sourceChain, "wstETHSymbioticVault");
        targets[2] = getAddress(sourceChain, "wstETHSymbioticVault");

        bytes[] memory targetData = new bytes[](3);
        targetData[0] =
            abi.encodeWithSelector(ERC20.approve.selector, getAddress(sourceChain, "wstETHSymbioticVault"), 100e18);
        targetData[1] = abi.encodeWithSignature("deposit(address,uint256)", boringVault, 100e18);
        targetData[2] = abi.encodeWithSignature("withdraw(address,uint256)", boringVault, 100e18);

        uint256[] memory values = new uint256[](3);

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 epoch = SymbioticVault(getAddress(sourceChain, "wstETHSymbioticVault")).currentEpoch() + 1;

        skip(10 days);

        uint256 beforeClaim = vm.snapshotState();

        // Use claim to withdraw.
        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[3];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "wstETHSymbioticVault");

        targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("claim(address,uint256)", boringVault, epoch);

        values = new uint256[](1);

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            getERC20(sourceChain, "WSTETH").balanceOf(address(boringVault)),
            100e18,
            "BoringVault should have 100 wstETH."
        );

        vm.revertToState(beforeClaim);

        // Use claimBatch to withdraw.
        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[4];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "wstETHSymbioticVault");

        targetData = new bytes[](1);
        uint256[] memory batch = new uint256[](1);
        batch[0] = epoch;
        targetData[0] = abi.encodeWithSignature("claimBatch(address,uint256[])", boringVault, batch);

        values = new uint256[](1);

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            getERC20(sourceChain, "WSTETH").balanceOf(address(boringVault)),
            100e18,
            "BoringVault should have 100 wstETH."
        );
    }

     struct RewardDistribution {
        uint256 amount;
        uint48 timestamp;
    }

    function testSymbioticVaultIntegrationMainnet() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "wstETHDefaultCollateral"), address(boringVault), 100e18);

        address networkMiddleware = address(0x96d37DC47CBE2486E25c4a4587FFCdc48cDd3172);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        address[] memory vaults = new address[](1);
        vaults[0] = getAddress(sourceChain, "wstETHSymbioticVault");
        ERC20[] memory assets = new ERC20[](1);
        assets[0] = ERC20(getAddress(sourceChain, "wstETHDefaultCollateral"));
        address[] memory rewards = new address[](1); 
        rewards[0] = getAddress(sourceChain, "wstETHSymbioticVaultRewards"); 
        _addSymbioticVaultLeafs(leafs, vaults, assets, rewards);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "wstETHDefaultCollateral");
        targets[1] = getAddress(sourceChain, "wstETHSymbioticVault");
        targets[2] = getAddress(sourceChain, "wstETHSymbioticVault");
        
        bytes[] memory activeSharesOfHints = new bytes[](0);  
        bytes memory data = abi.encode(networkMiddleware, 100e18, activeSharesOfHints); 
        data; 

        bytes[] memory targetData = new bytes[](3);
        targetData[0] =
            abi.encodeWithSelector(ERC20.approve.selector, getAddress(sourceChain, "wstETHSymbioticVault"), type(uint256).max);
        targetData[1] = abi.encodeWithSignature("deposit(address,uint256)", boringVault, 100e18);
        //targetData[2] = abi.encodeWithSignature("claimRewards(address,address,bytes)", boringVault, getAddress(sourceChain, "WETH"), data);
        targetData[2] = abi.encodeWithSignature("withdraw(address,uint256)", boringVault, 100e18);

        uint256[] memory values = new uint256[](3);

        address[] memory decodersAndSanitizers = new address[](3); 
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        //decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 epoch = SymbioticVault(getAddress(sourceChain, "wstETHSymbioticVault")).currentEpoch() + 1;

        skip(10 days);

        uint256 beforeClaim = vm.snapshotState();

        // Use claim to withdraw.
        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[3];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "wstETHSymbioticVault");

        targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("claim(address,uint256)", boringVault, epoch);

        values = new uint256[](1);

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            getERC20(sourceChain, "wstETHDefaultCollateral").balanceOf(address(boringVault)),
            100e18,
            "BoringVault should have 100 wstETHDefaultCollateral."
        );
        vm.revertToState(beforeClaim);

        // Use claimBatch to withdraw.
        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[4];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "wstETHSymbioticVault");

        targetData = new bytes[](1);
        uint256[] memory batch = new uint256[](1);
        batch[0] = epoch;
        targetData[0] = abi.encodeWithSignature("claimBatch(address,uint256[])", boringVault, batch);

        values = new uint256[](1);

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            getERC20(sourceChain, "wstETHDefaultCollateral").balanceOf(address(boringVault)),
            100e18,
            "BoringVault should have 100 wstETHDefaultCollateral."
        );
        
    }

    function testSymbioticVaultIntegrationMainnetRewards() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "wstETHDefaultCollateral"), address(boringVault), 100e18);


        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        address[] memory vaults = new address[](1);
        vaults[0] = getAddress(sourceChain, "wstETHSymbioticVault");
        ERC20[] memory assets = new ERC20[](1);
        assets[0] = ERC20(getAddress(sourceChain, "wstETHDefaultCollateral"));
        address[] memory rewards = new address[](1); 
        rewards[0] = getAddress(sourceChain, "wstETHSymbioticVaultRewards"); 
        _addSymbioticVaultLeafs(leafs, vaults, assets, rewards);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "wstETHDefaultCollateral");
        targets[1] = getAddress(sourceChain, "wstETHSymbioticVault");
        

        bytes[] memory targetData = new bytes[](2);
        targetData[0] =
            abi.encodeWithSelector(ERC20.approve.selector, getAddress(sourceChain, "wstETHSymbioticVault"), type(uint256).max);
        targetData[1] = abi.encodeWithSignature("deposit(address,uint256)", boringVault, 100e18);

        uint256[] memory values = new uint256[](2);

        address[] memory decodersAndSanitizers = new address[](2); 
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);


        {
            // 1. First get/setup our contracts
            address rewardsContract = getAddress(sourceChain, "wstETHSymbioticVaultRewards");

            // 2. We need to mock the middleware service to return our middleware address
            vm.mockCall(
                0xD7dC9B366c027743D90761F71858BCa83C6899Ad,
                abi.encodeWithSelector(INetworkMiddlewareService.middleware.selector, 0x96d37DC47CBE2486E25c4a4587FFCdc48cDd3172),
                abi.encode(0x96d37DC47CBE2486E25c4a4587FFCdc48cDd3172)
            );
        
            // 3. Setup reward distribution parameters
            uint48 timestamp = uint48(block.timestamp - 1); // Must be in the past
            uint256 maxAdminFee = 1000; // 10% max
            
        //address networkMiddleware = address(0x96d37DC47CBE2486E25c4a4587FFCdc48cDd3172);
            // 4. Deal tokens to middleware for distribution
            deal(getAddress(sourceChain, "WETH"), 0x96d37DC47CBE2486E25c4a4587FFCdc48cDd3172, 100e18);

            // Mock vault responses
            vm.mockCall(
                0xBecfad885d8A89A0d2f0E099f66297b0C296Ea21,
                abi.encodeWithSelector(IVault.activeSharesAt.selector, timestamp, ""),
                abi.encode(1e18) // Non-zero shares
            );
                
            vm.mockCall(
                0xBecfad885d8A89A0d2f0E099f66297b0C296Ea21,
                abi.encodeWithSelector(IVault.activeStakeAt.selector, timestamp, ""),
                abi.encode(1e18) // Non-zero stake
            );

            // 5. Impersonate middleware to call distributeRewards
            vm.startPrank(0x96d37DC47CBE2486E25c4a4587FFCdc48cDd3172);
            ERC20(getAddress(sourceChain, "WETH")).approve(rewardsContract, 100e18);
            
            IStakerRewards(rewardsContract).distributeRewards(
                0x96d37DC47CBE2486E25c4a4587FFCdc48cDd3172,
                getAddress(sourceChain, "WETH"),
                100e18,
                abi.encode(timestamp, maxAdminFee, "", "")
            );
            vm.stopPrank();


        (uint256 a, )  = IStakerRewards(getAddress(sourceChain, "wstETHSymbioticVaultRewards")).rewards(getAddress(sourceChain, "WETH"), 0x96d37DC47CBE2486E25c4a4587FFCdc48cDd3172, 0); 
        assertGt(a, 0); 

        }
 
        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[5];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "wstETHSymbioticVaultRewards");

        targetData = new bytes[](1);
        bytes[] memory activeSharesOfHints = new bytes[](0);
        bytes memory data = abi.encode(0x96d37DC47CBE2486E25c4a4587FFCdc48cDd3172, 100e18, activeSharesOfHints);
        targetData[0] = abi.encodeWithSignature("claimRewards(address,address,bytes)", boringVault, getAddress(sourceChain, "WETH"), data);

        values = new uint256[](1);

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);


    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface SymbioticVault {
    function currentEpoch() external view returns (uint256);
}

interface IStakerRewards {

     struct RewardDistribution {
        uint256 amount;
        uint48 timestamp;
    }

    function rewards(
        address token,
        address network,
        uint256 rewardIndex
    ) external view returns (uint256 amount, uint48 timestamp);
    
    function distributeRewards(address network, address token, uint256 amount, bytes calldata data) external;

}

interface INetworkMiddlewareService { 
    function  middleware(address _middleware) external view returns (address); 
}

interface IVault {
    function activeSharesAt(uint48 ts, bytes memory hint) external view returns (uint256); 
    function activeStakeAt(uint48 ts, bytes memory hint) external view returns (uint256); 
}
