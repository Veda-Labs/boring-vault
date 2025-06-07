// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Sonic/CreateStakedSonicUSDMerkleRoot.s.sol:CreateStakedSonicUSDMerkleRoot --rpc-url $SONIC_MAINNET_RPC_URL
 */
contract CreateStakedSonicUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x4D85bA8c3918359c78Ed09581E5bc7578ba932ba;
    address public managerAddress = 0x5F7f5205A3E7c63c3bd287EecBe7879687D4c698;
    address public accountantAddress = 0x13cCc810DfaA6B71957F2b87060aFE17e6EB8034;
    address public rawDataDecoderAndSanitizer = 0xE96762FD748EfdCF4156c64aBc39227529FaF021;
    
    //one offs
    address public siloVaultDecoder = 0x62eab851AC6aF5C0B3e017F70db71A40Dfa1B1f0; 

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(sonicMainnet);
        setAddress(false, sonicMainnet, "boringVault", boringVault);
        setAddress(false, sonicMainnet, "managerAddress", managerAddress);
        setAddress(false, sonicMainnet, "accountantAddress", accountantAddress);
        setAddress(false, sonicMainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "scUSD");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true);

          // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "scUSD");

        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");

        _addUniswapV3Leafs(leafs, token0, token1, false, true); //use swapRouter02

        // ========================== Beets ==========================
        _addBalancerLeafs(
            leafs, getBytes32(sourceChain, "scUSD_USDC_PoolId"), getAddress(sourceChain, "scUSD_USDC_gauge")
        );
        _addBalancerSwapLeafs(leafs, getBytes32(sourceChain, "USDC_stS_PoolId")); //USDC, stS
        _addBalancerSwapLeafs(leafs, getBytes32(sourceChain, "USDC_wS_PoolId")); //USDC, wS
        _addBalancerSwapLeafs(leafs, getBytes32(sourceChain, "stS_BEETS_PoolId")); //stS, BEETS (swap BEETS for stS, then USDC, swap function leaves only support 2 token pools atm)

        // ========================== BeetsV3 ==========================
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_USDC_scUSD_boosted"), true, getAddress(sourceChain, "balancerV3_USDC_scUSD_boosted_gauge")); 

        // ========================== Odos ==========================
        
        address[] memory tokens = new address[](10);   
        SwapKind[] memory kind = new SwapKind[](10); 
        tokens[0] = getAddress(sourceChain, "USDC"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = getAddress(sourceChain, "stS"); 
        kind[1] = SwapKind.Sell; 
        tokens[2] = getAddress(sourceChain, "wS"); 
        kind[2] = SwapKind.Sell; 
        tokens[3] = getAddress(sourceChain, "scUSD"); 
        kind[3] = SwapKind.BuyAndSell; 
        tokens[4] = getAddress(sourceChain, "BEETS"); 
        kind[4] = SwapKind.Sell; 
        tokens[5] = getAddress(sourceChain, "BEETSFRAGMENTSS1"); 
        kind[5] = SwapKind.Sell; 
        tokens[6] = getAddress(sourceChain, "CRV"); 
        kind[6] = SwapKind.Sell; 
        tokens[7] = getAddress(sourceChain, "WETH"); 
        kind[7] = SwapKind.Sell; 
        tokens[8] = getAddress(sourceChain, "SILO"); 
        kind[8] = SwapKind.Sell; 
        tokens[9] = getAddress(sourceChain, "UNI"); 
        kind[9] = SwapKind.Sell; 

        _addOdosSwapLeafs(leafs, tokens, kind); 
        
        // ========================== Teller ==========================
        ERC20[] memory tellerAssets = new ERC20[](1);
        tellerAssets[0] = getERC20(sourceChain, "USDC");
        _addTellerLeafs(leafs, getAddress(sourceChain, "scUSDTeller"), tellerAssets, false, true);

        // ========================== Silo ==========================
        
        // ws/USDC id8
        address[] memory incentivesControllers = new address[](2); 
        incentivesControllers[0] = getAddress(sourceChain, "silo_wS_USDC_id8_USDC_IncentivesController"); 
        incentivesControllers[1] = getAddress(sourceChain, "silo_wS_USDC_id8_wS_IncentivesController"); 
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_wS_USDC_id8_config"), incentivesControllers); 
        
        // ws/USDC id20
        incentivesControllers[0] = getAddress(sourceChain, "silo_wS_USDC_id20_USDC_IncentivesController"); 
        incentivesControllers[1] = address(0);
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_wS_USDC_id20_config"), incentivesControllers);


        // USDC/wstkscUSD id23
        incentivesControllers[0] = getAddress(sourceChain, "silo_USDC_wstkscUSD_id23_USDC_IncentivesController"); 
        incentivesControllers[1] = address(0);  
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_USDC_wstkscUSD_id23_config"), incentivesControllers);

        // S/USDC id15 (no incentives) 
        incentivesControllers[0] = address(0); 
        incentivesControllers[1] = address(0);  
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_S_scUSD_id15_config"), incentivesControllers);

        incentivesControllers[0] = getAddress(sourceChain, "silo_PT-aUSDC_scUSD_id46_scUSD_IncentivesController"); 
        incentivesControllers[1] = address(0);  
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_PT-aUSDC_scUSD_id46_config"), incentivesControllers);

        // sfrxUSD/scUSD id48
        incentivesControllers[0] = address(0); 
        incentivesControllers[1] = address(0);  
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_sfrxUSD_scUSD_id48_config"), incentivesControllers);

        // ========================== Silo Vaults =========================
        
        setAddress(true, sonicMainnet, "rawDataDecoderAndSanitizer", siloVaultDecoder);
        _addSiloVaultLeafs(leafs, getAddress(sourceChain, "silo_Mithras_vault"));
        _addSiloVaultLeafs(leafs, getAddress(sourceChain, "silo_RE7_vault"));

        // ========================== Curve =========================
        //
        setAddress(true, sonicMainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        _addCurveLeafs(
            leafs,
            getAddress(sourceChain, "curve_USDC_scUSD_pool"),
            2,
            getAddress(sourceChain, "curve_USDC_scUSD_gauge")
        );
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "curve_USDC_scUSD_pool"));

        // ========================== Euler =========================

        ERC4626[] memory depositVaults = new ERC4626[](4);
        depositVaults[0] = ERC4626(getAddress(sourceChain, "euler_scUSD_MEV"));
        depositVaults[1] = ERC4626(getAddress(sourceChain, "euler_USDC_MEV"));
        depositVaults[2] = ERC4626(getAddress(sourceChain, "euler_USDC_RE7"));
        depositVaults[3] = ERC4626(getAddress(sourceChain, "euler_scUSD_RE7"));

        address[] memory subaccounts = new address[](1);
        subaccounts[0] = address(boringVault);

        _addEulerDepositLeafs(leafs, depositVaults, subaccounts);
        
        // ========================== Native =========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "wS"));

         // ========================== Merkl =========================
        ERC20[] memory tokensToClaim = new ERC20[](3);
        tokensToClaim[0] = getERC20(sourceChain, "rEUL");
        tokensToClaim[1] = getERC20(sourceChain, "wS");
        tokensToClaim[2] = getERC20(sourceChain, "UNI");
        _addMerklLeafs(leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "dev1Address"), tokensToClaim);

        // ========================== Verify =========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Sonic/StakedSonicUSDStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
