import "scenarioA.spec";

rule integrityOfDeposit(env e)
{
    safeAssumptions();
    nonSceneSender(e.msg.sender);
    address asset; uint256 depositAmount; uint256 minimumMint;
    mathint assetsBefore = userAssets(e, asset, e.msg.sender);
    mathint sharesBefore = userAssets(e, vault_contract, e.msg.sender);

    mathint shares = deposit(e, asset, depositAmount, minimumMint);
    
    mathint assetsAfter = userAssets(e, asset, e.msg.sender);
    mathint sharesAfter = userAssets(e, vault_contract, e.msg.sender);

    assert shares >= minimumMint;
    assert assetsBefore - depositAmount == assetsAfter;
    assert sharesBefore + shares == sharesAfter;
}

rule integrityOfDepositWithPermit(env e)
{
    safeAssumptions();
    nonSceneSender(e.msg.sender);
    address asset; uint256 depositAmount; uint256 minimumMint;
    uint256 deadline; uint8 v; bytes32 r; bytes32 s;

    mathint assetsBefore = userAssets(e, asset, e.msg.sender);
    mathint sharesBefore = userAssets(e, vault_contract, e.msg.sender);

    mathint shares = depositWithPermit(e, asset, depositAmount, minimumMint,
        deadline, v, r, s);
    
    mathint assetsAfter = userAssets(e, asset, e.msg.sender);
    mathint sharesAfter = userAssets(e, vault_contract, e.msg.sender);

    assert shares >= minimumMint;
    assert assetsBefore - depositAmount == assetsAfter;
    assert sharesBefore + shares == sharesAfter;
}

rule integrityOfBulkDeposit(env e)
{
    safeAssumptions();
    nonSceneSender(e.msg.sender);
    address asset; uint256 depositAmount; uint256 minimumMint; address receiver;
    mathint assetsBefore = userAssets(e, asset, e.msg.sender);
    mathint sharesBefore = userAssets(e, vault_contract, receiver);

    mathint shares = bulkDeposit(e, asset, depositAmount, minimumMint, receiver);
    
    mathint assetsAfter = userAssets(e, asset, e.msg.sender);
    mathint sharesAfter = userAssets(e, vault_contract, receiver);

    assert shares >= minimumMint;
    assert assetsBefore - depositAmount == assetsAfter;
    assert sharesBefore + shares == sharesAfter;
}

rule integrityOfWithdraw(env e)
{
    safeAssumptions();
    nonSceneSender(e.msg.sender);
    address asset; uint256 sharesAmount; uint256 minimumAssets; address receiver;
    require asset != vault_contract && receiver != vault_contract;
    mathint sharesBefore = userAssets(e, vault_contract, e.msg.sender);
    mathint assetsBefore = userAssets(e, asset, receiver);

    mathint assets = withdraw(e, asset, sharesAmount, minimumAssets, receiver);
    
    mathint sharesAfter = userAssets(e, vault_contract, e.msg.sender);
    mathint assetsAfter = userAssets(e, asset, receiver);

    assert assets >= minimumAssets;
    assert sharesBefore - sharesAmount == sharesAfter;
    assert assetsBefore + assets == assetsAfter;
}

rule integrityOfBulkWithdraw(env e)
{
    safeAssumptions();
    nonSceneSender(e.msg.sender);
    address asset; uint256 sharesAmount; uint256 minimumAssets; address receiver;
    require asset != vault_contract && receiver != vault_contract;
    mathint sharesBefore = userAssets(e, vault_contract, e.msg.sender);
    mathint assetsBefore = userAssets(e, asset, receiver);

    mathint assets = bulkWithdraw(e, asset, sharesAmount, minimumAssets, receiver);
    
    mathint sharesAfter = userAssets(e, vault_contract, e.msg.sender);
    mathint assetsAfter = userAssets(e, asset, receiver);

    assert assets >= minimumAssets;
    assert sharesBefore - sharesAmount == sharesAfter;
    assert assetsBefore + assets == assetsAfter;
}