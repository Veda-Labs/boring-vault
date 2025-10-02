import "setup/dispatching_AccountantWithRateProviders.spec";
import "setup/dispatching_BoringVault.spec";
import "setup/dispatching_TellerWithMultiAssetSupport.spec";

using AccountantWithRateProviders as accountant_contract;
using BoringVault as vault_contract;
using TellerWithMultiAssetSupport as teller_contract;

methods
{
    //function vault_contract.decimals() external returns (uint8) envfree;
}

function getHighWaterMark() returns uint96
{
    return accountant_contract.accountantState.highwaterMark;
}

definition ignoredMethod(method f) returns bool =
    f.selector == sig:vault_contract.manage(address[],bytes[],uint256[]).selector
    || f.selector == sig:vault_contract.manage(address,bytes,uint256).selector
    || f.isView;

function safeAssumptions()
{
    requireInvariant totalSupplyHolds_BoringVault();
    //require teller_contract.ONE_SHARE == 10 ^ vault_contract.decimals();
}

rule highwaterMarkNeverDecreases(env e, method f)
    filtered { f -> !ignoredMethod(f) 
        && f.selector != sig:accountant_contract.resetHighwaterMark().selector
    }
{
    uint96 WM_pre = getHighWaterMark();
    calldataarg args;
    f(e, args);

    uint96 WM_post = getHighWaterMark();
    assert WM_post >= WM_pre;
}

invariant exchangeRateLEhighwaterMark()
    accountant_contract.accountantState.exchangeRate <= 
        accountant_contract.accountantState.highwaterMark
    filtered { f -> !ignoredMethod(f) }
    { preserved { safeAssumptions(); }}

rule lastUpdateTimestampNeverDecreases(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    uint64 timestamp_pre = accountant_contract.accountantState.lastUpdateTimestamp;
    require timestamp_pre <= e.block.timestamp &&
        e.block.timestamp <= 2^30;

    calldataarg args;
    f(e, args);

    uint64 timestamp_post = accountant_contract.accountantState.lastUpdateTimestamp;
    assert timestamp_post >= timestamp_pre;
}

rule deniedUsers_balanceNondecreasing(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    safeAssumptions();
    address user;
    bool isDeniedFrom = teller_contract.beforeTransferData[user].denyFrom;
    uint balance_pre = vault_contract.balanceOf(e, user);

    calldataarg args;
    f(e, args);

    uint balance_post = vault_contract.balanceOf(e, user);
    assert isDeniedFrom => balance_post >= balance_pre;
}

rule deniedUsers_balanceIncreasing(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    safeAssumptions();
    address user;
    bool isDeniedTo = teller_contract.beforeTransferData[user].denyTo;
    uint balance_pre = vault_contract.balanceOf(e, user);

    calldataarg args;
    f(e, args);
    uint balance_post = vault_contract.balanceOf(e, user);
    assert isDeniedTo => balance_post <= balance_pre;
}

invariant totalSupplyLEqCap()
    vault_contract.totalSupply() <= teller_contract.depositCap
        || teller_contract.depositCap == 2^112 - 1  // max uint112 means the cap is not applied
    filtered { f -> !ignoredMethod(f)
        && f.selector != sig:teller_contract.setDepositCap(uint112).selector // setting the cap bellow current supply is used by admins to disable further deposits
        && f.selector != sig:vault_contract.enter(address,address,uint256,address,uint256).selector // other tellers could operate the vault and increase its totalSupply
        }
    { preserved { safeAssumptions();} }

rule depositNonceNeverGoesDown(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    uint64 depositNonce_pre = teller_contract.depositNonce;

    calldataarg args;
    f(e, args);

    uint64 depositNonce_post = teller_contract.depositNonce;
    assert depositNonce_post >= depositNonce_pre;
}

rule dustFavorsTheHouse(uint assetsIn, env e)
{
    //require e.msg.sender != currentContract;
    //uint256 totalSupplyBefore = totalSupply();
    address asset; uint minimumShares; uint minimumAssets;

    uint balanceBefore = asset.balanceOf(e, vault_contract);

    uint shares = deposit(e, asset, assetsIn, minimumShares);
    uint assetsOut = withdraw(e, asset, shares, minimumAssets, e.msg.sender);

    uint balanceAfter = asset.balanceOf(e, vault_contract);

    assert balanceAfter >= balanceBefore;
}

rule tellerDoesntHoldTokens(env e, method f)
{
    safeAssumptions();
    address asset;
    // todo require that the teler contract is not the target of the funds.

    uint balanceBefore = asset.balanceOf(e, teller_contract);
    calldataarg args;
    f(e, args);

    uint balanceAfter = asset.balanceOf(e, teller_contract);

    assert balanceAfter == balanceBefore;
}

rule accountantDoesntHoldTokens(env e, method f)
{
    safeAssumptions();
    address asset;

    uint balanceBefore = asset.balanceOf(e, accountant_contract);
    calldataarg args;
    f(e, args);

    uint balanceAfter = asset.balanceOf(e, accountant_contract);

    assert balanceAfter == balanceBefore;
}


