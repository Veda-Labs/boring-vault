import "teller_basic.spec";

methods
{
    //function vault_contract.decimals() external returns (uint8) envfree;
    //function accountant_contract.getPendingVestingGains() external returns (uint256) envfree;
}

// holds
invariant exchangeRateLEqlastSharePrice()
    accountant_contract.accountantState.exchangeRate <= 
        accountant_contract.vestingState.lastSharePrice
    filtered { f -> !ignoredMethod(f) }
    { preserved { safeAssumptions(); }}

invariant exchangeRateLEhighwaterMark_unlessPaused()
    !accountant_contract.accountantState.isPaused => 
        accountant_contract.accountantState.exchangeRate <= accountant_contract.accountantState.highwaterMark
    filtered { f -> !ignoredMethod(f)
        && f.selector != sig:accountant_contract.unpause().selector 
        && f.selector == sig:accountant_contract.postLoss(uint256).selector
        }
    { preserved with(env e) { 
        safeAssumptions(); 
        requireInvariant exchangeRateLEqlastSharePrice();
        requireInvariant cumulativeSupplyBounded();
        
        //require getPendingVestingGains(e) * accountant_contract.ONE_SHARE <= (max_uint96 - accountant_contract.vestingState.lastSharePrice) * vault_contract.totalSupply();
        require accountant_contract.vestingState.lastSharePrice <= 2^90; //unreasonably high value
        require getPendingVestingGains(e) <= vault_contract.totalSupply();
        }
    }


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

invariant cumulativeSupplyBounded()
    accountant_contract.supplyObservation.cumulativeSupplyLast <= 
        accountant_contract.supplyObservation.cumulativeSupply;

rule exchangeRateLEhighwaterMark_unlessPaused_postLoss()
{  
    safeAssumptions(); 
    requireInvariant exchangeRateLEqlastSharePrice();
    uint96 exRate_pre = accountant_contract.accountantState.exchangeRate;
    uint96 hWM_pre = accountant_contract.accountantState.highwaterMark;
    uint128 lastSharePrice_pre = accountant_contract.vestingState.lastSharePrice;

    //require lastSharePrice_pre < 2^20;
    //require hWM_pre < 2^10;

    env e; uint256 loss;
    require getPendingVestingGains(e) * accountant_contract.ONE_SHARE <= (max_uint96 - lastSharePrice_pre) * vault_contract.totalSupply();
    postLoss(e, loss);
    // limit the ratio between loss and price
    // try to find the exact formula for the condition
    //require loss < 2^20;

    uint96 exRate_post = accountant_contract.accountantState.exchangeRate;
    uint96 hWM_post = accountant_contract.accountantState.highwaterMark;
    uint128 lastSharePrice_post = accountant_contract.vestingState.lastSharePrice;

    //require lastSharePrice_post < 2^20;
    //require exRate_post < 2^20;
    
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

rule testCondition()
{  
    safeAssumptions(); 
    requireInvariant exchangeRateLEqlastSharePrice();
    uint96 exRate = accountant_contract.accountantState.exchangeRate;
    uint96 hWM = accountant_contract.accountantState.highwaterMark;
    env e; uint256 loss;

    uint128 price = accountant_contract.vestingState.lastSharePrice;
    uint256 vestingGains = getPendingVestingGains(e);
    uint256 supply = vault_contract.totalSupply();
    uint256 c = accountant_contract.ONE_SHARE;
    uint256 m = max_uint96;

    bool cond1 = vestingGains * accountant_contract.ONE_SHARE <= 
        (max_uint96 - price) * supply;

    bool cond2 = vestingGains <= supply && price <= max_uint96 - accountant_contract.ONE_SHARE;

    assert cond2 => cond1;
}

invariant accountantDecimalsCorrect(env e)
    accountant_contract.decimals == accountant_contract.base.decimals(e)
    filtered { f ->
        f.selector == sig:accountant_contract.vestYield(uint256,uint256).selector
}

invariant sharePriceMoreThanOneAsset()
    accountant_contract.vestingState.lastSharePrice >= 10^vault_contract.decimals
    || accountant_contract.downCastOverflow
    filtered 
    { f -> !ignoredMethod(f)
       
    }
{ preserved with (env e2) {
        requireAllInvariants_accountant(e2);
        safeAssumptions();
        nonSceneAddress(e2.msg.sender);
    }
}

invariant assetsMoreThanShares(env e)
    accountant_contract.totalAssets(e) + 1 >= vault_contract.totalSupply()
    filtered 
    { f -> !ignoredMethod(f)
        && (f.contract == teller_contract || f.contract == accountant_contract)
        && f.selector != sig:teller_contract.refundDeposit(uint256,address,address,uint256,uint256,uint256,uint256,address).selector // can break if the sharesAmount is too low. This can happen since we don't really track the sum of deposits and their shares in publicDepositHistory
        //&& f.selector == sig:teller_contract.deposit(address, uint256, uint256,address).selector 
        //&& f.selector == sig:teller_contract.depositWithPermit(address,uint256,uint256,uint256,uint8,bytes32,bytes32,address).selector
        //&& f.selector == sig:teller_contract.bulkDeposit(address,uint256,uint256,address).selector
        //&& f.selector == sig:teller_contract.withdraw(address,uint256,uint256,address).selector
        //&& f.selector == sig:teller_contract.bulkWithdraw(address,uint256,uint256,address).selector
        && isPublicMethod(f)
    }
    {
    preserved with (env e2) {
        requireAllInvariants_accountant(e2);
        safeAssumptions();
        nonSceneAddress(e2.msg.sender);

        //requireSmallNumbers_Unsafe(e2);
    }
}

invariant sharePriceBoundedUpper(env e)
    accountant_contract.vestingState.lastSharePrice * vault_contract.totalSupply() <= 
        (accountant_contract.totalAssets(e)+1) * teller_contract.ONE_SHARE
    filtered 
    { f -> !ignoredMethod(f)
        && (f.contract == teller_contract || f.contract == accountant_contract)
        //&& f.selector == sig:teller_contract.deposit(address, uint256, uint256,address).selector 
        //&& f.selector == sig:teller_contract.withdraw(address,uint256,uint256,address).selector
    }
    {
    preserved with (env e2) {
        requireAllInvariants_accountant(e2);
        safeAssumptions();
        nonSceneAddress(e2.msg.sender);
    }
}

invariant sharePriceBoundedUpper_strict(env e)
    accountant_contract.vestingState.lastSharePrice * vault_contract.totalSupply() <= 
        (accountant_contract.totalAssets(e)) * teller_contract.ONE_SHARE
filtered 
    { f -> !ignoredMethod(f)
        && (f.contract == teller_contract || f.contract == accountant_contract)
        && f.selector != sig:teller_contract.refundDeposit(uint256,address,address,uint256,uint256,uint256,uint256,address).selector // can break if the sharesAmount is too low. This can happen since we don't really track the sum of deposits and their shares in publicDepositHistory
        && (
            f.selector == sig:teller_contract.deposit(address, uint256, uint256,address).selector 
            || f.selector == sig:teller_contract.withdraw(address,uint256,uint256,address).selector
        )
        
    }
    {
    preserved with (env e2) {
        requireAllInvariants_accountant(e2);
        safeAssumptions();
        nonSceneAddress(e2.msg.sender);
    
        //require vault_contract.totalSupply() > 0;
    }
}

invariant sharePriceBoundedLower(env e)
    (accountant_contract.vestingState.lastSharePrice) * vault_contract.totalSupply() >= 
        (accountant_contract.totalAssets(e)) * teller_contract.ONE_SHARE
    filtered 
    { f -> !ignoredMethod(f)
        && (f.contract == teller_contract)  //funds could be moved by methods called on the Vault or on the Asset
        && f.selector != sig:teller_contract.refundDeposit(uint256,address,address,uint256,uint256,uint256,uint256,address).selector // can break if the sharesAmount is too low. This can happen since we don't really track the sum of deposits and their shares in publicDepositHistory
        //&& f.selector == sig:teller_contract.deposit(address, uint256, uint256,address).selector 
        //&& f.selector == sig:teller_contract.depositWithPermit(address,uint256,uint256,uint256,uint8,bytes32,bytes32,address).selector
        //&& f.selector == sig:teller_contract.bulkDeposit(address,uint256,uint256,address).selector
        //&& f.selector == sig:teller_contract.withdraw(address,uint256,uint256,address).selector
        //&& f.selector == sig:teller_contract.bulkWithdraw(address,uint256,uint256,address).selector
        //&& !isPublicMethod(f)
}
    {
    preserved with (env e2) {
        //require accountant_contract.supplyObservation.cumulativeSupply <= vault_contract.totalSupply();

        requireAllInvariants_accountant(e2);

        require e2.block.timestamp == e.block.timestamp;
        require accountant_contract.getPendingVestingGains(e2) <= vault_contract.totalSupply();
        //require vault_contract.totalSupply() > 0; //the initial state uses the lastSharePrice directly that could be incorrectly initialized
        safeAssumptions();
        nonSceneAddress(e2.msg.sender);
    }
}

invariant totalAssetsCovered(env e)
    accountant_contract.totalAssets(e) <= userAssets(e, ERC20Mock, vault_contract) 
    || accountant_contract.downCastOverflow
    filtered 
    { f -> !ignoredMethod(f)
        && (f.contract == teller_contract || f.contract == accountant_contract)
        && f.selector != sig:teller_contract.refundDeposit(uint256,address,address,uint256,uint256,uint256,uint256,address).selector // can break if the sharesAmount is too low. This can happen since we don't really track the sum of deposits and their shares in publicDepositHistory
        //&& f.selector == sig:teller_contract.deposit(address, uint256, uint256,address).selector 
        //&& f.selector == sig:teller_contract.depositWithPermit(address,uint256,uint256,uint256,uint8,bytes32,bytes32,address).selector
        //&& f.selector == sig:teller_contract.bulkDeposit(address,uint256,uint256,address).selector
        //&& f.selector == sig:teller_contract.withdraw(address,uint256,uint256,address).selector
        //&& f.selector == sig:teller_contract.bulkWithdraw(address,uint256,uint256,address).selector
        //&& !isPublicMethod(f)
}
    {
    preserved with (env e2) {
        //require accountant_contract.supplyObservation.cumulativeSupply <= vault_contract.totalSupply();

        requireAllInvariants_accountant(e2);

        require e2.block.timestamp == e.block.timestamp;
        require accountant_contract.getPendingVestingGains(e2) <= vault_contract.totalSupply();
        require vault_contract.totalSupply() > 0; //the initial state uses the lastSharePrice directly that could be incorrectly initialized
        require teller_contract.ONE_SHARE == 1000000;

        safeAssumptions();
        nonSceneAddress(e2.msg.sender);

    }
}

invariant vaultSolvency_1Asset(env e)
    (userAssets(e, ERC20Mock, vault_contract) - accountant_contract.getPendingVestingGains(e)) * teller_contract.ONE_SHARE 
        >= (vault_contract.totalSupply(e)) * (accountant_contract.getRateInQuoteSafe(e, ERC20Mock)) 
    || accountant_contract.downCastOverflow
filtered { f -> !ignoredMethod(f)
    && (f.contract == teller_contract || f.contract == accountant_contract)
    && f.selector != sig:teller_contract.refundDeposit(uint256,address,address,uint256,uint256,uint256,uint256,address).selector // can break if the sharesAmount is too low. This can happen since we don't really track the sum of deposits and their shares in publicDepositHistory

    //&& f.selector == sig:teller_contract.deposit(address, uint256, uint256,address).selector 
    //&& f.selector == sig:teller_contract.depositWithPermit(address,uint256,uint256,uint256,uint8,bytes32,bytes32,address).selector
    //&& f.selector == sig:teller_contract.bulkDeposit(address,uint256,uint256,address).selector
    //&& f.selector == sig:teller_contract.withdraw(address,uint256,uint256,address).selector
    //&& f.selector == sig:teller_contract.bulkWithdraw(address,uint256,uint256,address).selector
    //&& isPublicMethod(f)
}
{
    preserved with (env e2) {
        requireAllInvariants_accountant(e2);
        
        require e2.block.timestamp == e.block.timestamp;

        safeAssumptions();
        nonSceneAddress(e2.msg.sender);
        //require vault_contract.totalSupply() > 0;
        //requireSmallNumbers_Unsafe(e2);
        //require accountant_contract.getPendingVestingGains(e) == 0;
    }
}

invariant exchangeRateEqlastSharePrice()
    accountant_contract.accountantState.exchangeRate == 
        accountant_contract.vestingState.lastSharePrice
    || accountant_contract.downCastOverflow
    filtered { f -> !ignoredMethod(f) }
    { preserved with (env e2) { 
        requireAllInvariants_accountant(e2);
        safeAssumptions(); }
}

invariant virtualPriceIsCorrect()
    accountant_contract.vestingState.lastSharePrice == 
    accountant_contract.lastVirtualSharePrice * accountant_contract.ONE_SHARE / 10^27
    { preserved with(env e) { 
        safeAssumptions(); 
        requireAllInvariants_accountant(e);
    }
}

function requireAllInvariants_accountant(env e)
{
    // these hold
    requireInvariant exchangeRateLEhighwaterMark_unlessPaused();
    requireInvariant sharePriceBoundedLower(e);
    requireInvariant exchangeRateEqlastSharePrice();
    requireInvariant cumulativeSupplyBounded();
    requireInvariant sharePriceBoundedUpper(e);
    requireInvariant sharePriceMoreThanOneAsset(); // doesnt hold after the constructor
    requireInvariant assetsMoreThanShares(e);
    requireInvariant totalAssetsCovered(e);
    requireInvariant vaultSolvency_1Asset(e);
    
    requireInvariant virtualPriceIsCorrect();

    // holds as an invariant accountantDecimalsCorrect
    require accountant_contract.decimals == accountant_contract.base.decimals(e); 
    require accountant_contract.base == ERC20Mock;

    require teller_contract.assetData[ERC20Mock].sharePremium == 0;
    require accountant_contract.downCastOverflow == false;
    
}