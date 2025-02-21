// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol"; import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol"; import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {SpectraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SpectraDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract SpectraIntegrationTest is Test, MerkleTreeHelper {
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
        uint256 blockNumber = 21868408;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullSpectraFinanceDecoderAndSanitizer());

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

    function testSpectraIntegrationWrappingFunctions() external {
        deal(getAddress(sourceChain, "GHO"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "stkGHO"), address(boringVault), 100_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addSpectraLeafs(
            leafs, 
            getAddress(sourceChain, "spectra_stkGHO_Pool"),
            getAddress(sourceChain, "spectra_stkGHO_PT"),
            getAddress(sourceChain, "spectra_stkGHO_YT"),
            getAddress(sourceChain, "spectra_stkGHO") //swToken
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree); 

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[0]; //approve GHO (for wrapping)
        manageLeafs[1] = leafs[1]; //approve stkGHO (on PT)
        manageLeafs[2] = leafs[6]; //wrap
        manageLeafs[3] = leafs[7]; //unwrap

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "GHO");
        targets[1] = getAddress(sourceChain, "stkGHO");
        targets[2] = getAddress(sourceChain, "spectra_stkGHO"); //wrap
        targets[3] = getAddress(sourceChain, "spectra_stkGHO"); //unwrap

        bytes[] memory targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "spectra_stkGHO_PT"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "spectra_stkGHO"), type(uint256).max
        );
        targetData[2] = 
            abi.encodeWithSignature(
                "wrap(uint256,address)", 1e8, address(boringVault));  
        targetData[3] = 
            abi.encodeWithSignature(
                "unwrap(uint256,address,address)", 1e8, address(boringVault), address(boringVault));  

        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](4);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        
    }

    function testSpectraPTERC4626Functions() external {
        deal(getAddress(sourceChain, "GHO"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "stkGHO"), address(boringVault), 100_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addSpectraLeafs(
            leafs, 
            getAddress(sourceChain, "spectra_stkGHO_Pool"),
            getAddress(sourceChain, "spectra_stkGHO_PT"),
            getAddress(sourceChain, "spectra_stkGHO_YT"),
            getAddress(sourceChain, "spectra_stkGHO") //swToken
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree); 

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        // withdraw(), mint(), and redeem() are not implemented in this Spectra contract
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve GHO
        manageLeafs[1] = leafs[8]; //deposit

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "GHO");
        targets[1] = getAddress(sourceChain, "spectra_stkGHO_PT"); //deposit

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "spectra_stkGHO_PT"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("deposit(uint256,address)", 100e18, getAddress(sourceChain, "boringVault"));


        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        
    }

    function testSpectraPTIBTFunctions() external {
        deal(getAddress(sourceChain, "GHO"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "stkGHO"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "spectra_stkGHO"), address(boringVault), 1000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addSpectraLeafs(
            leafs, 
            getAddress(sourceChain, "spectra_stkGHO_Pool"),
            getAddress(sourceChain, "spectra_stkGHO_PT"),
            getAddress(sourceChain, "spectra_stkGHO_YT"),
            getAddress(sourceChain, "spectra_stkGHO") //swToken
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree); 

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        // withdraw(), mint(), and redeem() are not implemented in this Spectra contract
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](7);
        manageLeafs[0] = leafs[3]; //approve PT to spend swIBT
        manageLeafs[1] = leafs[9]; //depositIBT
        manageLeafs[2] = leafs[11]; //redeemForIBT
        manageLeafs[3] = leafs[13]; //withdrawIBT
        manageLeafs[4] = leafs[15]; //updateYield
        manageLeafs[5] = leafs[16]; //claimYield
        manageLeafs[6] = leafs[17]; //burn (YT)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](7);
        targets[0] = getAddress(sourceChain, "spectra_stkGHO"); //swToken approves PT
        targets[1] = getAddress(sourceChain, "spectra_stkGHO_PT"); //depositIBT
        targets[2] = getAddress(sourceChain, "spectra_stkGHO_PT"); //redeemForIBT
        targets[3] = getAddress(sourceChain, "spectra_stkGHO_PT"); //withdrawIBT
        targets[4] = getAddress(sourceChain, "spectra_stkGHO_PT"); //updateYield
        targets[5] = getAddress(sourceChain, "spectra_stkGHO_PT"); //claimYield
        targets[6] = getAddress(sourceChain, "spectra_stkGHO_YT"); //claimYield

        bytes[] memory targetData = new bytes[](7);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "spectra_stkGHO_PT"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("depositIBT(uint256,address)", 100e18, getAddress(sourceChain, "boringVault"));
        targetData[2] =
            abi.encodeWithSignature("redeemForIBT(uint256,address,address)", 50e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"));
        targetData[3] =
            abi.encodeWithSignature("withdrawIBT(uint256,address,address)", 1e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"));
        targetData[4] =
            abi.encodeWithSignature("updateYield(address)", getAddress(sourceChain, "boringVault"));
        targetData[5] =
            abi.encodeWithSignature("claimYield(address,uint256)", getAddress(sourceChain, "boringVault"), 0);
        targetData[6] =
            abi.encodeWithSignature("burn(uint256)", 1e16);


        address[] memory decodersAndSanitizers = new address[](7);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](7);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        
    }
    
    //decoding the FE, we can see that when doing FixRate(), we are essentally just buying PTs from the curve pool
    function testFixRate() external {
        deal(getAddress(sourceChain, "GHO"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "stkGHO"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "spectra_stkGHO"), address(boringVault), 1000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addSpectraLeafs(
            leafs, 
            getAddress(sourceChain, "spectra_stkGHO_Pool"),
            getAddress(sourceChain, "spectra_stkGHO_PT"),
            getAddress(sourceChain, "spectra_stkGHO_YT"),
            getAddress(sourceChain, "spectra_stkGHO") //swToken
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree); 

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        // withdraw(), mint(), and redeem() are not implemented in this Spectra contract
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[1]; //approve swGHO
        manageLeafs[1] = leafs[6]; //wrap
        manageLeafs[2] = leafs[4]; //approve swToken swap in Curve Pool
        manageLeafs[3] = leafs[18]; //exchange() (sell swGHO for stkGHO_PT, fixing the rate)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "stkGHO"); //approve swGHO to spend our stkGHO to wrap it
        targets[1] = getAddress(sourceChain, "spectra_stkGHO"); //wrap
        targets[2] = getAddress(sourceChain, "spectra_stkGHO"); //approve curve pool
        targets[3] = getAddress(sourceChain, "spectra_stkGHO_Pool"); //exchange in curve pool swToken -> PT

        bytes[] memory targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "spectra_stkGHO"), type(uint256).max
        );
        targetData[1] = 
            abi.encodeWithSignature( "wrap(uint256,address)", 1e8, address(boringVault));  
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "spectra_stkGHO_Pool"), type(uint256).max
        );
        targetData[3] =
            abi.encodeWithSignature("exchange(uint256,uint256,uint256,uint256)", 0, 1, 50e18, 0);


        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](4);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        
        uint256 ptBalance = getERC20(sourceChain, "spectra_stkGHO_PT").balanceOf(address(boringVault)); 
        console.log("PT BALANCE AFTER SWAP: ", ptBalance); 
        assertGt(ptBalance, 0); 

    }

    function testAddLiquidity() external {
        deal(getAddress(sourceChain, "GHO"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "stkGHO"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "spectra_stkGHO"), address(boringVault), 1000e18);
        deal(getAddress(sourceChain, "spectra_stkGHO_PT"), address(boringVault), 1000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addSpectraLeafs(
            leafs, 
            getAddress(sourceChain, "spectra_stkGHO_Pool"),
            getAddress(sourceChain, "spectra_stkGHO_PT"),
            getAddress(sourceChain, "spectra_stkGHO_YT"),
            getAddress(sourceChain, "spectra_stkGHO") //swToken
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree); 

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        // withdraw(), mint(), and redeem() are not implemented in this Spectra contract
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[4]; //approve swGHO in curve pool
        manageLeafs[1] = leafs[5]; //approve swGHO_PT in curve pool
        manageLeafs[2] = leafs[19]; //add_liquidity
        manageLeafs[3] = leafs[20]; //remove_liqudity

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "spectra_stkGHO"); //swToken approves PT
        targets[1] = getAddress(sourceChain, "spectra_stkGHO_PT"); //depositIBT
        targets[2] = getAddress(sourceChain, "spectra_stkGHO_Pool"); //add_liquidity
        targets[3] = getAddress(sourceChain, "spectra_stkGHO_Pool"); //remove_liquidity

        bytes[] memory targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "spectra_stkGHO_Pool"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "spectra_stkGHO_Pool"), type(uint256).max
        );

        uint256[2] memory amounts; //fixed array size
        amounts[0] = 1e18;
        amounts[1] = 1e18;
        targetData[2] = abi.encodeWithSignature("add_liquidity(uint256[2],uint256)", amounts, 0);
        
        amounts[0] = 0; 
        amounts[1] = 0; 
        targetData[3] =
            abi.encodeWithSignature("remove_liquidity(uint256,uint256[2])", 1e18, amounts);


        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](4);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        
        //check that we have some remaining balance of lp tokens
        uint256 lpBalance = ERC20(0xa62cA1514944cC858a52E672DF52FDE0fda44A20).balanceOf(address(boringVault)); 
        console.log("LP BALANCE AFTER ADD AND REMOVE: ", lpBalance); 
        assertGt(lpBalance, 0); 

    }

    // do all these tests for the other kind of pools 
    function testSpectraPTERC4626Functions__NonSwToken() external {
        deal(getAddress(sourceChain, "lvlUSD"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "slvlUSD"), address(boringVault), 100_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addSpectraLeafs(
            leafs, 
            getAddress(sourceChain, "spectra_lvlUSD_Pool"),
            getAddress(sourceChain, "spectra_lvlUSD_PT"),
            getAddress(sourceChain, "spectra_lvlUSD_YT"),
            getAddress(sourceChain, "spectra_lvlUSD_IBT") //IBT
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree); 

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve GHO
        manageLeafs[1] = leafs[8]; //deposit

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "lvlUSD");
        targets[1] = getAddress(sourceChain, "spectra_lvlUSD_PT"); //deposit

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "spectra_lvlUSD_PT"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("deposit(uint256,address)", 100e18, getAddress(sourceChain, "boringVault"));


        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testSpectraPTIBTFunctions__nonSwToken() external {
        deal(getAddress(sourceChain, "lvlUSD"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "slvlUSD"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "spectra_lvlUSD_IBT"), address(boringVault), 1000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addSpectraLeafs(
            leafs, 
            getAddress(sourceChain, "spectra_lvlUSD_Pool"),
            getAddress(sourceChain, "spectra_lvlUSD_PT"),
            getAddress(sourceChain, "spectra_lvlUSD_YT"),
            getAddress(sourceChain, "spectra_lvlUSD_IBT") //swToken
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree); 

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        // withdraw(), mint(), and redeem() are not implemented in this Spectra contract
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](7);
        manageLeafs[0] = leafs[3]; //approve PT to spend swIBT
        manageLeafs[1] = leafs[9]; //depositIBT
        manageLeafs[2] = leafs[11]; //redeemForIBT
        manageLeafs[3] = leafs[13]; //withdrawIBT
        manageLeafs[4] = leafs[15]; //updateYield
        manageLeafs[5] = leafs[16]; //claimYield
        manageLeafs[6] = leafs[17]; //burn (YT)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](7);
        targets[0] = getAddress(sourceChain, "spectra_lvlUSD_IBT"); //staking token approves PT
        targets[1] = getAddress(sourceChain, "spectra_lvlUSD_PT"); //depositIBT
        targets[2] = getAddress(sourceChain, "spectra_lvlUSD_PT"); //redeemForIBT
        targets[3] = getAddress(sourceChain, "spectra_lvlUSD_PT"); //withdrawIBT
        targets[4] = getAddress(sourceChain, "spectra_lvlUSD_PT"); //updateYield
        targets[5] = getAddress(sourceChain, "spectra_lvlUSD_PT"); //claimYield
        targets[6] = getAddress(sourceChain, "spectra_lvlUSD_YT"); //claimYield

        bytes[] memory targetData = new bytes[](7);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "spectra_lvlUSD_PT"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("depositIBT(uint256,address)", 100e18, getAddress(sourceChain, "boringVault"));
        targetData[2] =
            abi.encodeWithSignature("redeemForIBT(uint256,address,address)", 50e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"));
        targetData[3] =
            abi.encodeWithSignature("withdrawIBT(uint256,address,address)", 1e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"));
        targetData[4] =
            abi.encodeWithSignature("updateYield(address)", getAddress(sourceChain, "boringVault"));
        targetData[5] =
            abi.encodeWithSignature("claimYield(address,uint256)", getAddress(sourceChain, "boringVault"), 0);
        targetData[6] =
            abi.encodeWithSignature("burn(uint256)", 1e16);


        address[] memory decodersAndSanitizers = new address[](7);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](7);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        
    }

    function testFixRate__NonSwToken() external {
        deal(getAddress(sourceChain, "lvlUSD"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "slvlUSD"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "spectra_lvlUSD_IBT"), address(boringVault), 1000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addSpectraLeafs(
            leafs, 
            getAddress(sourceChain, "spectra_lvlUSD_Pool"),
            getAddress(sourceChain, "spectra_lvlUSD_PT"),
            getAddress(sourceChain, "spectra_lvlUSD_YT"),
            getAddress(sourceChain, "spectra_lvlUSD_IBT") //swToken
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree); 

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        // withdraw(), mint(), and redeem() are not implemented in this Spectra contract
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[4]; //approve swToken swap in Curve Pool
        manageLeafs[1] = leafs[18]; //exchange() (sell swGHO for stkGHO_PT, fixing the rate)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "slvlUSD"); //approve curve pool
        targets[1] = getAddress(sourceChain, "spectra_lvlUSD_Pool"); //exchange in curve pool swToken -> PT

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "spectra_lvlUSD_Pool"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("exchange(uint256,uint256,uint256,uint256)", 0, 1, 50e18, 0);


        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        
        uint256 ptBalance = getERC20(sourceChain, "spectra_lvlUSD_PT").balanceOf(address(boringVault)); 
        console.log("PT BALANCE AFTER SWAP: ", ptBalance); 
        assertGt(ptBalance, 0); 

    }

    function testAddLiquidity__NonSwToken() external {
        deal(getAddress(sourceChain, "lvlUSD"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "slvlUSD"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "spectra_lvlUSD_IBT"), address(boringVault), 1000e18);
        deal(getAddress(sourceChain, "spectra_lvlUSD_PT"), address(boringVault), 1000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addSpectraLeafs(
            leafs, 
            getAddress(sourceChain, "spectra_lvlUSD_Pool"),
            getAddress(sourceChain, "spectra_lvlUSD_PT"),
            getAddress(sourceChain, "spectra_lvlUSD_YT"),
            getAddress(sourceChain, "spectra_lvlUSD_IBT") //swToken
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree); 

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        // withdraw(), mint(), and redeem() are not implemented in this Spectra contract
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[4]; //approve swGHO in curve pool
        manageLeafs[1] = leafs[5]; //approve swGHO_PT in curve pool
        manageLeafs[2] = leafs[19]; //add_liquidity
        manageLeafs[3] = leafs[20]; //remove_liqudity

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "spectra_lvlUSD_IBT"); //swToken approves PT
        targets[1] = getAddress(sourceChain, "spectra_lvlUSD_PT"); //depositIBT
        targets[2] = getAddress(sourceChain, "spectra_lvlUSD_Pool"); //add_liquidity
        targets[3] = getAddress(sourceChain, "spectra_lvlUSD_Pool"); //remove_liquidity

        bytes[] memory targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "spectra_lvlUSD_Pool"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "spectra_lvlUSD_Pool"), type(uint256).max
        );

        uint256[2] memory amounts; //fixed array size
        amounts[0] = 1e18;
        amounts[1] = 1e18;
        targetData[2] = abi.encodeWithSignature("add_liquidity(uint256[2],uint256)", amounts, 0);
        
        amounts[0] = 0; 
        amounts[1] = 0; 
        targetData[3] =
            abi.encodeWithSignature("remove_liquidity(uint256,uint256[2])", 1e18, amounts);


        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](4);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        
        //check that we have some remaining balance of lp tokens
        uint256 lpBalance = ERC20(0x15127Ef53F07F2B4FC0cc6B8CD2100170FFaFed6).balanceOf(address(boringVault)); 
        console.log("LP BALANCE AFTER ADD AND REMOVE: ", lpBalance); 
        assertGt(lpBalance, 0); 

    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}


contract FullSpectraFinanceDecoderAndSanitizer is SpectraDecoderAndSanitizer {}
