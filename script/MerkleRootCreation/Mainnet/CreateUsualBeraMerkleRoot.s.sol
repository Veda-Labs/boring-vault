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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateUsualBeraMerkleRoot.s.sol:CreateUsualBeraMerkleRoot --rpc-url $MAINNET_RPC_URL
 */
contract CreateUsualBeraMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x165c62448015d96c920dDA001Ae27733AF2C36c7;
    address public managerAddress = 0x0E6d1Eb34544023C595199AE4dd32908642d970f;
    address public accountantAddress = 0x2E0e8cF5FE97423f6929403246eBa88de4b2811D;
    address public rawDataDecoderAndSanitizer = 0x20A650CEc7d32EE955D4e32d74fBC88A4E3b3deA;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](5);
        SwapKind[] memory kind = new SwapKind[](5);
        assets[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "USDT");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "DAI");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "USD0");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "USD0_plus");
        kind[4] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Usual Money ==========================
        _addUsualMoneyLeafs(leafs); //minting, redeeming, etc

        // ========================== Incentives Controller ==========================
        _addTransferLeafs(
            leafs, getERC20(sourceChain, "USUAL"), getAddress(sourceChain, "beraUsual_incentives_distributor")
        );

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/UsualBeraStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
