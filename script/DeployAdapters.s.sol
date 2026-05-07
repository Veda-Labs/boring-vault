// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {HedgedBtcEthMmStrategyAdapter} from "src/adapters/HedgedBtcEthMmStrategyAdapter.sol";
import {UniV3PositionTvlAdapter} from "src/adapters/Univ3TvlAdapter.sol";
import {UniswapV3PositionTvlAdapter} from "src/adapters/UniswapV3PositionTvlAdapter.sol";
import {UniV4PositionTvlAdapter} from "src/adapters/Univ4TvlAdapter.sol";
import {MorphoBlueTvlAdapter} from "src/adapters/MorphoBlueTvlAdapter.sol";
import {Erc20TvlAdapter} from "src/adapters/Erc20TvlAdapter.sol";
import {CapCusdBalanceAdapter} from "src/adapters/CapCusdBalanceAdapter.sol";
import {CbBtcUsdcAaveV3BalanceAdapter} from "src/adapters/cbBtcUsdcAaveV3BalanceAdapter.sol";
import {CbBtcUsdcMorphoBalanceAdapter} from "src/adapters/cbBtcUsdcMorphoBalanceAdapter.sol";
import {WethUsdcAaveV3BalanceAdapter} from "src/adapters/WethUsdcAaveV3BalanceAdapter.sol";
import {SiUsdBalanceAdapter} from "src/adapters/SiUsdBalanceAdapter.sol";
import {CapStcusdBalanceAdapter} from "src/adapters/CapStcusdBalanceAdapter.sol";
import {PtCusd29Jan2026BalanceAdapter} from "src/adapters/PtCusd29Jan2026BalanceAdapter.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

// contract DeployUniAdapter is Script, MerkleTreeHelper {
//     uint256 public privateKey;
//
//     function setUp() external {
//         privateKey = vm.envUint("PK");
//         setSourceChainName("arbitrum");
//     }
//
//     function run() external {
//         vm.startBroadcast(privateKey);
//
//         UniV3PositionTvlAdapter adapter =
//             new UniV3PositionTvlAdapter(0x2f5e87C9312fa29aed5c179E456625D79015299c, 5167902, 18);
//
//         console.log("TVL of user", adapter.getUserTvl(address(0)));
//
//         vm.stopBroadcast();
//     }
// }

contract DeployUniv4Adapter is Script, MerkleTreeHelper {
    uint256 public privateKey;

    function setUp() external {
        privateKey = vm.envUint("PK");

        setSourceChainName("monad");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        UniV4PositionTvlAdapter adapter = new UniV4PositionTvlAdapter(
            0x18a9fc874581f3ba12b7898f80a683c66fd5877fd74b26a85ba9a3a79c549954,
            103770,
            -316360, // lower tick
            -314410, // upper tick
            6 // target decimals
        );

        console.log("TVL of user", adapter.getUserTvl(address(0)));

        vm.stopBroadcast();
    }
}

contract DeploycbBtcAaveAdapter is Script, MerkleTreeHelper {
    uint256 public privateKey;

    address AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address CBBTC_USD_CHAINLINK_FEED = 0xb41E773f507F7a7EA890b1afB7d2b660c30C8B0A;
    address USDC_USD_CHAINLINK_FEED = 0x3f73F03aa83B2A48ed27E964eD0fDb590332095B;
    address SYUSD_VAULT = 0x279CAD277447965AF3d24a78197aad1B02a2c589;
    address SYUSD_ACCOUNTANT = 0x03D9a9cE13D16C7cFCE564f41bd7E85E5cde8Da6;

    function setUp() external {
        privateKey = vm.envUint("PK");
        setSourceChainName("mainnet");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        CbBtcUsdcAaveV3BalanceAdapter adapter = new CbBtcUsdcAaveV3BalanceAdapter(
            AAVE_V3_POOL, CBBTC_USD_CHAINLINK_FEED, USDC_USD_CHAINLINK_FEED, SYUSD_VAULT, SYUSD_ACCOUNTANT
        );

        vm.stopBroadcast();

        (uint256 collat, uint256 debt, uint256 credit) =
            adapter.getUserPosition(0x272BCD869CbDFcb32c335dB2f1F6C54Eb1A50aCc);
        console.log("collateral", collat);
        console.log("debt", debt);
        console.log("credit", credit);
        console.log("TVL in CBTC terms", adapter.getUserTvl(0x272BCD869CbDFcb32c335dB2f1F6C54Eb1A50aCc));
    }
}
contract DeploycbBtcMorphoAdapter is Script, MerkleTreeHelper {
    uint256 public privateKey;

    bytes32 MORPHO_MARKET_ID = 0x64d65c9a2d91c36d56fbc42d69e979335320169b3df63bf92789e2c8883fcc64;
    address CBBTC_USD_CHAINLINK_FEED = 0xb41E773f507F7a7EA890b1afB7d2b660c30C8B0A;
    address USDC_USD_CHAINLINK_FEED = 0x3f73F03aa83B2A48ed27E964eD0fDb590332095B;
    address SYUSD_VAULT = 0x279CAD277447965AF3d24a78197aad1B02a2c589;
    address SYUSD_ACCOUNTANT = 0x03D9a9cE13D16C7cFCE564f41bd7E85E5cde8Da6;

    function setUp() external {
        privateKey = vm.envUint("PK");
        setSourceChainName("mainnet");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        CbBtcUsdcMorphoBalanceAdapter adapter = new CbBtcUsdcMorphoBalanceAdapter(
            MORPHO_MARKET_ID, CBBTC_USD_CHAINLINK_FEED, USDC_USD_CHAINLINK_FEED, SYUSD_VAULT, SYUSD_ACCOUNTANT
        );

        vm.stopBroadcast();

        (uint256 collat, uint256 debt, uint256 credit) =
            adapter.getUserPosition(0xc0d3c06701C267C06629a9a09089A4c7E7c7aD08);
        console.log("collateral", collat);
        console.log("debt", debt);
        console.log("credit", credit);
        console.log("TVL in CBTC terms", adapter.getUserTvl(0xc0d3c06701C267C06629a9a09089A4c7E7c7aD08));
    }
}

contract DeployWethAaveAdapter is Script, MerkleTreeHelper {
    uint256 public privateKey;

    address AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address WETH_USD_CHAINLINK_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address USDC_USD_CHAINLINK_FEED = 0x3f73F03aa83B2A48ed27E964eD0fDb590332095B;
    address WSTETH_USD_CHAINLINK_FEED = 0xe1D97bF61901B075E9626c8A2340a7De385861Ef;
    address SYUSD_VAULT = 0x279CAD277447965AF3d24a78197aad1B02a2c589;
    address SYUSD_ACCOUNTANT = 0x03D9a9cE13D16C7cFCE564f41bd7E85E5cde8Da6;

    function setUp() external {
        privateKey = vm.envUint("PK");
        setSourceChainName("mainnet");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        WethUsdcAaveV3BalanceAdapter adapter = new WethUsdcAaveV3BalanceAdapter(
            AAVE_V3_POOL,
            WSTETH_USD_CHAINLINK_FEED,
            WETH_USD_CHAINLINK_FEED,
            USDC_USD_CHAINLINK_FEED,
            SYUSD_VAULT,
            SYUSD_ACCOUNTANT
        );

        vm.stopBroadcast();

        (uint256 collat, uint256 debt, uint256 credit) =
            adapter.getUserPosition(0xA32DA4FF6476143972CB7360Bf5C18C4a590F44E);
        console.log("collateral", collat);
        console.log("debt", debt);
        console.log("credit", credit);
        console.log("TVL in WETH terms", adapter.getUserTvl(0xA32DA4FF6476143972CB7360Bf5C18C4a590F44E));
    }
}

contract DeployHedgedMmStrategyAdapter is Script, MerkleTreeHelper {
    function setUp() external {
        setSourceChainName("arbitrum");
    }

    function run() external {
        vm.startBroadcast(vm.envUint("PK"));

        HedgedBtcEthMmStrategyAdapter adapter = new HedgedBtcEthMmStrategyAdapter(
            0xc80E787e1c2A3841928F69e6a35e3F12c7b38a00,
            0xA923d8C976388518D65528324A587E4700f8F40f,
            0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f
        );

        vm.stopBroadcast();
    }
}

contract DeploySiUsdBalanceAdapter is Script, MerkleTreeHelper {
    uint256 public privateKey;

    function setUp() external {
        setSourceChainName("mainnet");
    }

    function run() external {
        vm.startBroadcast(vm.envUint("PK"));

        SiUsdBalanceAdapter adapter = new SiUsdBalanceAdapter(0xDBDC1Ef57537E34680B898E1FEBD3D68c7389bCB);

        vm.stopBroadcast();
    }
}

contract DeployMorphoBlueTvlAdapter is Script, MerkleTreeHelper {
    Deployer private deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function run() external {
        setSourceChainName("mainnet");
        vm.startBroadcast(vm.envUint("DEPLOYER01"));

        bytes memory creationCode = type(MorphoBlueTvlAdapter).creationCode;
        bytes memory constructorArgs = abi.encode(
            getBytes32(sourceChain, "cbBtc_USDC_86"),
            getAddress(sourceChain, "CBBTC_USD_oracle"),
            getAddress(sourceChain, "USDC_USD_oracle"),
            getAddress(sourceChain, "USDC_USD_oracle"),
            getAddress(sourceChain, "USDC")
        );

        deployer.deployContract("cbBtc_USDC_86 MorphoBlueTvlAdapter", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}

contract DeployErc20TvlAdapter is Script, MerkleTreeHelper {
    Deployer private deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function run() external {
        setSourceChainName("mainnet");
        vm.startBroadcast(vm.envUint("DEPLOYER01"));

        bytes memory creationCode = type(Erc20TvlAdapter).creationCode;
        bytes memory constructorArgs = abi.encode(
            getAddress(sourceChain, "stcUSD"),
            getAddress(sourceChain, "stcUSD_USD_oracle"),
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "USDC_USD_oracle")
        );

        deployer.deployContract("stcUSD/USD Erc20TvlAdapter", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}

contract DeployUniswapV3PositionTvlAdapterScript is Script, MerkleTreeHelper {
    Deployer private deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function run() external {
        setSourceChainName("mainnet");
        vm.startBroadcast(vm.envUint("DEPLOYER01"));

        bytes memory creationCode = type(UniswapV3PositionTvlAdapter).creationCode;
        bytes memory constructorArgs = abi.encode(
            getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
            getAddress(sourceChain, "RLUSD_USDC_100"),
            1259775, // random tokenId
            getAddress(sourceChain, "RLUSD_USD_oracle"),
            getAddress(sourceChain, "USDC_USD_oracle"),
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "USDC_USD_oracle")
        );

        deployer.deployContract("RLUSD_USDC_100 UniswapV3PositionTvlAdapter Example", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}
