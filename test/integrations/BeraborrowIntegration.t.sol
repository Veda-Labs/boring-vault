// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BeraborrowDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BeraborrowDecoderAndSanitizer.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";

contract FullBeraborrowDecoderAndSanitizer is BeraborrowDecoderAndSanitizer {}
        

contract BeraborrowIntegrationTest is BaseTestIntegration {

    struct ExecuteWithdrawalParams {
        uint256 epoch;
        address upperHint;
        address lowerHint;
    }

    function _setUpBerachain() internal {
        super.setUp(); 
        _setupChain("berachain", 4312769); 
            
        address beraborrowDecoder = address(new FullBeraborrowDecoderAndSanitizer()); 

        _overrideDecoder(beraborrowDecoder); 
    }

    function _setUpBerachainLater() internal {
        super.setUp(); 
        _setupChain("berachain", 5393637); 
            
        address beraborrowDecoder = address(new FullBeraborrowDecoderAndSanitizer()); 

        _overrideDecoder(beraborrowDecoder); 
    }


    function testBeraborrowIntegration() external {
        _setUpBerachain();  

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 100e18);
        
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        
        //deposit asset? can we go from deposit asset -> den manager?
        //no... but we can go from colVault -> asset() for approvals at least...
        //maybe ask their team if there is an easy way to get those values?
        
        address[] memory collateralVaults = new address[](1);   
        collateralVaults[0] = getAddress(sourceChain, "bWETH"); 

        address[] memory denManagers = new address[](1);   
        denManagers[0] = getAddress(sourceChain, "WETHDenManager");   

        _addBeraborrowLeafs(leafs, collateralVaults, denManagers, false);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);


        Tx memory tx_ = _getTxArrays(3); //approve collat, approve nectar, open, close

        tx_.manageLeafs[0] = leafs[0];  //approve
        tx_.manageLeafs[1] = leafs[1];  //approve
        tx_.manageLeafs[2] = leafs[2];  //open 
        //tx_.manageLeafs[3] = leafs[3];  //close 

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);


        tx_.targets[0] = getAddress(sourceChain, "NECT"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[2] = getAddress(sourceChain, "collVaultRouter"); //open
        //tx_.targets[3] = getAddress(sourceChain, "collVaultRouter"); //close

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "collVaultRouter"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "collVaultRouter"), type(uint256).max
        );

        //should we try getting head + tail?
        
        DecoderCustomTypes.OpenDenVaultParams memory openParams = DecoderCustomTypes.OpenDenVaultParams(
            getAddress(sourceChain, "WETHDenManager"),
            getAddress(sourceChain, "bWETH"),
            10000000000000000,
            70000000000000000000,
            73500000000000000,
            0xE5A8929c08Dc8382D9E9F7D3C2f5e122e3e42315,
            0x89185DA0B3d2AA20c42F9D12fE765572e1A7bdA6,
            73132500000000000,
            14,
            ""
        ); 

        tx_.targetData[2] = abi.encodeWithSignature("openDenVault((address,address,uint256,uint256,uint256,address,address,uint256,uint256,bytes))", openParams); 

       

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        //tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_); 


        uint256 nectBal = getERC20(sourceChain, "NECT").balanceOf(address(boringVault)); 
        assertGt(nectBal, 0); 

        tx_ = _getTxArrays(1); //approve collat, approve nectar, open, close

        tx_.manageLeafs[0] = leafs[3];  //open 

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "collVaultRouter"); //open

        DecoderCustomTypes.AdjustDenVaultParams memory adjustParams = DecoderCustomTypes.AdjustDenVaultParams(
            getAddress(sourceChain, "WETHDenManager"),
            getAddress(sourceChain, "bWETH"),
            10000000000000000,
            0,
            1000000000000000,
            0,
            false,
            0xE5A8929c08Dc8382D9E9F7D3C2f5e122e3e42315,
            0x89185DA0B3d2AA20c42F9D12fE765572e1A7bdA6,
            true,
            0,
            994005000000000,
            14,
            ""
        ); 

        tx_.targetData[0] = abi.encodeWithSignature("adjustDenVault((address,address,uint256,uint256,uint256,uint256,bool,address,address,bool,uint256,uint256,uint256,bytes))", adjustParams); 


        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_); 

        //should have withdrawn some WETH
        
        deal(getAddress(sourceChain, "NECT"), address(boringVault), nectBal + 1e18);  
                
        tx_ = _getTxArrays(1); //approve collat, approve nectar, open, close

        tx_.manageLeafs[0] = leafs[4];  //close

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "collVaultRouter"); //open

        tx_.targetData[0] = abi.encodeWithSignature(
            "closeDenVault(address,address,uint256,uint256,bool)",
            getAddress(sourceChain, "WETHDenManager"),
            getAddress(sourceChain, "bWETH"),
            0,
            14,
            true
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_); 

    }

    function testBeraborrowManagedVaultIntegration() external {
        _setUpBerachainLater();  
        
        deal(getAddress(sourceChain, "WBTC"), address(boringVault), 10e8);
        
        ManageLeaf[] memory leafs = new ManageLeaf[](4);

        address[] memory managedVaults = new address[](1);
        managedVaults[0] = getAddress(sourceChain, "bbWBTCManagedVault");
        _addBeraborrowManagedVaultLeafs(leafs, managedVaults);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);


        Tx memory tx_ = _getTxArrays(4); //approve collat, approve nectar, open, close

        tx_.manageLeafs[0] = leafs[0];  //approve
        tx_.manageLeafs[1] = leafs[1];  //deposit
        tx_.manageLeafs[2] = leafs[2];  //redeemIntent
        tx_.manageLeafs[3] = leafs[3];  //cancelWithdrawalIntent

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);


        tx_.targets[0] = getAddress(sourceChain, "WBTC"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "bbWBTCManagedVault"); //deposit 
        tx_.targets[2] = getAddress(sourceChain, "bbWBTCManagedVault"); //redeemIntent
        tx_.targets[3] = getAddress(sourceChain, "bbWBTCManagedVault"); //cancelWithdrawalIntent


        DecoderCustomTypes.AddCollParams memory addCollParams = DecoderCustomTypes.AddCollParams(
            address(0),
            address(0),
            0,
            0
        );


        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "bbWBTCManagedVault"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "deposit(uint256,address,(address,address,uint256,uint256))", 10e8, address(boringVault), addCollParams
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "redeemIntent(uint256,address,address)", 10e8, address(boringVault), address(boringVault)
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "cancelWithdrawalIntent(uint256,uint256,address)", 1941935, 10e8, address(boringVault)
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_); 

    }

    function testBeraborrowManagedVaultIntegrationWithdrawFromEpoch() external {
        _setUpBerachainLater();  
        
        deal(getAddress(sourceChain, "WBTC"), address(boringVault), 10e8);
        
        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        address[] memory managedVaults = new address[](1);
        managedVaults[0] = getAddress(sourceChain, "bbWBTCManagedVault");
        _addBeraborrowManagedVaultLeafs(leafs, managedVaults);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);


        Tx memory tx_ = _getTxArrays(3); //approve collat, approve nectar, open, close

        tx_.manageLeafs[0] = leafs[0];  //approve
        tx_.manageLeafs[1] = leafs[1];  //deposit
        tx_.manageLeafs[2] = leafs[2];  //redeemIntent

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);


        tx_.targets[0] = getAddress(sourceChain, "WBTC"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "bbWBTCManagedVault"); //deposit 
        tx_.targets[2] = getAddress(sourceChain, "bbWBTCManagedVault"); //redeemIntent


        DecoderCustomTypes.AddCollParams memory addCollParams = DecoderCustomTypes.AddCollParams(
            address(0),
            address(0),
            0,
            0
        );


        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "bbWBTCManagedVault"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "deposit(uint256,address,(address,address,uint256,uint256))", 10e8, address(boringVault), addCollParams
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "redeemIntent(uint256,address,address)", 10e8, address(boringVault), address(boringVault)
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_); 
        
        skip(2 days); 

        //IBeraBorrow.ExecuteWithdrawalParams memory p = IBeraBorrow.ExecuteWithdrawalParams(
        //    1942223,
        //    address(0),
        //    address(0)
        //); 

        //vm.prank(0xCE7d3fd53C0510325B3CEbB96298522e6c538753); 
        //IBeraBorrow(getAddress(sourceChain, "bbWBTCManagedVault")).executeWithdrawalEpoch(p); 

        tx_ = _getTxArrays(1); //approve collat, approve nectar, open, close

        tx_.manageLeafs[0] = leafs[4];  //redeemFromEpoch

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "bbWBTCManagedVault"); //deposit 

        DecoderCustomTypes.ExternalRebalanceParams memory params = DecoderCustomTypes.ExternalRebalanceParams(
            getAddress(sourceChain, "collVaultUnwrapper"),  
            "",
            0
        ); 

        tx_.targetData[0] = abi.encodeWithSignature(
            "withdrawFromEpoch(uint256,address,(address,bytes,uint256))",
            10e8,
            address(boringVault), 
            params   
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        
        vm.expectRevert(); //custom error 0x746fe1ff (NotReported()) due to vault needing to be removed by admins 
        _submitManagerCall(manageProofs, tx_); 
        
    }
}

interface IBeraBorrow{
    
    struct ExecuteWithdrawalParams {
        uint256 epoch;
        address upperHint;
        address lowerHint;
    }

    function executeWithdrawalEpoch(ExecuteWithdrawalParams calldata params) external; 
}
