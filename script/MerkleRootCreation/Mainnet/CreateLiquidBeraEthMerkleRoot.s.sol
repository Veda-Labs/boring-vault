// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";
/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidBeraEthMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */

contract CreateLiquidBeraEthMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x83599937c2C9bEA0E0E8ac096c6f32e86486b410;
    address public managerAddress = 0x62b283d4FeFB2a120e1120dba9f83bE6CA41bCD7;
    address public accountantAddress = 0x04B8136820598A4e50bEe21b8b6a23fE25Df9Bd8;
    address public rawDataDecoderAndSanitizer = ;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidBeraEthStrategistMerkleRoot();
    }

    function generateLiquidBeraEthStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        leafIndex = 0;

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        address[] memory assets = new address[](5);
        SwapKind[] memory kind = new SwapKind[](5);
        assets[0] = getAddress(sourceChain, "WETH");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "WEETH");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "EETH");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "STETH");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "WSTETH");
        kind[4] = SwapKind.BuyAndSell;

        // ========================== Lido ==========================
        _addLidoLeafs(leafs);

        // ========================== EtherFi ==========================
        /**
         * stake, unstake, wrap, unwrap
         */
        _addEtherFiLeafs(leafs);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        //Verify 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/LiquidBeraEthStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForITBPositionManager(
        ManageLeaf[] memory leafs,
        address itbPositionManager,
        ERC20[] memory tokensUsed,
        string memory itbContractName
    ) internal {
        // acceptOwnership
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "acceptOwnership()",
            new address[](0),
            string.concat("Accept ownership of the ", itbContractName, " contract"),
            itbDecoderAndSanitizer
        );
        for (uint256 i; i < tokensUsed.length; ++i) {
            // Transfer
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(tokensUsed[i]),
                false,
                "transfer(address,uint256)",
                new address[](1),
                string.concat("Transfer ", tokensUsed[i].symbol(), " to the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbPositionManager;
            // Withdraw
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbPositionManager,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                string.concat("Withdraw ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
            // WithdrawAll
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbPositionManager,
                false,
                "withdrawAll(address)",
                new address[](1),
                string.concat("Withdraw all ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
        }
    }

    function _addLeafsForItbReserve(
        ManageLeaf[] memory leafs,
        address itbPositionManager,
        ERC20[] memory tokensUsed,
        string memory itbContractName
    ) internal {
        _addLeafsForITBPositionManager(leafs, itbPositionManager, tokensUsed, itbContractName);

        // mint
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "mint(uint256)",
            new address[](0),
            string.concat("Mint ", itbContractName),
            itbDecoderAndSanitizer
        );

        // redeem
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "redeem(uint256,uint256[])",
            new address[](0),
            string.concat("Redeem ", itbContractName),
            itbDecoderAndSanitizer
        );

        // redeemCustom
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "redeemCustom(uint256,uint48[],uint192[],address[],uint256[])",
            new address[](tokensUsed.length),
            string.concat("Redeem custom ", itbContractName),
            itbDecoderAndSanitizer
        );
        for (uint256 i; i < tokensUsed.length; ++i) {
            leafs[leafIndex].argumentAddresses[i] = address(tokensUsed[i]);
        }

        // assemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "assemble(uint256,uint256)",
            new address[](0),
            string.concat("Assemble ", itbContractName),
            itbDecoderAndSanitizer
        );

        // disassemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "disassemble(uint256,uint256[])",
            new address[](0),
            string.concat("Disassemble ", itbContractName),
            itbDecoderAndSanitizer
        );

        // fullDisassemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "fullDisassemble(uint256[])",
            new address[](0),
            string.concat("Full disassemble ", itbContractName),
            itbDecoderAndSanitizer
        );
    }
}

