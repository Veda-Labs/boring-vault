// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {TellerWithYieldStreaming} from "src/base/Roles/TellerWithYieldStreaming.sol";
import {AaveV3BufferHelper} from "src/base/Roles/AaveV3BufferHelper.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployTellerWithYieldStreaming.s.sol:DeployTellerWithYieldStreamingScript --with-gas-price 30000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployTellerWithYieldStreamingScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;
    Deployer public deployer = Deployer(deployerAddress);
    address public v3PoolMainnet = 0x2816cf15F6d2A220E789aA011D5EE4eB6c47FEbA;
    //address public accountant = 0xb9583126AFa968935d99c4B515b508741CfeaF27;
    address public boringVault = 0x41359177826535F1Fa18937A421aDa03eE45c653;
    //address public WETHmainnet = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    //address public USDTmainnet = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    //address public USDCmainnet = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    //address public tempOwner = 0x7E97CaFdd8772706dbC3c83d36322f7BfC0f63C7;
    //address public rolesAuthority = 0xA22B0Ad31097ab7903Cf6a70109e500Bd109F6E9;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("ink");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        // deploy buffer helper
        creationCode = type(AaveV3BufferHelper).creationCode;
        constructorArgs = abi.encode(v3PoolMainnet, boringVault);
        AaveV3BufferHelper bufferHelper = AaveV3BufferHelper(
            deployer.deployContract(
                "Balanced Yield USDC Aave Buffer Helper V0.1", creationCode, constructorArgs, 0
            )
        );

        // deploy teller
        //creationCode = type(TellerWithYieldStreaming).creationCode;
        //constructorArgs = abi.encode(tempOwner, boringVault, accountant, WETHmainnet);
        //TellerWithYieldStreaming teller = TellerWithYieldStreaming(
        //    deployer.deployContract(
        //        "Insipid Ferret Teller With Yield Streaming V0.0", creationCode, constructorArgs, 0
        //    )
        //);
        //teller.updateAssetData(ERC20(USDTmainnet), true, true, 0);
        //teller.updateAssetData(ERC20(USDCmainnet), true, true, 0);
        //teller.allowBufferHelper(ERC20(USDTmainnet), bufferHelper);
        //teller.allowBufferHelper(ERC20(USDCmainnet), bufferHelper);
        //teller.setDepositBufferHelper(ERC20(USDTmainnet), bufferHelper);
        //teller.setDepositBufferHelper(ERC20(USDCmainnet), bufferHelper);
        //teller.setWithdrawBufferHelper(ERC20(USDTmainnet), bufferHelper);
        //teller.setWithdrawBufferHelper(ERC20(USDCmainnet), bufferHelper);
        //teller.setAuthority(Authority(rolesAuthority));
        //teller.transferOwnership(address(0));

        vm.stopBroadcast();
    }
}
