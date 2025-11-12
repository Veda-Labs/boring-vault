// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AccountantWithYieldStreaming} from "src/base/Roles/AccountantWithYieldStreaming.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployAccountantWithYieldStreaming.s.sol:DeployAccountantWithYieldStreamingScript --with-gas-price 30000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployAccountantWithYieldStreamingScript is Script, Test, ContractNames, MainnetAddresses {
    uint256 public privateKey;
    Deployer public deployer = Deployer(deployerAddress);
    address public boringVault = 0xA53a60245922836B73184f443338FA24152d6AeE;
    address public payoutAddress = 0xc871E437627E40005b6fC8cdCf0AACb1B8Eb5ab0;
    address public USDTmainnet = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public USDCmainnet = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public tempOwner = 0x7E97CaFdd8772706dbC3c83d36322f7BfC0f63C7;
    address public rolesAuthority = 0xA22B0Ad31097ab7903Cf6a70109e500Bd109F6E9;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        creationCode = type(AccountantWithYieldStreaming).creationCode;
        constructorArgs = abi.encode(tempOwner, boringVault, payoutAddress, 1e6, USDTmainnet, 1.01e4, 0.99e4, 1, 0.1e4, 0.1e4);
        AccountantWithYieldStreaming accountant = AccountantWithYieldStreaming(
            deployer.deployContract(
                "Balanced Yield USDC Accountant With Yield Streaming V0.0", creationCode, constructorArgs, 0
            )
        );
        
        //console.log("accountant address: ", accountant); 

        //accountant.setRateProviderData(ERC20(USDCmainnet), true, address(0));
        //accountant.setAuthority(Authority(rolesAuthority));
        //accountant.transferOwnership(address(0));

        vm.stopBroadcast();
    }
}
