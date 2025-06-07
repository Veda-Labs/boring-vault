// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {DeriveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DeriveDecoderAndSanitizer.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullDeriveDecoderAndSanitizer is DeriveDecoderAndSanitizer {}

contract DeriveIntegrationTest is BaseTestIntegration {

    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 22124456); 
            
        address deriveDecoder = address(new FullDeriveDecoderAndSanitizer()); 

        _overrideDecoder(deriveDecoder); 
    }

    function _setUpDerive() internal {
        super.setUp(); 
        _setupChain("derive", 21711962); 
            
        address deriveDecoder = address(new FullDeriveDecoderAndSanitizer()); 

        _overrideDecoder(deriveDecoder); 
    }


    function testDeriveDeposit() public {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "LBTC"), address(boringVault), 0.5e8); 
        deal(address(boringVault), 0.5e18); 

        address connectorPlugOnDeriveChain = 0x2E1245D57a304C7314687E529D610071628117f3;
        address controllerOnMainnet = 0x52CB41109b637F03B81b3FD6Dce4E3948b2F0923; 

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addDeriveVaultLeafs(
            leafs, 
            getAddress(sourceChain, "derive_LBTC_basis_deposit"),
            getAddress(sourceChain, "derive_LBTC_basis_deposit_connector"),
            getAddress(sourceChain, "derive_LBTC_basis_withdraw"),
            getAddress(sourceChain, "derive_LBTC_basis_withdraw_connector"),
            connectorPlugOnDeriveChain,            
            controllerOnMainnet,
            address(boringVault) //bv address on derive
        ); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(3); 
        
        //manage leafs
        tx_.manageLeafs[0] = leafs[0]; //approve LBTC
        tx_.manageLeafs[1] = leafs[1]; //approve bLBTC (basis traded lbtc)
        tx_.manageLeafs[2] = leafs[2]; //bridge LBTC (deposit)

        //generate proofs
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "LBTC"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "derive_LBTC_basis_token"); //approve 
        tx_.targets[2] = getAddress(sourceChain, "derive_LBTC_basis_deposit"); //bridge() (deposit vault)

        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "derive_LBTC_basis_deposit"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "derive_LBTC_basis_withdraw"), type(uint256).max
        ); 
        
        bytes memory extraDepositData = abi.encode(address(boringVault), connectorPlugOnDeriveChain);  

        tx_.targetData[2] = abi.encodeWithSignature(
            "bridge(address,uint256,uint256,address,bytes,bytes)",  
            address(boringVault),
            234, 
            2000000,
            0x457379de638CAFeB1759a22457fe893b288E2e89, //connector (https://github.com/0xdomrom/socket-plugs/blob/main/deployments/superbridge/prod_lyra_addresses.json#L99)
            extraDepositData, 
            ""
        );
        
        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        tx_.values[0] = 0; 
        tx_.values[1] = 0; 
        tx_.values[2] = 0.0001e18; //for testing only, could use `getMinFees` to get the correct fee amount as these are not reimbursed if fees are overpaid
        
        //submit the call 
        _submitManagerCall(manageProofs, tx_); 
        
        //no tokens are received until tx is finalized on Derive chain 
        uint256 basisLBTCBalance = getERC20(sourceChain, "derive_LBTC_basis_token").balanceOf(address(boringVault)); 
        assertEq(basisLBTCBalance, 0); 

        //skip some time
        skip (7 days); 
        
        //mimic the deposit here, it is a 1:1 receipt token
        deal(getAddress(sourceChain, "derive_LBTC_basis_token"), address(boringVault), 0.5e18); 

        tx_ = _getTxArrays(1); 
        
        //manage leafs
        tx_.manageLeafs[0] = leafs[3]; //bridge bLBTC (withdraw)

        //generate proofs
        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "derive_LBTC_basis_withdraw"); //bridge() (withdraw vault)

        
        extraDepositData = abi.encode(address(boringVault), controllerOnMainnet);  

        tx_.targetData[0] = abi.encodeWithSignature(
            "bridge(address,uint256,uint256,address,bytes,bytes)",  
            address(boringVault),
            234, 
            2000000,
            0x5E72430EC945CCc183c34e2860FFC2b5bac712c2, //connector (https://github.com/0xdomrom/socket-plugs/blob/main/deployments/supertoken/prod_lyra-tsa_addresses.json#L178)
            extraDepositData, 
            ""
        );
        
        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        tx_.values[0] = 0.0001e18; //for testing only, could use `getMinFees` to get the correct fee amount as these are not reimbursed if fees are overpaid
        
        //submit the call 
        _submitManagerCall(manageProofs, tx_); 
        
    }

    function testDeriveClaim() public {
        _setUpDerive(); 

        //deal(getAddress(sourceChain, "LBTC"), address(boringVault), 0.5e8); 
        //deal(address(boringVault), 0.5e18); 

        //address connectorPlugOnDeriveChain = 0x2E1245D57a304C7314687E529D610071628117f3;
        //address controllerOnMainnet = 0x52CB41109b637F03B81b3FD6Dce4E3948b2F0923; 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addDeriveClaimLeafs(leafs); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1); 
        
        //manage leafs
        tx_.manageLeafs[0] = leafs[0]; //claimAll

        //generate proofs
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "rewardDistributor"); //approve 

        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature("claimAll()");
        
        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        
        //submit the call 
        _submitManagerCall(manageProofs, tx_); 

        //mock some rewards of stDRV so we can unwrap
        deal(getAddress(sourceChain, "stDRV"), address(boringVault), 10e18); 

        tx_ = _getTxArrays(1); 
        
        //manage leafs
        tx_.manageLeafs[0] = leafs[1]; //redeem stDRV

        //generate proofs
        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "stDRV"); //redeem

        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature("redeem(uint256,uint256)", 10e18, 0); //no redeem time
        
        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        
        //submit the call 
        _submitManagerCall(manageProofs, tx_); 
        
        //looks like we get 80% of our rewards if we insta-claim? makes sense since there is a vesting feature
        uint256 drvBalance = getERC20(sourceChain, "DRV").balanceOf(address(boringVault)); 
        assertGt(drvBalance, 0); 

        //===== test finalize =====

        //mock some rewards of stDRV so we can unwrap
        deal(getAddress(sourceChain, "stDRV"), address(boringVault), 10e18); 

        tx_ = _getTxArrays(1); 
        
        //manage leafs
        tx_.manageLeafs[0] = leafs[1]; //redeem stDRV

        //generate proofs
        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "stDRV"); //redeem

        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature("redeem(uint256,uint256)", 10e18, 4 weeks); 
        
        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        
        //submit the call 
        _submitManagerCall(manageProofs, tx_); 
        
        skip(4 weeks);     

        tx_ = _getTxArrays(1); 
        
        //manage leafs
        tx_.manageLeafs[0] = leafs[2]; //redeem stDRV

        //generate proofs
        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "stDRV"); //redeem
        
        uint256 redeemIndex; 

        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature("finalizeRedeem(uint256)", redeemIndex); 
        
        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        
        //submit the call 
        _submitManagerCall(manageProofs, tx_); 
    
        
        drvBalance = getERC20(sourceChain, "DRV").balanceOf(address(boringVault)); 
        assertEq(drvBalance, 18e18); 
    }

    function testDeriveBridgeBackToEth() public {
        _setUpDerive(); 

        deal(getAddress(sourceChain, "LBTC"), address(boringVault), 0.5e8); 
        deal(address(boringVault), 0.5e18); 

        //address connectorPlugOnDeriveChain = 0x2E1245D57a304C7314687E529D610071628117f3;
        //address controllerOnMainnet = 0x52CB41109b637F03B81b3FD6Dce4E3948b2F0923; 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addDeriveBridgeLeafs(
            leafs,
            getAddress(sourceChain, "LBTC"),
            getAddress(sourceChain, "derive_LBTC_controller"),
            0x52CB41109b637F03B81b3FD6Dce4E3948b2F0923
        ); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 
        
        //manage leafs
        tx_.manageLeafs[0] = leafs[2]; //approve
        tx_.manageLeafs[1] = leafs[3]; //bridge

        //generate proofs
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "LBTC"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "derive_LBTC_controller"); //bridge

        //targetDatas
        bytes memory extra = abi.encode(address(0), address(0)); 
        tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "derive_LBTC_controller"), type(uint256).max);
        tx_.targetData[1] = abi.encodeWithSignature(
            "bridge(address,uint256,uint256,address,bytes,bytes)",  
            address(boringVault),
            234, 
            2000000,
            0x52CB41109b637F03B81b3FD6Dce4E3948b2F0923, 
            extra, 
            ""
        );
        
        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        tx_.values[0] = 0; 
        tx_.values[1] = 0.1e18; 
        
        //submit the call 
        _submitManagerCall(manageProofs, tx_); 

    }
}
