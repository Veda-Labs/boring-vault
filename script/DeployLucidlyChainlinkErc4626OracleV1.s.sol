// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {Deployer} from "src/helper/Deployer.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {AggregatorV3Interface} from "src/adapters/libraries/ChainlinkDataFeedLib.sol";
import {LucidlyChainlinkErc4626OracleV1} from "src/adapters/oracle/LucidlyChainlinkErc4626OracleV1.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployLucidlyChainlinkErc4626OracleV1Script is Script {}
