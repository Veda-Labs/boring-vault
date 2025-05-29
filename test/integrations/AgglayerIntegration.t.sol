// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AgglayerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AgglayerDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullAgglayerDecoderAndSanitizer is AgglayerDecoderAndSanitizer{}


contract AgglayerIntegrationTest is BaseTestIntegration {


    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 22474150); 
            
        address agglayerDecoder = address(new FullAgglayerDecoderAndSanitizer()); 

        _overrideDecoder(agglayerDecoder); 
    }

    function testAgglayerBridgeAsset() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100e6);  
        deal(address(boringVault), 1e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);


        uint32 toChain = uint32(3); 
        uint32 fromChain = uint32(0); 
        address zkEVMBridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
        _addAgglayerTokenLeafs(
            leafs, 
            zkEVMBridge,
            getAddress(sourceChain, "USDC"),
            fromChain,
            toChain 
        );    

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        
        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve USDC
        tx_.manageLeafs[1] = leafs[1]; //bridgeAsset (USDC)

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "USDC"); //approve 
        tx_.targets[1] = zkEVMBridge;  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", zkEVMBridge, type(uint256).max
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "bridgeAsset(uint32,address,uint256,address,bool,bytes)",
            toChain, 
            address(boringVault),
            100e6,
            getAddress(sourceChain, "USDC"), 
            true,
            ""
        ); 


        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
    }

    //function testAgglayerBridgeMessage() external {
    //    _setUpMainnet(); 

    //    deal(getAddress(sourceChain, "USDC"), address(boringVault), 100e6);  
    //    deal(address(boringVault), 1e18); 

    //    ManageLeaf[] memory leafs = new ManageLeaf[](8);


    //    uint32 toChain = uint32(3); 
    //    uint32 fromChain = uint32(0); 
    //    address zkEVMBridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
    //    _addAgglayerTokenLeafs(
    //        leafs, 
    //        zkEVMBridge,
    //        getAddress(sourceChain, "USDC"),
    //        fromChain,
    //        toChain 
    //    );    

    //    bytes32[][] memory manageTree = _generateMerkleTree(leafs);

    //    //_generateTestLeafs(leafs, manageTree);

    //    manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

    //    
    //    Tx memory tx_ = _getTxArrays(2); 

    //    tx_.manageLeafs[0] = leafs[0]; //approve USDC
    //    tx_.manageLeafs[1] = leafs[3]; //bridgeAsset (USDC)

    //    bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
    //    
    //    tx_.targets[0] = getAddress(sourceChain, "USDC"); //approve 
    //    tx_.targets[1] = zkEVMBridge;  
    //    
    //    bytes memory metadata = abi.encode(getAddress(sourceChain, "USDC"), 100e6); 
    //    tx_.targetData[0] = abi.encodeWithSignature(
    //        "approve(address,uint256)", zkEVMBridge, type(uint256).max
    //    ); 
    //    tx_.targetData[1] = abi.encodeWithSignature(
    //        "bridgeMessage(uint32,address,bool,bytes)",
    //        toChain, 
    //        address(boringVault),
    //        true,
    //        metadata
    //    ); 

    //    tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
    //    tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

    //    _submitManagerCall(manageProofs, tx_); 
    //}


    function testAgglayerClaimAsset() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100e6);  
        deal(address(boringVault), 1e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        uint32 toChain = uint32(3); 
        uint32 fromChain = uint32(0); 
        address zkEVMBridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
        _addAgglayerTokenLeafs(
            leafs, 
            zkEVMBridge,
            getAddress(sourceChain, "USDT"),
            fromChain,
            toChain 
        );    

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        
        Tx memory tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[2]; //claimAsset

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = zkEVMBridge;  

        bytes32[32] memory proofs0; 
        proofs0[0] = 0xea16a4729192f84bddfed2897b05c59ac5f5361767e10812ce0a9d73e545f6d4;
        proofs0[1] = 0x43db1a9ea1c72a5d36d7d3a5d3dd79a018580781e67ef13cd55dcd6ba35d26e5;
        proofs0[2] = 0xd231824f33000c12729b039d76d7d5a86db0ec5ab43bd26992bba0b6b9011bee;
        proofs0[3] = 0x21ddb9a356815c3fac1026b6dec5df3124afbadb485c9ba5a3e3398a04b7ba85;
        proofs0[4] = 0x0623dcdfb05d2c671978ed57963125aac03c5562a4ee69c3b10083d8e87ad1d4;
        proofs0[5] = 0xc269fc1f5c31c97067cc6ba91d0140b9080e47033682479853bf23daf15b00ea;
        proofs0[6] = 0x641def147934e812584edeceb89ffdfe16cb1e4f11ab5e4378f1dfa2590e7aca;
        proofs0[7] = 0xffd70157e48063fc33c97a050f7f640233bf646cc98d9524c6b92bcf3ab56f83;
        proofs0[8] = 0x9867cc5f7f196b93bae1e27e6320742445d290f2263827498b54fec539f756af;
        proofs0[9] = 0x4cc8c89bb991f6479051de3d83f5cdd3c705e932227704825704f01d5f610977;
        proofs0[10] = 0xf9dc3e7fe016e050eff260334f18a5d4fe391d82092319f5964f2e2eb7c1c3a5;
        proofs0[11] = 0xa4086555f5acc28059d60be13ad9f9e1ffa534349c627adb5c21ebbf99e02312;
        proofs0[12] = 0x2581fd557aca0de1e7c6d588c5009950b0a7a838bb2fb1326a9bcdff613b59db;
        proofs0[13] = 0xc1df82d9c4b87413eae2ef048f94b4d3554cea73d92b0f7af96e0271c691e2bb;
        proofs0[14] = 0x5c67add7c6caf302256adedf7ab114da0acfe870d449a3a489f781d659e8becc;
        proofs0[15] = 0xda7bce9f4e8618b6bd2f4132ce798cdc7a60e7e1460a7299e3c6342a579626d2;
        proofs0[16] = 0x2733e50f526ec2fa19a22b31e8ed50f23cd1fdf94c9154ed3a7609a2f1ff981f;
        proofs0[17] = 0xe1d3b5c807b281e4683cc6d6315cf95b9ade8641defcb32372f1c126e398ef7a;
        proofs0[18] = 0x5a2dce0a8a7f68bb74560f8f71837c2c2ebbcbf7fffb42ae1896f13f7c7479a0;
        proofs0[19] = 0xb46a28b6f55540f89444f63de0378e3d121be09e06cc9ded1c20e65876d36aa0;
        proofs0[20] = 0xc65e9645644786b620e2dd2ad648ddfcbf4a7e5b1a3a4ecfe7f64667a3f0b7e2;
        proofs0[21] = 0xf4418588ed35a2458cffeb39b93d26f18d2ab13bdce6aee58e7b99359ec2dfd9;
        proofs0[22] = 0x5a9c16dc00d6ef18b7933a6f8dc65ccb55667138776f7dea101070dc8796e377;
        proofs0[23] = 0x4df84f40ae0c8229d0d6069e5c8f39a7c299677a09d367fc7b05e3bc380ee652;
        proofs0[24] = 0xcdc72595f74c7b1043d0e1ffbab734648c838dfb0527d971b602bc216c9619ef;
        proofs0[25] = 0x0abf5ac974a1ed57f4050aa510dd9c74f508277b39d7973bb2dfccc5eeb0618d;
        proofs0[26] = 0xb8cd74046ff337f0a7bf2c8e03e10f642c1886798d71806ab1e888d9e5ee87d0;
        proofs0[27] = 0x838c5655cb21c6cb83313b5a631175dff4963772cce9108188b34ac87c81c41e;
        proofs0[28] = 0x662ee4dd2dd7b2bc707961b1e646c4047669dcb6584f0d8d770daf5d7e7deb2e;
        proofs0[29] = 0x388ab20e2573d171a88108e79d820e98f26c0b84aa8b2f4aa4968dbb818ea322;
        proofs0[30] = 0x93237c50ba75ee485f4c22adf2f741400bdf8d6a9cc7df7ecae576221665d735;
        proofs0[31] = 0x8448818bb4ae4562849e949e17ac16e0be16688e156b5cf15e098c627c0056a9;

        bytes32[32] memory proofs1; 
        proofs1[0] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proofs1[1] = 0xc5a60307fb57becb76bc2651f1a6d0e091331eb18ff8fd58a50b66fb7d4b6f34;
        proofs1[2] = 0x65eb29cce8d586de8920a6b22c36731d9b9e138f25ad98c67bcff0cdc6c9b66c;
        proofs1[3] = 0xdacd9092b06808534dcdf6ad6e35aa0dc191643a7ff01be30e05f69e5a69b475;
        proofs1[4] = 0xced7da7df817c9a06161d9c27d817f9f8b951bd49bfba71698c6a1763ea967f8;
        proofs1[5] = 0x0eb01ebfc9ed27500cd4dfc979272d1f0913cc9f66540d7e8005811109e1cf2d;
        proofs1[6] = 0x887c22bd8750d34016ac3c66b5ff102dacdd73f6b014e710b51e8022af9a1968;
        proofs1[7] = 0xffd70157e48063fc33c97a050f7f640233bf646cc98d9524c6b92bcf3ab56f83;
        proofs1[8] = 0x9867cc5f7f196b93bae1e27e6320742445d290f2263827498b54fec539f756af;
        proofs1[9] = 0xcefad4e508c098b9a7e1d8feb19955fb02ba9675585078710969d3440f5054e0;
        proofs1[10] = 0xf9dc3e7fe016e050eff260334f18a5d4fe391d82092319f5964f2e2eb7c1c3a5;
        proofs1[11] = 0xf8b13a49e282f609c317a833fb8d976d11517c571d1221a265d25af778ecf892;
        proofs1[12] = 0x3490c6ceeb450aecdc82e28293031d10c7d73bf85e57bf041a97360aa2c5d99c;
        proofs1[13] = 0xc1df82d9c4b87413eae2ef048f94b4d3554cea73d92b0f7af96e0271c691e2bb;
        proofs1[14] = 0x5c67add7c6caf302256adedf7ab114da0acfe870d449a3a489f781d659e8becc;
        proofs1[15] = 0xda7bce9f4e8618b6bd2f4132ce798cdc7a60e7e1460a7299e3c6342a579626d2;
        proofs1[16] = 0x2733e50f526ec2fa19a22b31e8ed50f23cd1fdf94c9154ed3a7609a2f1ff981f;
        proofs1[17] = 0xe1d3b5c807b281e4683cc6d6315cf95b9ade8641defcb32372f1c126e398ef7a;
        proofs1[18] = 0x5a2dce0a8a7f68bb74560f8f71837c2c2ebbcbf7fffb42ae1896f13f7c7479a0;
        proofs1[19] = 0xb46a28b6f55540f89444f63de0378e3d121be09e06cc9ded1c20e65876d36aa0;
        proofs1[20] = 0xc65e9645644786b620e2dd2ad648ddfcbf4a7e5b1a3a4ecfe7f64667a3f0b7e2;
        proofs1[21] = 0xf4418588ed35a2458cffeb39b93d26f18d2ab13bdce6aee58e7b99359ec2dfd9;
        proofs1[22] = 0x5a9c16dc00d6ef18b7933a6f8dc65ccb55667138776f7dea101070dc8796e377;
        proofs1[23] = 0x4df84f40ae0c8229d0d6069e5c8f39a7c299677a09d367fc7b05e3bc380ee652;
        proofs1[24] = 0xcdc72595f74c7b1043d0e1ffbab734648c838dfb0527d971b602bc216c9619ef;
        proofs1[25] = 0x0abf5ac974a1ed57f4050aa510dd9c74f508277b39d7973bb2dfccc5eeb0618d;
        proofs1[26] = 0xb8cd74046ff337f0a7bf2c8e03e10f642c1886798d71806ab1e888d9e5ee87d0;
        proofs1[27] = 0x838c5655cb21c6cb83313b5a631175dff4963772cce9108188b34ac87c81c41e;
        proofs1[28] = 0x662ee4dd2dd7b2bc707961b1e646c4047669dcb6584f0d8d770daf5d7e7deb2e;
        proofs1[29] = 0x388ab20e2573d171a88108e79d820e98f26c0b84aa8b2f4aa4968dbb818ea322;
        proofs1[30] = 0x93237c50ba75ee485f4c22adf2f741400bdf8d6a9cc7df7ecae576221665d735;
        proofs1[31] = 0x8448818bb4ae4562849e949e17ac16e0be16688e156b5cf15e098c627c0056a9;

        bytes memory metadata = hex"000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a546574686572205553440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000045553445400000000000000000000000000000000000000000000000000000000"; 
        tx_.targetData[0] = abi.encodeWithSignature(
            "claimAsset(bytes32[32],bytes32[32],uint256,bytes32,bytes32,uint32,address,uint32,address,uint256,bytes)",
            proofs0,
            proofs1,
            uint256(8589941366),
            bytes32(0x47b23a8f9e6977ccb5ebc3a11268206e473e00b55faca3e2e850ce4a97dffefd),
            bytes32(0x02c5c82f37c11d01da3a0a63035f7b8c3c8cb5aa8eb76a2139dc5bbb574989e9),
            uint32(0),
            getAddress(sourceChain, "USDT"),
            uint32(0),
            address(boringVault),
            4000000,
            metadata
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        
        vm.expectRevert(); //custom error: 0xe0417cec (InvalidSmtProof) expected as we are checking the leafs here with data taken from this tx: https://etherscan.io/tx/0x65912ac7d83068b2a2a48e95d0d3ae3f96634128647235ed6d849a628f959040
        //This test verifies that the boring vault can call this function as expected
        _submitManagerCall(manageProofs, tx_); 
    }


    //function testAgglayerClaimMessage() external {
    //    _setUpMainnet(); 

    //    deal(getAddress(sourceChain, "USDC"), address(boringVault), 100e6);  
    //    deal(address(boringVault), 1e18); 

    //    ManageLeaf[] memory leafs = new ManageLeaf[](8);

    //    uint32 toChain = uint32(3); 
    //    uint32 fromChain = uint32(0); 
    //    address zkEVMBridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
    //    _addAgglayerTokenLeafs(
    //        leafs, 
    //        zkEVMBridge,
    //        getAddress(sourceChain, "USDT"),
    //        fromChain,
    //        toChain 
    //    );    

    //    bytes32[][] memory manageTree = _generateMerkleTree(leafs);

    //    //_generateTestLeafs(leafs, manageTree);

    //    manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

    //    
    //    Tx memory tx_ = _getTxArrays(1); 

    //    tx_.manageLeafs[0] = leafs[2]; //claimAsset

    //    bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
    //    
    //    tx_.targets[0] = zkEVMBridge;  

    //    bytes32[32] memory proofs0; 
    //    proofs0[0] = 0xea16a4729192f84bddfed2897b05c59ac5f5361767e10812ce0a9d73e545f6d4;
    //    proofs0[1] = 0x43db1a9ea1c72a5d36d7d3a5d3dd79a018580781e67ef13cd55dcd6ba35d26e5;
    //    proofs0[2] = 0xd231824f33000c12729b039d76d7d5a86db0ec5ab43bd26992bba0b6b9011bee;
    //    proofs0[3] = 0x21ddb9a356815c3fac1026b6dec5df3124afbadb485c9ba5a3e3398a04b7ba85;
    //    proofs0[4] = 0x0623dcdfb05d2c671978ed57963125aac03c5562a4ee69c3b10083d8e87ad1d4;
    //    proofs0[5] = 0xc269fc1f5c31c97067cc6ba91d0140b9080e47033682479853bf23daf15b00ea;
    //    proofs0[6] = 0x641def147934e812584edeceb89ffdfe16cb1e4f11ab5e4378f1dfa2590e7aca;
    //    proofs0[7] = 0xffd70157e48063fc33c97a050f7f640233bf646cc98d9524c6b92bcf3ab56f83;
    //    proofs0[8] = 0x9867cc5f7f196b93bae1e27e6320742445d290f2263827498b54fec539f756af;
    //    proofs0[9] = 0x4cc8c89bb991f6479051de3d83f5cdd3c705e932227704825704f01d5f610977;
    //    proofs0[10] = 0xf9dc3e7fe016e050eff260334f18a5d4fe391d82092319f5964f2e2eb7c1c3a5;
    //    proofs0[11] = 0xa4086555f5acc28059d60be13ad9f9e1ffa534349c627adb5c21ebbf99e02312;
    //    proofs0[12] = 0x2581fd557aca0de1e7c6d588c5009950b0a7a838bb2fb1326a9bcdff613b59db;
    //    proofs0[13] = 0xc1df82d9c4b87413eae2ef048f94b4d3554cea73d92b0f7af96e0271c691e2bb;
    //    proofs0[14] = 0x5c67add7c6caf302256adedf7ab114da0acfe870d449a3a489f781d659e8becc;
    //    proofs0[15] = 0xda7bce9f4e8618b6bd2f4132ce798cdc7a60e7e1460a7299e3c6342a579626d2;
    //    proofs0[16] = 0x2733e50f526ec2fa19a22b31e8ed50f23cd1fdf94c9154ed3a7609a2f1ff981f;
    //    proofs0[17] = 0xe1d3b5c807b281e4683cc6d6315cf95b9ade8641defcb32372f1c126e398ef7a;
    //    proofs0[18] = 0x5a2dce0a8a7f68bb74560f8f71837c2c2ebbcbf7fffb42ae1896f13f7c7479a0;
    //    proofs0[19] = 0xb46a28b6f55540f89444f63de0378e3d121be09e06cc9ded1c20e65876d36aa0;
    //    proofs0[20] = 0xc65e9645644786b620e2dd2ad648ddfcbf4a7e5b1a3a4ecfe7f64667a3f0b7e2;
    //    proofs0[21] = 0xf4418588ed35a2458cffeb39b93d26f18d2ab13bdce6aee58e7b99359ec2dfd9;
    //    proofs0[22] = 0x5a9c16dc00d6ef18b7933a6f8dc65ccb55667138776f7dea101070dc8796e377;
    //    proofs0[23] = 0x4df84f40ae0c8229d0d6069e5c8f39a7c299677a09d367fc7b05e3bc380ee652;
    //    proofs0[24] = 0xcdc72595f74c7b1043d0e1ffbab734648c838dfb0527d971b602bc216c9619ef;
    //    proofs0[25] = 0x0abf5ac974a1ed57f4050aa510dd9c74f508277b39d7973bb2dfccc5eeb0618d;
    //    proofs0[26] = 0xb8cd74046ff337f0a7bf2c8e03e10f642c1886798d71806ab1e888d9e5ee87d0;
    //    proofs0[27] = 0x838c5655cb21c6cb83313b5a631175dff4963772cce9108188b34ac87c81c41e;
    //    proofs0[28] = 0x662ee4dd2dd7b2bc707961b1e646c4047669dcb6584f0d8d770daf5d7e7deb2e;
    //    proofs0[29] = 0x388ab20e2573d171a88108e79d820e98f26c0b84aa8b2f4aa4968dbb818ea322;
    //    proofs0[30] = 0x93237c50ba75ee485f4c22adf2f741400bdf8d6a9cc7df7ecae576221665d735;
    //    proofs0[31] = 0x8448818bb4ae4562849e949e17ac16e0be16688e156b5cf15e098c627c0056a9;

    //    bytes32[32] memory proofs1; 
    //    proofs1[0] = 0x0000000000000000000000000000000000000000000000000000000000000000;
    //    proofs1[1] = 0xc5a60307fb57becb76bc2651f1a6d0e091331eb18ff8fd58a50b66fb7d4b6f34;
    //    proofs1[2] = 0x65eb29cce8d586de8920a6b22c36731d9b9e138f25ad98c67bcff0cdc6c9b66c;
    //    proofs1[3] = 0xdacd9092b06808534dcdf6ad6e35aa0dc191643a7ff01be30e05f69e5a69b475;
    //    proofs1[4] = 0xced7da7df817c9a06161d9c27d817f9f8b951bd49bfba71698c6a1763ea967f8;
    //    proofs1[5] = 0x0eb01ebfc9ed27500cd4dfc979272d1f0913cc9f66540d7e8005811109e1cf2d;
    //    proofs1[6] = 0x887c22bd8750d34016ac3c66b5ff102dacdd73f6b014e710b51e8022af9a1968;
    //    proofs1[7] = 0xffd70157e48063fc33c97a050f7f640233bf646cc98d9524c6b92bcf3ab56f83;
    //    proofs1[8] = 0x9867cc5f7f196b93bae1e27e6320742445d290f2263827498b54fec539f756af;
    //    proofs1[9] = 0xcefad4e508c098b9a7e1d8feb19955fb02ba9675585078710969d3440f5054e0;
    //    proofs1[10] = 0xf9dc3e7fe016e050eff260334f18a5d4fe391d82092319f5964f2e2eb7c1c3a5;
    //    proofs1[11] = 0xf8b13a49e282f609c317a833fb8d976d11517c571d1221a265d25af778ecf892;
    //    proofs1[12] = 0x3490c6ceeb450aecdc82e28293031d10c7d73bf85e57bf041a97360aa2c5d99c;
    //    proofs1[13] = 0xc1df82d9c4b87413eae2ef048f94b4d3554cea73d92b0f7af96e0271c691e2bb;
    //    proofs1[14] = 0x5c67add7c6caf302256adedf7ab114da0acfe870d449a3a489f781d659e8becc;
    //    proofs1[15] = 0xda7bce9f4e8618b6bd2f4132ce798cdc7a60e7e1460a7299e3c6342a579626d2;
    //    proofs1[16] = 0x2733e50f526ec2fa19a22b31e8ed50f23cd1fdf94c9154ed3a7609a2f1ff981f;
    //    proofs1[17] = 0xe1d3b5c807b281e4683cc6d6315cf95b9ade8641defcb32372f1c126e398ef7a;
    //    proofs1[18] = 0x5a2dce0a8a7f68bb74560f8f71837c2c2ebbcbf7fffb42ae1896f13f7c7479a0;
    //    proofs1[19] = 0xb46a28b6f55540f89444f63de0378e3d121be09e06cc9ded1c20e65876d36aa0;
    //    proofs1[20] = 0xc65e9645644786b620e2dd2ad648ddfcbf4a7e5b1a3a4ecfe7f64667a3f0b7e2;
    //    proofs1[21] = 0xf4418588ed35a2458cffeb39b93d26f18d2ab13bdce6aee58e7b99359ec2dfd9;
    //    proofs1[22] = 0x5a9c16dc00d6ef18b7933a6f8dc65ccb55667138776f7dea101070dc8796e377;
    //    proofs1[23] = 0x4df84f40ae0c8229d0d6069e5c8f39a7c299677a09d367fc7b05e3bc380ee652;
    //    proofs1[24] = 0xcdc72595f74c7b1043d0e1ffbab734648c838dfb0527d971b602bc216c9619ef;
    //    proofs1[25] = 0x0abf5ac974a1ed57f4050aa510dd9c74f508277b39d7973bb2dfccc5eeb0618d;
    //    proofs1[26] = 0xb8cd74046ff337f0a7bf2c8e03e10f642c1886798d71806ab1e888d9e5ee87d0;
    //    proofs1[27] = 0x838c5655cb21c6cb83313b5a631175dff4963772cce9108188b34ac87c81c41e;
    //    proofs1[28] = 0x662ee4dd2dd7b2bc707961b1e646c4047669dcb6584f0d8d770daf5d7e7deb2e;
    //    proofs1[29] = 0x388ab20e2573d171a88108e79d820e98f26c0b84aa8b2f4aa4968dbb818ea322;
    //    proofs1[30] = 0x93237c50ba75ee485f4c22adf2f741400bdf8d6a9cc7df7ecae576221665d735;
    //    proofs1[31] = 0x8448818bb4ae4562849e949e17ac16e0be16688e156b5cf15e098c627c0056a9;

    //    bytes memory metadata = hex"000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a546574686572205553440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000045553445400000000000000000000000000000000000000000000000000000000"; 
    //    tx_.targetData[0] = abi.encodeWithSignature(
    //        "claimAsset(bytes32[32],bytes32[32],uint256,bytes32,bytes32,uint32,address,uint32,address,uint256,bytes)",
    //        proofs0,
    //        proofs1,
    //        uint256(8589941366),
    //        bytes32(0x47b23a8f9e6977ccb5ebc3a11268206e473e00b55faca3e2e850ce4a97dffefd),
    //        bytes32(0x02c5c82f37c11d01da3a0a63035f7b8c3c8cb5aa8eb76a2139dc5bbb574989e9),
    //        uint32(0),
    //        getAddress(sourceChain, "USDT"),
    //        uint32(0),
    //        address(boringVault),
    //        4000000,
    //        metadata
    //    ); 

    //    tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
    //    
    //    vm.expectRevert(); //custom error: 0xe0417cec (InvalidSmtProof) expected as we are checking the leafs here with data taken from this tx: https://etherscan.io/tx/0x65912ac7d83068b2a2a48e95d0d3ae3f96634128647235ed6d849a628f959040
    //    //This test verifies that the boring vault can call this function as expected
    //    _submitManagerCall(manageProofs, tx_); 
    //}

}
        
