import "dispatching_AccountantWithYieldStreaming.spec";
import "dispatching_BoringVault.spec";
import "dispatching_TellerWithYieldStreaming.spec";

using AccountantWithYieldStreaming as AccountantWithYieldStreaming;

use builtin rule sanity filtered { f ->
    (f.contract == AccountantWithYieldStreaming) =>
    (f.selector != sig:AccountantWithYieldStreaming.updateExchangeRate(uint96).selector &&
    f.selector != sig:AccountantWithYieldStreaming.previewUpdateExchangeRate(uint96).selector)
}