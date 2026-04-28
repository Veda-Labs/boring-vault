// rules specific for accountantWithRateProviders

import "accountant_basic.spec";

invariant exchangeRateLEhighwaterMark_unlessPaused()
    !accountant_contract.accountantState.isPaused => 
        accountant_contract.accountantState.exchangeRate <= accountant_contract.accountantState.highwaterMark
    filtered { f -> !ignoredMethod(f)
        && f.selector != sig:unpause().selector }
    { preserved { safeAssumptions(); }}
