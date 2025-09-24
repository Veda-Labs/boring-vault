import "setup/dispatching_AccountantWithRateProviders.spec";
import "setup/dispatching_BoringVault.spec";
import "setup/dispatching_TellerWithMultiAssetSupport.spec";

using AccountantWithRateProviders as accountantWithRateProviders;
using BoringVault as vault_token;
using TellerWithMultiAssetSupport as teller_contract;

function getHighWaterMark() returns uint96
{
    return accountantWithRateProviders.accountantState.highwaterMark;
}

rule highwaterMarkNeverDecreases(env e, method f)
{
    uint96 WM_pre = getHighWaterMark();
    calldataarg args;
    f(e, args);

    uint96 WM_post = getHighWaterMark();
    assert WM_post >= WM_pre;
}

invariant exchangeRateLEhighwaterMark()
    accountantWithRateProviders.accountantState.exchangeRate <= 
        accountantWithRateProviders.accountantState.highwaterMark;

rule lastUpdateTimestampNeverDecreases(env e, method f)
{
    uint64 timestamp_pre = accountantWithRateProviders.accountantState.lastUpdateTimestamp;
    require timestamp_pre <= e.block.timestamp &&
        e.block.timestamp <= 2^30;

    calldataarg args;
    f(e, args);

    uint64 timestamp_post = accountantWithRateProviders.accountantState.lastUpdateTimestamp;
    assert timestamp_post >= timestamp_pre;
}

rule deniedUsers_balanceNondecreasing(env e, method f)
{
    requireInvariant totalSupplyHolds_BoringVault();
    address user;
    bool isDeniedFrom = teller_contract.beforeTransferData[user].denyFrom;
    uint balance_pre = vault_token.balanceOf(e, user);

    calldataarg args;
    f(e, args);

    uint balance_post = vault_token.balanceOf(e, user);
    assert isDeniedFrom => balance_post >= balance_pre;
}