import "scenarioA.spec";

// This resembles the convertToShares method.
function convertToShares(storage init, uint256 assets, address asset_contract) returns uint256
{
    env e;
    uint256 minimumMint;
    uint256 shares = deposit(e, asset_contract, assets, minimumMint) at init;
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

////////////////////////////////////////////////////////////////////////////////
////           Dynamic Calls                                               /////
////////////////////////////////////////////////////////////////////////////////

persistent ghost bool callMade;
persistent ghost bool delegatecallMade;

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (addr != vault_contract) {
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
rule noDynamicCalls {
    method f;
    env e;
    calldataarg args;

    require !callMade && !delegatecallMade;

    f(e, args);

    assert !callMade && !delegatecallMade;
}

////////////////////////////////////////////////////////////////////////////////
////           #  asset To shares mathematical properties                  /////
////////////////////////////////////////////////////////////////////////////////

rule conversionOfZero {
    address asset;
    storage init = lastStorage;
    uint256 convertZeroShares = convertToAssets(init, 0, asset);
    uint256 convertZeroAssets = convertToShares(init, 0, asset);

    assert convertZeroShares == 0,
        "converting zero shares must return zero assets";
    assert convertZeroAssets == 0,
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

////////////////////////////////////////////////////////////////////////////////
////                   #    Unit Test                                      /////
////////////////////////////////////////////////////////////////////////////////

rule depositMonotonicity(env e, address asset) {
    safeAssumptions();
    storage start = lastStorage;
    uint minShares;
    uint256 smallerAssets; uint256 largerAssets;
    require currentContract != e.msg.sender;

    deposit(e, asset, smallerAssets, minShares);

    uint256 smallerShares = vault_contract.balanceOf(e.msg.sender) ;

    deposit(e, asset, largerAssets, minShares) at start;
    uint256 largerShares = vault_contract.balanceOf(e.msg.sender) ;

    assert smallerAssets < largerAssets => smallerShares <= largerShares,
            "when supply tokens outnumber asset tokens, a larger deposit of assets must produce an equal or greater number of shares";
}


rule zeroDepositZeroShares(env e, uint assetAmount)
{
    address asset; uint256 minShares;
    uint shares = deposit(e, asset, assetAmount, minShares);

    assert shares == 0 <=> assetAmount == 0;
}

////////////////////////////////////////////////////////////////////////////////
////                    #    Valid State                                   /////
////////////////////////////////////////////////////////////////////////////////

invariant assetsMoreThanSupply(env e, address asset)
    asset.totalSupply(e) * accountant_contract.getRateInQuoteSafe(e, asset) >= vault_contract.totalSupply(e);

function userAssets(env e, address user, address asset) returns uint256
{
    return asset.balanceOf(e, user);
}

invariant noAssetsIfNoSupply(address asset, env e) 
    (userAssets(e, asset, currentContract) == 0 => vault_contract.totalSupply(e) == 0) &&
    (asset.totalSupply(e) == 0 => (vault_contract.totalSupply(e) == 0));

invariant noSupplyIfNoAssets(env e, address asset)
    noSupplyIfNoAssetsDef(e, asset);     // see defition in "helpers and miscellaneous" section


////////////////////////////////////////////////////////////////////////////////
////                    #     State Transition                             /////
////////////////////////////////////////////////////////////////////////////////


rule totalsMonotonicity(env e, method f) 
{
    address asset;
    require e.msg.sender != currentContract; 
    uint256 totalSupplyBefore = vault_contract.totalSupply(e);
    uint256 totalAssetsBefore =  asset.totalSupply(e);
    address receiver;
    
    calldataarg args;
    f(e, args);

    uint256 totalSupplyAfter = vault_contract.totalSupply(e);
    uint256 totalAssetsAfter = asset.totalSupply(e);
    
    // possibly assert totalSupply and totalAssets must not change in opposite directions
    assert totalSupplyBefore < totalSupplyAfter  <=> totalAssetsBefore < totalAssetsAfter,
        "if totalSupply changes by a larger amount, the corresponding change in totalAssets must remain the same or grow";
    assert totalSupplyAfter == totalSupplyBefore => totalAssetsBefore == totalAssetsAfter,
        "equal size changes to totalSupply must yield equal size changes to totalAssets";
}


////////////////////////////////////////////////////////////////////////////////
////                       #   Risk Analysis                           /////////
////////////////////////////////////////////////////////////////////////////////

invariant vaultSolvency(address asset, env e)
    userAssets(e, asset, vault_contract) * accountant_contract.getRateInQuoteSafe(e, asset) >= vault_contract.totalSupply(e)
{
    preserved {
        safeAssumptions();
    }
}


invariant zeroAllowanceOnAssets(env e, address user, address asset)
    asset.allowance(e, currentContract, user) == 0
{
    preserved {
        require e.msg.sender != currentContract;
    }
}

////////////////////////////////////////////////////////////////////////////////
////               # stakeholder properties  (Risk Analysis )         //////////
////////////////////////////////////////////////////////////////////////////////


rule onlyContributionMethodsReduceAssets(env e, method f) {
    safeAssumptions();
    address user; 
    require user != currentContract && user != vault_contract;
    address asset;
    uint256 userAssetsBefore = userAssets(e, asset, user);

    calldataarg args;
    f(e, args);

    uint256 userAssetsAfter = userAssets(e, asset, user);

    assert userAssetsBefore > userAssetsAfter =>
        (f.selector == sig:deposit(address, uint256, uint256).selector 
        || f.selector == sig:depositWithPermit(address,uint256,uint256,uint256,uint8,bytes32,bytes32).selector
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
         && currentContract != owner;

    uint256 ownerSharesBefore = vault_contract.balanceOf(owner);
    uint256 receiverAssetsBefore = userAssets(e, asset, receiver);

    withdraw(e, asset, shares, minimumAssets, receiver);

    uint256 ownerSharesAfter = vault_contract.balanceOf(owner);
    uint256 receiverAssetsAfter = userAssets(e, asset, receiver);

    assert ownerSharesBefore > ownerSharesAfter <=> receiverAssetsBefore < receiverAssetsAfter,
        "an owner's shares must decrease if and only if the receiver's assets increase";
}

////////////////////////////////////////////////////////////////////////////////
////                        # helpers and miscellaneous                //////////
////////////////////////////////////////////////////////////////////////////////

definition noSupplyIfNoAssetsDef(env e, address asset) returns bool = 
    (userAssets(e, asset, currentContract) == 0 => asset.totalSupply(e) == 0 ) &&
    (asset.totalSupply(e) == 0 <=> (vault_contract.totalSupply(e) == 0 ));
