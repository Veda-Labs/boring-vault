// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {MerkleProofLib} from "@solmate/utils/MerkleProofLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {IPausable} from "src/interfaces/IPausable.sol";
import {DroneLib} from "src/base/Drones/DroneLib.sol";

contract ManagerWithBitmapVerification { 

    //bits and bobs
    mapping(address => uint256[2]) public subscriptions; 

}
