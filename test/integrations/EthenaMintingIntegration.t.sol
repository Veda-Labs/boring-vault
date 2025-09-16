// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; import {ERC20} from "@solmate/tokens/ERC20.sol";
import {EthenaMintingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EthenaMintingDecoderAndSanitizer.sol"; 
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullEthenaMintingDecoderAndSanitizer is EthenaMintingDecoderAndSanitizer, BaseDecoderAndSanitizer{}


contract EthenaMintingIntegrationTest is BaseTestIntegration {


    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 23370056); 
            
        address ethenaDecoder = address(new FullEthenaMintingDecoderAndSanitizer()); 

        _overrideDecoder(ethenaDecoder); 
    }

    function testEthenaMint() external {
        _setUpMainnet(); 

        //get env var
        uint256 privateKey = vm.envUint("PRIVATE_KEY"); 
        address signer = vm.addr(privateKey); 

        vm.startPrank(0x3B0AAf6e6fCd4a7cEEf8c92C32DFeA9E64dC1862); 
        IRoleGranter(0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3).grantRole(0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6, address(boringVault)); 
        IRoleGranter(getAddress(sourceChain, "ethenaMinterV2")).addWhitelistedBenefactor(address(boringVault)); 
        vm.stopPrank(); 


        deal(getAddress(sourceChain, "USDT"), address(boringVault), 100_000_000e6);  

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addEthenaMintingLeafs(leafs, signer); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[1]; //approve USDT
        tx_.manageLeafs[1] = leafs[2]; //setDelegatedSigner 

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "USDT"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "ethenaMinterV2");  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "ethenaMinterV2"), type(uint256).max
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "setDelegatedSigner(address)", signer 
        ); 


        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 

        
        //accept the signer status
        vm.prank(signer); 
        IRoleGranter(getAddress(sourceChain, "ethenaMinterV2")).confirmDelegatedSigner(address(boringVault)); 


        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[4]; //mint w/ USDT

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "ethenaMinterV2");  

        DecoderCustomTypes.EthenaOrder memory order = DecoderCustomTypes.EthenaOrder(
            "RFQ-P0VD6VB7S5OXY",
            DecoderCustomTypes.EthenaOrderType.MINT,
            1757959283,
            1757959283,
            address(boringVault), 
            address(boringVault), 
            getAddress(sourceChain, "USDT"),
            1531628760000,
            1530859540000000000000000
        ); 

        address[] memory eRoute = new address[](1); 
        eRoute[0] = 0x8f0eE0393Eae7fc1638BD7860a3FEc6a663786AE; 
        uint128[] memory eRatio = new uint128[](1); 
        eRatio[0] = 10000; 

        DecoderCustomTypes.EthenaRoute memory routes = DecoderCustomTypes.EthenaRoute(
            eRoute,
            eRatio
        ); 

        bytes32 orderHash = IRoleGranter(getAddress(sourceChain, "ethenaMinterV2")).hashOrder(order); 
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, orderHash);
        bytes memory sigBytes = abi.encodePacked(r, s, v);

        DecoderCustomTypes.EthenaSignature memory signature = DecoderCustomTypes.EthenaSignature(
            DecoderCustomTypes.SignatureType.EIP712,
            sigBytes
        ); 

        tx_.targetData[0] = abi.encodeWithSignature(
            "mint((string,uint8,uint120,uint128,address,address,address,uint128,uint128),(address[],uint128[]),(uint8,bytes))",
            order,
            routes,
            signature
        ); 
        
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        uint256 usdeBalance = getERC20(sourceChain, "USDE").balanceOf(address(boringVault)); 
        assertEq(usdeBalance, 1530859540000000000000000); 
    }

    function testEthenaRedeem() external {
        _setUpMainnet(); 

        //get env var
        uint256 privateKey = vm.envUint("PRIVATE_KEY"); 
        address signer = vm.addr(privateKey); 

        vm.startPrank(0x3B0AAf6e6fCd4a7cEEf8c92C32DFeA9E64dC1862); 
        IRoleGranter(0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3).grantRole(0x44ac9762eec3a11893fefb11d028bb3102560094137c3ed4518712475b2577cc, address(boringVault)); 
        IRoleGranter(getAddress(sourceChain, "ethenaMinterV2")).addWhitelistedBenefactor(address(boringVault)); 
        vm.stopPrank(); 


        deal(getAddress(sourceChain, "USDE"), address(boringVault), 9909000000000000000000); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addEthenaMintingLeafs(leafs, signer); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve USDE
        tx_.manageLeafs[1] = leafs[2]; //setDelegatedSigner 

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "USDE"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "ethenaMinterV2");  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "ethenaMinterV2"), type(uint256).max
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "setDelegatedSigner(address)", signer 
        ); 


        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 

        
        //accept the signer status
        vm.prank(signer); 
        IRoleGranter(getAddress(sourceChain, "ethenaMinterV2")).confirmDelegatedSigner(address(boringVault)); 


        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[5]; //reddem for USDT

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "ethenaMinterV2");  

        DecoderCustomTypes.EthenaOrder memory order = DecoderCustomTypes.EthenaOrder(
            "RFQ-P0VD6VB7S5OXY",
            DecoderCustomTypes.EthenaOrderType.REDEEM,
            1757959283,
            1757959283,
            address(boringVault), 
            address(boringVault), 
            getAddress(sourceChain, "USDT"),
            9903565040,
            9909000000000000000000
        ); 

        bytes32 orderHash = IRoleGranter(getAddress(sourceChain, "ethenaMinterV2")).hashOrder(order); 
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, orderHash);
        bytes memory sigBytes = abi.encodePacked(r, s, v);

        DecoderCustomTypes.EthenaSignature memory signature = DecoderCustomTypes.EthenaSignature(
            DecoderCustomTypes.SignatureType.EIP712,
            sigBytes
        ); 

        tx_.targetData[0] = abi.encodeWithSignature(
            "redeem((string,uint8,uint120,uint128,address,address,address,uint128,uint128),(uint8,bytes))",
            order,
            signature
        ); 
        
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        uint256 usdtBalance = getERC20(sourceChain, "USDT").balanceOf(address(boringVault)); 
        assertEq(usdtBalance, 9903565040); 
    }

    function testEthenaMintRevertsIfSignerRemoved() external {
        _setUpMainnet(); 

        //get env var
        uint256 privateKey = vm.envUint("PRIVATE_KEY"); 
        address signer = vm.addr(privateKey); 

        vm.startPrank(0x3B0AAf6e6fCd4a7cEEf8c92C32DFeA9E64dC1862); 
        IRoleGranter(0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3).grantRole(0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6, address(boringVault)); 
        IRoleGranter(getAddress(sourceChain, "ethenaMinterV2")).addWhitelistedBenefactor(address(boringVault)); 
        vm.stopPrank(); 


        deal(getAddress(sourceChain, "USDT"), address(boringVault), 100_000_000e6);  

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addEthenaMintingLeafs(leafs, signer); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[1]; //approve USDT
        tx_.manageLeafs[1] = leafs[2]; //setDelegatedSigner 

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "USDT"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "ethenaMinterV2");  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "ethenaMinterV2"), type(uint256).max
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "setDelegatedSigner(address)", signer 
        ); 


        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 

        
        //accept the signer status
        vm.prank(signer); 
        IRoleGranter(getAddress(sourceChain, "ethenaMinterV2")).confirmDelegatedSigner(address(boringVault)); 


        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[3]; //remove delegated signer

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "ethenaMinterV2");  

        tx_.targetData[0] = abi.encodeWithSignature(
            "removeDelegatedSigner(address)", signer
        ); 
        
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        

        //try to mint now
        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[4]; //mint w/ USDT

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "ethenaMinterV2");  

        DecoderCustomTypes.EthenaOrder memory order = DecoderCustomTypes.EthenaOrder(
            "RFQ-P0VD6VB7S5OXY",
            DecoderCustomTypes.EthenaOrderType.MINT,
            1757959283,
            1757959283,
            address(boringVault), 
            address(boringVault), 
            getAddress(sourceChain, "USDT"),
            1531628760000,
            1530859540000000000000000
        ); 

        address[] memory eRoute = new address[](1); 
        eRoute[0] = 0x8f0eE0393Eae7fc1638BD7860a3FEc6a663786AE; 
        uint128[] memory eRatio = new uint128[](1); 
        eRatio[0] = 10000; 

        DecoderCustomTypes.EthenaRoute memory routes = DecoderCustomTypes.EthenaRoute(
            eRoute,
            eRatio
        ); 

        bytes32 orderHash = IRoleGranter(getAddress(sourceChain, "ethenaMinterV2")).hashOrder(order); 
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, orderHash);
        bytes memory sigBytes = abi.encodePacked(r, s, v);

        DecoderCustomTypes.EthenaSignature memory signature = DecoderCustomTypes.EthenaSignature(
            DecoderCustomTypes.SignatureType.EIP712,
            sigBytes
        ); 

        tx_.targetData[0] = abi.encodeWithSignature(
            "mint((string,uint8,uint120,uint128,address,address,address,uint128,uint128),(address[],uint128[]),(uint8,bytes))",
            order,
            routes,
            signature
        ); 
        
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        
        vm.expectRevert(); 
        _submitManagerCall(manageProofs, tx_); 
        
        uint256 usdeBalance = getERC20(sourceChain, "USDE").balanceOf(address(boringVault)); 
        assertEq(usdeBalance, 0); 
    }
}

interface IRoleGranter {
    function grantRole(bytes32 role, address account) external; 
    function hashOrder(DecoderCustomTypes.EthenaOrder memory order) external view returns (bytes32); 
    function confirmDelegatedSigner(address signer) external; 
    function addWhitelistedBenefactor(address benefactor) external; 
}
