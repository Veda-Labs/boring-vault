# reentrancy: holds
certora/scripts/setup.sh A && certoraRun certora/confs/scenarioA.conf --verify "TellerWithMultiAssetSupport:certora/specs/rentrancy_view.spec" --msg reentrancy_A --prover_args "-enableStorageSplitting false"
certora/scripts/setup.sh B && certoraRun certora/confs/scenarioB.conf --verify "TellerWithBuffer:certora/specs/rentrancy_view.spec" --msg reentrancy_B --prover_args "-enableStorageSplitting false"
certora/scripts/setup.sh C && certoraRun certora/confs/scenarioC.conf --verify "TellerWithYieldStreaming:certora/specs/rentrancy_view.spec" --msg reentrancy_C --prover_args "-enableStorageSplitting false"
certora/scripts/setup.sh D && certoraRun certora/confs/scenarioD.conf --verify "LayerZeroTeller:certora/specs/rentrancy_view.spec" --msg reentrancy_D --prover_args "-enableStorageSplitting false"
certora/scripts/setup.sh E && certoraRun certora/confs/scenarioE.conf --verify "LayerZeroTellerWithRateLimiting:certora/specs/rentrancy_view.spec" --msg reentrancy_E --prover_args "-enableStorageSplitting false"


# teller basic:
certora/scripts/setup.sh A && certoraRun certora/confs/scenarioA.conf --verify "TellerWithMultiAssetSupport:certora/specs/teller_basic.spec" --msg teller_basic_A # done
certora/scripts/setup.sh B && certoraRun certora/confs/scenarioB.conf --verify "TellerWithBuffer:certora/specs/teller_basic.spec" --msg teller_basic_B # done
certora/scripts/setup.sh C && certoraRun certora/confs/scenarioC.conf --verify "TellerWithYieldStreaming:certora/specs/teller_basic.spec" --msg teller_basic_C --exclude_rule dustFavorsTheHouse # done
certora/scripts/setup.sh D && certoraRun certora/confs/scenarioD.conf --verify "LayerZeroTeller:certora/specs/teller_basic.spec" --msg teller_basic_D # done
certora/scripts/setup.sh E && certoraRun certora/confs/scenarioE.conf --verify "LayerZeroTellerWithRateLimiting:certora/specs/teller_basic.spec" --msg teller_basic_E # done


##  holds except for AccountantWithYeildStreaming

# teller accounting:
certora/scripts/setup.sh A && certoraRun certora/confs/scenarioA.conf --verify "TellerWithMultiAssetSupport:certora/specs/teller_accounting_easyRules.spec" --msg accounting_easyRules_A # done
certora/scripts/setup.sh B && certoraRun certora/confs/scenarioB.conf --verify "TellerWithBuffer:certora/specs/teller_accounting_easyRules.spec" --msg accounting_easyRules_B # done
certora/scripts/setup.sh C && certoraRun certora/confs/scenarioC.conf --verify "TellerWithYieldStreaming:certora/specs/teller_accounting_easyRules.spec" --msg accounting_easyRules_C
certora/scripts/setup.sh D && certoraRun certora/confs/scenarioD.conf --verify "LayerZeroTeller:certora/specs/teller_accounting_easyRules.spec" --msg accounting_easyRules_D # done
certora/scripts/setup.sh E && certoraRun certora/confs/scenarioE.conf --verify "LayerZeroTellerWithRateLimiting:certora/specs/teller_accounting_easyRules.spec" --msg accounting_easyRules_E # done


################    DONE

# accountants:
certora/scripts/setup.sh A && certoraRun certora/confs/accountantWithRateProviders.conf --msg accountant_base   # done
certora/scripts/setup.sh C && certoraRun certora/confs/accountantWithYieldStreaming.conf --msg accountant_base  # done
certora/scripts/setup.sh C && certoraRun certora/confs/accountantWithYieldStreaming.conf --verify AccountantWithYieldStreaming:certora/specs/accountantWithYieldStreaming.spec --msg accountantWithYieldStreaming

# integrity
certora/scripts/setup.sh A && certoraRun certora/confs/scenarioA.conf --verify "TellerWithMultiAssetSupport:certora/specs/teller_integrity.spec" --msg integrity_TellerWithMultiAssetSupport # done
certora/scripts/setup.sh B && certoraRun certora/confs/scenarioB.conf --verify "TellerWithBuffer:certora/specs/teller_integrity.spec" --msg integrity_TellerWithBuffer # done
certora/scripts/setup.sh C && certoraRun certora/confs/scenarioC.conf --verify "TellerWithYieldStreaming:certora/specs/teller_integrity.spec" --msg integrity_TellerWithYieldStreaming  # done
certora/scripts/setup.sh D && certoraRun certora/confs/scenarioD.conf --verify "LayerZeroTeller:certora/specs/teller_integrity.spec" --msg integrity_LayerZeroTeller # done
certora/scripts/setup.sh E && certoraRun certora/confs/scenarioE.conf --verify "LayerZeroTellerWithRateLimiting:certora/specs/teller_integrity.spec" --msg integrity_LayerZeroTellerWithRateLimiting # done


# for testing
# certora/scripts/setup.sh C && certoraRun certora/confs/accountantWithYieldStreaming.conf --verify AccountantWithYieldStreaming:certora/specs/accountantWithYieldStreaming.spec --msg accountantWithYieldStreaming_postLoss --rule exchangeRateLEhighwaterMark_unlessPaused_postLoss
# certora/scripts/setup.sh C && certoraRun certora/confs/accountantWithYieldStreaming.conf --verify AccountantWithYieldStreaming:certora/specs/accountantWithYieldStreaming.spec --msg accountantWithYieldStreaming

# certora/scripts/setup.sh C && certoraRun certora/confs/accountantWithYieldStreaming.conf --verify AccountantWithYieldStreaming:certora/specs/accountantWithYieldStreaming.spec --msg accountantWithYieldStreaming --prover_args "-destructiveOptimizations twostage -mediumTimeout 20 -lowTimeout 20 -tinyTimeout 20 -depth 20" --rule totalAssetsCovered --rule vaultSolvency_1Asset