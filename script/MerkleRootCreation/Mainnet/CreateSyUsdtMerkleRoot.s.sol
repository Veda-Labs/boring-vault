// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {LayerZeroTeller} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract CreateSyUsdtLeafs is Script, MerkleTreeHelper {
    uint256 public privateKey;

    Deployer public deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    address public rawDataDecoderAndSanitizerEthereum = 0xfb3d1B638319cbD7E6459D17B8dDe74C4B5EA307;
    RolesAuthority internal rolesAuthority = RolesAuthority(0x1B77bB2d878d3CE1C55D5621CFFDF0C6ce62BB63);
    BoringVault internal boringVault = BoringVault(payable(0x2A9001e73811aEBad909aB14e453Fd0A91d7A31a));
    LayerZeroTeller internal teller = LayerZeroTeller(0x90F9101416b1eCF7297C918Aaf775E6EE6A77760);
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0x529DE000e4AdAA243aB42b83D2563E2E7A3B182e);
    AccountantWithRateProviders internal accountant =
        AccountantWithRateProviders(0x4C937c0D0b6660a1F72263220c934F23d864495d);
    BoringOnChainQueue internal queue = BoringOnChainQueue(0x67b1faa35e51fAE48e3f035cDAE6601B1CDeFB2D);
    BoringSolver internal solver = BoringSolver(0xbF3A130838C76Dd4Ec864d84BB4Df2DFb0D41CF3);

    address public syUsdVault = 0x279CAD277447965AF3d24a78197aad1B02a2c589;
    address public syUsdWithdrawQueue = 0xF632c10b19f2a0451cD4A653fC9ca0c15eA1040b;
    address public syUsdTeller = 0xaefc11908fF97c335D16bdf9F2Bf720817423825;
    address public syUsdQueueSolver = 0x1d82e9bCc8F325caBBca6E6A3B287fE586536805;

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

    function setUp() external {
        privateKey = vm.envUint("DEPLOYER01");
        vm.createSelectFork("mainnet");
        setSourceChainName("mainnet");

        setAddress(true, mainnet, "boringVault", address(boringVault));
        setAddress(true, mainnet, "managerAddress", address(manager));
        setAddress(true, mainnet, "manager", address(manager));
        setAddress(true, mainnet, "accountantAddress", address(accountant));
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizerEthereum);
    }

    function run() public {
        // ManageLeaf[] memory leafs = new ManageLeaf[](64);
        // _addLeafs(leafs);
        // bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        // string memory filePath = "./leafs/Mainnet/SyUsdtMainnetStrategistLeafs.json";
        // _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        address newOwner = 0x1b514df3413DA9931eB31f2Ab72e32c0A507Cad5;

        Deployer.Tx[] memory txns = new Deployer.Tx[](8);

        // txns[0] = Deployer.Tx

        vm.startBroadcast(privateKey);

        // manager.setManageRoot(0x31Cf9D74d825E8BcF9608275B85dD9F1f4B3b429, manageTree[manageTree.length - 1][0]);
        // rolesAuthority.setUserRole(0x31Cf9D74d825E8BcF9608275B85dD9F1f4B3b429, STRATEGIST_ROLE, true);

        vm.stopBroadcast();
    }

    function _addLeafs(ManageLeaf[] memory leafs) internal {
        // fee claiming
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDT");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // syusd leafs
        ERC20[] memory assets = new ERC20[](1);
        assets[0] = ERC20(getAddress(sourceChain, "USDC"));
        _addTellerLeafs(leafs, address(syUsdTeller), assets, false, true);
        _addWithdrawQueueLeafs(leafs, syUsdWithdrawQueue, syUsdVault, assets);

        // fly trade leafs
        address[] memory swapAssets = new address[](2);
        swapAssets[0] = getAddress(sourceChain, "USDT");
        swapAssets[1] = getAddress(sourceChain, "USDC");
        SwapKind[] memory kind = new SwapKind[](2);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;

        _addMagpieSwapLeafs(leafs, swapAssets, kind);

        // TON relayer
        _addEthereumToTonViaLZMultiCallLeafs(
            leafs,
            getAddress(sourceChain, "USDT"),
            getAddress(sourceChain, "LZMultiCall"),
            getAddress(sourceChain, "LZMultiCallTransferHelper"),
            getAddress(sourceChain, "USDTTonOFTAdapter"),
            getBytes32(sourceChain, "syUSDTTonRelayer")
        );
    }
}
