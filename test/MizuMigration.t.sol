// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority, Auth} from "@solmate/auth/authorities/RolesAuthority.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

// Run this command forge test -vv --match-path test/MizuMigration.t.sol --skip script
contract MizuMigrationTest is Test {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    // Underlying BoringVaults
    BoringVault internal hyperBTC = BoringVault(payable(0x9920d2075A350ACAaa4c6D00A56ebBEeD021cD7f));
    BoringVault internal hyperETH = BoringVault(payable(0x9E3C0D2D70e9A4BF4f9d5F0A6E4930ce76Fed09e));
    BoringVault internal hyperUSD = BoringVault(payable(0x340116F605Ca4264B8bC75aAE1b3C8E42AE3a3AB));

    // Underlying RolesAuthorities
    RolesAuthority internal rolesAuthorityHyperBTC = RolesAuthority(0xD1D2926e025609FB792aFA5673b755BdC22404a5);
    RolesAuthority internal rolesAuthorityHyperETH = RolesAuthority(0x0308296E380aB78d920e7d9EE5A2cF8cB38280C0);
    RolesAuthority internal rolesAuthorityHyperUSD = RolesAuthority(0xED8C9A514eB81124e370015878ea1fB3fEF18158);

    // Underlying Tellers
    TellerWithMultiAssetSupport internal tellerHyperBTC =
        TellerWithMultiAssetSupport(0xc8e88864800dCa0Ca7e68D0bD313296288c5eafa);
    TellerWithMultiAssetSupport internal tellerHyperETH =
        TellerWithMultiAssetSupport(0x47a871268CdC8846fa36afa5dE09302066349BaE);
    TellerWithMultiAssetSupport internal tellerHyperUSD =
        TellerWithMultiAssetSupport(0xbC08eF3368615Be8495EB394a0b7d8d5FC6d1A55);

    // Underlying Accountants
    AccountantWithRateProviders internal accountantHyperBTC =
        AccountantWithRateProviders(0xE7168910FAd153C123160AE87A84E0edbC393872);
    AccountantWithRateProviders internal accountantHyperETH =
        AccountantWithRateProviders(0xFD3d3AA636E3d0e702449CEE17F902eaf9c0B57e);
    AccountantWithRateProviders internal accountantHyperUSD =
        AccountantWithRateProviders(0x9212cA0805D9fEAB6E02a9642f5df33bc970eC13);

    // Underlying Midas Vaults
    address internal midasBTC = 0x164645fbC7220a3b4f8f5C6B473bCf1b6db146DD;
    address internal midasETH = 0x416ec6E04c009F9Bae99a47ef836BF2cc64Ec93c;
    address internal midasUSD = 0xd6FD5D4Fa64Fc7131e0ec3A4A53dC620A0FFc1Bc;

    // Underlying Midas Shares
    address internal midasShareBTC = 0xFFa36b4b011d87D89Fef3098aB30fEf7bcC3571e;
    address internal midasShareETH = 0x8E2C2C9dEF45efB9Bd3C448945830Ddb254154BE;
    address internal midasShareUSD = 0xA48CfD53263ADe6abDb0ac75287Cc0d5A2EEE17F;

    // BoringVault Share holders
    address internal userHyperBTC = 0xD248d2f09bFbe04e67fC7Fea08828D6AD6d95B6D;
    address internal userHyperETH = 0x971c83d7f22354DD381735B0B72BC707cAf3539C;
    address internal userHyperUSD = 0x971c83d7f22354DD381735B0B72BC707cAf3539C;

    // Multisig
    address internal multisig = 0x1D36f9e751638aFF1d8422cc557D70D5494a1854;

    uint256 newHyperBTCExchangeRate;
    uint256 newHyperETHExchangeRate;
    uint256 newHyperUSDExchangeRate;

    ERC20[] internal assetsBTC;
    ERC20[] internal assetsETH;
    ERC20[] internal assetsUSD;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 22698535;
        _startFork(rpcKey, blockNumber);

        assetsBTC.push(ERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599));

        assetsETH.push(ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        // assetsETH.push(ERC20(0x7122985656e38BDC0302Db86685bb972b145bD3C)); // Stone
        // assetsETH.push(ERC20(0xE6829d9a7eE3040e1276Fa75293Bde931859e8fA)); // cmETH
        // assetsETH.push(ERC20(0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee));

        assetsUSD.push(ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
        assetsUSD.push(ERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7));
    }

    function testMigration() public {
        // Make from a module for the mutlisig so it can call `execTransactionFromModule`.
        address from = 0xe2E2E2e2e2e2E2E2E2E2e2E2e2E2E2e2e2e2E2e2;
        vm.store(
            multisig,
            0xd71a90a935e1abe19645d4f9630a0044413a815e634f2ca5c4b4b04becfec14c,
            0x0000000000000000000000000000000000000000000000000000000000000001
        );

        address target;
        bytes memory data;
        (target, data) = createTx0();

        vm.prank(from);
        Safe(multisig).execTransactionFromModule(target, 0, data, Safe.Operation.DelegateCall);

        (target, data) = createTx1();
        vm.prank(from);
        Safe(multisig).execTransactionFromModule(target, 0, data, Safe.Operation.DelegateCall);

        (target, data) = createTx2();
        vm.prank(from);
        Safe(multisig).execTransactionFromModule(target, 0, data, Safe.Operation.DelegateCall);

        userWithdrawFlow(userHyperBTC, tellerHyperBTC, hyperBTC, ERC20(midasShareBTC));
        userWithdrawFlow(userHyperETH, tellerHyperETH, hyperETH, ERC20(midasShareETH));
        userWithdrawFlow(userHyperUSD, tellerHyperUSD, hyperUSD, ERC20(midasShareUSD));
    }

    function testPrintTxs() public {
        address target;
        bytes memory data;
        (target, data) = createTx0();
        console.log("TX0: ");
        console.log("target: ", target);
        console.log("data: ");
        console.logBytes(data);

        (target, data) = createTx1();
        console.log("TX1: ");
        console.log("target: ", target);
        console.log("data: ");
        console.logBytes(data);

        (target, data) = createTx2();
        console.log("TX2: ");
        console.log("target: ", target);
        console.log("data: ");
        console.logBytes(data);
    }
    // ========================================= HELPER FUNCTIONS =========================================

    // Goal stop all deposits
    function createTx0() internal view returns (address target, bytes memory data) {
        address[] memory targets = new address[](6);
        targets[0] = address(rolesAuthorityHyperBTC);
        targets[1] = address(rolesAuthorityHyperBTC);
        targets[2] = address(rolesAuthorityHyperETH);
        targets[3] = address(rolesAuthorityHyperETH);
        targets[4] = address(rolesAuthorityHyperUSD);
        targets[5] = address(rolesAuthorityHyperUSD);
        bytes[] memory datas = new bytes[](6);
        datas[0] = abi.encodeWithSelector(
            RolesAuthority.setPublicCapability.selector,
            address(tellerHyperBTC),
            TellerWithMultiAssetSupport.deposit.selector,
            false
        );
        datas[1] = abi.encodeWithSelector(
            RolesAuthority.setPublicCapability.selector,
            address(tellerHyperBTC),
            TellerWithMultiAssetSupport.depositWithPermit.selector,
            false
        );
        datas[2] = abi.encodeWithSelector(
            RolesAuthority.setPublicCapability.selector,
            address(tellerHyperETH),
            TellerWithMultiAssetSupport.deposit.selector,
            false
        );
        datas[3] = abi.encodeWithSelector(
            RolesAuthority.setPublicCapability.selector,
            address(tellerHyperETH),
            TellerWithMultiAssetSupport.depositWithPermit.selector,
            false
        );
        datas[4] = abi.encodeWithSelector(
            RolesAuthority.setPublicCapability.selector,
            address(tellerHyperUSD),
            TellerWithMultiAssetSupport.deposit.selector,
            false
        );
        datas[5] = abi.encodeWithSelector(
            RolesAuthority.setPublicCapability.selector,
            address(tellerHyperUSD),
            TellerWithMultiAssetSupport.depositWithPermit.selector,
            false
        );
        (target, data) = createMultiSendTx(targets, datas);
    }

    // Goal move ALL assets into Midas vaults
    function createTx1() internal view returns (address target, bytes memory data) {
        // Need to call approve and depositInstant for every asset.
        uint256 length = 2 * (assetsBTC.length + assetsETH.length + assetsUSD.length) + 6;
        address[] memory targets = new address[](length);
        bytes[] memory datas = new bytes[](length);

        targets[0] = address(hyperBTC);
        datas[0] = abi.encodeWithSelector(Auth.transferOwnership.selector, multisig);
        targets[1] = address(hyperETH);
        datas[1] = abi.encodeWithSelector(Auth.transferOwnership.selector, multisig);
        targets[2] = address(hyperUSD);
        datas[2] = abi.encodeWithSelector(Auth.transferOwnership.selector, multisig);

        uint256 idx = 3;

        for (uint256 i = 0; i < assetsBTC.length; ++i) {
            ERC20 asset = assetsBTC[i];
            uint8 assetDecimals = asset.decimals();
            targets[idx] = address(hyperBTC);
            uint256 amount = asset.balanceOf(address(hyperBTC));
            datas[idx++] = abi.encodeWithSignature(
                "manage(address,bytes,uint256)",
                address(asset),
                abi.encodeWithSelector(ERC20.approve.selector, midasBTC, amount),
                0
            );

            targets[idx] = address(hyperBTC);
            datas[idx++] = abi.encodeWithSignature(
                "manage(address,bytes,uint256)",
                address(midasBTC),
                abi.encodeWithSelector(
                    MidasVault.depositInstant.selector, asset, _changeDecimals(amount, assetDecimals, 18), 0, bytes32(0)
                ),
                0
            );
        }

        for (uint256 i = 0; i < assetsETH.length; ++i) {
            ERC20 asset = assetsETH[i];
            uint8 assetDecimals = asset.decimals();
            targets[idx] = address(hyperETH);
            uint256 amount = asset.balanceOf(address(hyperETH));
            datas[idx++] = abi.encodeWithSignature(
                "manage(address,bytes,uint256)",
                address(asset),
                abi.encodeWithSelector(ERC20.approve.selector, midasETH, amount),
                0
            );

            targets[idx] = address(hyperETH);
            datas[idx++] = abi.encodeWithSignature(
                "manage(address,bytes,uint256)",
                address(midasETH),
                abi.encodeWithSelector(
                    MidasVault.depositInstant.selector, asset, _changeDecimals(amount, assetDecimals, 18), 0, bytes32(0)
                ),
                0
            );
        }

        for (uint256 i = 0; i < assetsUSD.length; ++i) {
            ERC20 asset = assetsUSD[i];
            uint8 assetDecimals = asset.decimals();
            targets[idx] = address(hyperUSD);
            uint256 amount = asset.balanceOf(address(hyperUSD));
            datas[idx++] = abi.encodeWithSignature(
                "manage(address,bytes,uint256)",
                address(asset),
                abi.encodeWithSelector(ERC20.approve.selector, midasUSD, amount),
                0
            );

            targets[idx] = address(hyperUSD);
            datas[idx++] = abi.encodeWithSignature(
                "manage(address,bytes,uint256)",
                address(midasUSD),
                abi.encodeWithSelector(
                    MidasVault.depositInstant.selector, asset, _changeDecimals(amount, assetDecimals, 18), 0, bytes32(0)
                ),
                0
            );
        }

        targets[length - 3] = address(hyperBTC);
        datas[length - 3] = abi.encodeWithSelector(Auth.transferOwnership.selector, multisig);
        targets[length - 2] = address(hyperETH);
        datas[length - 2] = abi.encodeWithSelector(Auth.transferOwnership.selector, multisig);
        targets[length - 1] = address(hyperUSD);
        datas[length - 1] = abi.encodeWithSelector(Auth.transferOwnership.selector, multisig);

        (target, data) = createMultiSendTx(targets, datas);
    }

    // Add midas shares as valid withdraw asset, update exchange rate, and allow public bulkWithdraw
    function createTx2() internal returns (address target, bytes memory data) {
        address[] memory targets = new address[](21);
        targets[0] = address(accountantHyperBTC); // transferOwnership to multisig
        targets[1] = address(tellerHyperBTC); // transferOwnership to multisig
        targets[2] = address(accountantHyperBTC); // setRateProviderData
        targets[3] = address(accountantHyperBTC); // update exchange rate
        targets[4] = address(accountantHyperBTC); // unpause
        targets[5] = address(tellerHyperBTC); // add asset as withdraw asset
        targets[6] = address(rolesAuthorityHyperBTC); // allow public calls to bulkWithdraw
        targets[7] = address(accountantHyperETH); // transferOwnership to multisig
        targets[8] = address(tellerHyperETH); // transferOwnership to multisig
        targets[9] = address(accountantHyperETH); // setRateProviderData
        targets[10] = address(accountantHyperETH); // update exchange rate
        targets[11] = address(accountantHyperETH); // unpause
        targets[12] = address(tellerHyperETH); // add asset as withdraw asset
        targets[13] = address(rolesAuthorityHyperETH); // allow public calls to bulkWithdraw
        targets[14] = address(accountantHyperUSD); // transferOwnership to multisig
        targets[15] = address(tellerHyperUSD); // transferOwnership to multisig
        targets[16] = address(accountantHyperUSD); // setRateProviderData
        targets[17] = address(accountantHyperUSD); // update exchange rate
        targets[18] = address(accountantHyperUSD); // unpause
        targets[19] = address(tellerHyperUSD); // add asset as withdraw asset
        targets[20] = address(rolesAuthorityHyperUSD); // allow public calls to bulkWithdraw
        bytes[] memory datas = new bytes[](21);
        // This assumes accountants and boring vaults use SAME decimals
        newHyperBTCExchangeRate = (10 ** accountantHyperBTC.decimals()).mulDivDown(
            ERC20(midasShareBTC).balanceOf(address(hyperBTC)), hyperBTC.totalSupply()
        );
        newHyperBTCExchangeRate = _changeDecimals(newHyperBTCExchangeRate, 18, 8);
        if (newHyperBTCExchangeRate > type(uint96).max) revert("BTC bad exchange rate");
        console.log("New Exchange Rate BTC: ", newHyperBTCExchangeRate);
        newHyperETHExchangeRate = (10 ** accountantHyperETH.decimals()).mulDivDown(
            ERC20(midasShareETH).balanceOf(address(hyperETH)), hyperETH.totalSupply()
        );
        newHyperETHExchangeRate = _changeDecimals(newHyperETHExchangeRate, 18, 18);
        if (newHyperETHExchangeRate > type(uint96).max) revert("ETH bad exchange rate");
        console.log("New Exchange Rate ETH: ", newHyperETHExchangeRate);

        newHyperUSDExchangeRate = (10 ** accountantHyperUSD.decimals()).mulDivDown(
            ERC20(midasShareUSD).balanceOf(address(hyperUSD)), hyperUSD.totalSupply()
        );
        newHyperUSDExchangeRate = _changeDecimals(newHyperUSDExchangeRate, 18, 6);
        if (newHyperUSDExchangeRate > type(uint96).max) revert("USD bad exchange rate");
        console.log("New Exchange Rate USD: ", newHyperUSDExchangeRate);

        datas[0] = abi.encodeWithSelector(Auth.transferOwnership.selector, multisig);
        datas[1] = abi.encodeWithSelector(Auth.transferOwnership.selector, multisig);
        datas[2] = abi.encodeWithSelector(
            AccountantWithRateProviders.setRateProviderData.selector, midasShareBTC, true, address(0)
        );
        datas[3] =
            abi.encodeWithSelector(AccountantWithRateProviders.updateExchangeRate.selector, newHyperBTCExchangeRate);
        datas[4] = abi.encodeWithSelector(AccountantWithRateProviders.unpause.selector);
        datas[5] =
            abi.encodeWithSelector(TellerWithMultiAssetSupport.updateAssetData.selector, midasShareBTC, false, true, 0);
        datas[6] = abi.encodeWithSelector(
            RolesAuthority.setPublicCapability.selector,
            address(tellerHyperBTC),
            TellerWithMultiAssetSupport.bulkWithdraw.selector,
            true
        );

        datas[7] = abi.encodeWithSelector(Auth.transferOwnership.selector, multisig);
        datas[8] = abi.encodeWithSelector(Auth.transferOwnership.selector, multisig);
        datas[9] = abi.encodeWithSelector(
            AccountantWithRateProviders.setRateProviderData.selector, midasShareETH, true, address(0)
        );
        datas[10] =
            abi.encodeWithSelector(AccountantWithRateProviders.updateExchangeRate.selector, newHyperETHExchangeRate);
        datas[11] = abi.encodeWithSelector(AccountantWithRateProviders.unpause.selector);
        datas[12] =
            abi.encodeWithSelector(TellerWithMultiAssetSupport.updateAssetData.selector, midasShareETH, false, true, 0);
        datas[13] = abi.encodeWithSelector(
            RolesAuthority.setPublicCapability.selector,
            address(tellerHyperETH),
            TellerWithMultiAssetSupport.bulkWithdraw.selector,
            true
        );

        datas[14] = abi.encodeWithSelector(Auth.transferOwnership.selector, multisig);
        datas[15] = abi.encodeWithSelector(Auth.transferOwnership.selector, multisig);
        datas[16] = abi.encodeWithSelector(
            AccountantWithRateProviders.setRateProviderData.selector, midasShareUSD, true, address(0)
        );
        datas[17] =
            abi.encodeWithSelector(AccountantWithRateProviders.updateExchangeRate.selector, newHyperUSDExchangeRate);
        datas[18] = abi.encodeWithSelector(AccountantWithRateProviders.unpause.selector);
        datas[19] =
            abi.encodeWithSelector(TellerWithMultiAssetSupport.updateAssetData.selector, midasShareUSD, false, true, 0);
        datas[20] = abi.encodeWithSelector(
            RolesAuthority.setPublicCapability.selector,
            address(tellerHyperUSD),
            TellerWithMultiAssetSupport.bulkWithdraw.selector,
            true
        );

        (target, data) = createMultiSendTx(targets, datas);
    }

    function userWithdrawFlow(address user, TellerWithMultiAssetSupport teller, BoringVault share, ERC20 midasShare)
        internal
    {
        vm.startPrank(user);
        teller.bulkWithdraw(midasShare, share.balanceOf(user), 0, user);
        vm.stopPrank();
    }

    function createMultiSendTx(address[] memory targets, bytes[] memory data)
        internal
        pure
        returns (address target, bytes memory multiSendData)
    {
        require(targets.length == data.length, "Length mismatch");

        // MultiSend contract address
        target = 0x40A2aCCbd92BCA938b02010E17A5b8929b49130D;

        // Encode all transactions
        bytes memory transactions;
        for (uint256 i = 0; i < targets.length; i++) {
            // Each transaction is packed as:
            // operation (1 byte) + to (20 bytes) + value (32 bytes) + data length (32 bytes) + data (variable)
            transactions = abi.encodePacked(
                transactions,
                uint8(0), // operation = 0 for call
                targets[i], // to address
                uint256(0), // value = 0
                uint256(data[i].length), // data length
                data[i] // data
            );
        }

        // Encode the multiSend function call
        multiSendData = abi.encodeWithSignature("multiSend(bytes)", transactions);
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function _changeDecimals(uint256 amount, uint8 fromDecimals, uint8 toDecimals) internal pure returns (uint256) {
        if (fromDecimals == toDecimals) {
            return amount;
        } else if (fromDecimals < toDecimals) {
            return amount * 10 ** (toDecimals - fromDecimals);
        } else {
            return amount / 10 ** (fromDecimals - toDecimals);
        }
    }
}

interface MidasVault {
    function depositInstant(address tokenIn, uint256 amountToken, uint256 minReceiveAmount, bytes32 referrerId)
        external;
    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount) external;
}

interface Safe {
    enum Operation {
        Call,
        DelegateCall
    }

    function execTransactionFromModule(address to, uint256 value, bytes memory data, Operation operation) external;
}
