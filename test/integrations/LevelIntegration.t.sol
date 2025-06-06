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
import {LevelDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LevelDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract LevelIntegrationTest is Test, MerkleTreeHelper {
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
        uint256 blockNumber = 22632756;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullLevelMoneyDecoderAndSanitizer());

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

    function testLvlUSDMintingAndRedeeming() external {
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100_000e6);
        deal(getAddress(sourceChain, "USDT"), address(boringVault), 100_000e6);

        address contractAddress = getAddress(sourceChain, "levelMinter");
        
        // contract has no funds to actually redeem on this block
        deal(getAddress(sourceChain, "USDC"), getAddress(sourceChain, "levelMinter"), 100_000e6);
        deal(getAddress(sourceChain, "USDT"), getAddress(sourceChain, "levelMinter"), 100_000e6);

        // loop through potential slots
        //for (uint256 slot = 0; slot < 20; slot++) {
        //    bytes32 slotValue = vm.load(contractAddress, bytes32(uint256(slot)));

        //    // Check if this slot contains a byte that's 0 (false) followed by a byte that's 1 (true)
        //    // Extract first byte (least significant)
        //    uint8 firstByte = uint8(uint256(slotValue) & 0xFF);
        //    // Extract second byte
        //    uint8 secondByte = uint8((uint256(slotValue) >> 8) & 0xFF);

        //    if (firstByte == 0 && secondByte == 1) {
        //        console.log("Found the slot! Slot number: %d", slot);
        //        console.log("Current value: 0x%x", uint256(slotValue));
        //        console.log("First byte (checkMinterRole): %d", firstByte);
        //        console.log("Second byte (checkRedeemerRole): %d", secondByte);

        //        // Now set checkRedeemerRole to false by clearing the second byte
        //        bytes32 newValue = slotValue & ~bytes32(uint256(0xFF) << 8);

        //        // Store the new value
        //        vm.store(contractAddress, bytes32(uint256(slot)), newValue);

        //        // Verify the change
        //        bytes32 verifyValue = vm.load(contractAddress, bytes32(uint256(slot)));
        //        console.log("Value after change: 0x%x", uint256(verifyValue));
        //    }
        //}
        

        vm.startPrank(0x0798880E772009DDf6eF062F2Ef32c738119d086); 
        RolesAuthority(0xc8425ACE617acA1dDcB09Cb7784b67403440098A).setPublicCapability(getAddress(sourceChain, "levelMinter"), 0xabaaabae, true); 
        vm.stopPrank(); 

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addLevelLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](7);
        manageLeafs[0] = leafs[0]; //approve usdc
        manageLeafs[1] = leafs[1]; //approve usdt
        manageLeafs[2] = leafs[2]; //approve lvlUSD
        manageLeafs[3] = leafs[3]; //usdc -> mint lvlUSD
        manageLeafs[4] = leafs[4]; //usdt -> mint lvlUSD
        manageLeafs[5] = leafs[5]; //initiateRedeem (USDC)
        manageLeafs[6] = leafs[6]; //initiateRedeem (USDC)

        (bytes32[][] memory manageProofs) = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](7);
        targets[0] = getAddress(sourceChain, "USDC"); //approve levelMinter
        targets[1] = getAddress(sourceChain, "USDT"); //approve levelMinter
        targets[2] = getAddress(sourceChain, "lvlUSD"); //approve levelMinter
        targets[3] = getAddress(sourceChain, "levelMinter"); //mintDefault (USDC)
        targets[4] = getAddress(sourceChain, "levelMinter"); //mintDefault (USDT)
        targets[5] = getAddress(sourceChain, "levelMinter"); //initiateRedeem (USDC)
        targets[6] = getAddress(sourceChain, "levelMinter"); //initiateRedeem (USDT)

        bytes[] memory targetData = new bytes[](7);
        targetData[0] =
            abi.encodeWithSelector(ERC20.approve.selector, getAddress(sourceChain, "levelShares"), type(uint256).max);
        targetData[1] =
            abi.encodeWithSelector(ERC20.approve.selector, getAddress(sourceChain, "levelShares"), type(uint256).max);
        targetData[2] =
            abi.encodeWithSelector(ERC20.approve.selector, getAddress(sourceChain, "levelMinter"), type(uint256).max);

        DecoderCustomTypes.LevelOrderV2 memory order = DecoderCustomTypes.LevelOrderV2(
            address(boringVault), //beneficiary
            getAddress(sourceChain, "USDC"),
            860000000, //gotten from on-chain
            859548540855159900000 //gotten from on-chain
        ); 

        targetData[3] =
            abi.encodeWithSignature("mint((address,address,uint256,uint256))", order);

        DecoderCustomTypes.LevelOrderV2 memory order1 = DecoderCustomTypes.LevelOrderV2(
            address(boringVault), //beneficiary
            getAddress(sourceChain, "USDT"),
            106513946, //gotten from on-chain
            106481991816200010000 //gotten from on-chain
        ); 

        targetData[4] =
            abi.encodeWithSignature("mint((address,address,uint256,uint256))", order1);

        targetData[5] =
            abi.encodeWithSignature("initiateRedeem(address,uint256,uint256)", getAddress(sourceChain, "USDC"), 24e18, 1e6); 

        targetData[6] =
            abi.encodeWithSignature("initiateRedeem(address,uint256,uint256)", getAddress(sourceChain, "USDT"), 10e18, 1e6); 

        uint256[] memory values = new uint256[](7);

        address[] memory decodersAndSanitizers = new address[](7);
        for (uint256 i = 0; i < decodersAndSanitizers.length; i++) {
            decodersAndSanitizers[i] = rawDataDecoderAndSanitizer;
        }

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);


        //skip time until we can complete the redeem 
        skip(12 hours); 

        manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[7]; //completeRedeem usdc
        manageLeafs[1] = leafs[8]; //completeRedeem usdt

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](2);
        targets[0] = getAddress(sourceChain, "levelMinter"); //initiateRedeem (USDC)
        targets[1] = getAddress(sourceChain, "levelMinter"); //initiateRedeem (USDT)

        targetData = new bytes[](2);

        targetData[0] =
            abi.encodeWithSignature("completeRedeem(address,address)", getAddress(sourceChain, "USDC"), address(boringVault));
        targetData[1] =
            abi.encodeWithSignature("completeRedeem(address,address)", getAddress(sourceChain, "USDT"), address(boringVault));

        values = new uint256[](2);

        decodersAndSanitizers = new address[](2);
        for (uint256 i = 0; i < decodersAndSanitizers.length; i++) {
            decodersAndSanitizers[i] = rawDataDecoderAndSanitizer;
        }

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        //uint256 expectedlvlUSDBalance = 67167210184620000; //dust 
        //uint256 lvlUSDBalance = getERC20(sourceChain, "lvlUSD").balanceOf(address(boringVault)); 
        //assertEq(expectedlvlUSDBalance, lvlUSDBalance); 
    }

    function testStakedLvlUSDFunctions() external {
        // Give BoringVault some slvlUSD.
        uint256 assets = 100_000e18;
        deal(getAddress(sourceChain, "slvlUSD"), address(boringVault), assets);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addLevelLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[16];
        manageLeafs[1] = leafs[17];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "slvlUSD");
        targets[1] = getAddress(sourceChain, "slvlUSD");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("cooldownAssets(uint256)", assets / 2);
        uint256 shares = ERC4626(getAddress(sourceChain, "slvlUSD")).previewWithdraw(assets / 2);
        targetData[1] = abi.encodeWithSignature("cooldownShares(uint256)", shares);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        EthenaSusde susde = EthenaSusde(getAddress(sourceChain, "slvlUSD"));
        (uint104 end, uint152 amount) = susde.cooldowns(address(boringVault));
        assertGt(end, block.timestamp, "Cooldown end should have been set.");
        assertEq(amount, assets, "Cooldown amount should equal assets.");

        // Wait the cooldown duration.
        skip(susde.cooldownDuration());

        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[18];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "slvlUSD");

        targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("unstake(address)", address(boringVault));

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        values = new uint256[](1);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            getERC20(sourceChain, "lvlUSD").balanceOf(address(boringVault)),
            amount,
            "BoringVault should have received unstaked lvlUSD."
        );
    }

    function testLevelERC4626Integration() external {
        deal(getAddress(sourceChain, "lvlUSD"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addLevelLeafs(leafs); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        //we cannot withdraw/redeem while cooldown active
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[11]; //approve
        manageLeafs[1] = leafs[12]; //deposit
        manageLeafs[2] = leafs[14]; //mint

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "lvlUSD");
        targets[1] = getAddress(sourceChain, "slvlUSD");
        targets[2] = getAddress(sourceChain, "slvlUSD");

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "slvlUSD"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("deposit(uint256,address)", 100e18, getAddress(sourceChain, "boringVault"));
        targetData[2] = //mint 10 shares
         abi.encodeWithSignature("mint(uint256,address)", 10e18, getAddress(sourceChain, "boringVault"));

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }
    

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullLevelMoneyDecoderAndSanitizer is LevelDecoderAndSanitizer {}

interface EthenaSusde {
    function cooldownDuration() external view returns (uint24);
    function cooldowns(address) external view returns (uint104 cooldownEnd, uint152 underlyingAmount);
}
