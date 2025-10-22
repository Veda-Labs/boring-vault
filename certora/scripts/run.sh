# certoraRun certora/confs/scenarioA.conf --verify "TellerWithMultiAssetSupport:certora/specs/rentrancy_view.spec" --msg reentrancy-A
# certoraRun certora/confs/scenarioA_accounting.conf

# certoraRun certora/confs/scenarioA.conf --verify "TellerWithMultiAssetSupport:certora/specs/teller_basic.spec" --msg TellerWithMultiAssetSupport
# certoraRun certora/confs/scenarioB.conf --verify "TellerWithBuffer:certora/specs/teller_basic.spec" --msg TellerWithBuffer
# certoraRun certora/confs/scenarioC.conf --verify "TellerWithYieldStreaming:certora/specs/teller_basic.spec" --msg TellerWithYieldStreaming
# certoraRun certora/confs/scenarioD.conf --verify "LayerZeroTeller:certora/specs/teller_basic.spec" --msg LayerZeroTeller
certoraRun certora/confs/scenarioE.conf --verify "LayerZeroTellerWithRateLimiting:certora/specs/teller_basic.spec" --msg LayerZeroTellerWithRateLimiting


# certoraRun certora/confs/accountantWithYieldStreaming.conf --msg accountant_base # one rule to sort out
# certoraRun certora/confs/accountantWithYieldStreaming.conf --verify AccountantWithYieldStreaming:certora/specs/accountantWithYieldStreaming.spec --msg accountantWithYieldStreaming # TODO

################    DONE
# certoraRun certora/confs/accountantWithRateProviders.conf --msg accountant_base

# certoraRun certora/confs/scenarioA.conf --verify "TellerWithMultiAssetSupport:certora/specs/teller_integrity.spec" --msg integrity_TellerWithMultiAssetSupport
# certoraRun certora/confs/scenarioB.conf --verify "TellerWithBuffer:certora/specs/teller_integrity.spec" --msg integrity_TellerWithBuffer
# certoraRun certora/confs/scenarioC.conf --verify "TellerWithYieldStreaming:certora/specs/teller_integrity.spec" --msg integrity_TellerWithYieldStreaming
# certoraRun certora/confs/scenarioD.conf --verify "LayerZeroTeller:certora/specs/teller_integrity.spec" --msg integrity_LayerZeroTeller
# certoraRun certora/confs/scenarioE.conf --verify "LayerZeroTellerWithRateLimiting:certora/specs/teller_integrity.spec" --msg integrity_LayerZeroTellerWithRateLimiting






