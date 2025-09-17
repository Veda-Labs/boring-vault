import "dispatching_AccountantWithYieldStreaming.spec";
import "dispatching_BoringVault.spec";
import "dispatching_TellerWithYieldStreaming.spec";

use builtin rule sanity filtered { f ->
    (f.contract == dispatching_AccountantWithYieldStreaming) =>
    (f.selector != sig:updateExchangeRate(uint96).selector &&
    f.selector != sig:previewUpdateExchangeRate(uint96).selector)
}