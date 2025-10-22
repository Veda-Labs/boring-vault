# certora/scripts/setup.sh A && certoraRun certora/confs/scenarioA.conf --verify "TellerWithMultiAssetSupport:certora/specs/rentrancy_view.spec" --msg reentrancy --prover_args "-enableStorageSplitting false"


certora/scripts/setup.sh A && certoraRun certora/confs/scenarioA.conf --verify "TellerWithMultiAssetSupport:certora/specs/teller_accounting_hardRules.spec" --msg accounting_hardRules
certora/scripts/setup.sh B && certoraRun certora/confs/scenarioB.conf --verify "TellerWithBuffer:certora/specs/teller_accounting_hardRules.spec" --msg accounting_hardRules
certora/scripts/setup.sh C && certoraRun certora/confs/scenarioC.conf --verify "TellerWithYieldStreaming:certora/specs/teller_accounting_hardRules.spec" --msg accounting_hardRules
certora/scripts/setup.sh D && certoraRun certora/confs/scenarioD.conf --verify "LayerZeroTeller:certora/specs/teller_accounting_hardRules.spec" --msg accounting_hardRules
certora/scripts/setup.sh E && certoraRun certora/confs/scenarioE.conf --verify "LayerZeroTellerWithRateLimiting:certora/specs/teller_accounting_hardRules.spec" --msg accounting_hardRules

certora/scripts/setup.sh A && certoraRun certora/confs/scenarioA.conf --verify "TellerWithMultiAssetSupport:certora/specs/teller_accounting_easyRules.spec" --msg accounting_easyRules
certora/scripts/setup.sh B && certoraRun certora/confs/scenarioB.conf --verify "TellerWithBuffer:certora/specs/teller_accounting_easyRules.spec" --msg accounting_easyRules
certora/scripts/setup.sh C && certoraRun certora/confs/scenarioC.conf --verify "TellerWithYieldStreaming:certora/specs/teller_accounting_easyRules.spec" --msg accounting_easyRules
certora/scripts/setup.sh D && certoraRun certora/confs/scenarioD.conf --verify "LayerZeroTeller:certora/specs/teller_accounting_easyRules.spec" --msg accounting_easyRules
certora/scripts/setup.sh E && certoraRun certora/confs/scenarioE.conf --verify "LayerZeroTellerWithRateLimiting:certora/specs/teller_accounting_easyRules.spec" --msg accounting_easyRules


#### these have some issues
# certora/scripts/setup.sh A && certoraRun certora/confs/scenarioA.conf --verify "TellerWithMultiAssetSupport:certora/specs/teller_basic.spec" --msg teller_basic
# certora/scripts/setup.sh B && certoraRun certora/confs/scenarioB.conf --verify "TellerWithBuffer:certora/specs/teller_basic.spec" --msg teller_basic
# certora/scripts/setup.sh C && certoraRun certora/confs/scenarioC.conf --verify "TellerWithYieldStreaming:certora/specs/teller_basic.spec" --msg teller_basic
# certora/scripts/setup.sh D && certoraRun certora/confs/scenarioD.conf --verify "LayerZeroTeller:certora/specs/teller_basic.spec" --msg teller_basic
# certora/scripts/setup.sh E && certoraRun certora/confs/scenarioE.conf --verify "LayerZeroTellerWithRateLimiting:certora/specs/teller_basic.spec" --msg teller_basic


# certoraRun certora/confs/accountantWithYieldStreaming.conf --msg accountant_base # one rule to sort out
# certoraRun certora/confs/accountantWithYieldStreaming.conf --verify AccountantWithYieldStreaming:certora/specs/accountantWithYieldStreaming.spec --msg accountantWithYieldStreaming # TODO

################    DONE
# certoraRun certora/confs/accountantWithRateProviders.conf --msg accountant_base

# certoraRun certora/confs/scenarioA.conf --verify "TellerWithMultiAssetSupport:certora/specs/teller_integrity.spec" --msg integrity_TellerWithMultiAssetSupport
# certoraRun certora/confs/scenarioB.conf --verify "TellerWithBuffer:certora/specs/teller_integrity.spec" --msg integrity_TellerWithBuffer
# certoraRun certora/confs/scenarioC.conf --verify "TellerWithYieldStreaming:certora/specs/teller_integrity.spec" --msg integrity_TellerWithYieldStreaming
# certoraRun certora/confs/scenarioD.conf --verify "LayerZeroTeller:certora/specs/teller_integrity.spec" --msg integrity_LayerZeroTeller
# certoraRun certora/confs/scenarioE.conf --verify "LayerZeroTellerWithRateLimiting:certora/specs/teller_integrity.spec" --msg integrity_LayerZeroTellerWithRateLimiting






