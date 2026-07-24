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
        // Same contention-robustness pattern as vaultSolvency_1Asset. This property is linear
        // (totalAssets+1 >= totalSupply), so its whole cost comes from the context: pin decimals
        // so 10^decimals folds to a constant (no symbolic exponentiation), and trim the required
        // invariants to drop the nonlinear ones this proof doesn't need — virtualPriceIsCorrect
        // (*10^27), exchangeRateLEhighwaterMark_unlessPaused (highwaterMark), cumulativeSupplyBounded.
        require vault_contract.decimals() == 6;
        safeAssumptions();
        requireInvariant sharePriceBoundedLower(e2);
        requireInvariant sharePriceBoundedUpper(e2);
        requireInvariant sharePriceMoreThanOneAsset();
        requireInvariant exchangeRateEqlastSharePrice();
        requireInvariant assetsMoreThanShares(e2);
        requireInvariant totalAssetsCovered(e2);
        requireInvariant vaultSolvency_1Asset(e2);
        require accountant_contract.decimals == accountant_contract.base.decimals(e2);
        require accountant_contract.base == ERC20Mock;
        require teller_contract.assetData[ERC20Mock].sharePremium == 0;
        require accountant_contract.getPendingVestingGains(e2) <= vault_contract.totalSupply();
        nonSceneAddress(e2.msg.sender);
    }
    preserved claimFees(address a) with (env e2) {
        // claimFees passed already; add only the decimals pin for the same 10^decimals fold.
        // Keep the full invariant set — fee logic can rely on the highwaterMark/exchangeRate ones.
        require vault_contract.decimals() == 6;
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
        require accountant_contract.ONE_SHARE == 1000000; // concrete ONE_SHARE avoids nonlinear-arith timeout

        nonSceneAddress(e2.msg.sender);
    }
    preserved constructor()
    {
        requireFreshStart();
    }
}

// Helper lemma for vaultSolvency_1Asset's preserved block. That block feeds the prover a
// linearizing upper bound on the symbolic product `totalSupply * getRateInQuoteSafe`; this rule
// DISCHARGES that bound against the real implementation, so it is verified rather than merely
// assumed. getRateInQuoteSafe(base) returns getRate() (AccountantWithYieldStreaming.getRate /
// getRateInQuote), which is either `lastSharePrice` (when totalSupply==0 or pendingGains==0) or
// `totalAssets.mulDivDown(ONE_SHARE, totalSupply)` (pendingGains>0). Both branches satisfy the
// bound: the mulDivDown floor gives `totalSupply*getRate <= totalAssets*ONE_SHARE`, and the
// lastSharePrice case is exactly sharePriceBoundedUpper. The assumptions below are a subset of
// what that preserved block establishes, so proving it here justifies the `require` there.
rule rateInQuoteSafeBoundedByAssets(env e)
{
    require vault_contract.decimals() == 6;
    safeAssumptions();
    requireInvariant sharePriceBoundedUpper(e);
    require accountant_contract.base == ERC20Mock;
    require accountant_contract.getPendingVestingGains(e) <= vault_contract.totalSupply();

    assert vault_contract.totalSupply(e) * accountant_contract.getRateInQuoteSafe(e, ERC20Mock)
        <= (accountant_contract.totalAssets(e) + 1) * accountant_contract.ONE_SHARE;
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
        // Pin decimals to the harness's concrete 6-dec value so 10^decimals folds to a
        // constant (1e6) everywhere (safeAssumptions, sharePriceMoreThanOneAsset) instead of
        // being symbolic exponentiation — the main SMT cost driver for this rule.
        require vault_contract.decimals() == 6;
        safeAssumptions();
        // Trimmed invariant set (vs requireAllInvariants_accountant): drop virtualPriceIsCorrect
        // (lastVirtualSharePrice + a *10^27 term), exchangeRateLEhighwaterMark_unlessPaused
        // (highwaterMark) and cumulativeSupplyBounded (cumulativeSupply) — none of that state
        // appears in this invariant or the deposit/withdraw share math, so requiring them is
        // pure nonlinear context bloat. Keep only what justifies the solvency bound.
        requireInvariant sharePriceBoundedLower(e2);
        requireInvariant sharePriceBoundedUpper(e2);
        requireInvariant sharePriceMoreThanOneAsset();
        requireInvariant exchangeRateEqlastSharePrice();
        requireInvariant assetsMoreThanShares(e2);
        requireInvariant totalAssetsCovered(e2);
        requireInvariant vaultSolvency_1Asset(e2);
        require accountant_contract.decimals == accountant_contract.base.decimals(e2);
        require accountant_contract.base == ERC20Mock;
        require teller_contract.assetData[ERC20Mock].sharePremium == 0;
        require accountant_contract.getPendingVestingGains(e2) <= vault_contract.totalSupply();
        require e2.block.timestamp == e.block.timestamp;
        // NB: teller/accountant ONE_SHARE are already pinned to 1e6 here — decimals()==6 (above)
        // + safeAssumptions()'s `ONE_SHARE == 10^decimals()` collapse both — so no explicit pin.
        // Linearize the RHS symbolic*symbolic product totalSupply*getRateInQuoteSafe with a sound
        // upper bound. This is NOT a bare assumption: rule rateInQuoteSafeBoundedByAssets verifies
        // it against the real getRateInQuoteSafe (mulDivDown floor on the pendingGains>0 branch;
        // sharePriceBoundedUpper on the lastSharePrice branch). Feeding it collapses the nonlinear
        // product to a linear term and avoids the timeout.
        require vault_contract.totalSupply(e2) * accountant_contract.getRateInQuoteSafe(e2, ERC20Mock)
            <= (accountant_contract.totalAssets(e2) + 1) * accountant_contract.ONE_SHARE;
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
        // Pin ONE_SHARE to its concrete value (6-decimal harness, as totalAssetsCovered
        // already assumes for the teller) so `* 10^27 / ONE_SHARE` is a constant divide,
        // not symbolic nonlinear arithmetic — this is what times the rule out.
        require accountant_contract.ONE_SHARE == 1000000;
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