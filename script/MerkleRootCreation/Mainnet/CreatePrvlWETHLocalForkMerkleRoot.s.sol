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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreatePrvlWETHLocalForkMerkleRoot.s.sol:CreateRoot --rpc-url $MAINNET_RPC_URL -vvvv
 */
contract CreateRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    // LocalFork deployed addresses from localForkAddresses.txt
    address public agentTeller_1 = 0x7c5257EA4f3577643Be6D9A33824E8E9245CDa01;
    address public agentTeller_2 = 0xB31d657fe51edAd5577af4D948c119C9895Ea757;
    address public clientBoringVault = 0x5C1c20F7ae77f7cD80Fa4D08e053124b946f6C47;
    address public rawDataDecoderAndSanitizer = 0x771aD7Ba7C8cFfC2b6E906c98fAE8Ef8054bc162;
    address public clientManagerAddress = 0x493Fe36C7B88aa6316F3C5B0e5dfBe7E49ECf652;
    address public clientAccountantAddress = 0x5c4FBdA6bEc35DEeAD2bC54e7EeFC88a483a89B6;

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
            tellerAssets[0] = getERC20(sourceChain, "WETH");

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

        string memory filePath = "./leafs/Mainnet/FundMgmtWETHMainnetLeafs.json";

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
