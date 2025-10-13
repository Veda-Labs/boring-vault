import "setup/dispatching_AccountantWithRateProviders.spec";
import "setup/dispatching_BoringVault.spec";
import "setup/dispatching_TellerWithMultiAssetSupport.spec";
import "MathSummaries.spec";

using AccountantWithRateProviders as accountant_contract;
using BoringVault as vault_contract;
using TellerWithMultiAssetSupport as teller_contract;
using WETH as WETH;

methods
{
    //function vault_contract.decimals() external returns (uint8) envfree;
}

function getHighWaterMark() returns uint96
{
    return accountant_contract.accountantState.highwaterMark;
}

definition ignoredMethod(method f) returns bool =
    f.selector == sig:vault_contract.manage(address[],bytes[],uint256[]).selector
    || f.selector == sig:vault_contract.manage(address,bytes,uint256).selector
    || f.isView;

function safeAssumptions()
{
    //require vault_contract.decimals() < 5;
    require vault_contract.decimals() < 50; //thats more than enough decimals. 10^78 > 2^256
    require accountant_contract.ONE_SHARE == 10 ^ vault_contract.decimals();
    require teller_contract.ONE_SHARE == 10 ^ vault_contract.decimals();
    requireInvariant totalSupplyHolds_BoringVault();
    requireInvariant totalSupplyHolds_ERC20Mock();
}

function nonSceneSender(address sender)
{
    //env e;
    //bytes4 signature_exit = sig:vault_contract.exit(address,address,uint256,address,uint256).selector;
    require sender != currentContract 
        && sender != vault_contract
        && sender != WETH
        && !teller_contract.authority.isAuthorized(sender, signature_exit)
       ;
}

rule highwaterMarkNeverDecreases(env e, method f)
    filtered { f -> !ignoredMethod(f) 
        && f.selector != sig:accountant_contract.resetHighwaterMark().selector
    }
{
    uint96 WM_pre = getHighWaterMark();
    calldataarg args;
    f(e, args);

    uint96 WM_post = getHighWaterMark();
    assert WM_post >= WM_pre;
}

invariant exchangeRateLEhighwaterMark_unlessPaused()
    !accountant_contract.accountantState.isPaused => 
        accountant_contract.accountantState.exchangeRate <= accountant_contract.accountantState.highwaterMark
    filtered { f -> !ignoredMethod(f)
        && f.selector != sig:accountant_contract.unpause().selector }
    { preserved { safeAssumptions(); }}

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

rule deniedUsers_balanceNonDecreasing(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    safeAssumptions();
    if (f.selector != sig:accountant_contract.claimFees(address).selector)
        nonSceneSender(e.msg.sender);   // the claimFees can only be called by the Vault so this condidtion would cause vacuity

    address user;
    bool isDeniedFrom = teller_contract.beforeTransferData[user].denyFrom;
    uint balance_pre = vault_contract.balanceOf(e, user);

    calldataarg args;
    f(e, args);

    uint balance_post = vault_contract.balanceOf(e, user);
    assert isDeniedFrom => balance_post >= balance_pre;
}

rule deniedUsers_balanceNonIncreasing(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    safeAssumptions();
    if (f.selector != sig:accountant_contract.claimFees(address).selector)
        nonSceneSender(e.msg.sender);   // the claimFees can only be called by the Vault so this condidtion would cause vacuity

    address user;
    bool isDeniedTo = teller_contract.beforeTransferData[user].denyTo;
    uint balance_pre = vault_contract.balanceOf(e, user);

    calldataarg args;
    f(e, args);
    uint balance_post = vault_contract.balanceOf(e, user);
    assert isDeniedTo => balance_post <= balance_pre;
}

invariant totalSupplyLEqCap()
    vault_contract.totalSupply() <= teller_contract.depositCap
        || teller_contract.depositCap == 2^112 - 1  // max uint112 means the cap is not applied
    filtered { f -> !ignoredMethod(f)
        && f.selector != sig:teller_contract.setDepositCap(uint112).selector // setting the cap bellow current supply is used by admins to disable further deposits
        && f.selector != sig:vault_contract.enter(address,address,uint256,address,uint256).selector // other tellers could operate the vault and increase its totalSupply
        }
    { preserved { safeAssumptions();} }

rule depositNonceNeverGoesDown(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    uint64 depositNonce_pre = teller_contract.depositNonce;

    calldataarg args;
    f(e, args);

    uint64 depositNonce_post = teller_contract.depositNonce;
    assert depositNonce_post >= depositNonce_pre;
}

rule dustFavorsTheHouse(uint assetsIn, env e)
{
    //require e.msg.sender != currentContract;
    //uint256 totalSupplyBefore = totalSupply();
    address asset; uint minimumShares; uint minimumAssets;

    uint balanceBefore = asset.balanceOf(e, vault_contract);

    uint shares = deposit(e, asset, assetsIn, minimumShares);
    uint assetsOut = withdraw(e, asset, shares, minimumAssets, e.msg.sender);

    uint balanceAfter = asset.balanceOf(e, vault_contract);

    assert balanceAfter >= balanceBefore;
}

rule tellerDoesntHoldTokens(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    safeAssumptions();
    if (f.selector != sig:accountant_contract.claimFees(address).selector)
        nonSceneSender(e.msg.sender);   // the claimFees can only be called by the Vault so this condidtion would cause vacuity

    address asset; require asset != vault_contract;
    // todo require that the teller contract is not the target of the funds.

    uint balanceBefore = asset.balanceOf(e, teller_contract);
    calldataarg args;
    f(e, args);

    uint balanceAfter = asset.balanceOf(e, teller_contract);

    assert balanceAfter == balanceBefore;
}

rule accountantDoesntHoldTokens(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    safeAssumptions();
    if (f.selector != sig:accountant_contract.claimFees(address).selector)
        nonSceneSender(e.msg.sender);   // the claimFees can only be called by the Vault so this condidtion would cause vacuity

    address asset; require asset != vault_contract;

    uint balanceBefore = asset.balanceOf(e, accountant_contract);
    calldataarg args;
    f(e, args);

    uint balanceAfter = asset.balanceOf(e, accountant_contract);

    assert balanceAfter == balanceBefore;
}

function userAssets(env e, address asset, address user) returns uint256
{
    return asset.balanceOf(e, user);
}

rule tellerPaused_valuesFrozen(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    require teller_contract.isPaused;
    uint64 depositNonce_pre = teller_contract.depositNonce;
    
    uint256 historyKey;
    bytes32 historyItem_pre = teller_contract.publicDepositHistory[historyKey];
    // TODO add more here

    calldataarg args;
    f(e, args);

    uint64 depositNonce_post = teller_contract.depositNonce;
    bytes32 historyItem_post = teller_contract.publicDepositHistory[historyKey];

    assert depositNonce_post == depositNonce_pre
        && (historyItem_post == historyItem_pre 
            || f.selector == sig:teller_contract.refundDeposit(uint256,address,address,uint256,uint256,uint256,uint256).selector) //refunds are allowed during pause
    ;
}

rule accountantPaused_valuesFrozen(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    require accountant_contract.accountantState.isPaused;

    address payoutAddress_pre = accountant_contract.accountantState.payoutAddress;
    uint96 highwaterMark_pre = accountant_contract.accountantState.highwaterMark;
    uint128 feesOwedInBase_pre = accountant_contract.accountantState.feesOwedInBase;
    uint128 totalSharesLastUpdate_pre = accountant_contract.accountantState.totalSharesLastUpdate;
    uint96 exchangeRate_pre = accountant_contract.accountantState.exchangeRate;
    uint16 allowedExchangeRateChangeUpper_pre = accountant_contract.accountantState.allowedExchangeRateChangeUpper;
    uint16 allowedExchangeRateChangeLower_pre = accountant_contract.accountantState.allowedExchangeRateChangeLower;
    uint64 lastUpdateTimestamp_pre = accountant_contract.accountantState.lastUpdateTimestamp;
    bool isPaused_pre = accountant_contract.accountantState.isPaused;
    uint24 minimumUpdateDelayInSeconds_pre = accountant_contract.accountantState.minimumUpdateDelayInSeconds;
    uint16 platformFee_pre = accountant_contract.accountantState.platformFee;
    uint16 performanceFee_pre = accountant_contract.accountantState.performanceFee;

    calldataarg args;
    f(e, args);

    address payoutAddress_post = accountant_contract.accountantState.payoutAddress;
    uint96 highwaterMark_post = accountant_contract.accountantState.highwaterMark;
    uint128 feesOwedInBase_post = accountant_contract.accountantState.feesOwedInBase;
    uint128 totalSharesLastUpdate_post = accountant_contract.accountantState.totalSharesLastUpdate;
    uint96 exchangeRate_post = accountant_contract.accountantState.exchangeRate;
    uint16 allowedExchangeRateChangeUpper_post = accountant_contract.accountantState.allowedExchangeRateChangeUpper;
    uint16 allowedExchangeRateChangeLower_post = accountant_contract.accountantState.allowedExchangeRateChangeLower;
    uint64 lastUpdateTimestamp_post = accountant_contract.accountantState.lastUpdateTimestamp;
    bool isPaused_post = accountant_contract.accountantState.isPaused;
    uint24 minimumUpdateDelayInSeconds_post = accountant_contract.accountantState.minimumUpdateDelayInSeconds;
    uint16 platformFee_post = accountant_contract.accountantState.platformFee;
    uint16 performanceFee_post = accountant_contract.accountantState.performanceFee;

    assert feesOwedInBase_post == feesOwedInBase_pre &&
        payoutAddress_post == payoutAddress_pre &&
        highwaterMark_post == highwaterMark_pre &&
        feesOwedInBase_post == feesOwedInBase_pre &&
        totalSharesLastUpdate_post == totalSharesLastUpdate_pre &&
        exchangeRate_post == exchangeRate_pre &&
        allowedExchangeRateChangeUpper_post == allowedExchangeRateChangeUpper_pre &&
        allowedExchangeRateChangeLower_post == allowedExchangeRateChangeLower_pre &&
        lastUpdateTimestamp_post == lastUpdateTimestamp_pre &&
        isPaused_post == isPaused_pre &&
        minimumUpdateDelayInSeconds_post == minimumUpdateDelayInSeconds_pre &&
        platformFee_post == platformFee_pre &&
        performanceFee_post == performanceFee_pre;
}

invariant allowedExchangeRateChangeUpper_bound()
    accountant_contract.accountantState.allowedExchangeRateChangeUpper >= 10^4
    filtered { f -> !ignoredMethod(f) }

invariant allowedExchangeRateChangeLower_bound()
    accountant_contract.accountantState.allowedExchangeRateChangeLower <= 10^4
    filtered { f -> !ignoredMethod(f) }

rule vaultCannotChange(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    address vault_pre = teller_contract.vault;

    calldataarg args;
    f(e, args);

    address vault_post = teller_contract.vault;
    assert vault_pre == vault_post;
}

rule feesCanOnlyDecreaseViaClaimFees(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    uint256 fees_pre = accountant_contract.accountantState.feesOwedInBase;

    calldataarg args;
    f(e, args);

    uint256 fees_post = accountant_contract.accountantState.feesOwedInBase;
    assert fees_post < fees_pre => f.selector == sig:accountant_contract.claimFees(address).selector;
}

function dispatcher_withReceiver(env e, method f, address receiver)
{

}