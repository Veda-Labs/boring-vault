// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {DolomiteDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DolomiteDecoderAndSanitizer.sol";  
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract DolomiteFinanceIntegrationTest is Test, MerkleTreeHelper {
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

    function _setUpArbitrum() internal {
        setSourceChainName("arbitrum");
        // Setup forked environment.
        string memory rpcKey = "ARBITRUM_RPC_URL";
        uint256 blockNumber = 298481162;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer =
            address(new FullDolomiteDecoderAndSanitizer(getAddress(sourceChain, "dolomiteMargin")));

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

    function _setUpBerachain() internal {
        setSourceChainName("berachain");
        // Setup forked environment.
        string memory rpcKey = "BERA_CHAIN_RPC_URL";
        uint256 blockNumber = 792906;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new FullDolomiteDecoderAndSanitizer(getAddress(sourceChain, "dolomiteMargin"))
        );

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

    function testDolomiteIntegrationDepositsAndWithdraws() external {
        _setUpArbitrum(); 

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e18);
        deal(address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "USDC"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //string memory filePath = "./testTEST.json";
        //_generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](13);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //depositWei
        manageLeafs[2] = leafs[2]; //depositWeiIntoDefault
        manageLeafs[3] = leafs[3]; //withdrawWei
        manageLeafs[4] = leafs[4]; //withdrawWeiFromDefault
        manageLeafs[5] = leafs[5]; //depositETH
        manageLeafs[6] = leafs[6]; //depositETHIntoDefault
        manageLeafs[7] = leafs[7]; //withdrawETH
        manageLeafs[8] = leafs[8]; //withdrawETHFromDefault
        manageLeafs[9] = leafs[9]; //depositPar
        manageLeafs[10] = leafs[10]; //depositParIntoDefault
        manageLeafs[11] = leafs[11]; //withdrawPar
        manageLeafs[12] = leafs[12]; //withdrawParFromDefault

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](13);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[2] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[3] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[4] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[5] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[6] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[7] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[8] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[9] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[10] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[11] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[12] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");

        uint256 marketId = IDolomiteMargin(getAddress(sourceChain, "dolomiteMargin")).getMarketIdByTokenAddress(
            getAddress(sourceChain, "USDC")
        );

        bytes[] memory targetData = new bytes[](13);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "dolomiteMargin"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature("depositWei(uint256,uint256,uint256)", 0, marketId, 100e6);
        targetData[2] = abi.encodeWithSignature("depositWeiIntoDefaultAccount(uint256,uint256)", marketId, 100e6);
        targetData[3] = abi.encodeWithSignature("withdrawWei(uint256,uint256,uint256,uint8)", 0, marketId, 100e6, 0);
        targetData[4] =
            abi.encodeWithSignature("withdrawWeiFromDefaultAccount(uint256,uint256,uint8)", marketId, 100e6, 0);
        targetData[5] = abi.encodeWithSignature("depositETH(uint256)", 0);
        targetData[6] = abi.encodeWithSignature("depositETHIntoDefaultAccount()");
        targetData[7] = abi.encodeWithSignature("withdrawETH(uint256,uint256,uint8)", 0, 1e18, 0);
        targetData[8] = abi.encodeWithSignature("withdrawETHFromDefaultAccount(uint256,uint8)", 1e18, 0);
        targetData[9] = abi.encodeWithSignature("depositPar(uint256,uint256,uint256)", 0, marketId, 100);
        targetData[10] = abi.encodeWithSignature("depositParIntoDefaultAccount(uint256,uint256)", marketId, 100);
        targetData[11] = abi.encodeWithSignature("withdrawPar(uint256,uint256,uint256,uint8)", 0, marketId, 100, 0);
        targetData[12] =
            abi.encodeWithSignature("withdrawParFromDefaultAccount(uint256,uint256,uint8)", marketId, 100, 0);

        address[] memory decodersAndSanitizers = new address[](13);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[10] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[11] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[12] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](13);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        values[4] = 0;
        values[5] = 1e18;
        values[6] = 1e18;
        values[7] = 0;
        values[8] = 0;
        values[9] = 0;
        values[10] = 0;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testDolomiteIntegrationBorrowing() external {
        _setUpArbitrum(); 

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e18);
        deal(address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "USDC"));
        _addDolomiteBorrowLeafs(leafs, getAddress(sourceChain, "WETH"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //string memory filePath = "./testTEST.json";
        //_generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //depositWei
        manageLeafs[2] = leafs[13]; //borrow
        manageLeafs[3] = leafs[16]; //transferBetweenAccounts
        manageLeafs[4] = leafs[15]; //repayAll
        manageLeafs[5] = leafs[14]; //closeBorrow

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](6);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[2] = getAddress(sourceChain, "dolomiteBorrowProxy");
        targets[3] = getAddress(sourceChain, "dolomiteBorrowProxy");
        targets[4] = getAddress(sourceChain, "dolomiteBorrowProxy");
        targets[5] = getAddress(sourceChain, "dolomiteBorrowProxy");

        uint256 marketId = IDolomiteMargin(getAddress(sourceChain, "dolomiteMargin")).getMarketIdByTokenAddress(
            getAddress(sourceChain, "USDC")
        );
        uint256 marketIdBorrow = IDolomiteMargin(getAddress(sourceChain, "dolomiteMargin")).getMarketIdByTokenAddress(
            getAddress(sourceChain, "WETH")
        );

        bytes[] memory targetData = new bytes[](6);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "dolomiteMargin"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature("depositWei(uint256,uint256,uint256)", 0, marketId, 100e6);
        targetData[2] = abi.encodeWithSignature(
            "openBorrowPosition(uint256,uint256,uint256,uint256,uint8)", 0, 1, marketIdBorrow, 10e6, 2
        );
        targetData[3] = abi.encodeWithSignature(
            "transferBetweenAccounts(uint256,uint256,uint256,uint256,uint8)", 1, 2, marketIdBorrow, 10e6, 2
        );
        targetData[4] =
            abi.encodeWithSignature("repayAllForBorrowPosition(uint256,uint256,uint256,uint8)", 0, 2, marketIdBorrow, 2);

        uint256[] memory collateralIds = new uint256[](1);
        collateralIds[0] = marketIdBorrow;

        targetData[5] = abi.encodeWithSignature("closeBorrowPosition(uint256,uint256,uint256[])", 2, 0, collateralIds);

        address[] memory decodersAndSanitizers = new address[](6);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](6);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testDolomiteIntegrationDepositsAndWithdrawsBerachain() external {
        _setUpBerachain(); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "WETH")); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //string memory filePath = "./testTEST.json";
        //_generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](9);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //depositWei
        manageLeafs[2] = leafs[2]; //depositWeiIntoDefault
        manageLeafs[3] = leafs[3]; //withdrawWei
        manageLeafs[4] = leafs[4]; //withdrawWeiFromDefault
        manageLeafs[5] = leafs[9]; //depositPar
        manageLeafs[6] = leafs[10]; //depositParIntoDefault
        manageLeafs[7] = leafs[11]; //withdrawPar
        manageLeafs[8] = leafs[12]; //withdrawParFromDefault

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](9);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[2] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[3] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[4] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[5] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[6] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[7] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");
        targets[8] = getAddress(sourceChain, "dolomiteDepositWithdrawRouter");

        uint256 marketId = IDolomiteMargin(getAddress(sourceChain, "dolomiteMargin")).getMarketIdByTokenAddress(getAddress(sourceChain, "WETH"));   

        bytes[] memory targetData = new bytes[](9);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "dolomiteMargin"), type(uint256).max);
        targetData[1] = 
            abi.encodeWithSignature("depositWei(uint256,uint256,uint256)", 0, marketId, 100e6);  
        targetData[2] = 
            abi.encodeWithSignature("depositWeiIntoDefaultAccount(uint256,uint256)", marketId, 100e6);  
        targetData[3] = 
            abi.encodeWithSignature("withdrawWei(uint256,uint256,uint256,uint8)", 0, marketId, 100e6, 0);  
        targetData[4] = 
            abi.encodeWithSignature("withdrawWeiFromDefaultAccount(uint256,uint256,uint8)", marketId, 100e6, 0);  
        targetData[5] = 
            abi.encodeWithSignature("depositPar(uint256,uint256,uint256)", 0, marketId, 100);  
        targetData[6] = 
            abi.encodeWithSignature("depositParIntoDefaultAccount(uint256,uint256)", marketId, 100);  
        targetData[7] = 
            abi.encodeWithSignature("withdrawPar(uint256,uint256,uint256,uint8)", 0, marketId, 100, 0);  
        targetData[8] = 
            abi.encodeWithSignature("withdrawParFromDefaultAccount(uint256,uint256,uint8)", marketId, 100, 0);  

        address[] memory decodersAndSanitizers = new address[](9);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](9);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testDolomiteDTokens() external {
        _setUpBerachain(); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "dWETH"))); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //deposit
        manageLeafs[2] = leafs[2]; //withdraw
        manageLeafs[3] = leafs[3]; //mint
        manageLeafs[4] = leafs[4]; //redeem

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](5);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "dWETH");
        targets[2] = getAddress(sourceChain, "dWETH");
        targets[3] = getAddress(sourceChain, "dWETH");
        targets[4] = getAddress(sourceChain, "dWETH");


        bytes[] memory targetData = new bytes[](5);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "dWETH"), type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("deposit(uint256,address)", 100e6, getAddress(sourceChain, "boringVault"));
        targetData[2] = abi.encodeWithSignature(
            "withdraw(uint256,address,address)",
            90e6,
            getAddress(sourceChain, "boringVault"),
            getAddress(sourceChain, "boringVault")
        );
        targetData[3] = //mint 10 shares
         abi.encodeWithSignature("mint(uint256,address)", 10e6, getAddress(sourceChain, "boringVault"));
        targetData[4] = //redeem 10 shares
        abi.encodeWithSignature(
            "redeem(uint256,address,address)",
            10e6,
            getAddress(sourceChain, "boringVault"),
            getAddress(sourceChain, "boringVault")
        );

        address[] memory decodersAndSanitizers = new address[](5);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](5);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullDolomiteDecoderAndSanitizer is DolomiteDecoderAndSanitizer, ERC4626DecoderAndSanitizer {
    constructor(address _dolomiteMargin) DolomiteDecoderAndSanitizer(_dolomiteMargin){}
}

interface IDolomiteMargin {
    function getMarketIdByTokenAddress(address token) external view returns (uint256);
}
