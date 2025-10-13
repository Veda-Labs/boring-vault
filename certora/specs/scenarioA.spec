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

function nonSceneAddress(address sender)
{
    require sender != teller_contract 
        && sender != vault_contract
        && sender != WETH;

    env e;
    bytes4 signature_enter = to_bytes4(sig:vault_contract.enter(address,address,uint256,address,uint256).selector);
    bytes4 signature_exit = to_bytes4(sig:vault_contract.exit(address,address,uint256,address,uint256).selector);
    
    require 
        !vault_contract.isAuthorized(e, sender, signature_enter)
        && !vault_contract.isAuthorized(e, sender, signature_exit)
        ;
}

rule deniedUsers_balanceNonDecreasing(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    safeAssumptions();
    if (f.selector != sig:accountant_contract.claimFees(address).selector)
        nonSceneAddress(e.msg.sender);   // the claimFees can only be called by the Vault so this condidtion would cause vacuity

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
        nonSceneAddress(e.msg.sender);   // the claimFees can only be called by the Vault so this condidtion would cause vacuity

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
    filtered { f -> !ignoredMethod(f)
        && f.contract != ERC20Mock }
{
    safeAssumptions();
    if (f.selector != sig:accountant_contract.claimFees(address).selector)
        nonSceneAddress(e.msg.sender);   // the claimFees can only be called by the Vault so this condidtion would cause vacuity

    address asset; require asset != vault_contract;
    address receiver; nonSceneAddress(receiver);
    
    require accountant_contract.accountantState.payoutAddress != teller_contract, "otherwise the teller holds the fees, i.e. does hold tokens";
    // todo require that the teller contract is not the target of the funds.

    uint balanceBefore = asset.balanceOf(e, teller_contract);
    callMethodWithReceiver(e, f, receiver);

    uint balanceAfter = asset.balanceOf(e, teller_contract);

    assert balanceAfter == balanceBefore;
}

function userAssets(env e, address asset, address user) returns uint256
{
    return asset.balanceOf(e, user);
}

rule tellerPaused_valuesFrozen(env e, method f)
    filtered { f -> !ignoredMethod(f) &&
        !isPublicMethod(f) // we proved that public methods revert when paused so they would just be vacuous here 
        }
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

// public methods should revert when paused
rule tellerPaused_methodsRevert(env e, method f)
    filtered { f -> isPublicMethod(f) }
{
    require teller_contract.isPaused;
    
    calldataarg args;
    f@withrevert(e, args);

    assert lastReverted;
}

rule vaultCannotChange(env e, method f)
    filtered { f -> !ignoredMethod(f) }
{
    address vault_pre = teller_contract.vault;

    calldataarg args;
    f(e, args);

    address vault_post = teller_contract.vault;
    assert vault_pre == vault_post;
}

function callMethodWithReceiver(env e, method f, address receiver)
{
    if (f.selector == sig:teller_contract.refundDeposit(
        uint256,address,address,uint256,uint256,uint256,uint256).selector)
    {
        uint256 nonce; address depositAsset; uint256 depositAmount; 
        uint256 shareAmount; uint256 depositTimestamp; 
        uint256 shareLockUpPeriodAtTimeOfDeposit;
        refundDeposit(e, nonce, receiver, depositAsset, depositAmount,
            shareAmount, depositTimestamp, shareLockUpPeriodAtTimeOfDeposit);
    }
    else if (f.selector == sig:teller_contract.withdraw(address,uint256,uint256,address).selector)
    {
        address withdrawAsset; uint256 shareAmount; uint256 minimumAssets;
        withdraw(e, withdrawAsset, shareAmount, minimumAssets, receiver);
    }
    else if (f.selector == sig:teller_contract.bulkWithdraw(address,uint256,uint256,address).selector)
    {
        address withdrawAsset; uint256 shareAmount; uint256 minimumAssets;
        bulkWithdraw(e, withdrawAsset, shareAmount, minimumAssets, receiver);
    }
    else 
    {
        calldataarg args;
        f(e, args);
    }
}

// Method that can be called by non-priveleged addresses
definition isPublicMethod(method f) returns bool = 
    f.selector == sig:teller_contract.deposit(address,uint256,uint256).selector ||
    f.selector == sig:teller_contract.bulkDeposit(address,uint256,uint256,address).selector ||
    f.selector == sig:teller_contract.depositWithPermit(address,uint256,uint256,uint256,uint8,bytes32,bytes32).selector ||
    f.selector == sig:teller_contract.withdraw(address,uint256,uint256,address).selector ||
    f.selector == sig:teller_contract.bulkWithdraw(address,uint256,uint256,address).selector;