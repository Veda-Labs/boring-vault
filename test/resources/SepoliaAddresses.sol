// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

contract SepoliaAddresses {
    // Paravel Ecosystem
    address public prvl0DevAddress = 0x98e46e0B009269CB6Fc0B4CD13C6E1247B8b00b8;
    address public prvl1DevAddress = 0x98e46e0B009269CB6Fc0B4CD13C6E1247B8b00b8;
    address public prvliquidPayoutAddress = 0x98e46e0B009269CB6Fc0B4CD13C6E1247B8b00b8;
    address public prvlDeployer = 0xa631E6B750A4544C4440773c2806b900Cf38fc46;

    // DeFi Ecosystem
    //address public ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    //https://developers.circle.com/stablecoins/usdc-contract-addresses
    //https://docs.uniswap.org/contracts/v3/reference/deployments/ethereum-deployments
    ERC20 public USDC = ERC20(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
    ERC20 public WETH = ERC20(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);

    //https://github.com/balancer/balancer-deployments/blob/master/v2/tasks/20210418-vault/output/base.json
    address public balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    // deployed contracts
    address public USDCPrvlClientVault = 0xdF3dac1B6F7d50AF3cb38Bdc0FC9A1D54f5F2C22;
}
