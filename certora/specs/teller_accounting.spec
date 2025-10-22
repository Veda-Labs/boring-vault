import "scenarioA.spec";

// This resembles the convertToShares method.
function convertToShares(storage init, uint256 assets, address asset_contract) returns uint256
{
    env e;
    uint256 minimumMint; address referral;
    uint256 shares = deposit(e, asset_contract, assets, minimumMint, referral) at init;
    return shares;
}

// This resembles the convertToAssets method.
function convertToAssets(storage init, uint256 shares, address asset_contract) returns uint256
{
    env e;
    uint256 minimumAssets;
    address receiver;
    uint256 assets = withdraw(e, asset_contract, shares, minimumAssets, receiver) at init;
    return assets;
}

// rule sharePriceDoesntDecrease(env e, method f)
//     filtered { f -> !f.isView }
// {
//     // address receiver;
//     requireConsistentState(e.msg.sender, siloVaultHarness);
//     requireConsistentState(e.msg.sender, asset());

//     uint256 totalAssets_pre = totalAssets(e); //lastTotalAssets(e); 
//     uint256 totalShares_pre = totalSupply(e);
//     calldataarg args;
//     f(e, args);
//     uint256 totalAssets_post = lastTotalAssets(e); // totalAssets(e);
//     uint256 totalShares_post = totalSupply(e);

//     // totalAssets_pre / totalShares_pre  <= totalAssets_post / totalShares_post
//     assert totalAssets_pre * totalShares_post  <= totalAssets_post * totalShares_pre;
    
// }

persistent ghost bool callMade;
persistent ghost bool delegatecallMade;

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (addr != vault_contract
        && addr != ERC20Mock) 
    {
        // TODO whitelist the asset.. e.g whenever the asset is passed to deposit, e.g.) {
        callMade = true;
    }
}

hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    delegatecallMade = true;
}

/*
This rule proves there are no instances in the code in which the user can act as the contract.
By proving this rule we can safely assume in our spec that e.msg.sender != currentContract.
*/
rule noDynamicCalls(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    require !callMade && !delegatecallMade;

    calldataarg args;
    f(e, args);

    assert !callMade && !delegatecallMade;
}

////////////////////////////////////////////////////////////////////////////////
////           #  asset-to-shares mathematical properties                  /////
////////////////////////////////////////////////////////////////////////////////

rule conversionOfZero {
    address asset;
    storage init = lastStorage;
    uint256 amount;
    uint256 convertZeroShares = convertToAssets(init, amount, asset);
    uint256 convertZeroAssets = convertToShares(init, amount, asset);

    assert amount == 0 => convertZeroShares == 0,
        "converting zero shares must return zero assets";
    assert amount == 0 => convertZeroAssets == 0,
        "converting zero assets must return zero shares";
}

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

rule conversionWeakMonotonicity_assets {
    uint256 smallerAssets; uint256 largerAssets;
    storage init = lastStorage; address asset;

    uint256 smallerShares = convertToShares(init, smallerAssets, asset); 
    uint256 largerShares = convertToShares(init, largerAssets, asset);

    assert smallerAssets < largerAssets => smallerShares <= largerShares,
        "converting more assets must yield equal or greater shares";
}

rule conversionWeakMonotonicity_shares {
    uint256 smallerShares; uint256 largerShares;
    storage init = lastStorage; address asset;

    uint256 smallerAssets = convertToAssets(init, smallerShares, asset); 
    uint256 largerAssets = convertToAssets(init, largerShares, asset); 
    
    assert smallerShares < largerShares => smallerAssets <= largerAssets,
        "converting more shares must yield equal or greater assets";
}

rule conversionWeakIntegrity_shares() {
    uint256 shares_pre; address asset;
    uint assets = convertToAssets(lastStorage, shares_pre, asset);
    uint shares_post = convertToShares(lastStorage, assets, asset);
    assert shares_post <= shares_pre,
        "converting shares to assets then back to shares must return shares less than or equal to the original amount";
}

rule conversionWeakIntegrity_assets() {
    uint256 assets_pre; address asset;
    uint shares = convertToShares(lastStorage, assets_pre, asset);
    uint assets_post = convertToAssets(lastStorage, shares, asset);

    assert assets_post <= assets_pre,
        "converting assets to shares then back to assets must return assets less than or equal to the original amount";
}

rule totalAssetsDoesntChange(env e, method f) 
{
    if (f.selector != sig:accountant_contract.claimFees(address).selector)
        nonSceneAddress(e.msg.sender);   // the claimFees can only be called by the Vault so this condidtion would cause vacuity

    address asset;
    uint256 totalAssetsBefore = asset.totalSupply(e);

    calldataarg args;
    f(e, args);

    uint256 totalAssetsAfter = asset.totalSupply(e);
    
    assert totalAssetsBefore == totalAssetsAfter;
}

// totalSupply and totalAssets must not change in opposite directions
rule totalsMonotonicity(env e, method f) 
{
    if (f.selector != sig:accountant_contract.claimFees(address).selector)
        nonSceneAddress(e.msg.sender);   // the claimFees can only be called by the Vault so this condidtion would cause vacuity

    address asset;
    uint256 totalSupplyBefore = vault_contract.totalSupply(e);
    uint256 totalAssetsBefore = asset.totalSupply(e);
    address receiver;
    
    calldataarg args;
    f(e, args);

    uint256 totalSupplyAfter = vault_contract.totalSupply(e);
    uint256 totalAssetsAfter = asset.totalSupply(e);
    
    assert totalSupplyBefore < totalSupplyAfter => totalAssetsBefore <= totalAssetsAfter;
    assert totalSupplyBefore > totalSupplyAfter => totalAssetsBefore >= totalAssetsAfter;
}

////////////////////////////////////////////////////////////////////////////////
////                       #   Risk Analysis                           /////////
////////////////////////////////////////////////////////////////////////////////

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

invariant vaultSolvency_1Asset(address asset, env e)
    userAssets(e, ERC20Mock, vault_contract) * teller_contract.ONE_SHARE 
        >= vault_contract.totalSupply(e) * accountant_contract.getRateInQuoteSafe(e, ERC20Mock)
filtered { f -> !ignoredMethod(f)
    && f.contract == teller_contract  //funds could be moved by methods called on the Vault or on the Asset
    && f.selector != sig:teller_contract.refundDeposit(uint256,address,address,uint256,uint256,uint256,uint256,address).selector // can break if the sharesAmount is too low. This can happen since we don't really track the sum of deposits and their shares in publicDepositHistory
    && f.selector == sig:teller_contract.deposit(address, uint256, uint256,address).selector 
    //&& f.selector == sig:teller_contract.depositWithPermit(address,uint256,uint256,uint256,uint8,bytes32,bytes32,address).selector
    //&& f.selector == sig:teller_contract.bulkDeposit(address,uint256,uint256,address).selector
    //&& f.selector == sig:teller_contract.withdraw(address,uint256,uint256,address).selector
    //&& f.selector == sig:teller_contract.bulkWithdraw(address,uint256,uint256,address).selector
    //&& !isPublicMethod(f)
}
{
    preserved with (env e2) {
        safeAssumptions();
        nonSceneAddress(e2.msg.sender);
    }
}

// Runs on teller only
// There are other ways to set allowance directly on the vault
invariant zeroAllowanceOnAssets(env e, address user, address asset)
    asset.allowance(e, currentContract, user) == 0
filtered { f -> f.contract == teller_contract } 
{
    preserved with (env e2) {
        nonSceneAddress(e2.msg.sender);
    }
}

rule onlyContributionMethodsReduceAssets(env e, method f) 
    filtered { f -> f.contract == teller_contract }
{
    safeAssumptions();
    address user; nonSceneAddress(user);
    address asset; require asset != vault_contract;
    uint256 userAssetsBefore = userAssets(e, asset, user);

    calldataarg args;
    f(e, args);

    uint256 userAssetsAfter = userAssets(e, asset, user);

    assert userAssetsBefore > userAssetsAfter =>
        (f.selector == sig:deposit(address, uint256, uint256,address).selector 
        || f.selector == sig:depositWithPermit(address,uint256,uint256,uint256,uint8,bytes32,bytes32,address).selector
        || f.selector == sig:bulkDeposit(address,uint256,uint256,address).selector
        ),
        "a user's assets must not go down except on calls to contribution methods or calls directly to the asset.";
}

rule withdrawingProducesAssets(env e)
{
    uint256 shares; address asset;
    address receiver; address owner = e.msg.sender;
    uint256 minimumAssets;
    require currentContract != e.msg.sender
         && currentContract != receiver
         && currentContract != owner
         && minimumAssets > 0  //otherwise it's possible to loose dust shares and not receive any asset because of rounding
         && receiver != vault_contract;

    uint256 ownerSharesBefore = vault_contract.balanceOf(owner);
    uint256 receiverAssetsBefore = userAssets(e, asset, receiver);

    uint256 assetsReceived = withdraw(e, asset, shares, minimumAssets, receiver);

    uint256 ownerSharesAfter = vault_contract.balanceOf(owner);
    uint256 receiverAssetsAfter = userAssets(e, asset, receiver);

    assert ownerSharesBefore > ownerSharesAfter <=> receiverAssetsBefore < receiverAssetsAfter,
        "an owner's shares must decrease if and only if the receiver's assets increase";
}

