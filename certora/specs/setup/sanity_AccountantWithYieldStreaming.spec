import "dispatching_AccountantWithYieldStreaming.spec";
use builtin rule sanity filtered { f ->
    f.contract == currentContract &&
    f.selector != sig:updateExchangeRate(uint96).selector
}

rule sanity_updateExchangeRateAlwaysReverts() {
    env e;
    uint96 newExchangeRate;

    updateExchangeRate@withrevert(e, newExchangeRate);

    assert(lastReverted);
}
