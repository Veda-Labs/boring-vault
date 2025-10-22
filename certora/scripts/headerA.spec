import "setup/dispatching_BoringVault.spec";
import "setup/snippet_ERC20_Mock.spec";
import "MathSummaries.spec";

import "setup/dispatching_AccountantWithRateProviders.spec";    // A, B, D, E
import "setup/dispatching_TellerWithMultiAssetSupport.spec";    // A

using AccountantWithRateProviders as accountant_contract;       // A, B, D, E
using TellerWithMultiAssetSupport as teller_contract;           // A