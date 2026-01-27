// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreatePrvlUSDCLocalForkMerkleRoot.s.sol:CreateRoot --rpc-url $MAINNET_RPC_URL -vvvv
 */
contract CreateRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    // LocalFork deployed addresses from localForkAddresses.txt
    address public agentTeller_1 = 0xe03544247540E32A51DD2fa1B8d5D30fc4E20AEa;
    address public agentTeller_2 = 0x5078e98b06f5aebC81095fCACBb9c6ED5e7276E6;
    address public clientBoringVault = 0xA9dA417025B427cE8519F989BBD5d89F3E322a20;
    address public rawDataDecoderAndSanitizer = 0xB040c5290C9161e77295be4dBF5F54dd7C6628f6;
    address public clientManagerAddress = 0x4693621DD1248D2c9b64090824f7FF588cfAc1d9;
    address public clientAccountantAddress = 0xDA1B54c28c32187C51e961e8B6ba9eFAFd1AD98e;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateFundMgmtMerkleRoot();
    }

    function generateFundMgmtMerkleRoot() public {
        setSourceChainName("mainnet");

        // Set runtime addresses for deployed contracts
        setAddress(false, "mainnet", "agentTeller_1", agentTeller_1);
        setAddress(false, "mainnet", "agentTeller_2", agentTeller_2);
        setAddress(false, "mainnet", "clientBoringVault", clientBoringVault);
        setAddress(false, "mainnet", "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, "mainnet", "clientManagerAddress", clientManagerAddress);
        setAddress(false, "mainnet", "clientAccountantAddress", clientAccountantAddress);
        setAddress(false, "mainnet", "boringVault", clientBoringVault);
        setAddress(false, "mainnet", "managerAddress", clientManagerAddress);
        setAddress(false, "mainnet", "accountantAddress", clientAccountantAddress);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // ========================== Client-Facing Vault ==========================
        {
            ERC20[] memory tellerAssets = new ERC20[](1);
            tellerAssets[0] = getERC20(sourceChain, "USDC");

            // Add boring vault leafs.
            _addTellerMgmtLeafs(leafs, getAddress(sourceChain, "agentTeller_1"), tellerAssets);
            _addTellerMgmtLeafs(leafs, getAddress(sourceChain, "agentTeller_2"), tellerAssets);
            _addLeafsForFeeClaiming(
                leafs,
                getAddress(sourceChain, "clientAccountantAddress"),
                tellerAssets,
                false
            );
        }

        string memory filePath = "./leafs/Mainnet/FundMgmtUSDCMainnetLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    // ========================== Add Teller Deposit Leafs ==========================
    function _addTellerMgmtLeafs(ManageLeaf[] memory leafs, address teller, ERC20[] memory assets) internal {
        ERC20 boringVault = TellerWithMultiAssetSupport(teller).vault();

        for (uint256 i; i < assets.length; ++i) {
            // Approve BoringVault to spend all assets.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(assets[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve ", boringVault.name(), ", to spend ", assets[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(boringVault);

            // Bulk deposit asset.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                teller,
                false,
                "bulkDeposit(address,uint256,uint256,address)",
                new address[](2),
                string.concat("bulk deposit ", assets[i].symbol(), " into ", boringVault.name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = address(clientBoringVault);
        
         // Bulk withdraw.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                teller,
                false,
                "bulkWithdraw(address,uint256,uint256,address)",
                new address[](2),
                string.concat("bulk withdraw ", assets[i].symbol(), " from ", boringVault.name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = address(clientBoringVault);
        }
    }   
}  
