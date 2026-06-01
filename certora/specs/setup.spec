import "setup/dispatching_BoringVault.spec";
import "setup/snippet_ERC20_Mock.spec";
import "MathSummaries.spec";

import "setup/dispatching_AccountantWithYieldStreaming.spec";   // C
import "setup/dispatching_TellerWithYieldStreaming.spec";       // C

using AccountantWithYieldStreaming as accountant_contract;      // C
using TellerWithYieldStreaming as teller_contract;              // C

using BoringVault as vault_contract;
using WETH as WETH;

methods
{
    // summarising vault.manage to empty method to avoid global havoc through functionCallWithValue();
    function vault_contract.manage(address,bytes,uint256) external returns (bytes)  => emptyManage1();
    function vault_contract.manage(address[],bytes[],uint256[]) external returns (bytes[]) => emptyManage2();
}

function emptyManage1() returns (bytes)
{
    bytes results;
    return results;
}

function emptyManage2() returns (bytes[])
{
    bytes[] results;
    return results;
}

function userAssets(env e, address asset, address user) returns uint256
{
    return asset.balanceOf(e, user);
}

// Method that can be called by non-priveleged addresses
definition isPublicMethod(method f) returns bool = 
    f.selector == sig:teller_contract.deposit(address,uint256,uint256,address).selector ||
    f.selector == sig:teller_contract.bulkDeposit(address,uint256,uint256,address).selector ||
    f.selector == sig:teller_contract.depositWithPermit(address,uint256,uint256,uint256,uint8,bytes32,bytes32,address).selector ||
    f.selector == sig:teller_contract.withdraw(address,uint256,uint256,address).selector ||
    f.selector == sig:teller_contract.bulkWithdraw(address,uint256,uint256,address).selector;


definition ignoredMethod(method f) returns bool =
    f.selector == sig:vault_contract.manage(address[],bytes[],uint256[]).selector
    || f.selector == sig:vault_contract.manage(address,bytes,uint256).selector
    || f.isView;

function nonSceneAddress(address sender)
{
    require sender != teller_contract 
        && sender != vault_contract
        && sender != accountant_contract
        && sender != WETH;

    env e;
    bytes4 signature_enter = to_bytes4(sig:vault_contract.enter(address,address,uint256,address,uint256).selector);
    bytes4 signature_exit = to_bytes4(sig:vault_contract.exit(address,address,uint256,address,uint256).selector);
    
    require 
        !vault_contract.isAuthorized(e, sender, signature_enter)
        && !vault_contract.isAuthorized(e, sender, signature_exit)
        ;
}
