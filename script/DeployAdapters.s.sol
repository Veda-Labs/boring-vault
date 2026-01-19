// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {UniV3PositionTvlAdapter} from "src/adapters/Univ3TvlAdapter.sol";
import {UniV4PositionTvlAdapter} from "src/adapters/Univ4TvlAdapter.sol";
import {MorphoLoopTvlAdapter} from "src/adapters/MorphoLoopTvlAdapter.sol";
import {CapCusdBalanceAdapter} from "src/adapters/CapCusdBalanceAdapter.sol";
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

