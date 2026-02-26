import "teller_basic.spec";

rule convertToAssetsWeakAdditivity() {
    uint256 sharesA; uint256 sharesB; uint256 assetsA; uint256 assetsB;
    uint sharesAPlusB = require_uint256(sharesA + sharesB); uint256 assetsAPlusB;
    storage init = lastStorage; address asset;
    assetsA = convertToAssets(init, sharesA, asset);
    assetsB = convertToAssets(init, sharesB, asset);
    assetsAPlusB = convertToAssets(init, sharesAPlusB, asset);

    require sharesA + sharesB < max_uint128
         && assetsA + assetsB < max_uint256
         && assetsAPlusB < max_uint256;

    assert assetsA + assetsB <= assetsAPlusB,
        "converting sharesA and sharesB to assets then summing them must yield a smaller or equal result to summing them then converting";
}

rule convertToSharesWeakAdditivity() {
    uint256 assetsA; uint256 assetsB; uint256 sharesA; uint256 sharesB;
    uint assetsAPlusB = require_uint256(assetsA + assetsB); uint256 sharesAPlusB;

    storage init = lastStorage; address asset;
    sharesA = convertToShares(init, assetsA, asset);
    sharesB = convertToShares(init, assetsB, asset);
    sharesAPlusB = convertToShares(init, assetsAPlusB, asset);

    require sharesA + sharesB < max_uint128
         && assetsA + assetsB < max_uint256
         && sharesAPlusB < max_uint256;

    assert sharesA + sharesB <= sharesAPlusB,
        "converting assetsA and assetsB to shares then summing them must yield a smaller or equal result to summing them then converting";
}


// total value of all asset the Vault holds must be greater or equal to total value of all shares
// where valueOf(shares) = shares * rate(asset) / ONE_SHARE
function isSolvent(env e) returns bool
{
    //assets1 * oneShare / rate(asset1) + assets2 * oneShare / rate(asset2)  >= totalShares

    //without division:
    //assets1 * oneShare * rate(asset2) + assets2 * oneShare * rate(asset1) >= totalShares * rate(asset1) * rate(asset2)
    //(assets1 * rate(asset2) + assets2 * rate(asset1)) * oneShare >= totalShares * rate(asset1) * rate(asset2)
    
    mathint rate1 = accountant_contract.getRateInQuoteSafe(e, ERC20Mock);
    mathint rate2 = accountant_contract.getRateInQuoteSafe(e, WETH);

    mathint value = userAssets(e, ERC20Mock, vault_contract) * rate2
                  + userAssets(e, WETH, vault_contract) * rate1;
    return value * teller_contract.ONE_SHARE >= vault_contract.totalSupply(e) * rate1 * rate2;
}

invariant vaultSolvency(address asset, env e)
    isSolvent(e)
filtered { f -> !ignoredMethod(f)
    && f.contract == teller_contract  //funds could be moved by methods called on the Vault or on the Asset
    && f.selector != sig:teller_contract.refundDeposit(uint256,address,address,uint256,uint256,uint256,uint256,address).selector // can break if the refunder is the vault
}
{
    preserved with (env e2) {
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
        requireAllInvariants(e2);
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
        requireAllInvariants(e2);
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
        requireAllInvariants(e2);
        safeAssumptions();
        nonSceneAddress(e2.msg.sender);
        
        requireSmallNumbers_Unsafe(e2);
        //require vault_contract.totalSupply() > 0;
    }
    preserved deposit(address add, uint256 amount, uint256 minShares, address ref) with (env e2) {
            requireAllInvariants(e2);
            safeAssumptions();
            nonSceneAddress(e2.msg.sender);
            requireSmallNumbers_Unsafe(e2);
            //require vault_contract.totalSupply() > 0;
            require amount < 1000;
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

        requireAllInvariants(e2);

        require e2.block.timestamp == e.block.timestamp;
        require accountant_contract.getPendingVestingGains(e2) <= vault_contract.totalSupply();
        //require vault_contract.totalSupply() > 0; //the initial state uses the lastSharePrice directly that could be incorrectly initialized
        safeAssumptions();
        nonSceneAddress(e2.msg.sender);
    }
}

invariant sharePriceMoreThanOneAsset()
    accountant_contract.vestingState.lastSharePrice >= 10^vault_contract.decimals
    || accountant_contract.downCastOverflow
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
{ preserved with (env e2) {
        requireAllInvariants(e2);

        require accountant_contract.getPendingVestingGains(e2) <= vault_contract.totalSupply();
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

        requireAllInvariants(e2);

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
        requireAllInvariants(e2);
        
        require e2.block.timestamp == e.block.timestamp;

        safeAssumptions();
        nonSceneAddress(e2.msg.sender);
        //require vault_contract.totalSupply() > 0;
        //requireSmallNumbers_Unsafe(e2);
        //require accountant_contract.getPendingVestingGains(e) == 0;
    }
    preserved constructor()
    {
        require accountant_contract.getPendingVestingGains(e) == 0;
    }
}

invariant exchangeRateEqlastSharePrice()
    accountant_contract.accountantState.exchangeRate == 
        accountant_contract.vestingState.lastSharePrice
    || accountant_contract.downCastOverflow
    filtered { f -> !ignoredMethod(f) }
    { preserved with (env e2) { 
        requireAllInvariants(e2);
        safeAssumptions(); }
}

invariant cumulativeSupplyBounded()
    accountant_contract.supplyObservation.cumulativeSupplyLast <= 
        accountant_contract.supplyObservation.cumulativeSupply
    filtered { f -> !ignoredMethod(f)
}

invariant exchangeRateLEhighwaterMark_unlessPaused()
    (!accountant_contract.accountantState.isPaused => 
        accountant_contract.accountantState.exchangeRate <= accountant_contract.accountantState.highwaterMark)
    || accountant_contract.downCastOverflow
    filtered { f -> !ignoredMethod(f)
        && f.selector != sig:accountant_contract.unpause().selector 
        //&& f.selector == sig:accountant_contract.postLoss(uint256).selector
        }
    { preserved with(env e) { 
        safeAssumptions(); 
        requireInvariant exchangeRateEqlastSharePrice();
        require !accountant_contract.downCastOverflow;
        
        //require accountant_contract.getPendingVestingGains(e) * accountant_contract.ONE_SHARE <= (max_uint96 - accountant_contract.vestingState.lastSharePrice) * vault_contract.totalSupply();
        //require getPendingVestingGains(e) <= vault_contract.totalSupply();
        }
        preserved constructor() {
            require accountant_contract.accountantState.highwaterMark ==
                accountant_contract.accountantState.exchangeRate;
        }
}

invariant virtualPriceIsCorrect()
    accountant_contract.vestingState.lastSharePrice == 
    accountant_contract.lastVirtualSharePrice * accountant_contract.ONE_SHARE / 10^27
    { preserved with(env e) { 
        safeAssumptions(); 
        requireAllInvariants(e);
    }
}

rule noFreeAssets(env e)
{
    safeAssumptions();
    requireAllInvariants(e);
    nonSceneAddress(e.msg.sender);
    
    //requireSmallNumbers_Unsafe(e);

    address asset; uint256 assetsAmount;
    //require assetsAmount < 10^6;
    //require accountant_contract.vestingState.vestingGains > 0;
    //uint shares = deposit(e, asset, assetsAmount, minShares, e.msg.sender); 
    uint shares = bulkDeposit(e, asset, assetsAmount, 0, e.msg.sender); 
    
    //uint assetsReceived = withdraw(e, asset,shares,minAssets,e.msg.sender);
    uint assetsReceived = bulkWithdraw(e,asset,shares, 0 ,e.msg.sender);

    //satisfy assetsReceived > assetsAmount + 1 * teller_contract.ONE_SHARE;
    //satisfy assetsReceived > assetsAmount;
    assert assetsReceived <= assetsAmount;
}

function requireAllInvariants(env e)
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

function requireSmallNumbers_Unsafe(env e)
{
    require teller_contract.ONE_SHARE == 1000;
    require accountant_contract.vestingState.lastSharePrice <= 100000; 

    require userAssets(e, ERC20Mock, vault_contract) < 10000000;
    require userAssets(e, ERC20Mock, vault_contract) > 1000;

    require vault_contract.totalSupply(e) < 10000000;
    require vault_contract.totalSupply(e) > 10000;

    //require accountant_contract.vestingState.vestingGains == 0;
}


rule vaultSolvency_1Asset_test(env e)
{
    safeAssumptions();
    nonSceneAddress(e.msg.sender);
    require (userAssets(e, ERC20Mock, vault_contract) - accountant_contract.getPendingVestingGains(e)) * teller_contract.ONE_SHARE 
        >= (vault_contract.totalSupply(e)) * (accountant_contract.getRateInQuoteSafe(e, ERC20Mock)); 

    require accountant_contract.totalAssets(e) == 12000000002;
    require vault_contract.totalSupply(e) == 10000000002;

    require accountant_contract.getRateInQuoteSafe(e, ERC20Mock) == 1199999;

    uint256 assetsAmount = 21000000;
    uint shares = deposit(e, ERC20Mock, assetsAmount, 0, e.msg.sender); 

    assert (userAssets(e, ERC20Mock, vault_contract) - accountant_contract.getPendingVestingGains(e)) * teller_contract.ONE_SHARE 
        >= (vault_contract.totalSupply(e)) * (accountant_contract.getRateInQuoteSafe(e, ERC20Mock)); 
    
}