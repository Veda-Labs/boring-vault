// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {HedgedBtcEthMmStrategyAdapter} from "src/adapters/HedgedBtcEthMmStrategyAdapter.sol";
import {UniV3PositionTvlAdapter} from "src/adapters/Univ3TvlAdapter.sol";
import {UniV4PositionTvlAdapter} from "src/adapters/Univ4TvlAdapter.sol";
import {MorphoLoopTvlAdapter} from "src/adapters/MorphoLoopTvlAdapter.sol";
import {CapCusdBalanceAdapter} from "src/adapters/CapCusdBalanceAdapter.sol";
import {SiUsdBalanceAdapter} from "src/adapters/SiUsdBalanceAdapter.sol";
import {CapStcusdBalanceAdapter} from "src/adapters/CapStcusdBalanceAdapter.sol";
import {PtCusd29Jan2026BalanceAdapter} from "src/adapters/PtCusd29Jan2026BalanceAdapter.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

contract DeployPtCusdLoopAdapters is Script, MerkleTreeHelper {
    function setUp() external {
        vm.createSelectFork("mainnet");
        setSourceChainName("mainnet");
    }

    function run() external {
        vm.startBroadcast(vm.envUint("PK"));

        CapCusdBalanceAdapter cusd = new CapCusdBalanceAdapter(
            0x9A5a3c3Ed0361505cC1D4e824B3854De5724434A,
            0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6,
            0xcCcc62962d17b8914c62D74FfB843d73B2a3cccC
        );

        CapStcusdBalanceAdapter stcusd = new CapStcusdBalanceAdapter(
            0x797Fa8167C35b19A30a5E7973561588BfEc0A086,
            0x9A5a3c3Ed0361505cC1D4e824B3854De5724434A,
            0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6,
            0x88887bE419578051FF9F4eb6C858A951921D8888
        );

        PtCusd29Jan2026BalanceAdapter ptcusd = new PtCusd29Jan2026BalanceAdapter(
            0xC8B82fb30a8e57c9C708B70D6f25d7B15DBEab09,
            0x9A5a3c3Ed0361505cC1D4e824B3854De5724434A,
            0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6,
            0x545A490f9ab534AdF409A2E682bc4098f49952e3
        );

        MorphoLoopTvlAdapter loop =
            new MorphoLoopTvlAdapter(0x802ec6e878dc9fe6905b8a0a18962dcca10440a87fa2242fbf4a0461c7b0c789);

        vm.stopBroadcast();
    }
}

contract DeployUniAdapter is Script, MerkleTreeHelper {
    uint256 public privateKey;

    function setUp() external {
        privateKey = vm.envUint("PK");
        setSourceChainName("arbitrum");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        UniV3PositionTvlAdapter adapter =
            new UniV3PositionTvlAdapter(0x2f5e87C9312fa29aed5c179E456625D79015299c, 5167902, 18);

        console.log("TVL of user", adapter.getUserTvl(address(0)));

        vm.stopBroadcast();
    }
}

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

contract DeployMorphoLoopAdapter is Script, MerkleTreeHelper {
    uint256 public privateKey;

    function setUp() external {
        privateKey = vm.envUint("PK");

        setSourceChainName("base");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        MorphoLoopTvlAdapter adapter =
            new MorphoLoopTvlAdapter(0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836);
        (uint256 collat, uint256 debt, uint256 supplied) =
            adapter.getUserPositionValues(0x4A0768ad836E787391f85bBaA110DF64D35C64d9);
        console.log("collateral", collat);
        console.log("debt", debt);
        console.log("supplied", supplied);
        console.log("LTV", (debt) * 1e8 / collat); // assuming supplied is in USDC terms
        console.log("TVL in USDC terms", adapter.getUserTvl(0x4A0768ad836E787391f85bBaA110DF64D35C64d9));

        vm.stopBroadcast();
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
