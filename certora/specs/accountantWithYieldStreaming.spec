import "teller_basic.spec";

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
        }}


rule lastVestingUpdateNeverDecreases(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    uint128 lastVestingUpdate_pre = accountant_contract.vestingState.lastVestingUpdate;
    require e.block.timestamp >= lastVestingUpdate_pre;
    require e.block.timestamp <= 2^40;
    calldataarg args;
    f(e, args);

    uint128 lastVestingUpdate_post = accountant_contract.vestingState.lastVestingUpdate;
    assert lastVestingUpdate_post >= lastVestingUpdate_pre;
}

rule exchangeRateLEhighwaterMark_unlessPaused_postLoss()
{  
    safeAssumptions(); 
    requireInvariant exchangeRateLEqlastSharePrice();
    uint96 exRate_pre = accountant_contract.accountantState.exchangeRate;
    uint96 hWM_pre = accountant_contract.accountantState.highwaterMark;
    uint128 lastSharePrice_pre = accountant_contract.vestingState.lastSharePrice;

    
    require lastSharePrice_pre < 2^20;
    require hWM_pre < 2^10;

    env e; uint256 loss;
    postLoss(e, loss);
    // limit the ratio between loss and price
    // try to find the exact formula for the condition
    //require loss < 2^20;

    uint96 exRate_post = accountant_contract.accountantState.exchangeRate;
    uint96 hWM_post = accountant_contract.accountantState.highwaterMark;
    uint128 lastSharePrice_post = accountant_contract.vestingState.lastSharePrice;

    require lastSharePrice_post < 2^20;
    require exRate_post < 2^20;
    
    assert (exRate_pre <= hWM_pre) => (exRate_post <= hWM_post); 
}

rule integrityOfVestYield(env e)
{
    safeAssumptions(); 
    requireInvariant exchangeRateLEqlastSharePrice();
    require e.block.timestamp < 2^40;

    uint256 yieldAmount; uint256 duration;
    accountant_contract.vestYield(e, yieldAmount, duration);

    uint64 startTime = accountant_contract.vestingState.startVestingTime;
    uint64 lastUpdateTimestamp = accountant_contract.lastStrategistUpdateTimestamp;
    
    assert startTime == e.block.timestamp 
        && lastUpdateTimestamp == e.block.timestamp;
}
