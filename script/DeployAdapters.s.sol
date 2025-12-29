// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {UniV3PositionTvlAdapter} from "src/adapters/Univ3TvlAdapter.sol";
import {UniV4PositionTvlAdapter} from "src/adapters/Univ4TvlAdapter.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

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

