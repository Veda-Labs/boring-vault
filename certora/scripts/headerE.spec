import "setup/dispatching_BoringVault.spec";
import "setup/snippet_ERC20_Mock.spec"; // B
import "MathSummaries.spec";

import "setup/dispatching_AccountantWithRateProviders.spec";      // A, B, D, E
import "setup/dispatching_LayerZeroTellerWithRateLimiting.spec";  // E

using AccountantWithRateProviders as accountant_contract;         // A, B, D, E
using LayerZeroTellerWithRateLimiting as teller_contract;         // E