// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {TimelockController, AccessControl} from "@openzeppelin/contracts/governance/TimelockController.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployTimelock.s.sol:DeployTimelockScript --with-gas-price 15000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployTimelockScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;

    Deployer public deployer;
    TimelockController public timelock;

    address public canceller = 0xA916fD5252160A7E56A6405741De76dc0Da5A0Cd;
    address public executor = address(0);

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("unichain");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        deployer = Deployer(deployerAddress);
        creationCode = type(TimelockController).creationCode;
        uint256 minDelay = 0;
        address[] memory proposers = new address[](3);
        proposers[0] = 0xD48b7e87fDCCaCa7ea93F347755c799eBE0fD35F; // real
        proposers[1] = 0xf8553c8552f906C19286F21711721E206EE4909E; // temp
        proposers[2] = 0x1cdF47387358A1733968df92f7cC14546D9E1047; // temp
        address[] memory executors = new address[](1);
        executors[0] = executor;
        address tempAdmin = 0x7E97CaFdd8772706dbC3c83d36322f7BfC0f63C7;
        constructorArgs = abi.encode(minDelay, proposers, executors, tempAdmin);
        timelock =
        TimelockController(payable(deployer.deployContract("Golden Goose Timelock V0.1", creationCode, constructorArgs, 0)));


        timelock.grantRole(timelock.CANCELLER_ROLE(), canceller);
        for (uint256 i = 0; i < proposers.length; i++) {
            timelock.revokeRole(timelock.CANCELLER_ROLE(), proposers[i]);
        }
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), tempAdmin);

        vm.stopBroadcast();
    }
}
