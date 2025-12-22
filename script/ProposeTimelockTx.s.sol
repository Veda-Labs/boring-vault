// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { Deployer } from "src/helper/Deployer.sol";
import { RolesAuthority, Authority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { ContractNames } from "resources/ContractNames.sol";
import { MainnetAddresses } from "test/resources/MainnetAddresses.sol";
import { TimelockController, AccessControl } from "@openzeppelin/contracts/governance/TimelockController.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/ProposeTimelockTx.s.sol:ProposeTimelockTxScript --with-gas-price 15000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract ProposeTimelockTxScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;

    RolesAuthority public rolesAuthority = RolesAuthority(0x6889E57BcA038C28520C0B047a75e567502ea5F6);
    TimelockController public timelock = TimelockController(payable(0x70a64840A353c58f63333570f53dba0948bEcE3d));
    address public multisig = 0xCEA8039076E35a825854c5C2f85659430b06ec96;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        address[] memory targets = new address[](6);
        targets[0] = address(timelock);
        targets[1] = address(timelock);
        targets[2] = address(timelock);
        targets[3] = address(timelock);
        targets[4] = address(timelock);
        targets[5] = address(timelock);

        uint256[] memory values = new uint256[](6);

        bytes[] memory payloads = new bytes[](6);
        payloads[0] = abi.encodeWithSelector(AccessControl.grantRole.selector, timelock.CANCELLER_ROLE(), multisig);
        payloads[1] = abi.encodeWithSelector(AccessControl.grantRole.selector, timelock.PROPOSER_ROLE(), multisig);
        payloads[2] = abi.encodeWithSelector(AccessControl.revokeRole.selector, timelock.CANCELLER_ROLE(), dev0Address);
        payloads[3] = abi.encodeWithSelector(AccessControl.revokeRole.selector, timelock.CANCELLER_ROLE(), dev1Address);
        payloads[4] = abi.encodeWithSelector(AccessControl.revokeRole.selector, timelock.PROPOSER_ROLE(), dev0Address);
        payloads[5] = abi.encodeWithSelector(AccessControl.revokeRole.selector, timelock.PROPOSER_ROLE(), dev1Address);

        timelock.scheduleBatch(targets, values, payloads, bytes32(0), bytes32(0), 300);

        vm.stopBroadcast();
    }
}
