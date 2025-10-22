import "setup/dispatching_BoringVault.spec";
import "setup/snippet_ERC20_Mock.spec";
import "MathSummaries.spec";

import "setup/dispatching_AccountantWithYieldStreaming.spec";   // C
import "setup/dispatching_TellerWithYieldStreaming.spec";       // C

using AccountantWithYieldStreaming as accountant_contract;      // C
using TellerWithYieldStreaming as teller_contract;              // C