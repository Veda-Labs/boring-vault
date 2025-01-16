// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority, Auth} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {TimelockController, AccessControl} from "@openzeppelin/contracts/governance/TimelockController.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  forge script script/ProposeTimelockTx.s.sol:ProposeTimelockTxScript --with-gas-price 15000000000 --broadcast --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract ProposeTimelockTxScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;

    RolesAuthority public rolesAuthority = RolesAuthority(0xFa5b3E35F961229b25Caa108C3D42cEEb20d0122);
    TimelockController public timelock;
    address public multisig = 0x948dd9351D3721489Fe7A4530C55849cF0b4735D;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("sonicMainnet");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        Deployer deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d);
        address[] memory proposers = new address[](2);
        proposers[0] = dev0Address;
        proposers[1] = multisig;
        address[] memory executors = new address[](2);
        executors[0] = dev0Address;
        executors[1] = multisig;
        bytes memory constructorArgs = abi.encode(0, proposers, executors, address(0));
        timelock = TimelockController(
            payable(
                deployer.deployContract(
                    "TimelockController V0.3", type(TimelockController).creationCode, constructorArgs, 0
                )
            )
        );

        address[] memory targets = new address[](3);
        targets[0] = address(timelock);
        targets[1] = address(timelock);
        targets[2] = address(timelock);

        uint256[] memory values = new uint256[](3);

        bytes[] memory payloads = new bytes[](3);
        payloads[0] = abi.encodeWithSelector(AccessControl.revokeRole.selector, timelock.CANCELLER_ROLE(), dev0Address);
        payloads[1] = abi.encodeWithSelector(AccessControl.revokeRole.selector, timelock.PROPOSER_ROLE(), dev0Address);
        payloads[2] = abi.encodeWithSelector(AccessControl.revokeRole.selector, timelock.EXECUTOR_ROLE(), dev0Address);
        timelock.scheduleBatch(targets, values, payloads, bytes32(0), bytes32(0), 0);

        {
            address target = address(rolesAuthority);
            bytes memory payload = abi.encodeWithSelector(Auth.transferOwnership.selector, multisig);
            timelock.schedule(target, 0, payload, bytes32(0), bytes32(0), 0);
        }

        vm.stopBroadcast();
    }
}
