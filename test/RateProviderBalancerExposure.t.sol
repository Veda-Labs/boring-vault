// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Test, console} from "@forge-std/Test.sol";
import {Vm} from "@forge-std/Vm.sol";
import {ChainValues} from "test/resources/ChainValues.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";

/**
 * @notice Asserts that no rate provider we configure reads Balancer pool state.
 *
 * @dev Balancer's read-only reentrancy lets an attacker inside a Vault callback observe a
 *      manipulated `getRate()` on a Balancer pool token. Our accountants read
 *      `IRateProvider.getRate()` on paths reachable from permissionless entry points
 *      (`TellerWithMultiAssetSupport.deposit` -> `getRateInQuoteSafe` -> `getRateInQuote` ->
 *      `data.rateProvider.getRate()`), so a rate provider that reads a Balancer pool would make
 *      that read manipulable. Every provider we ship today reads an LST/LRT rate source instead,
 *      which is why no `VaultReentrancyLib.ensureNotInVaultContext` guard is needed.
 *
 *      That safety is a property of the configured *addresses*, not of the source, so no static
 *      analysis can check it -- the address is a constructor argument or a post-deploy
 *      `setRateProviderData` call. This test checks it the only way it can be checked: by asking
 *      the deployed contracts on a fork.
 *
 *      A candidate is a Balancer pool if either
 *        - V2: it answers `getPoolId()`, and the canonical V2 Vault maps that id back to it, or
 *        - V3: the V3 Vault reports `isPoolRegistered(candidate)`.
 *      Both are positive identifications against the Vault, so a contract that merely happens to
 *      expose `getPoolId()` cannot trip it, and a Balancer-*deployed* rate provider that is not a
 *      pool (e.g. mainnet wstETH's 0x06FF...1282) correctly passes.
 */
contract RateProviderBalancerExposureTest is Test, ChainValues {
    using AddressToBytes32Lib for bytes32;

    /// @dev Mirrors the structs in script/ArchitectureDeployments/DeployArcticArchitectureWithConfig.s.sol,
    ///      which decodes this same `accountantAssets` array. Field order must match the JSON keys
    ///      in alphabetical order, which is how forge encodes a parsed JSON object.
    struct AddressOrName {
        address address_;
        string name;
    }

    struct AccountantAsset {
        AddressOrName addressOrName;
        bool isPeggedToBase;
        address rateProvider;
    }

    string internal constant CONFIG_ROOT = "deployments/configurations";

    /// @dev keccak(chainName) => forkId + 1, so one fork is created per chain and reused.
    mapping(bytes32 => uint256) internal forkIdPlusOne;

    uint256 internal providersChecked;
    uint256 internal violations;
    uint256 internal filesChecked;
    uint256 internal chainsCovered;
    uint256 internal skippedNoBalancer;
    uint256 internal unclassifiedChains;
    uint256 internal skippedNoRpc;
    uint256 internal skippedUnreadable;
    bool internal mainnetCovered;

    function testNoConfiguredRateProviderIsBalancerPool() external {
        Vm.DirEntry[] memory entries = vm.readDir(CONFIG_ROOT, 2);

        for (uint256 i; i < entries.length; ++i) {
            // Chain directories sit at depth 1, the vault configs inside them at depth 2.
            if (entries[i].isDir || entries[i].depth != 2) continue;
            if (!_endsWithJson(entries[i].path)) continue;
            _checkConfig(entries[i].path);
        }

        console.log("--- rate provider Balancer exposure ---");
        console.log(string.concat("configs checked:      ", vm.toString(filesChecked)));
        console.log(string.concat("chains forked:        ", vm.toString(chainsCovered)));
        console.log(string.concat("rate sources probed:  ", vm.toString(providersChecked)));
        console.log(string.concat("skipped, no Balancer: ", vm.toString(skippedNoBalancer)));
        console.log(string.concat("skipped, no RPC:      ", vm.toString(skippedNoRpc)));
        console.log(string.concat("skipped, unreadable:  ", vm.toString(skippedUnreadable)));
        console.log(string.concat("unclassified chains:  ", vm.toString(unclassifiedChains)));

        // A pass with nothing probed is indistinguishable from a pass with nothing wrong, so
        // require that the chain carrying most of our configured providers was actually reached.
        assertTrue(mainnetCovered, "no mainnet coverage: is MAINNET_RPC_URL set?");
        assertEq(
            unclassifiedChains,
            0,
            "chain has configs but no balancerVault in ChainValues (set address(1) when Balancer is absent)"
        );
        assertEq(violations, 0, "a configured rate provider reads Balancer pool state");
    }

    function _checkConfig(string memory path) internal {
        string memory json = vm.readFile(path);
        // deployments/configurations/Mainnet/SwapperTestVault.json is a committed empty file.
        if (bytes(json).length == 0) {
            skippedUnreadable++;
            console.log(string.concat("SKIP empty config: ", path));
            return;
        }
        if (!vm.keyExistsJson(json, ".deploymentParameters.chainName")) {
            skippedUnreadable++;
            console.log(string.concat("SKIP config without chainName: ", path));
            return;
        }

        string memory chain = vm.parseJsonString(json, ".deploymentParameters.chainName");

        address v2Vault = values[chain]["balancerVault"].toAddress();
        address v3Vault = values[chain]["balancerV3Vault"].toAddress();

        // ChainValues stores address(1) as the explicit "Balancer is not deployed here" sentinel.
        // Both keys unset means the chain was never classified, which would skip it invisibly --
        // fail instead, so a new chain has to be classified before its configs count as checked.
        if (v2Vault == address(0) && v3Vault == address(0)) {
            unclassifiedChains++;
            console.log(string.concat("UNCLASSIFIED chain, no balancerVault in ChainValues: ", chain, " (", path, ")"));
            return;
        }

        // With no Vault on the chain there is no pool state to read, so the check is vacuous.
        if (v2Vault <= address(1) && v3Vault <= address(1)) {
            skippedNoBalancer++;
            return;
        }

        if (!_selectFork(chain)) {
            skippedNoRpc++;
            console.log(string.concat("SKIP no RPC for chain: ", chain, " (", path, ")"));
            return;
        }

        filesChecked++;
        AccountantAsset[] memory assets = abi.decode(vm.parseJson(json, ".accountantAssets"), (AccountantAsset[]));
        for (uint256 i; i < assets.length; ++i) {
            address provider = assets[i].rateProvider;
            if (provider == address(0)) continue; // pegged to base, no rate read

            _probe(provider, assets[i].addressOrName.name, path, v2Vault, v3Vault, false);

            // A GenericRateProvider is a pass-through: the rate really comes from target().
            address target = _genericRateProviderTarget(provider);
            if (target != address(0)) {
                _probe(target, assets[i].addressOrName.name, path, v2Vault, v3Vault, true);
            }
        }
    }

    function _probe(
        address candidate,
        string memory assetName,
        string memory path,
        address v2Vault,
        address v3Vault,
        bool viaTarget
    ) internal {
        providersChecked++;
        if (!_isBalancerV2Pool(candidate, v2Vault) && !_isBalancerV3Pool(candidate, v3Vault)) return;

        violations++;
        // Both branches are cast to `string`: a ternary over string literals of different lengths
        // does not typecheck.
        string memory via = viaTarget ? string(" (via GenericRateProvider.target())") : string("");
        console.log(
            string.concat(
                "BALANCER POOL AS RATE SOURCE: ",
                vm.toString(candidate),
                via,
                " asset=",
                assetName,
                " config=",
                path
            )
        );
    }

    /// @dev V2 pools expose getPoolId(); confirm against the Vault so a lookalike cannot trip it.
    function _isBalancerV2Pool(address candidate, address vault) internal view returns (bool) {
        if (vault <= address(1)) return false;

        (bool ok, bytes memory data) = candidate.staticcall(abi.encodeWithSignature("getPoolId()"));
        if (!ok || data.length != 32) return false;
        bytes32 poolId = abi.decode(data, (bytes32));

        (bool vaultOk, bytes memory vaultData) = vault.staticcall(abi.encodeWithSignature("getPool(bytes32)", poolId));
        if (!vaultOk || vaultData.length < 64) return false;
        (address pool,) = abi.decode(vaultData, (address, uint8));
        return pool == candidate;
    }

    /// @dev V3 pools are not self-identifying, so ask the Vault directly.
    function _isBalancerV3Pool(address candidate, address v3Vault) internal view returns (bool) {
        if (v3Vault <= address(1)) return false;

        (bool ok, bytes memory data) =
            v3Vault.staticcall(abi.encodeWithSignature("isPoolRegistered(address)", candidate));
        if (!ok || data.length != 32) return false;
        return abi.decode(data, (bool));
    }

    function _genericRateProviderTarget(address provider) internal view returns (address) {
        (bool ok, bytes memory data) = provider.staticcall(abi.encodeWithSignature("target()"));
        if (!ok || data.length != 32) return address(0);
        return abi.decode(data, (address));
    }

    /// @dev Fork aliases in foundry.toml [rpc_endpoints] use the same names as ChainValues.
    function _selectFork(string memory chain) internal returns (bool) {
        bytes32 key = keccak256(bytes(chain));
        uint256 cached = forkIdPlusOne[key];
        if (cached != 0) {
            vm.selectFork(cached - 1);
            return true;
        }

        try vm.createSelectFork(chain) returns (uint256 forkId) {
            forkIdPlusOne[key] = forkId + 1;
            chainsCovered++;
            if (key == keccak256(bytes(mainnet))) mainnetCovered = true;
            return true;
        } catch {
            return false;
        }
    }

    function _endsWithJson(string memory path) internal pure returns (bool) {
        bytes memory raw = bytes(path);
        if (raw.length < 5) return false;
        return raw[raw.length - 5] == "."
            && raw[raw.length - 4] == "j"
            && raw[raw.length - 3] == "s"
            && raw[raw.length - 2] == "o"
            && raw[raw.length - 1] == "n";
    }
}
