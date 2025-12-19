// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// import "forge-std/Script.sol";
// import {console} from "../lib/forge-std/src/console.sol";
// import {UniV3PositionTvlAdapter} from "src/adapters/Univ3TvlAdapter.sol";


// contract DeployUniAdapter is Script, MerkleTreeHelper {
//     uint256 public privateKey;

//     function setUp() external {
//         privateKey = vm.envUint("PK");

//         setSourceChainName("arbitrum");
//     }

//     function run() external {
//         vm.startBroadcast(privateKey);

//         address adapter = new UniV3PositionTvlAdapter(
//             0x2f5e87C9312fa29aed5c179E456625D79015299c,
//             5167902,
//             18
//         );

//         console.log("TVL of user",adapter.getUserTvl(address(0)));

//         vm.stopBroadcast();
//     }
// }

