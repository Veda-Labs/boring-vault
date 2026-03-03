// rules that apply to both accountants

import "setup.spec";

function safeAssumptions()
{
    //require vault_contract.decimals() < 5;
    require vault_contract.decimals() < 50; //thats more than enough decimals. 10^78 > 2^256
    require accountant_contract.ONE_SHARE == 10 ^ vault_contract.decimals();
    require teller_contract.ONE_SHARE == 10 ^ vault_contract.decimals();
    requireInvariant totalSupplyHolds_BoringVault();
    requireInvariant totalSupplyHolds_ERC20Mock();
}

rule accountantDoesntHoldTokens(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    safeAssumptions();
    if (f.selector != sig:accountant_contract.claimFees(address).selector)
        nonSceneAddress(e.msg.sender);   // the claimFees can only be called by the Vault so this condidtion would cause vacuity

    address asset; require asset != vault_contract;
    require accountant_contract.accountantState.payoutAddress != accountant_contract, "otherwise the accountant holds the fees, i.e. does hold tokens";

    uint balanceBefore = asset.balanceOf(e, accountant_contract);
    calldataarg args;
    f(e, args);

    uint balanceAfter = asset.balanceOf(e, accountant_contract);

    assert balanceAfter == balanceBefore;

}

rule accountantPaused_valuesFrozen(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    bool paused = accountant_contract.accountantState.isPaused;

    uint128 feesOwedInBase_pre = accountant_contract.accountantState.feesOwedInBase;
    uint96 exchangeRate_pre = accountant_contract.accountantState.exchangeRate;

    calldataarg args;
    f(e, args);

    uint128 feesOwedInBase_post = accountant_contract.accountantState.feesOwedInBase;
    uint96 exchangeRate_post = accountant_contract.accountantState.exchangeRate;
    
    assert paused => (
        exchangeRate_post == exchangeRate_pre &&
         (feesOwedInBase_post == feesOwedInBase_pre 
            || f.selector == sig:accountant_contract.resetHighwaterMark().selector //fees should only be able to change via this method when paused
         )
        );

}

invariant allowedExchangeRateChangeUpper_bound()
    accountant_contract.accountantState.allowedExchangeRateChangeUpper >= 10^4
    filtered { f -> !ignoredMethod(f) }

invariant allowedExchangeRateChangeLower_bound()
    accountant_contract.accountantState.allowedExchangeRateChangeLower <= 10^4
    filtered { f -> !ignoredMethod(f) }

rule feesCanOnlyDecreaseViaClaimFees(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    uint256 fees_pre = accountant_contract.accountantState.feesOwedInBase;

    calldataarg args;
    f(e, args);

    uint256 fees_post = accountant_contract.accountantState.feesOwedInBase;
    assert fees_post < fees_pre => f.selector == sig:accountant_contract.claimFees(address).selector;
}

rule highwaterMarkNeverDecreases(env e, method f)
    filtered { f -> !ignoredMethod(f) 
        && f.selector != sig:accountant_contract.resetHighwaterMark().selector
    }
{
    uint96 WM_pre = accountant_contract.accountantState.highwaterMark;
    calldataarg args;
    f(e, args);

    uint96 WM_post = accountant_contract.accountantState.highwaterMark;
    assert WM_post >= WM_pre;
}

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