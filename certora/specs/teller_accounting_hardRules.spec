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

invariant vaultSolvency_1Asset(address asset, env e)
    userAssets(e, ERC20Mock, vault_contract) * teller_contract.ONE_SHARE 
        >= vault_contract.totalSupply(e) * accountant_contract.getRateInQuoteSafe(e, ERC20Mock)
filtered { f -> !ignoredMethod(f)
    && (f.contract == teller_contract  //funds could be moved by methods called on the Vault or on the Asset
    || f.contract == accountant_contract)
    && f.selector != sig:teller_contract.refundDeposit(uint256,address,address,uint256,uint256,uint256,uint256,address).selector // can break if the sharesAmount is too low. This can happen since we don't really track the sum of deposits and their shares in publicDepositHistory

    //&& f.selector == sig:teller_contract.deposit(address, uint256, uint256,address).selector 
    //&& f.selector == sig:teller_contract.depositWithPermit(address,uint256,uint256,uint256,uint8,bytes32,bytes32,address).selector
    //&& f.selector == sig:teller_contract.bulkDeposit(address,uint256,uint256,address).selector
    //&& f.selector == sig:teller_contract.withdraw(address,uint256,uint256,address).selector
    //&& f.selector == sig:teller_contract.bulkWithdraw(address,uint256,uint256,address).selector
    && !isPublicMethod(f)
}
{
    preserved with (env e2) {
        safeAssumptions();
        nonSceneAddress(e2.msg.sender);
    }
}