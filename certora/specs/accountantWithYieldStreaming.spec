import "scenarioA.spec";

invariant exchangeRateGTzero()
    accountant_contract.accountantState.exchangeRate > 0 
    filtered { f -> !ignoredMethod(f) }
    { preserved { safeAssumptions(); }} 

// holds
invariant exchangeRateLEqlastSharePrice()
    accountant_contract.accountantState.exchangeRate <= 
        accountant_contract.vestingState.lastSharePrice
    filtered { f -> !ignoredMethod(f) }
    { preserved { safeAssumptions(); }}

invariant startVestingTimeLEendVestingTime()
    accountant_contract.vestingState.startVestingTime <= 
        accountant_contract.vestingState.endVestingTime
    filtered { f -> !ignoredMethod(f) }
    { preserved { safeAssumptions(); }}

invariant startVestingTimeLTendVestingTime()
    accountant_contract.vestingState.vestingGains > 0 =>
    accountant_contract.vestingState.startVestingTime < 
        accountant_contract.vestingState.endVestingTime
    filtered { f -> !ignoredMethod(f) }
    { preserved { safeAssumptions(); }}

invariant exchangeRateLEhighwaterMark_unlessPaused()
    !accountant_contract.accountantState.isPaused => 
        accountant_contract.accountantState.exchangeRate <= accountant_contract.accountantState.highwaterMark
    filtered { f -> !ignoredMethod(f)
        && f.selector != sig:accountant_contract.unpause().selector }
    { preserved { 
        safeAssumptions(); 
        requireInvariant exchangeRateLEqlastSharePrice();
        requireInvariant exchangeRateGTzero();
        }}

rule vestingGainsNeverDecreases(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    uint128 vestingGains_pre = accountant_contract.vestingState.vestingGains;

    calldataarg args;
    f(e, args);

    uint128 vestingGains_post = accountant_contract.vestingState.vestingGains;
    assert vestingGains_post >= vestingGains_pre;
}

rule lastVestingUpdateNeverDecreases(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    uint128 lastVestingUpdate_pre = accountant_contract.vestingState.lastVestingUpdate;

    calldataarg args;
    f(e, args);

    uint128 lastVestingUpdate_post = accountant_contract.vestingState.lastVestingUpdate;
    assert lastVestingUpdate_post >= lastVestingUpdate_pre;
}

rule exchangeRateLEhighwaterMark_unlessPaused_postLoss()
{  
    safeAssumptions(); 
    requireInvariant exchangeRateLEqlastSharePrice();
    requireInvariant exchangeRateGTzero();
    uint96 exRate_pre = accountant_contract.accountantState.exchangeRate;
    uint96 hWM_pre = accountant_contract.accountantState.highwaterMark;
    uint128 lastSharePrice_pre = accountant_contract.vestingState.lastSharePrice;

    
    require lastSharePrice_pre < 2^20;
    require hWM_pre < 2^10;

    env e; uint256 loss;
    postLoss(e, loss);
    //require loss < 2^20;

    uint96 exRate_post = accountant_contract.accountantState.exchangeRate;
    uint96 hWM_post = accountant_contract.accountantState.highwaterMark;
    uint128 lastSharePrice_post = accountant_contract.vestingState.lastSharePrice;

    require lastSharePrice_post < 2^20;
    require exRate_post < 2^20;
    
    assert (exRate_pre <= hWM_pre) => (exRate_post <= hWM_post); 
}
