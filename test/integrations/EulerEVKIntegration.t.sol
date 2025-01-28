// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {EulerEVKFullDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EulerEVKFullDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {DroneLib} from "src/base/Drones/DroneLib.sol";
import {BoringDrone} from "src/base/Drones/BoringDrone.sol";

import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract EulerEVKIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;
    BoringDrone public boringDrone;

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
        uint256 blockNumber = 21695774;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);
        boringDrone = new BoringDrone(address(boringVault), 0);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new EulerEVKFullDecoderAndSanitizer());

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
    }

    //function testEulerEVKIntegration() external {
    //    deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
    //    ERC4626 evkWETH = ERC4626(getAddress(sourceChain, "evkWETH"));
    //    ERC4626 evkUSDC = ERC4626(getAddress(sourceChain, "evkUSDC"));

    //    ERC4626[] memory depositVaults = new ERC4626[](1);  
    //    depositVaults[0] = evkWETH; 

    //    ERC4626[] memory borrowVaults = new ERC4626[](1);  
    //    borrowVaults[0] = evkUSDC; 

    //    address[] memory subaccounts = new address[](1); 
    //    subaccounts[0] = address(boringVault); 

    //    ManageLeaf[] memory leafs = new ManageLeaf[](16);
    //    _addEulerDepositLeafs(leafs, depositVaults, subaccounts); 
    //    _addEulerBorrowLeafs(leafs, borrowVaults, subaccounts);

    //    bytes32[][] memory manageTree = _generateMerkleTree(leafs);

    //    manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

    //    ManageLeaf[] memory manageLeafs = new ManageLeaf[](11);
    //    manageLeafs[0] = leafs[0]; //approve for deposit
    //    manageLeafs[1] = leafs[1]; //deposit
    //    manageLeafs[2] = leafs[2]; //withdraw
    //    manageLeafs[3] = leafs[3]; //mint
    //    manageLeafs[4] = leafs[4]; //redeem
    //    manageLeafs[5] = leafs[7]; //approve
    //    manageLeafs[6] = leafs[8]; //enableController
    //    manageLeafs[7] = leafs[5]; //enableCollateral
    //    manageLeafs[8] = leafs[9]; //borrow
    //    manageLeafs[9] = leafs[10]; //repay
    //    manageLeafs[10] = leafs[11]; //repayWithShares

    //    bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

    //    address[] memory targets = new address[](11);
    //    targets[0] = getAddress(sourceChain, "WETH");
    //    targets[1] = getAddress(sourceChain, "evkWETH");
    //    targets[2] = getAddress(sourceChain, "evkWETH");
    //    targets[3] = getAddress(sourceChain, "evkWETH");
    //    targets[4] = getAddress(sourceChain, "evkWETH");

    //    targets[5] = getAddress(sourceChain, "USDC");
    //    targets[6] = getAddress(sourceChain, "ethereumVaultConnector");
    //    targets[7] = getAddress(sourceChain, "ethereumVaultConnector");
    //    targets[8] = getAddress(sourceChain, "evkUSDC");
    //    targets[9] = getAddress(sourceChain, "evkUSDC");
    //    targets[10] = getAddress(sourceChain, "evkUSDC");

    //    bytes[] memory targetData = new bytes[](11);
    //    targetData[0] =
    //        abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "evkWETH"), type(uint256).max);
    //    targetData[1] = abi.encodeWithSignature("deposit(uint256,address)", 1000e18, address(boringVault));
    //    targetData[2] = abi.encodeWithSignature(
    //        "withdraw(uint256,address,address)", 1e18, address(boringVault), address(boringVault)
    //    );
    //    targetData[3] = abi.encodeWithSignature("mint(uint256,address)", 100, address(boringVault));
    //    targetData[4] =
    //        abi.encodeWithSignature("redeem(uint256,address,address)", 100, address(boringVault), address(boringVault));
    //    targetData[5] =
    //        abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "evkUSDC"), type(uint256).max);
    //    targetData[6] = abi.encodeWithSignature(
    //        "enableController(address,address)", address(boringVault), getAddress(sourceChain, "evkUSDC")
    //    );
    //    targetData[7] = abi.encodeWithSignature(
    //        "enableCollateral(address,address)", address(boringVault), getAddress(sourceChain, "evkWETH")
    //    );
    //    targetData[8] = abi.encodeWithSignature("borrow(uint256,address)", 1e6, address(boringVault));
    //    targetData[9] = abi.encodeWithSignature("repay(uint256,address)", 1e4, address(boringVault));
    //    targetData[10] =
    //        abi.encodeWithSignature("repayWithShares(uint256,address)", type(uint256).max, address(boringVault));

    //    uint256[] memory values = new uint256[](11);

    //    address[] memory decodersAndSanitizers = new address[](11);
    //    decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[10] = rawDataDecoderAndSanitizer;

    //    manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    //}

    //function testEulerEVKIntegrationDisableCollateral() external {
    //    deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
    //    ERC4626 evkWETH = ERC4626(getAddress(sourceChain, "evkWETH"));
    //    ERC4626 evkUSDC = ERC4626(getAddress(sourceChain, "evkUSDC"));

    //    ERC4626[] memory depositVaults = new ERC4626[](1);  
    //    depositVaults[0] = evkWETH; 

    //    ERC4626[] memory borrowVaults = new ERC4626[](1);  
    //    borrowVaults[0] = evkUSDC; 

    //    address[] memory subaccounts = new address[](1); 
    //    subaccounts[0] = address(boringVault); 

    //    ManageLeaf[] memory leafs = new ManageLeaf[](16);
    //    _addEulerDepositLeafs(leafs, depositVaults, subaccounts); 
    //    _addEulerBorrowLeafs(leafs, borrowVaults, subaccounts);

    //    bytes32[][] memory manageTree = _generateMerkleTree(leafs);

    //    manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

    //    ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
    //    manageLeafs[0] = leafs[7]; //approve borrow vault
    //    manageLeafs[1] = leafs[8]; //enableController
    //    manageLeafs[2] = leafs[5]; //enableCollateral
    //    manageLeafs[3] = leafs[6]; //disableCollateral
    //    manageLeafs[4] = leafs[12]; //disableController

    //    bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

    //    address[] memory targets = new address[](5);
    //    targets[0] = getAddress(sourceChain, "USDC");
    //    targets[1] = getAddress(sourceChain, "ethereumVaultConnector");
    //    targets[2] = getAddress(sourceChain, "ethereumVaultConnector");
    //    targets[3] = getAddress(sourceChain, "ethereumVaultConnector");
    //    targets[4] = getAddress(sourceChain, "evkUSDC");

    //    bytes[] memory targetData = new bytes[](5);
    //    targetData[0] =
    //        abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "evkUSDC"), type(uint256).max);
    //    targetData[1] = abi.encodeWithSignature(
    //        "enableController(address,address)", address(boringVault), getAddress(sourceChain, "evkUSDC")
    //    );
    //    targetData[2] = abi.encodeWithSignature(
    //        "enableCollateral(address,address)", address(boringVault), getAddress(sourceChain, "evkWETH")
    //    );
    //    targetData[3] = abi.encodeWithSignature(
    //        "disableCollateral(address,address)", address(boringVault), getAddress(sourceChain, "evkWETH")
    //    );
    //    targetData[4] = abi.encodeWithSignature("disableController()");

    //    uint256[] memory values = new uint256[](5);

    //    address[] memory decodersAndSanitizers = new address[](5);
    //    decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

    //    manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    //}


    //function testEulerEVKIntegrationEulerPrimeMultiple() external {
    //    deal(getAddress(sourceChain, "LBTC"), address(boringVault), 1_000e18);
    //    deal(getAddress(sourceChain, "WEETH"), address(boringVault), 1_000e18);
    //    ERC4626 evkLBTC = ERC4626(getAddress(sourceChain, "evkLBTC"));
    //    ERC4626 evkWEETH = ERC4626(getAddress(sourceChain, "evkWEETH"));

    //    ERC4626 evkUSDC = ERC4626(getAddress(sourceChain, "evkUSDC"));
    //    //ERC4626 evkWETH = ERC4626(getAddress(sourceChain, "evkWETH"));

    //    ERC4626[] memory depositVaults = new ERC4626[](2);  
    //    depositVaults[0] = evkLBTC; 
    //    depositVaults[1] = evkWEETH; 

    //    ERC4626[] memory borrowVaults = new ERC4626[](2);  
    //    borrowVaults[0] = evkUSDC; 
    //    borrowVaults[1] = evkUSDC; 

    //    address[] memory subaccounts = new address[](2); 
    //    subaccounts[0] = address(boringVault); 
    //    subaccounts[1] = address(uint160(address(boringVault)) ^ 0x10); 

    //    ManageLeaf[] memory leafs = new ManageLeaf[](128);
    //    _addEulerDepositLeafs(leafs, depositVaults, subaccounts); 
    //    _addEulerBorrowLeafs(leafs, borrowVaults, subaccounts); 


    //    bytes32[][] memory manageTree = _generateMerkleTree(leafs);

    //    string memory filePath = "./testTEST.json";
    //    _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    //    manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

    //    ManageLeaf[] memory manageLeafs = new ManageLeaf[](12);
    //    manageLeafs[0] = leafs[0]; //approve for deposit account 0
    //    manageLeafs[1] = leafs[1]; //deposit account 0
    //    manageLeafs[2] = leafs[5]; //enableCollateral acount 0

    //    manageLeafs[3] = leafs[21]; //approve for deposit subaccount 1
    //    manageLeafs[4] = leafs[22]; //deposit subaccount 1
    //    manageLeafs[5] = leafs[26]; //enableCollateral subaccount 1
    //    
    //    manageLeafs[6] = leafs[28]; //approve usdc account 0
    //    manageLeafs[7] = leafs[29]; //enableController account 0
    //    manageLeafs[8] = leafs[30]; //borrow account 0

    //    manageLeafs[9] = leafs[46]; //approve subaccount 1
    //    manageLeafs[10] = leafs[47]; //enableController subaccount 1
    //    manageLeafs[11] = leafs[48]; //borrow subaccount 1

    //    bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

    //    address[] memory targets = new address[](12);
    //    targets[0] = getAddress(sourceChain, "LBTC");
    //    targets[1] = getAddress(sourceChain, "evkLBTC");
    //    targets[2] = getAddress(sourceChain, "ethereumVaultConnector");

    //    targets[3] = getAddress(sourceChain, "WEETH");
    //    targets[4] = getAddress(sourceChain, "evkWEETH"); 
    //    targets[5] = getAddress(sourceChain, "ethereumVaultConnector");

    //    targets[6] = getAddress(sourceChain, "USDC");  
    //    targets[7] = getAddress(sourceChain, "ethereumVaultConnector");  
    //    targets[8] = getAddress(sourceChain, "evkUSDC"); 

    //    targets[9] = getAddress(sourceChain, "USDC");  
    //    targets[10] = getAddress(sourceChain, "ethereumVaultConnector"); //enable controller
    //    targets[11] = getAddress(sourceChain, "evkUSDC"); 

    //    bytes[] memory targetData = new bytes[](12);
    //    targetData[0] =
    //        abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "evkLBTC"), type(uint256).max);
    //    targetData[1] = abi.encodeWithSignature("deposit(uint256,address)", 1e8, subaccounts[0]);
    //    targetData[2] = abi.encodeWithSignature("enableCollateral(address,address)", subaccounts[0], getAddress(sourceChain, "evkLBTC"));
    //    targetData[3] = 
    //        abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "evkWEETH"), type(uint256).max);
    //    targetData[4] = abi.encodeWithSignature("deposit(uint256,address)", 1e18, subaccounts[1]);
    //    targetData[5] = abi.encodeWithSignature("enableCollateral(address,address)", subaccounts[1], getAddress(sourceChain, "evkWEETH"));
    //    targetData[6] = 
    //        abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "evkUSDC"), type(uint256).max);
    //    targetData[7] = 
    //        abi.encodeWithSignature("enableController(address,address)", address(boringVault), getAddress(sourceChain, "evkUSDC"));
    //    targetData[8] = 
    //        abi.encodeWithSignature("borrow(uint256,address)", 100e8, address(boringVault));
    //    targetData[9] = 
    //        abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "evkUSDC"), type(uint256).max);
    //    targetData[10] = 
    //        abi.encodeWithSignature("enableController(address,address)", subaccounts[1], getAddress(sourceChain, "evkUSDC"));
    //    targetData[11] = 
    //        abi.encodeWithSignature("borrow(uint256,address)", 100e8, subaccounts[1]);


    //    uint256[] memory values = new uint256[](12);

    //    address[] memory decodersAndSanitizers = new address[](12);
    //    decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[10] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[11] = rawDataDecoderAndSanitizer;

    //    manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    //}

    function testEulerEVKIntegrationSubaccountsViaCall() external {
        deal(getAddress(sourceChain, "LBTC"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6);
        deal(getAddress(sourceChain, "DAI"), address(boringVault), 10e18);
        ERC4626 evkLBTC = ERC4626(getAddress(sourceChain, "evkLBTC"));
        //ERC4626 evkWEETH = ERC4626(getAddress(sourceChain, "evkWEETH"));

        ERC4626 evkUSDC = ERC4626(getAddress(sourceChain, "evkUSDC"));
        ERC4626 evkDAI = ERC4626(getAddress(sourceChain, "evkDAI"));

        ERC4626[] memory depositVaults = new ERC4626[](2);  
        depositVaults[0] = evkLBTC; 
        depositVaults[1] = evkUSDC; 

        ERC4626[] memory borrowVaults = new ERC4626[](2);  
        borrowVaults[0] = evkUSDC; 
        borrowVaults[1] = evkDAI; 

        address[] memory subaccounts = new address[](2); 
        subaccounts[0] = address(boringVault); 
        subaccounts[1] = address(uint160(address(boringVault)) ^ 0x10); 

        ManageLeaf[] memory leafs = new ManageLeaf[](128);
        _addEulerDepositLeafs(leafs, depositVaults, subaccounts); 
        _addEulerBorrowLeafs(leafs, borrowVaults, subaccounts); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[24]; //approve for deposit subaccount 1
        manageLeafs[1] = leafs[25]; //deposit subaccount 1
        manageLeafs[2] = leafs[29]; //enableCollateral subaccount 1

        manageLeafs[3] = leafs[53]; //approve subaccount 1
        manageLeafs[4] = leafs[54]; //enableController subaccount 1
        manageLeafs[5] = leafs[59]; //borrow subaccount 1 via call

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](6);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "evkUSDC"); 
        targets[2] = getAddress(sourceChain, "ethereumVaultConnector");

        targets[3] = getAddress(sourceChain, "DAI");  
        targets[4] = getAddress(sourceChain, "ethereumVaultConnector"); //enable controller
        targets[5] = getAddress(sourceChain, "ethereumVaultConnector"); 

        bytes[] memory targetData = new bytes[](6);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "evkUSDC"), type(uint256).max);
        targetData[1] = abi.encodeWithSignature("deposit(uint256,address)", 1000e6, subaccounts[1]);
        targetData[2] = abi.encodeWithSignature("enableCollateral(address,address)", subaccounts[1], getAddress(sourceChain, "evkUSDC"));

        targetData[3] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "evkDAI"), type(uint256).max);
        targetData[4] = abi.encodeWithSignature("enableController(address,address)", subaccounts[1], getAddress(sourceChain, "evkDAI"));

        bytes memory functionToCall = abi.encodeWithSignature("borrow(uint256,address)", 10e18, subaccounts[0]); 
            
        targetData[5] = 
            abi.encodeWithSignature(
                "call(address,address,uint256,bytes)",
                address(evkDAI),
                address(subaccounts[1]),
                uint256(0),
                functionToCall 
            ); 

        uint256[] memory values = new uint256[](6);

        address[] memory decodersAndSanitizers = new address[](6);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        
        uint256 daiBalance = ERC20(getAddress(sourceChain, "DAI")).balanceOf(address(boringVault)); 
        assertEq(daiBalance, 20e18); 


        //skip some time 
        skip(2 days); 
        
        //now we try and repay our loan, disable the controller for our subaccount, and withdraw our usdc
       
        manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[56]; //repay
        manageLeafs[1] = leafs[58]; //disableContoller (dai)
        manageLeafs[2] = leafs[31]; //call (withdraw) on USDC (depositVault)

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](3);
        targets[0] = getAddress(sourceChain, "evkDAI"); 
        targets[1] = getAddress(sourceChain, "evkDAI"); 
        targets[2] = getAddress(sourceChain, "ethereumVaultConnector"); 

        targetData = new bytes[](3); 
        targetData[0] = abi.encodeWithSignature("repay(uint256,address)", type(uint256).max, subaccounts[1]); 
        targetData[1] = abi.encodeWithSignature("disableController()");  

        functionToCall = abi.encodeWithSignature("withdraw(uint256,address,address)", 1000e6, subaccounts[0], subaccounts[1]); 
            
        targetData[2] = 
            abi.encodeWithSignature(
                "call(address,address,uint256,bytes)",
                address(evkUSDC),
                address(subaccounts[1]),
                uint256(0),
                functionToCall 
            ); 

        values = new uint256[](3);

        decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 usdcBalance = getERC20(sourceChain, "USDC").balanceOf(address(boringVault)); 
        assertEq(usdcBalance, 1000e6); 

    }


    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface IEVK {
    function balanceOf(address user) external view returns (uint256);
    function asset() external view returns (address);
    function creator() external view returns (address);
}

interface IEVC {
    function getAccountOwner(address account) external view returns (address); 
}

