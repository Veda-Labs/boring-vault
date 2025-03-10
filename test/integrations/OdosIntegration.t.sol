// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract OdosIntegrationTest is Test, MerkleTreeHelper {
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

    function _setUpSpecificBlock__USDCSwap() internal {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21953429;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullOdosDecoderAndSanitizer(getAddress(sourceChain, "odosRouterV2")));

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

    function _setUpSpecificBlock__fxUSDSwap() internal {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 22018890;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullOdosDecoderAndSanitizer(getAddress(sourceChain, "odosRouterV2")));

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

    function _setUpSpecificBlock__WETHSwap() internal {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21953754;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullOdosDecoderAndSanitizer(getAddress(sourceChain, "odosRouterV2")));

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

    function _setUpSpecificBlock_SonicWETHSwap() internal {
        setSourceChainName("sonicMainnet");
        // Setup forked environment.
        string memory rpcKey = "SONIC_MAINNET_RPC_URL";
        uint256 blockNumber = 11169032; 

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullOdosDecoderAndSanitizer(getAddress(sourceChain, "odosRouterV2")));

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

    function testOdosSwapERC20() external {
        _setUpSpecificBlock__USDCSwap(); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e18);
        
        address[] memory tokens = new address[](3);   
        SwapKind[] memory kind = new SwapKind[](3);   
        tokens[0] = getAddress(sourceChain, "USDC"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = getAddress(sourceChain, "WETH"); 
        kind[1] = SwapKind.BuyAndSell; 
        tokens[2] = getAddress(sourceChain, "USDT"); 
        kind[2] = SwapKind.BuyAndSell; 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addOdosSwapLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0]; //approve usdc
        manageLeafs[1] = leafs[1]; //swap() usdc -> weth
        manageLeafs[2] = leafs[2]; //swapCompact() usdc -> weth

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "USDC"); //approve
        targets[1] = getAddress(sourceChain, "odosRouterV2"); //approve
        targets[2] = getAddress(sourceChain, "odosRouterV2"); //approve

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max
        );
        
        DecoderCustomTypes.swapTokenInfo memory swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "USDC"),
            inputAmount: 100000000,
            inputReceiver: getAddress(sourceChain, "odosExecutor"),
            outputToken: getAddress(sourceChain, "WETH"),
            outputQuote: 44870662095406488,
            outputMin: 44770662095406488,
            outputReceiver: address(boringVault)
        }); 

        bytes memory pathDefinition = hex"010203000d0101010201ff00000000000000000000000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000"; 

        targetData[1] = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)", swapTokenInfo, pathDefinition, getAddress(sourceChain, "odosExecutor"), 0
        );
        
        // @dev NOTE: this is swapCompact ABI-encoded. This tx data was retrieved directly from the Odos API. After assembling the tx, the output from the /assemble endpoint will return the following data in the data field. This includes everything needed for swapping. Submit the entire tx data as the targetData. Note that is already includes the function signature, etc.  
        targetData[2] = hex"83bd37f90001a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480001c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20405f5e10007a25b351495b2c8028f5c0001d768d1Fe6Ef1449A54F9409400fe9d0E4954ea3F000000015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f0000000003010204001201010201000001ab000004b500000000020d0001030201ff000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb486f40d4a6237c257fff2db00fa0510deeecd303ebcba27c8e7115b4eb50aa14999bc0866674a96ecb00000000"; 

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testOdosSwapERC20__Reverts() external {
        _setUpSpecificBlock__USDCSwap(); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e18);
        
        address[] memory tokens = new address[](3);   
        SwapKind[] memory kind = new SwapKind[](3);   
        tokens[0] = getAddress(sourceChain, "USDC"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = getAddress(sourceChain, "WETH"); 
        kind[1] = SwapKind.BuyAndSell; 
        tokens[2] = getAddress(sourceChain, "USDT"); 
        kind[2] = SwapKind.BuyAndSell; 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addOdosSwapLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0]; //approve usdc
        manageLeafs[1] = leafs[1]; //swap() usdc -> weth
        manageLeafs[2] = leafs[2]; //swapCompact() usdc -> weth

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "USDC"); //approve
        targets[1] = getAddress(sourceChain, "odosRouterV2"); //approve
        targets[2] = getAddress(sourceChain, "odosRouterV2"); //approve

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max
        );
        
        //include wrong output token 
        DecoderCustomTypes.swapTokenInfo memory swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "USDC"),
            inputAmount: 100000000,
            inputReceiver: getAddress(sourceChain, "odosExecutor"),
            outputToken: getAddress(sourceChain, "USDT"),
            outputQuote: 44870662095406488,
            outputMin: 44770662095406488,
            outputReceiver: address(boringVault)
        }); 

        bytes memory pathDefinition = hex"010203000d0101010201ff00000000000000000000000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000"; 

        targetData[1] = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)", swapTokenInfo, pathDefinition, getAddress(sourceChain, "odosExecutor"), 0
        );
        
        // @dev NOTE: this is swapCompact ABI-encoded. This tx data was retrieved directly from the Odos API. After assembling the tx, the output from the /assemble endpoint will return the following data in the data field. This includes everything needed for swapping. Submit the entire tx data as the targetData. Note that is already includes the function signature, etc.  
        targetData[2] = hex"83bd37f90001a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480001c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20405f5e10007a25b351495b2c8028f5c0001d768d1Fe6Ef1449A54F9409400fe9d0E4954ea3F000000015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f0000000003010204001201010201000001ab000004b500000000020d0001030201ff000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb486f40d4a6237c257fff2db00fa0510deeecd303ebcba27c8e7115b4eb50aa14999bc0866674a96ecb00000000"; 

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector, 
                targets[1], 
                targetData[1], 
                0
            )
        ); 
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        
        //correct output token
        swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "USDC"),
            inputAmount: 100000000,
            inputReceiver: getAddress(sourceChain, "odosExecutor"),
            outputToken: getAddress(sourceChain, "WETH"),
            outputQuote: 44870662095406488,
            outputMin: 44770662095406488,
            outputReceiver: address(boringVault)
        }); 

        targetData[1] = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)", swapTokenInfo, pathDefinition, getAddress(sourceChain, "odosExecutor"), 0
        );

        targetData[2] = hex"83bd37f90001a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480001dac17f958d2ee523a2206206994597c13d831ec70405f5e1000405f695c5028f5c0001d768d1Fe6Ef1449A54F9409400fe9d0E4954ea3F000131373595F40Ea48a7aAb6CBCB0d377C6066E2dCA00015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f0000000003010203005701010001020180000060ff0000000000000000000000000000000031373595f40ea48a7aab6cbcb0d377c6066e2dcaa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000"; 

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector, 
                targets[2], 
                targetData[2], 
                0
            )
        ); 

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

    }


    function testOdosSwapERC20__WETH() external {
        _setUpSpecificBlock__WETHSwap(); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e18);
        
        address[] memory tokens = new address[](3);   
        SwapKind[] memory kind = new SwapKind[](3);   
        tokens[0] = getAddress(sourceChain, "USDC"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = getAddress(sourceChain, "WETH"); 
        kind[1] = SwapKind.BuyAndSell; 
        tokens[2] = getAddress(sourceChain, "USDT"); 
        kind[2] = SwapKind.BuyAndSell; 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addOdosSwapLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[9]; //approve weth
        manageLeafs[1] = leafs[10]; //swap() weth -> usdt
        manageLeafs[2] = leafs[11]; //swapCompact() weth -> usdt

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "WETH"); //approve
        targets[1] = getAddress(sourceChain, "odosRouterV2"); //approve
        targets[2] = getAddress(sourceChain, "odosRouterV2"); //approve

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max
        );
        
        DecoderCustomTypes.swapTokenInfo memory swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "WETH"),
            inputAmount: 1e18,
            inputReceiver: getAddress(sourceChain, "odosExecutor"),
            outputToken: getAddress(sourceChain, "USDT"),
            outputQuote: 1,
            outputMin: 1,
            outputReceiver: address(boringVault)
        }); 

        bytes memory pathDefinition = hex"01020300510101010201077e6297b36a5670ff00000000000000000000000000352b186090068eb35d532428676ce510e17ab581c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000"; 

        targetData[1] = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)", swapTokenInfo, pathDefinition, getAddress(sourceChain, "odosExecutor"), 0
        );
        
        // @dev NOTE: this is swapCompact ABI-encoded. This tx data was retrieved directly from the Odos API. After assembling the tx, the output from the /assemble endpoint will return the following data in the data field. This includes everything needed for swapping. Submit the entire tx data as the targetData. Note that is already includes the function signature, etc.  
        targetData[2] = hex"83bd37f90001c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001dac17f958d2ee523a2206206994597c13d831ec7080de0b6b3a7640000048350be22028f5c0001d768d1Fe6Ef1449A54F9409400fe9d0E4954ea3F000000015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f0000000003010203000d0101010201ff000000000000000000000000000000000000000000c7bbec68d12a0d1830360f8ec58fa599ba1b0e9bc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000"; 

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testOdosSwapERC20_Sonic() external {
        _setUpSpecificBlock_SonicWETHSwap(); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        
        address[] memory tokens = new address[](3);   
        SwapKind[] memory kind = new SwapKind[](3);   
        tokens[0] = getAddress(sourceChain, "USDC"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = getAddress(sourceChain, "WETH"); 
        kind[1] = SwapKind.BuyAndSell; 
        tokens[2] = getAddress(sourceChain, "USDT"); 
        kind[2] = SwapKind.BuyAndSell; 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addOdosSwapLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[9]; //approve weth
        manageLeafs[1] = leafs[3]; //swap() weth -> usdc
        manageLeafs[2] = leafs[4]; //swapCompact() weth -> usdc

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "WETH"); //approve
        targets[1] = getAddress(sourceChain, "odosRouterV2"); //approve
        targets[2] = getAddress(sourceChain, "odosRouterV2"); //approve

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max
        );
        
        DecoderCustomTypes.swapTokenInfo memory swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "WETH"),
            inputAmount: 1e18,
            inputReceiver: getAddress(sourceChain, "odosExecutor"),
            outputToken: getAddress(sourceChain, "USDC"),
            outputQuote: 2239355834,
            outputMin: 2229355834,
            outputReceiver: address(boringVault)
        }); 
    
        //much longer path
        bytes memory pathDefinition = hex"04030a0102aa88cc0301000101020014012433768406010003020001a686fe0f06020104020001c5dfced4060201050200015b3a9e66060201060200000702010207eceabd67b0f236fe57f61e619d91e4b223eb75d20002000000000000000000bc02060201080901ff000000000000000000000000000000000000000000000f4dd4c3ccb1729f099b79d83540049758a5e9ff50c42deacd8fc9773493ed674b675be577f2634bb6d9b069f6b96a507243d501d1a23b3fccfc85d36fb30f3fcb864d49cdff15061ed5c6adfee40b40cfd41df89d060b72ebdd50d65f9021e4457c477efe809a1d337bdfc98b77a1067e3819f66d8ad23f29219dd400f2bf60e5a23d13be72b486d40388945c4b7d607aaf7b5cde9f09b5f03cf3b5c923aeea039e2fb66102314ce7b64ce5ce3e5183bc94ad38000000000000000000000000"; 

        targetData[1] = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)", swapTokenInfo, pathDefinition, getAddress(sourceChain, "odosExecutor"), 0
        );
        
        // @dev NOTE: this is swapCompact ABI-encoded. This tx data was retrieved directly from the Odos API. After assembling the tx, the output from the /assemble endpoint will return the following data in the data field. This includes everything needed for swapping. Submit the entire tx data as the targetData. Note that is already includes the function signature, etc.  
        targetData[2] = hex"83bd37f9000150c42deacd8fc9773493ed674b675be577f2634b000129219dd400f2bf60e5a23d13be72b486d4038894080de0b6b3a7640000048579dbba028f5c0001B28Ca7e465C452cE4252598e0Bc96Aeba553CF82000000015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f0000000006020307017015f2b506010001020001e6f4da260602010302000006020104020002060201050601ff000000000000000000000000000000000000000000000000b6d9b069f6b96a507243d501d1a23b3fccfc85d350c42deacd8fc9773493ed674b675be577f2634b6fb30f3fcb864d49cdff15061ed5c6adfee40b40cfd41df89d060b72ebdd50d65f9021e4457c477e9f46dd8f2a4016c26c1cf1f4ef90e5e1928d756b039e2fb66102314ce7b64ce5ce3e5183bc94ad380000000000000000"; 

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);


        uint256 usdcBal = getERC20(sourceChain, "USDC").balanceOf(address(boringVault)); 
        assertGt(usdcBal, 0); 
    }

    function testOdosSwapERC20_FxUSD() external {
        _setUpSpecificBlock__fxUSDSwap(); 

        deal(getAddress(sourceChain, "FXUSD"), address(boringVault), 1_000e18);
        
        address[] memory tokens = new address[](2);   
        SwapKind[] memory kind = new SwapKind[](2);   
        tokens[0] = getAddress(sourceChain, "FXUSD"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = getAddress(sourceChain, "USDT"); 
        kind[1] = SwapKind.BuyAndSell; 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addOdosSwapLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve fxUSD 
        manageLeafs[1] = leafs[1]; //swap() weth -> usdc
        //manageLeafs[2] = leafs[2]; //swapCompact() weth -> usdc

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "FXUSD"); //approve
        targets[1] = getAddress(sourceChain, "odosRouterV2"); //approve
        //targets[2] = getAddress(sourceChain, "odosRouterV2"); //approve

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max
        );
        
        DecoderCustomTypes.swapTokenInfo memory swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "FXUSD"),
            inputAmount: 1e18,
            inputReceiver: getAddress(sourceChain, "odosExecutor"),
            outputToken: getAddress(sourceChain, "USDT"),
            outputQuote: 1000254,
            outputMin: 1000000,
            outputReceiver: address(boringVault)
        }); 
    
        //much longer path
        //bytes memory pathDefinition = hex""; 

        //bytes memory pathDefinition = hex"010205006701000001020100020d0001030401ff0000000000000000000000001ee81c56e42ec34039d993d12410d437ddea341e085780639cc2cacd35e474e71f4d000e2405d8f6c2a856c3aff2110c1171b8f942256d40e980c726853d955acef822db058eb8505911ed77f175b99e00000000000000000000000000000000";
        
        //bytes memory pathDefinition = hex"010205006701000001020100020d0001030401ff0000000000000000000000001ee81c56e42ec34039d993d12410d437ddea341e085780639cc2cacd35e474e71f4d000e2405d8f6c2a856c3aff2110c1171b8f942256d40e980c726853d955acef822db058eb8505911ed77f175b99e00000000000000000000000000000000";
        
        targetData[1] = hex"3b635ce4000000000000000000000000085780639cc2cacd35e474e71f4d000e2405d8f60000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000001ee81c56e42ec34039d993d12410d437ddea341e000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000000000f49d400000000000000000000000000000000000000000000000000000000000f22b00000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f0000000000000000000000000000000000000000000000000000000000000140000000000000000000000000d768d1fe6ef1449a54f9409400fe9d0e4954ea3f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070010205006701000001020100020d0001030401ff0000000000000000000000001ee81c56e42ec34039d993d12410d437ddea341e085780639cc2cacd35e474e71f4d000e2405d8f6c2a856c3aff2110c1171b8f942256d40e980c726853d955acef822db058eb8505911ed77f175b99e00000000000000000000000000000000"; 

        //targetData[1] = abi.encodeWithSignature(
        //    "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)", swapTokenInfo, pathDefinition, getAddress(sourceChain, "odosExecutor"), 0
        //);
        
        // @dev NOTE: this is swapCompact ABI-encoded. This tx data was retrieved directly from the Odos API. After assembling the tx, the output from the /assemble endpoint will return the following data in the data field. This includes everything needed for swapping. Submit the entire tx data as the targetData. Note that is already includes the function signature, etc.  
        //targetData[1] = hex"83bd37f90001085780639cc2cacd35e474e71f4d000e2405d8f60001a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48080de0b6b3a7640000030f433e028f5c0001d768d1Fe6Ef1449A54F9409400fe9d0E4954ea3F00015018BE882DccE5E3F2f3B0913AE2096B9b3fB61f00015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f0000000003010203006701010001020100ff000000000000000000000000000000000000005018be882dcce5e3f2f3b0913ae2096b9b3fb61f085780639cc2cacd35e474e71f4d000e2405d8f6000000000000000000000000000000000000000000000000"; 

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);


        uint256 usdcBal = getERC20(sourceChain, "USDC").balanceOf(address(boringVault)); 
        assertGt(usdcBal, 0); 
    }


    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullOdosDecoderAndSanitizer is OdosDecoderAndSanitizer {
    constructor(address _odosRouter) OdosDecoderAndSanitizer(_odosRouter){}
}
