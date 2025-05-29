// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";
/**
 *  source .env && forge script script/MerkleRootCreation/Berachain/CreateLiquidBeraBtcMerkleRoot.s.sol:CreateLiquidBeraBtcMerkleRoot --rpc-url $BERA_CHAIN_RPC_URL
 */
contract CreateLiquidBeraBtcMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xC673ef7791724f0dcca38adB47Fbb3AEF3DB6C80;
    address public managerAddress = 0x603064caAf2e76C414C5f7b6667D118322d311E6;
    address public accountantAddress = 0xF44BD12956a0a87c2C20113DdFe1537A442526B5;
    address public rawDataDecoderAndSanitizer = 0x592dE5aa69eD7855b4126d3818af23A634d46214;
    

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(berachain);
        setAddress(false, berachain, "boringVault", boringVault);
        setAddress(false, berachain, "managerAddress", managerAddress);
        setAddress(false, berachain, "accountantAddress", accountantAddress);
        setAddress(false, berachain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Fee Claiming ==========================
        {
        ERC20[] memory feeAssets = new ERC20[](3); 
        feeAssets[0] = getERC20(sourceChain, "WBTC");
        feeAssets[1] = getERC20(sourceChain, "LBTC");
        feeAssets[2] = getERC20(sourceChain, "eBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true);  
        }

        // ========================== Ooga Booga ==========================
        address[] memory assets = new address[](9);
        SwapKind[] memory kind = new SwapKind[](9);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "LBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "eBTC");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "iBGT");
        kind[3] = SwapKind.Sell;
        assets[4] = getAddress(sourceChain, "NECT"); // in case we want to borrow elsewhere and swap to NECT
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "HONEY");
        kind[5] = SwapKind.Sell;
        assets[6] = getAddress(sourceChain, "BGT"); //just in case
        kind[6] = SwapKind.Sell;
        assets[7] = getAddress(sourceChain, "USDC"); // in case we want to borrow elsewhere and swap to NECT
        kind[7] = SwapKind.BuyAndSell;
        assets[8] = getAddress(sourceChain, "WBERA");
        kind[8] = SwapKind.Sell;

        _addOogaBoogaSwapLeafs(leafs, assets, kind);

        // ========================== Royco ==========================
        address[] memory weirollWallets = new address[](2); 
        weirollWallets[0] = 0x8704852E95AA04799db5A1B03C4205156A74af0F; 
        weirollWallets[1] = 0x7f668bAee90cA161e6a7a9D3E0148a6738C78360; 
        _addRoycoWithdrawMerkleDepositLeafs(leafs, weirollWallets); 
        
        // ========================== Tellers ==========================
        // Prime
        {
            address oldPrimeLiquidBeraBTCTeller = 0xf16Cd75E975163f3A0A1af42E5609aB67A6553D7;
            address newPrimeLiquidBeraBTCTeller = 0xCD20c63dDAfAc686d311B40f24DcaD316dDE8D9c; 

            ERC20[] memory tellerAssets = new ERC20[](3);
            tellerAssets[0] = getERC20(sourceChain, "WBTC");
            tellerAssets[1] = getERC20(sourceChain, "LBTC");
            tellerAssets[2] = getERC20(sourceChain, "eBTC");
            _addTellerLeafs(leafs, oldPrimeLiquidBeraBTCTeller, tellerAssets, false, true);
            _addTellerLeafs(leafs, newPrimeLiquidBeraBTCTeller, tellerAssets, false, true);
        }
        // eBTC
        {
            address eBTCTellerLZ = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268;
            ERC20[] memory tellerAssets = new ERC20[](2);
            tellerAssets[0] = getERC20(sourceChain, "WBTC");
            tellerAssets[1] = getERC20(sourceChain, "LBTC");
            _addTellerLeafs(leafs, eBTCTellerLZ, tellerAssets, false, true);
        }

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WBTC"), getAddress(sourceChain, "WBTC"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));   
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "LBTC"), getAddress(sourceChain, "LBTC_OFT"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));   

        // ========================== Crosschain Teller ==========================
        {
        address eBTCTellerLZ = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268;

        address[] memory depositAssets = new address[](2); 
        depositAssets[0] = getAddress(sourceChain, "LBTC"); 
        depositAssets[1] = getAddress(sourceChain, "WBTC"); 

        address[] memory feeAssets = new address[](1); 
        feeAssets[0] = getAddress(sourceChain, "ETH"); //pay bridge fee in ETH

        _addCrossChainTellerLeafs(leafs, eBTCTellerLZ, depositAssets, feeAssets, abi.encode(layerZeroMainnetEndpointId));  
        }

        // ========================== Kodiak ==========================
        address[] memory islands = new address[](1);  
        islands[0] = getAddress(sourceChain, "kodiak_island_EBTC_WBTC_005%");

        _addKodiakIslandLeafs(leafs, islands, false); //don't include native leaves

        // ========================== Infrared ==========================
        _addInfraredVaultLeafs(leafs, getAddress(sourceChain, "infrared_vault_primeLiquidBeraBTC"));
        _addInfraredVaultLeafs(leafs, getAddress(sourceChain, "infrared_vault_iBGT"));
        _addInfraredVaultLeafs(leafs, getAddress(sourceChain, "infrared_vault_wbtc_ebtc"));

        // ========================== BeraBorrow ==========================

        {
            address[] memory collateralAssets = new address[](4);
            collateralAssets[0] = getAddress(sourceChain, "bbWBTC");
            collateralAssets[1] = getAddress(sourceChain, "bbLBTC");
            collateralAssets[2] = getAddress(sourceChain, "bbeBTC");
            collateralAssets[3] = getAddress(sourceChain, "bbeBTC-WBTC");


            address[] memory denManagers = new address[](4);
            denManagers[0] = getAddress(sourceChain, "WBTCDenManager");
            denManagers[1] = getAddress(sourceChain, "LBTCDenManager");
            denManagers[2] = getAddress(sourceChain, "eBTCDenManager");
            denManagers[3] = getAddress(sourceChain, "eBTC-WBTCDenManager");


            _addBeraborrowLeafs(leafs, collateralAssets, denManagers, false);

            _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sNECT")));
            _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "vaultedsNECT")));
        }
        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Berachain/LiquidBeraBtcStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }
}

