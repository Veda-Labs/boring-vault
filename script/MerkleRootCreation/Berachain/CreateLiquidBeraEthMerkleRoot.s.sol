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
 *  source .env && forge script script/MerkleRootCreation/Berachain/CreateLiquidBeraEthMerkleRoot.s.sol:CreateLiquidBeraEthMerkleRoot --rpc-url $BERA_CHAIN_RPC_URL
 */
contract CreateLiquidBeraEthMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x83599937c2C9bEA0E0E8ac096c6f32e86486b410; 
    address public managerAddress = 0x62b283d4FeFB2a120e1120dba9f83bE6CA41bCD7; 
    address public accountantAddress = 0x04B8136820598A4e50bEe21b8b6a23fE25Df9Bd8;
    address public rawDataDecoderAndSanitizer = 0x934aF04aBF72B9dB1D5425F0d8bDbf6670E7d2C1;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== Ooga Booga ==========================
        address[] memory assets = new address[](4); 
        SwapKind[] memory kind = new SwapKind[](4); 
        assets[0] = getAddress(sourceChain, "iBGT"); 
        kind[0] = SwapKind.Sell; 
        assets[1] = getAddress(sourceChain, "WETH"); 
        kind[1] = SwapKind.BuyAndSell; 
        assets[2] = getAddress(sourceChain, "WEETH"); 
        kind[2] = SwapKind.BuyAndSell; 
        assets[3] = getAddress(sourceChain, "BGT"); //just in case
        kind[3] = SwapKind.Sell; 
        
        _addOogaBoogaSwapLeafs(leafs, assets, kind);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WETH"), getAddress(sourceChain, "stargateWETH"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== PrimeLiquidBeraETH ==========================
        ERC20[] memory tellerAssets = new ERC20[](2);
        tellerAssets[0] = getERC20(sourceChain, "WETH");
        tellerAssets[1] = getERC20(sourceChain, "WEETH");
        _addTellerLeafs(leafs, getAddress(sourceChain, "primeLiquidBeraETHTeller"), tellerAssets, false, true);

        // ========================== Royco ==========================
        address[] memory weirollWallets = new address[](3);
        weirollWallets[0] = 0xD9905ea24E55c1cE053F2DBe0fFA019dCbc1349d;
        weirollWallets[1] = 0x09dAdd9DC48660c4db718B2200f2710877e613A5;
        weirollWallets[2] = 0xC6f02dea1fF6349B14027C17522D8986974Cd2a0;
        _addRoycoWithdrawMerkleDepositLeafs(leafs, weirollWallets);

        // ========================== Infrared ==========================
        _addInfraredVaultLeafs(leafs, getAddress(sourceChain, "infrared_vault_primeLiquidBeraETH"));
        _addInfraredVaultLeafs(leafs, getAddress(sourceChain, "infrared_vault_iBGT"));

        //============================ BeraBorrow ==========================
        // TODO
        // {
        //     address[] memory collateralAssets = new address[](2);

        //     address[] memory borrowAssets = new address[](2);

        //     address[] memory denManagers = new address[](2);


        //     _addBeraborrowLeafs(leafs, collateralAssets, borrowAssets, denManagers, false);
        // }

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "WETH");
        feeAssets[1] = getERC20(sourceChain, "WEETH");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true);

        // ========================== Verify ==========================
        
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Berachain/LiquidBeraEth.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
