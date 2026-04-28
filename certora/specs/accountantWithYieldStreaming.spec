// rules specific for accountantWithYieldStreaming

import "accountant_basic.spec";

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
    { preserved { safeAssumptions(); }
}

invariant exchangeRateLEhighwaterMark_unlessPaused()
    !accountant_contract.accountantState.isPaused => 
        accountant_contract.accountantState.exchangeRate <= accountant_contract.accountantState.highwaterMark
    filtered { f -> !ignoredMethod(f)
        && f.selector != sig:accountant_contract.unpause().selector 
        && f.selector != sig:accountant_contract.postLoss(uint256).selector
        && f.selector != sig:accountant_contract.vestYield(uint256,uint256).selector
        }
    { preserved with(env e) { 
        safeAssumptions(); 
        requireInvariant exchangeRateLEqlastSharePrice();
        requireInvariant cumulativeSupplyBounded();
        
        //require accountant_contract.vestingState.lastSharePrice <= 2^90; //unreasonably high value
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

invariant accountantDecimalsCorrect(env e)
    accountant_contract.decimals == accountant_contract.base.decimals(e)
    filtered { f ->
        f.selector == sig:accountant_contract.vestYield(uint256,uint256).selector
}

invariant sharePriceMoreThanOneAsset()
    accountant_contract.vestingState.lastSharePrice >= 10^vault_contract.decimals
    
    filtered 
    {   f -> !ignoredMethod(f)
        && f.selector != sig:accountant_contract.postLoss(uint256).selector
    }
{   preserved with (env e2) {
        requireAllInvariants_accountant(e2);
        safeAssumptions();
        nonSceneAddress(e2.msg.sender);
    }
    preserved claimFees(address a) with (env e2) {
        safeAssumptions();
        requireAllInvariants_accountant(e2);
    }
    preserved constructor()
    {
        require accountant_contract.vestingState.lastSharePrice >= 10^vault_contract.decimals;
    }
}

invariant assetsMoreThanShares(env e)
    accountant_contract.totalAssets(e) + 1 >= vault_contract.totalSupply()
    filtered 
    { f -> !ignoredMethod(f)
        && f.selector != sig:teller_contract.refundDeposit(uint256,address,address,uint256,uint256,uint256,uint256,address).selector // can break if the sharesAmount is too low. This can happen since we don't really track the sum of deposits and their shares in publicDepositHistory      
        && isPublicMethod(f)
    }
    {
    preserved with (env e2) {
        requireAllInvariants_accountant(e2);
        safeAssumptions();
        nonSceneAddress(e2.msg.sender);
    }
    preserved claimFees(address a) with (env e2) {
        safeAssumptions();
        requireAllInvariants_accountant(e2);
    }
    preserved constructor()
    {
        requireFreshStart();
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
    preserved claimFees(address a) with (env e2) {
        safeAssumptions();
        requireAllInvariants_accountant(e2);
    }
    preserved constructor()
    {
        requireFreshStart();
    }
}

invariant sharePriceBoundedLower(env e)
    (accountant_contract.vestingState.lastSharePrice) * vault_contract.totalSupply() >= 
        (accountant_contract.totalAssets(e)) * teller_contract.ONE_SHARE
    filtered 
    { f -> !ignoredMethod(f)
        && (f.contract == teller_contract || f.contract == accountant_contract)  //funds could be moved by methods called on the Vault or on the Asset
        && f.selector != sig:accountant_contract.vestYield(uint256,uint256).selector
    }
    {
    preserved with (env e2) {
        safeAssumptions();
        requireAllInvariants_accountant(e2);
        require e2.block.timestamp == e.block.timestamp;
        require accountant_contract.getPendingVestingGains(e2) <= vault_contract.totalSupply();
        nonSceneAddress(e2.msg.sender);
    }
    preserved claimFees(address a) with (env e2) {
        safeAssumptions();
        requireAllInvariants_accountant(e2);
        require e2.block.timestamp == e.block.timestamp;
        require accountant_contract.getPendingVestingGains(e2) <= vault_contract.totalSupply();
    }
    preserved constructor()
    {
        requireFreshStart();
    }
}

invariant totalAssetsCovered(env e)
    accountant_contract.totalAssets(e) <= userAssets(e, ERC20Mock, vault_contract) 
    
    filtered 
    { f -> !ignoredMethod(f)
        && (f.contract == teller_contract || f.contract == accountant_contract)
        && f.selector != sig:teller_contract.refundDeposit(uint256,address,address,uint256,uint256,uint256,uint256,address).selector // can break if the sharesAmount is too low. This can happen since we don't really track the sum of deposits and their shares in publicDepositHistory
        && f.selector != sig:accountant_contract.vestYield(uint256,uint256).selector
    }
    {
    preserved with (env e2) {
        safeAssumptions();
        requireAllInvariants_accountant(e2);

        require e2.block.timestamp == e.block.timestamp;
        require accountant_contract.getPendingVestingGains(e2) <= vault_contract.totalSupply();
        require vault_contract.totalSupply() > 0; //the initial state uses the lastSharePrice directly that could be incorrectly initialized
        require teller_contract.ONE_SHARE == 1000000;

        nonSceneAddress(e2.msg.sender);
    }
    preserved constructor()
    {
        requireFreshStart();
    }
}

invariant vaultSolvency_1Asset(env e)
    (userAssets(e, ERC20Mock, vault_contract) - accountant_contract.getPendingVestingGains(e)) * teller_contract.ONE_SHARE 
        >= (vault_contract.totalSupply(e)) * (accountant_contract.getRateInQuoteSafe(e, ERC20Mock)) 
    
filtered { f -> !ignoredMethod(f)
    && (f.contract == teller_contract || f.contract == accountant_contract)
    && f.selector != sig:teller_contract.refundDeposit(uint256,address,address,uint256,uint256,uint256,uint256,address).selector // can break if the sharesAmount is too low. This can happen since we don't really track the sum of deposits and their shares in publicDepositHistory
    && f.selector != sig:accountant_contract.vestYield(uint256,uint256).selector
    && f.selector != sig:accountant_contract.postLoss(uint256).selector 
    && f.selector != sig:accountant_contract.pause().selector 
}
{
    preserved with (env e2) {
        safeAssumptions();
        requireAllInvariants_accountant(e2);
        require e2.block.timestamp == e.block.timestamp;
        nonSceneAddress(e2.msg.sender);
    }

    preserved constructor()
    {
        requireFreshStart();
        require accountant_contract.getPendingVestingGains(e) == 0;
    }
}

invariant exchangeRateEqlastSharePrice()
    accountant_contract.accountantState.exchangeRate == 
        accountant_contract.vestingState.lastSharePrice
    
    filtered { f -> !ignoredMethod(f) }
    { preserved with (env e2) { 
        requireAllInvariants_accountant(e2);
        safeAssumptions(); }
}

invariant virtualPriceIsCorrect()
    accountant_contract.vestingState.lastSharePrice * 10^27 
    / accountant_contract.ONE_SHARE == accountant_contract.lastVirtualSharePrice
    filtered { f -> !ignoredMethod(f) 
        && f.selector != sig:accountant_contract.postLoss(uint256).selector 
        }
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
    requireInvariant sharePriceMoreThanOneAsset();
    requireInvariant assetsMoreThanShares(e);
    requireInvariant totalAssetsCovered(e);
    requireInvariant vaultSolvency_1Asset(e);
    
    requireInvariant virtualPriceIsCorrect();

    // holds as an invariant accountantDecimalsCorrect
    require accountant_contract.decimals == accountant_contract.base.decimals(e); 
    require accountant_contract.base == ERC20Mock;

    require teller_contract.assetData[ERC20Mock].sharePremium == 0;
    require accountant_contract.getPendingVestingGains(e) <= vault_contract.totalSupply();
    
}

function requireFreshStart()
{
    require vault_contract.totalSupply() == 0;
}