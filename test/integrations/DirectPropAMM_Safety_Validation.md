# DirectPropAMM direct strategist integration safety validation

## Decision

**Conditional go.** Calling a verified, immutable DirectPropAMM directly from the BoringVault is acceptable without BoringSwapper when every activation condition below is met. This approval is specific to the pool's two taker swap selectors and one fixed pool deployment per token pair. It does not approve any pool administration selector.

The direct path is not equivalent to BoringSwapper. It intentionally accepts less defense in depth. In particular, the Merkle root does not impose a volume cap, an independent post-trade price check, or a maximum numeric allowance. Operations must treat those omissions as explicit risk acceptance rather than assume the pool reproduces BoringSwapper controls.

## Authorization boundary

The strategist root permits three call shapes across four leaves:

1. `approve(address,uint256)` on each pair token, with spender fixed to the pool. Two leaves, one per token.
2. `swapExactInput(...)` on the fixed pool, with recipient fixed to the BoringVault.
3. `swapExactOutput(...)` on the fixed pool, with recipient fixed to the BoringVault.

The sanitizer accepts only `customerId = keccak256("VEDA_DIRECT_PROP_AMM")`. This keeps every vault trade on one rounding-credit route instead of letting the strategist fragment across routes. The target pool is fixed by each leaf. The taker is implicitly the BoringVault because `ManagerWithMerkleVerification` executes the call through `BoringVault.manage`.

No owner or guardian pool selector is mirrored. Unsupported selectors revert in `BaseDecoderAndSanitizer` before proof verification.

`CUSTOMER_ID` is a compile-time constant in the decoder. Rotating it requires deploying a new decoder and setting a new root, and it starts a fresh rounding-credit route.

## Scalars the root cannot pin

A Merkle leaf commits to the decoder, the target, the value flag, the selector, and the address arguments the sanitizer returns. It commits to no numeric argument. Every scalar in the taker calldata is therefore strategist-controlled at execution time, with no ceiling:

| Argument | Strategist can submit | Effect |
| --- | --- | --- |
| `minAmountOut` / `maxAmountIn` | `0` / `type(uint256).max` | No slippage bound at all |
| `oraclePriceToleranceBps` | `10000` | Caller price binding becomes +/-100%, i.e. void |
| `minimumOracleUpdatedAt` | `0` | Caller freshness binding void |
| `deadline` | `type(uint256).max` | Calldata never expires |
| `tradeId` | anything | No effect on authorization |

`test/integrations/TempoPropAMMRealFork.t.sol::testRootDoesNotConstrainScalarsSoAnUnboundedSwapStillVerifies` executes exactly that calldata through `manageVaultWithMerkleVerification` and it settles. This is not a defect in the leaves; it is the limit of what a Merkle root can express. Accept it or compensate for it in tooling and monitoring.

With those four bindings voided, the worst case degrades to: **swap at whatever the pool oracle currently says, bounded only by the pool's own `maxOracleAge` and `maxPriceDeviationBps`, and by pool inventory.**

### Blast radius

The pool quotes at the oracle price with no spread and no fee. On a zero-spread venue a wrong price is not a cost of trading, it is a direct transfer. For a trade of notional `N` at a relative price error `e`, the vault loses `e * N`. This is the same adverse-selection exposure recorded as Medium finding #2 of the 2026-08-12 review, reached here through a different route.

Per-trade bound, once caller bindings are void:

```
loss_per_trade  = (maxPriceDeviationBps / 10_000) * N
N_max           = pool inventory of the output token
```

There is no lifetime bound. The directional anchor advances after each accepted trade, so `k` successive trades can walk the price by up to `k * maxPriceDeviationBps` in one direction. The anchor limits the size of a single step, not cumulative drift. Verified against real pool state in `testDirectionalAnchorAdvancesSoDriftIsNotBounded`: two successive 40 bps pushes are each inside a 50 bps guard, yet together they move the anchor 80 bps. Repetition is capped only by `min(vault balance of the input token, pool inventory of the output token)`, because the direct path has no token-bucket rate limit.

Worked example. A pool holding 1,000,000 units of output inventory with `maxPriceDeviationBps = 50` (0.5%) exposes up to 5,000 units per trade, and round-tripping until inventory or vault balance is exhausted compounds from there. Sizing pool inventory *is* sizing the blast radius; treat funded inventory as the risk limit, because nothing else caps it.

Two properties make this hard to detect:

- **The accountant cannot see it.** NAV is marked off the same pushed price the pool trades on. A swap executed at a stale or manipulated oracle price is NAV-neutral at the moment it happens and only surfaces when the accountant's rate provider diverges or the position is unwound elsewhere.
- **A stale price is the dangerous case, not the loud one.** The pool reverts when the oracle is *older* than `maxOracleAge`, but inside that window it trades happily at a price the market has already left behind. On the live configuration that window is 90,000 seconds (25 hours).

By comparison, BoringSwapper would have applied an independent `PriceValidator` check against configured rate providers, an administrative `maxSlippageBpsPerRoute` ceiling the strategist cannot raise, a per-route token bucket, an adapter allowlist with swapper-level pause switches, approvals scoped to the exact swap amount, and a post-swap dust sweep back to the vault. The direct path replaces all of that with strategist discipline plus the manager-level pause and root revocation, and it substitutes the `approve(0) -> approve(amount) -> swap -> approve(0)` batch convention for scoped approvals and the sweep.

## Mandatory strategist-tooling invariants

Because the tree cannot enforce these, they are tooling requirements, and tooling compliance is an activation condition rather than a recommendation.

1. **Quote first, through the route-aware quoter.** Call `quoteExactInputFor` / `quoteExactOutputFor` with `taker = BoringVault`, `recipient = BoringVault`, and the pinned `customerId`. The plain `quoteExactInput(bool,uint256)` / `quoteExactOutput(bool,uint256)` forms ignore the rounding-credit route and will disagree with settlement.
2. **`expectedOraclePrice` = the price the quote returned.** Never invert it. Both swap directions bind against the raw oracle price, so an inverted value in the quote-to-base direction silently widens or voids the binding instead of tightening it.
3. **`oraclePriceToleranceBps` small but nonzero.** Zero reverts on any push-oracle tick between quote and execution, which is not atomic. Nonzero-and-tight is the control; `10000` is the same as having none.
4. **`minimumOracleUpdatedAt` = the `updatedAt` the quote observed.** This is the only binding that rejects execution against an observation older than the one the strategist priced from.
5. **Tight `deadline`.** Seconds, not `type(uint256).max`. Unbounded calldata stays replayable for the life of the root.
6. **Real `minAmountOut` / `maxAmountIn`,** derived from the quote and an explicit slippage budget, never `0` / `type(uint256).max`.
Invariants 1 through 5 are asserted against real pool bytecode in `test/integrations/TempoPropAMMRealFork.t.sol`: `testCompliantToolingFlowSettlesAtTheQuotedPrice` (quote then bind), `testInvertedExpectedOraclePriceBreaksTheBinding` (2), `testCallerPriceBindingRejectsTickBeyondTolerance` / `testCallerPriceBindingAcceptsTickWithinTolerance` / `testZeroToleranceRevertsOnASingleUnitTick` / `testToleranceAboveBpsCeilingReverts` (3), `testMinimumOracleUpdatedAtRejectsAnOlderObservation` (4), and `testExpiredDeadlineReverts` (5).

7. **Handle the reverts quotes do not predict.** Quotes do not check output inventory and do not check pause state, so a quoted trade can still revert on either. Quotes *do* propagate oracle staleness: a quote against a stale oracle reverts with `StaleOraclePrice(updatedAt, maxAge)` rather than returning a usable price, verified against the reviewed pool in `testStaleOracleMakesTheHelperRefuseToQuote`.

Every batch must remain `approve(0) -> approve(requiredAmount) -> swap -> approve(0)` in one manager call. The approval leaf does not constrain the numeric allowance, so a compromised strategist can authorize more than needed. For the reviewed immutable pool bytecode that allowance alone is not spendable asynchronously, because the taker path pulls from `msg.sender` and can therefore only pull vault funds during a vault-initiated pool call. Revisit this conclusion if the pool bytecode or the token transfer semantics change.

## Recipient resolution trust

Settlement pays the raw `recipient` argument, while the pool's exact-delta balance check watches `addressRegistry.resolveRecipient(recipient)`. If those two addresses ever differ, a swap pays one address while the guard inspects another.

The registry is the Tempo predeploy at `0xfDC0000000000000000000000000000000000000`. Both live pools were wired to it at block 36,425,642 (`cast call <pool> "addressRegistry()(address)" --rpc-url https://rpc.tempo.xyz --block 36425642`). `testPoolImplementsReviewedTakerAbi` enforces the same wiring on whatever pool a root is about to ship against.

**Gate:** verify `resolveRecipient(vault) == vault` on the target chain before any root ships. This held for both live vaults as of 2026-08-12 and still holds at the pinned fork block. `testPoolResolvesVaultRecipientToItself` asserts it through the reviewed pool's own `resolveRecipient` view, which is the path settlement actually takes. It is a per-chain, per-vault check, not a one-time one.

## Pool and operations trust

Direct execution adds the pool oracle, pool owner, pool guardian, and the address registry to the vault's trusted operating boundary.

- **Every admin role sits on a single EOA, shared across both live pools:** owner `0xcC4957A13A225eA1BfC85346D48B7de2Cb2cE374` and guardian `0xA8240f16Eb4728bF5b23c4A9fBF96468C266231f` are two distinct keys, each with no code, and both pools return the same pair. The oracle reporter is likewise a single key. Read directly at block 36,425,642 via `owner()` and `guardian()` on both pool addresses; re-check against the pool a root actually ships at, since these are per-deployment facts.
- **The owner can replace the oracle while paused** via `setOracle(address)`, with any oracle of matching decimal precision. Pool ownership and oracle reporting must therefore meet the same security standard as vault administration.
- **The path fails closed, which is an availability risk.** A guardian pause, a revoked taker permission, exhausted inventory, or a stalled reporter makes the atomic strategy call revert. This is the intended direction of failure and it has already happened: at fork block 36,425,642 the pathUSD/PRIME pool's push oracle was last updated at timestamp 1,785,735,555, making it **1,927,044 seconds (22.3 days) stale** against a `maxOracleAge` of 90,000 seconds. The direct path is bricked in that state, with no fallback venue. Read directly from the pool's `oracle()` and that oracle's `updatedAt()` at the pinned block. `testRealPoolRevertsOnStaleOracle` proves the reviewed pool fails the same way.
- **The directional anchor can legitimately brick one direction.** A large genuine price move leaves the anchor behind, and that direction stays unusable until the owner resets it. Plan for one-sided availability.
- **Accountant valuation must stay independent.** The pool oracle does not and must not update BoringVault NAV.
- **Pool configuration changes require pause, review, and a new fork simulation before reactivation.**

## Interaction with the buffer-helper path

`DirectPropAMMBufferHelper` is not ported into this repository. Tests deploy it from the upstream creation bytecode vendored at `test/artifacts/propAMM/DirectPropAMMBufferHelper.json`, so what this memo validates is the contract the propAMM repository actually builds. `TellerWithBuffer` is what executes its output.

The contract at `0xcBc20b5a6553b06A0521395CFD4eB03150F401Cd` is **not** that build. Verified at block 36,425,642: its deployed code is 2,974 bytes against the reviewed build's 3,433, its `pool()` is the ineligible legacy pathUSD/PRIME pool `0x5Be0956E90095F6D255244D15D4C9f973c13954C`, and its `slippageBps()` is 0 (`cast code` / `cast call <helper> "pool()(address)" --rpc-url https://rpc.tempo.xyz --block 36425642`). Like the live pools, it predates the reviewed source; nothing in this memo covers it, and a fresh helper must be deployed alongside any fresh pool.

It is a strictly narrower path than the strategist root, and the difference matters:

- It builds calldata only. It holds no tokens and has no authority over the vault or the pool.
- Recipient is pinned to the vault and customer ID to an immutable, so a teller batch cannot be steered to another address or another rounding-credit route.
- Slippage is an immutable checked against a `MAX_SLIPPAGE_BPS` ceiling of 1000 at construction. Unlike the strategist path, this numeric bound cannot be raised after deployment.
- `deadline` is `block.timestamp` and `oraclePriceToleranceBps` is 0, so a batch is valid only in the block that produced it. That is safe because the teller call is atomic, and it is exactly why the strategist path needs a nonzero tolerance instead.
- It quotes with `quoteExactInput` / `quoteExactOutput`, which ignore the rounding-credit route. Verified in `testPlainQuoteIsConservativeVersusTheRouteAwareQuote`: the route-aware quote pays at least as much on the way in and asks at most as much on the way out, so the plain quote is a conservative bound in both directions.
- A stale pool oracle makes the helper refuse to quote at all, so the teller fails closed with the pool.

If the direct path and the buffer-helper path are both live on one vault, they are not independent:

- They draw on the **same pool inventory**, so one can exhaust the other.
- They share the **same rounding-credit route** whenever they use the same `customerId`. Use distinct customer IDs unless shared credit accounting is intended.
- **Either path advances the directional anchor**, so one path's trades change the deviation headroom available to the other.

Rate limits, monitoring, and inventory sizing must be reasoned about across both paths together, never per path.

## Controls retained by the direct path

### Merkle and vault controls

- Pool address fixed as the call target.
- Selector restricted to exact-input or exact-output swap.
- Recipient fixed to the BoringVault.
- Input-token approval spender fixed to the pool.
- Taker fixed implicitly to the BoringVault execution context.
- Customer ID fixed by the sanitizer.
- Manager-level pause and root revocation remain available.

### DirectPropAMM execution controls

The reviewed pool source enforces allowed taker and resolved-recipient mappings, deadline expiry, oracle freshness through `maxOracleAge`, a directional deviation check against the last accepted anchor, caller price and observation binding through `expectedOraclePrice` / `oraclePriceToleranceBps` / `minimumOracleUpdatedAt`, exact-input minimum output and exact-output maximum input bounds, available output inventory, exact pool and recipient balance deltas that reject fee-on-transfer behavior, a transient reentrancy guard, and rounding credit isolated by `keccak256(taker, resolvedRecipient, customerId)`.

These validate execution against the pool oracle. They do not provide an independent valuation check. As set out above, the four caller-binding arguments are strategist-chosen and therefore protect an honest strategist from stale or changed execution; they are not governance policy limits against a compromised key.

## Deployment gate

**Neither currently live pool is eligible.** Verified onchain at block 36,425,642:

| Pool | Address | Pair | Status |
| --- | --- | --- | --- |
| pathUSD/PRIME | 0x5Be0956E90095F6D255244D15D4C9f973c13954C | base 0x20C00000000000000000000058d0B8b2CFDb358c / quote 0x20C0000000000000000000000000000000000000 | Ineligible |
| USDCE/PRIME | 0x360d3b2f751247BAc6eda73876F067aEB46E6397 | base 0x20C00000000000000000000058d0B8b2CFDb358c / quote 0x20C000000000000000000000b9537d11c60E8b50 | Ineligible |

Both predate the reviewed source. Confirmed by direct bytecode and view inspection at the pinned block, scanning each dispatcher for the selector as a `PUSH4` immediate rather than probing by `staticcall`, which cannot distinguish an absent function from a guard reverting without data:

- **No rounding-credit ledger** (`roundingCredit(bytes32)` absent) and **no directional deviation guard** (`maxPriceDeviationBps()` absent).
- **A six-argument taker ABI**, not the reviewed ten-argument one:
  - live: `swapExactInput(bool,uint256,uint256,address,bytes32,bytes32)` = `0x096da718`, `swapExactOutput(...)` = `0x17031cd2`
  - reviewed: `swapExactInput(bool,uint256,uint256,address,bytes32,bytes32,uint256,uint256,uint256,uint256)` = `0x187fe9be`, `swapExactOutput(...)` = `0x8b6d66da`
  - The four caller-binding arguments do not exist on the live pools at all. Neither reviewed selector appears in any deployed bytecode.

The pool repository is also pre-audit. Before setting a root:

1. Deploy the pool from the reviewed current DirectPropAMM source.
2. Verify source, constructor arguments, immutable pair, oracle, address registry, owner, guardian, **deployed bytecode**, and non-upgradeability.
3. Run `DIRECT_PROP_AMM_POOL=0x... FOUNDRY_PROFILE=tempo forge test --match-test ReviewedTakerAbi` and require a pass. It asserts the reviewed selectors are present in the deployed dispatcher, the legacy ABI is gone, the registry is canonical, and both the deviation guard and the rounding-credit ledger exist. Unset, the same test runs against the vendored artifact, so it is a standing CI check as well as the gate.
4. Verify `resolveRecipient(vault) == vault` for the target vault on the target chain.
5. Configure only the intended BoringVault as taker and resolved recipient.
6. Set and verify `maxOracleAge` and directional `maxPriceDeviationBps` under the approved risk policy. Size both against the blast-radius formula above, not by convention.
7. Fund deliberately bounded two-sided inventory, understanding that inventory is the loss ceiling.
8. Deploy a decoder containing the fixed customer ID used by strategist calldata.
9. Add the leaves to the adopting vault's own root script via `_addDirectPropAMMLeafs`, with the exact pool, pair-token, BoringVault, and decoder addresses. There is deliberately no standalone generator: a root is per vault and must carry all of that vault's permissions in one tree, so a four-leaf tree set on a live vault would revoke everything else.
10. Run the Tempo fork suite against that source revision and deployment configuration.
11. Rehearse `approve(0) -> approve(amount) -> swap -> approve(0)` in both directions and verify zero residual allowances.
12. Certify strategist tooling against every invariant in "Mandatory strategist-tooling invariants", including the inverted-price case.
13. Confirm manager and pool pause procedures, oracle-staleness monitoring, and emergency ownership paths before unpausing.

The direct path is not acceptable if an independent onchain rate-provider check or an enforced flow-rate cap is required by the vault's mandate. In that case keep BoringSwapper in the path or add equivalent controls before activation.

## Validation evidence

Two suites, 51 tests, run under `FOUNDRY_PROFILE=tempo` on a Tempo fork. No pool behavior is mocked anywhere, and nothing skips.

`test/integrations/TempoPropAMMRealFork.t.sol` is the primary evidence: 36 tests driving the real `DirectPropAMM` and the real `PushPriceOracle`, deployed on the fork from bytecode compiled out of the propAMM repository (`test/artifacts/propAMM/DirectPropAMM.json`, `test/artifacts/propAMM/PushPriceOracle.json`; solc 0.8.30, via_ir, cancun, optimizer 200 runs). The artifacts are vendored as bytecode rather than source because this repository is pinned to solc 0.8.21 and the pool requires 0.8.30 plus `ReentrancyGuardTransient`. The compiled bytecode's taker selectors are `0x187fe9be` and `0x8b6d66da`, matching the pinned values exactly.

Everything else in that suite is live Tempo state: the TIP-20 PRIME and pathUSD tokens, the address registry predeploy, and the balances the swaps move. The BoringVault, RolesAuthority, ManagerWithMerkleVerification, and decoder are deployed fresh, because those are the contracts under test, and the leaves come from the production `_addDirectPropAMMLeafs` helper unchanged. Coverage: both swap directions and exact-output through `manageVaultWithMerkleVerification`, quote-versus-settlement equality via `quoteExactInputFor`, a round trip losing only rounding, rounding-credit accrual on the vault route, all five caller-binding invariants, the pool's own guards (stale oracle, directional anchor deviation, slippage, output inventory, pause, revoked taker permission), recipient resolution through the pool's own view, four proof-rejection cases, the decoder fallback, both customer-ID rejections, and the unbounded-scalar case.

Two of those tests guard the ABI rather than the behavior. `testPinnedSelectorsMatchInterfaceAndLeafSignatures` ties `IDirectPropAMM`, the decoder mirror, and the leaf signature strings to one pair of pinned selectors: the leaf is a string literal in `MerkleTreeHelper` with no compiler link to the interface, so drift between them would otherwise surface only as dead calldata at strategist execution time. `testPoolImplementsReviewedTakerAbi` pins the deployed dispatcher, described in the deployment gate above.

`test/integrations/TempoPropAMMBufferHelper.t.sol` covers the teller path against the same real pool and oracle: 15 tests over constructor validation (zero addresses, zero customer ID, the `MAX_SLIPPAGE_BPS` ceiling, pair read back from the pool), the `approve(0) -> approve(amount) -> swap -> approve(0)` batch shape in both directions, recipient and customer-ID pinning, withdrawal sizing to the shortfall only, the empty-batch case when the vault already holds enough quote token, single-block deadlines, conservatism of the plain quote against the route-aware quote, and fail-closed behavior on a stale oracle. Each test asserts the batch the helper returns and then executes it through `BoringVault.manage`, which is what `TellerWithBuffer` does with it.

An earlier third suite asserted properties of the two deployed six-argument pools at the pinned block. It was removed: pinned chain state is immutable, so those assertions could not regress, and they describe pools this integration does not target. The findings they recorded are stated above as observations with the commands to reproduce them. The one guard worth keeping, selector pinning, moved into the RealFork suite.

The remaining gap is deployment, not behavior: these tests prove the reviewed source behaves as this memo describes and that our leaves drive it correctly, but no pool built from that source exists onchain yet. Verifying deployed bytecode against the reviewed build stays an activation step.
