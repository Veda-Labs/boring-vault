// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

// source .env && forge script script/utils/Mainnet/DepositWETH.s.sol:DepositWETH --rpc-url $MAINNET_RPC_URL -vvvv --broadcast

interface IBoringVault {
    function deposit(address depositAsset, uint256 depositAmount, uint256 minimumMint) external returns (uint256 shares);
}

contract DepositWETH is Script {
    address constant BORING_VAULT = 0x68044594BC73722AC6D9Be0d8FfA918a6D50854c;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint256 constant DEPOSIT_AMOUNT = 1000000;
    uint256 constant MINIMUM_MINT = 0;

    function run() external {
        uint256 pk = vm.envUint("MAINNET_DEPLOYER_KEY");

        vm.startBroadcast(pk);

        IBoringVault vault = IBoringVault(BORING_VAULT);
        uint256 shares = vault.deposit(WETH, DEPOSIT_AMOUNT, MINIMUM_MINT);

        console.log("Deposited:", DEPOSIT_AMOUNT);
        console.log("Received shares:", shares);

        vm.stopBroadcast();
    }
}
