import "setup.spec";

methods {
    function _.balanceOf(address) external => ignoredUintStaticcall() expect(uint256);
    function _.totalSupply() internal => ignoredUintStaticcall() expect(uint256);
    function _.isAuthorized(address, bytes4) internal => ignoredBoolStaticcall() expect(bool);

    function _.getRateInQuoteSafe(address) external => ignoredUintStaticcall() expect(uint256);
    function _.getRateInQuote(address) external => ignoredUintStaticcall() expect(uint256);

}   

function ignoredBoolStaticcall() returns bool {
    ignoredStaticcall = true;
    bool value;
    return value;
}

function ignoredUintStaticcall() returns uint256 {
    ignoredStaticcall = true;
    uint256 value;
    return value;
}

persistent ghost bool ignoredStaticcall;

// True when at least one slot was written.
persistent ghost bool storageChanged;

// True when at least one STATICCALL is executed after a storage change.
persistent ghost bool staticCallAfterSStore;

// True when at least one slot is changed after a STATICCALL is executed after a storage change.
persistent ghost bool staticCallUnsafe;

hook ALL_SSTORE(uint slot, uint val) {
    if (slot != 0x2) //this is fine. It's the reentrancy lock
    {
        storageChanged = true;
    }
    if (staticCallAfterSStore) {
        staticCallUnsafe = true;
    }
}

hook STATICCALL(uint256 g, address addr, uint256 argsOffset, uint256 argsLength, uint256 retOffset, uint256 retLength) uint256 rc {
    // address(1) is ignored because it's the ecrecover function.
    if (!ignoredStaticcall && storageChanged && addr != 0x1 
        && selector != 404098525    // totalSupply()
        && selector != 499888400    // getRateInQuote
        && selector != 2181657562   // getRateInQuoteSafe
        && selector != 1738207182   // getRate
        && selector != 3714247998   // allowance(address,address)
        && selector != 434397065    // RateProviderMock.getRate(bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)
        && selector != sig:ERC20Mock.decimals().selector
        ) {
        staticCallAfterSStore = true;
    }
    ignoredStaticcall = false;
}

// Check that there are no reentrancy unsafe calls except potentially for balanceOf on the asset, realAssets on the adapters and canReceiveShares, canSendShares, canReceiveAssets and canSendAssets on the gates, and isInRegistry on adapter registry.
rule reentrancyViewSafe(method f, env e, calldataarg data)
filtered {
    f -> 
    f.selector != 1539645794        // depositAndBridgeWithPermit(CrossChainTellerWithGenericBridge.DepositAndBridgeWithPermitParams).selector // 0x5bc52162
    && f.selector != 4172789357     // depositAndBridge(address,uint256,uint256,address,bytes,address,uint256,address).selector // 0xf8b7b66d
    && f.selector != 93460288       // bridge(uint96,address,bytes,address,uint256).selector  // 0x05921740
    && f.selector != 3611446835     // previewFee(uint96,address,bytes,address).selector  // 0xd7424e33

    && f.selector != sig:withdraw(address,uint256,uint256,address).selector
    && f.selector != sig:bulkWithdraw(address,uint256,uint256,address).selector
} 
{
    require ignoredStaticcall == false, "setup ghost state";
    require storageChanged == false, "setup ghost state";
    require staticCallAfterSStore == false, "setup ghost state";
    require staticCallUnsafe == false, "setup ghost state";

    f(e, data);

    assert !staticCallUnsafe;
}

// rule reachability(method f, env e, calldataarg data)
// {
//     f(e, data);

//     satisfy true;
// }