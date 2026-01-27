// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {PrvlAaveBorrow, TokenConfig} from "src/adaptors/PrvlAaveBorrow.sol";
import "forge-std/Script.sol";

contract DeployPrvlBorrow is Script {
    address constant TEAM_MULTISIG = 0xE42C03CB1999E345fdE8465CAAf4B4379143375F;
    address constant AUTHORITY = 0x0951A4fa55DD8F20B1eab2021cD8693D32f410B5;
    address constant UNISWAP_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant AAVE_POOL = 0x4e033931ad43597d96D6bcc25c280717730B58B1;
    address constant VAULT = 0x951f36b2F8Fd8B213AE999E53dF1c77749A6cDed;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant A_WSTETH = 0xC035a7cf15375cE2706766804551791aD035E0C2;
    address constant DEBT_WETH = 0x91b7d78BF92db564221f6B5AeE744D1727d1Dd1e;

    function deploy() public returns (PrvlAaveBorrow adaptor, uint256 configId) {
        adaptor = new PrvlAaveBorrow(TEAM_MULTISIG, AUTHORITY, UNISWAP_ROUTER, AAVE_POOL, VAULT);

        TokenConfig memory config = TokenConfig({
            baseToken: WETH,
            depositToken: WSTETH,
            aToken: A_WSTETH,
            debtToken: DEBT_WETH,
            aaveVariableRate: 2,
            path0: hex"c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000647f39c581f595b53c5cb19bd0b3f8da6c935e2ca0",
            path1: hex"7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0000064c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
        });

        configId = adaptor.setTokenConfig(config);
    }

    function run() external {
        uint256 privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(privateKey);
        deploy();
        vm.stopBroadcast();
    }
}
