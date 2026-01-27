// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script} from "@forge-std/Script.sol";
import {console2} from "@forge-std/console2.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";

contract ProcessRequest1 is Script {
    address constant BORING_QUEUE = 0x66Afbd5b2558B34af02c9Cbe61bfc409C909F375;
    address constant BORING_SOLVER = 0x4e98f2d2DC317076De218947A5f540BE64f0cB3B;
    address constant TELLER = 0x68044594BC73722AC6D9Be0d8FfA918a6D50854c; // iPrvlETH Teller
    
    bytes32 constant REQUEST_ID = 0x0294923E5AC79E5BEEDA9295FDEDB8E70E0406FC3C9726FB6843EC441E4D075B;
    address constant USER = 0xBF6bcE589e21f48CdD5B3a3670090393f4aC075B;
    address constant ASSET_OUT = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    uint96 constant NONCE = 4;
    uint128 constant AMOUNT_OF_SHARES = 51000000000000000000;
    uint128 constant AMOUNT_OF_ASSETS = 1890470397;
    uint40 constant CREATION_TIME = 1760527019;
    uint24 constant SECONDS_TO_MATURITY = 0;
    uint24 constant SECONDS_TO_DEADLINE = 999999;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("Processing specific withdrawal request:");
        console2.log("Request ID:");
        console2.logBytes32(REQUEST_ID);
        console2.log("User:", USER);
        console2.log("Asset Out (WETH):", ASSET_OUT);
        console2.log("Shares:", uint256(AMOUNT_OF_SHARES));
        console2.log("Assets:", uint256(AMOUNT_OF_ASSETS));
        
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        requests[0] = BoringOnChainQueue.OnChainWithdraw({
            nonce: NONCE,
            user: USER,
            assetOut: ASSET_OUT,
            amountOfShares: AMOUNT_OF_SHARES,
            amountOfAssets: AMOUNT_OF_ASSETS,
            creationTime: CREATION_TIME,
            secondsToMaturity: SECONDS_TO_MATURITY,
            secondsToDeadline: SECONDS_TO_DEADLINE
        });
        
        BoringSolver solver = BoringSolver(BORING_SOLVER);
        
        console2.log("\nProcessing request through solver...");
        console2.log("Using teller:", TELLER);
        console2.log("Cover deficit: false");
        
        try solver.boringRedeemSolve(requests, TELLER, false) {
            console2.log("\nSuccessfully processed withdrawal request!");
        } catch Error(string memory reason) {
            console2.log("\nFailed to process request:", reason);
        } catch (bytes memory returnData) {
            console2.log("\nFailed to process request with data:");
            console2.logBytes(returnData);
        }
        
        vm.stopBroadcast();
    }
}