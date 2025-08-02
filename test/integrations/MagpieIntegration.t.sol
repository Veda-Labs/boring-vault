// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, stdStorage, StdStorage, stdError, console, Vm} from "../../lib/forge-std/src/Test.sol";
import {BoringVault, Auth} from "../../src/base/BoringVault.sol";
import {LayerZeroTeller} from "../../src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {AccountantWithRateProviders} from "../../src/base/Roles/AccountantWithRateProviders.sol";
import {ManagerWithMerkleVerification} from "../../src/base/Roles/ManagerWithMerkleVerification.sol";
import {
    ChainlinkCCIPTeller,
    CrossChainTellerWithGenericBridge
} from "../../src/base/Roles/CrossChain/Bridges/CCIP/ChainlinkCCIPTeller.sol";
import {Deployer} from "../../src/helper/Deployer.sol";
import {Pauser} from "../../src/base/Roles/Pauser.sol";
import {SafeTransferLib} from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";
import {IRateProvider} from "../../src/interfaces/IRateProvider.sol";
import {RolesAuthority, Authority} from "../../lib/solmate/src/auth/authorities/RolesAuthority.sol";
import {MockLayerZeroEndPoint} from "../../src/helper/MockLayerZeroEndPoint.sol";
import {TellerWithMultiAssetSupport} from "../../src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringOnChainQueue} from "../../src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "../../src/base/Roles/BoringQueue/BoringSolver.sol";
import {GenericRateProvider} from "../../src/helper/GenericRateProvider.sol";
import {MerkleTreeHelper} from "../../test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AddressToBytes32Lib} from "../../src/helper/AddressToBytes32Lib.sol";
import {BaseDecoderAndSanitizer} from "../../src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {MagpieDecoderAndSanitizer} from "../../src/base/DecodersAndSanitizers/MagpieDecoderAndSanitizer.sol";
import {console} from "../../lib/forge-std/src/Test.sol";
// struct ManageLeaf {
//     address target;
//     bool canSendValue;
//     string signature;
//     address[] argumentAddresses;
//     string description;
//     address decoderAndSanitizer;
// }

contract MagpieIntegTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    using AddressToBytes32Lib for address;

    ERC20 public USDC;
    ERC20 public RLP;
    address public owner;
    address user01 = makeAddr("user01");
    address user02 = makeAddr("user02");
    RolesAuthority internal rolesAuthority = RolesAuthority(0xf7F3ace7f6cA2Cb1E7ccbE3Bf2Da13D001D36fdF);
    BoringVault internal boringVault = BoringVault(payable(0x279CAD277447965AF3d24a78197aad1B02a2c589));
    LayerZeroTeller internal teller = LayerZeroTeller(0xaefc11908fF97c335D16bdf9F2Bf720817423825);
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0x9B3e565ffC70c4b72516BC2dbec4b3c790940CE8);
    AccountantWithRateProviders internal accountant =
        AccountantWithRateProviders(0x03D9a9cE13D16C7cFCE564f41bd7E85E5cde8Da6);
    BoringOnChainQueue internal queue = BoringOnChainQueue(0xF632c10b19f2a0451cD4A653fC9ca0c15eA1040b);
    BoringSolver internal solver = BoringSolver(0x1d82e9bCc8F325caBBca6E6A3B287fE586536805);
    Deployer internal deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);
    Pauser internal pauser = Pauser(0x31b9236A58f6EF7e0431811DAbBa8C706AFB0F2D);
    address public rawDataDecoderAndSanitizer;
    address public uniswapV3NonFungiblePositionManager;

    /// roles
    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant MINTER_ROLE = 2;
    uint8 public constant BURNER_ROLE = 3;
    uint8 public constant MANAGER_INTERNAL_ROLE = 4;
    uint8 public constant PAUSER_ROLE = 5;
    uint8 public constant SOLVER_ROLE = 12;
    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant MULTISIG_ROLE = 9;
    uint8 public constant STRATEGIST_MULTISIG_ROLE = 10;
    uint8 public constant STRATEGIST_ROLE = 7;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 11;
    uint8 public constant GENERIC_PAUSER_ROLE = 14;
    uint8 public constant GENERIC_UNPAUSER_ROLE = 15;
    uint8 public constant PAUSE_ALL_ROLE = 16;
    uint8 public constant UNPAUSE_ALL_ROLE = 17;
    uint8 public constant SENDER_PAUSER_ROLE = 18;
    uint8 public constant SENDER_UNPAUSER_ROLE = 19;
    uint8 public constant CAN_SOLVE_ROLE = 31;
    uint8 public constant ONLY_QUEUE_ROLE = 32;
    uint8 public constant SOLVER_ORIGIN_ROLE = 33;

    struct DepositAsset {
        ERC20 asset;
        bool isPeggedToBase;
        address rateProvider;
        string genericRateProviderName;
        address target;
        bytes4 selector;
        bytes32[8] params;
    }

    struct AddressOrName {
        address address_;
        string name;
    }

    struct WithdrawAsset {
        AddressOrName addressOrName;
        uint16 maxDiscount;
        uint16 minDiscount;
        uint24 minimumSecondsToDeadline;
        uint96 minimumShares;
        uint24 secondsToMaturity;
    }

    DepositAsset[] public depositAssets;
    WithdrawAsset[] public withdrawAssets;

    function setUp() external {
        setSourceChainName("mainnet");
        vm.createSelectFork(sourceChain);
        owner = 0x1b514df3413DA9931eB31f2Ab72e32c0A507Cad5;
        USDC = getERC20(sourceChain, "USDC");
        RLP = getERC20(sourceChain, "RLP");

        rawDataDecoderAndSanitizer =
            address(new FullMagpieDecoderAndSanitizer(address(boringVault), getAddress(sourceChain, "magpieRouterV3")));

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(accountant));
    }

    // One Inch Integration
    function test__CreateMagpieInteg() public {
        // give roles

        vm.startPrank(rolesAuthority.owner());
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE, address(manager), manager.manageVaultWithMerkleVerification.selector, true
        );
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        vm.stopPrank();

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1 * 1e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        // _addOdosSwapLeafs(leafs, tokens, kind);

        leafs[0] = ManageLeaf(
            address(USDC),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Magpie Router V3 to spend ", RLP.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[0].argumentAddresses[0] = getAddress(sourceChain, "magpieRouterV3");

        leafs[1] = ManageLeaf(
            getAddress(sourceChain, "magpieRouterV3"),
            false,
            "swapWithMagpieSignature(bytes)",
            new address[](0),
            string.concat("Swap Compact ", USDC.symbol(), " for ", RLP.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        vm.prank(manager.owner());
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        console.log("BoringVault USDC balance: %s", USDC.balanceOf(address(boringVault)));
        console.log("BoringVault RLP balance: %s", RLP.balanceOf(address(boringVault)));
        console.log("Address of boringVault: %s", address(boringVault));

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve RLP to Magpie Router V3
        manageLeafs[1] = leafs[1]; //swapWithMagpieSignature() USDC <-> RLP

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "RLP"); //approve
        targets[1] = getAddress(sourceChain, "magpieRouterV3"); //approve

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "magpieRouterV3"), type(uint256).max
        );

        // // @dev NOTE: this is swapWithMagpieSignature ABI-encoded. This tx data was retrieved directly from the MagpieV3 API. After assembling the tx, the output from the /assemble endpoint will return the following data in the data field. This includes everything needed for swapping. Submit the entire tx data as the targetData. Note that is already includes the function signature, etc.

        targetData[1] =
            hex"73fc44570000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000034802ad0120279cad277447965af3d24a78197aad1b02a2c589a0b86991c6218b36c1d19d4a2e9eb0ce3606eb484956b52ae2ff65d74ca2d61207523288e4528f96e000d4b800d9f800e3e000e5b5065a3d8233ce0e40854596503f3cf5a31a6cad69e0669e605787b38cd927582a9fff872a04efe956a8d3ab3569db697867f669082ab0e72c9dcf46c7dbe6af1c0000e0688dc307b82a1af6bb1291a796e0f800e03b9aca00060300e49995855c00494d039ab6792f18e368e530dff93102005c0200ed0300e4f196187f40d16fc0246ad3160ccc09b8d0d3a2cd28ae6c2fa8068db8bac710cb000000c8f801a0ffff9a5889f795069a41a8a2f0048600800000000000000000000000000000000000000000000000000000000000000001010a02010e02005c03012203012e0300e403013003013d0301400600060a00000000000000000000000000000000000000000000000000000000000003017d0500004628f13651ead6793f8d838b34b8f8522fb0cc5202010e0201a40500403df021240101c103008a03012e05004003008a66a1e37c9b0eaddca17d3662d6c05f4decf3e1100201d41202f5c7b4b9e47a1a484e8b270be34dbbc750550201d40201eb0500606e553f650102080500600642cf3b7e98a1bbc51ed6e5c09f5a93743e6008890201eb0202130500800101c103008a03012e05008003008a020070000206070706000000000000000000000000000000000000000000000000000000b82c524715c2b4449ed10302420500a003026300020a0b00000000000000000000000000000000000000000000000000000000000302760500c0030263eda49bce2f38d284f839be1f4f2e23e6c7cc7dbd0200700202a00500e00005060708070000000000000000000000000000000000000000000000000000000302bd0500c00302630500a002007002004805010002000000e900ed00000100000101010a00000000400161017d00ed070020019e01a4000001000001b801c1000000000001c501d401a406002001e801eb000001000001ff02080000000020020c021301eb0100000227023000000000000230023f0213060020023f02420000080020026d02760000070020029702a0000003000002b402bd000008002002de02ea000003000002ea02f30000000000000000000000000000000000000000000000000000";

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }
}

contract FullMagpieDecoderAndSanitizer is MagpieDecoderAndSanitizer {
    constructor(address _boringVault, address _magpieRouter) MagpieDecoderAndSanitizer(_magpieRouter) {}
}
