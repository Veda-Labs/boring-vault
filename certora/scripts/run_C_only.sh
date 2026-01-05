certora/scripts/setup.sh C

# # reentrancy: holds
certoraRun certora/confs/scenarioC.conf --verify "TellerWithYieldStreaming:certora/specs/rentrancy_view.spec" --msg reentrancy --prover_args "-enableStorageSplitting false"

# # solvency: all holds except for C
certoraRun certora/confs/scenarioC.conf --verify "TellerWithYieldStreaming:certora/specs/teller_accounting_hardRules.spec" --msg vaultSolvency_1Asset --rule vaultSolvency_1Asset --prover_args "-destructiveOptimizations twostage -mediumTimeout 20 -lowTimeout 20 -tinyTimeout 20 -depth 20"

# # teller basic:
certoraRun certora/confs/scenarioC.conf --verify "TellerWithYieldStreaming:certora/specs/teller_basic.spec" --msg teller_basic

# # teller accounting:
certoraRun certora/confs/scenarioC.conf --verify "TellerWithYieldStreaming:certora/specs/teller_accounting_easyRules.spec" --msg accounting_easyRules

# # accountants:
certoraRun certora/confs/accountantWithYieldStreaming.conf --msg accountant_base

# # integrity
certoraRun certora/confs/scenarioC.conf --verify "TellerWithYieldStreaming:certora/specs/teller_integrity.spec" --msg integrity_TellerWithYieldStreaming
