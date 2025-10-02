<span style="color:yellow">yellow</span> = in progress  
<span style="color:blue">blue</span> = we will do this  
<span style="color:gray">gray</span> = won't do  
the rest = undecided yet

## PROPERTIES IDEAS

- <span style="color:yellow">balanceOf[user] cannot decrease if beforeTransferData[user].denyFrom = true;</span>
- <span style="color:yellow">balanceOf[user] cannot increase if beforeTransferData[user].denyTo = true;
- beforeTransferData[user].denyOperator = true && permissionedTransfers => can move balance without owning them (FALSE because from == msg.sender no ?)
- if denyAll && f != (allowAll || allowXXX) => user should not be able to do anything
- if allowAll && f != (denyAll || denyXXX) => user should be able to do anything
- cannot mint more than cap if cap != type(uint112).max
- Boring base should only be able to claimFees on Accountant if not pause or feesOwedInBase != 0
- TellerWithMultiAssetSupport 
    - <span style="color:yellow">deposit nonce always goes up 
    - msg.sender is denied (from from,to and operator) but balance > 0 should not be possible ?
    - if isPaused true , depositNonce cannot increase
    - if isPaused true , no deposit, no withdraw ?
    - <span style="color:blue">if isPause true , publicDepositHistory shouldn't be written
    - if currentShareLockPeriod started at 0 and is == 0 nothing written to publicDepositHistory,beforeTransferData[user] 
    - !(beforeTransferData[from].shareUnlockTime > block.timestamp && transfer)
    - <span style="color:yellow">if cap != type(uint112).max => vault.totalSupply <= cap <= type(uint112).max
    - <span style="color:yellow">deposit and withdraw in favor of protocol 
- PairwiseRateLimiter/LayerZeroTellerWithRateLimiting
    - ∀ eid: rateLimit.lastUpdated ≤ block.timestamp
    - ∀ eid: rateLimit.amountInFlight ≤ rateLimit.limit
    - decay ≤ amountInFlight_stored
    - _amountCanBeSent should return good amount (to develop)
- AccountantWithRateProviders 
    - <span style="color:yellow">highwaterMark >= exchangeRate
    - Performance fees are only charged on new performance above previous peaks
    - <span style="color:yellow"> if no reset, highwaterMark_new ≥ highwaterMark_old
    - <span style="color:gray"> highWaterMark >= currentExchangeRate (duplicate)
    - allowedExchangeRateChangeUpper >= 1e4 && allowedExchangeRateChangeLower <= 1e4
    - <span style="color:blue">highwaterMark ≤ exchangeRate + currentExchangeRate * (allowedExchangeRateChangeUpper / 1e4) : TRUE 
    - if not paused , oldRate * allowedExchangeRateChangeLower / 1e4 <= exchange rate <= oldRate * allowedExchangeRateChangeUpper / 1e4
    - exchangeRateChange => totalSharesLastUpdate ≈ vault.totalSupply() 
    - <span style="color:blue">if exchangeRateChange && newExchangeRate not in bounds => Paused 
    - if (vault.totalSupply() > 0) then totalSharesLastUpdate > 0
        - also other relations? E.g. totalSupply changes => lastUpdate changes?
    - rateProviderData[base].isPeggedToBase == true
    - <span style="color:blue"> rateProvider.getRate() should not revert 
    - decimals == ERC20(_base).decimals()
    - vault cannot change, also other linked contracts
    - platformFees should be temporarily correct (1m passed = 1m * platformFees)
    - <span style="color:blue"> fees decrease (or == 0) only if claimFees is called, i.e. only a single method may decrease fees
- <span style="color:blue">AccountantWithYieldStreaming
    - if vestingGains > 0 => endVestingTime > startVestingTime
    - lastSharePrice > 0
    - cumulativeSupply_new > cumulativeSupply_old
    - updateExchangeRate && (startVestingTime == 0 || endVestingTime > startVestingTime + duration) => vestingGains = 0
    - exchangeRate and lastSharePrice relationship ? 
    - vestingState.lastVestingUpdate == supplyObservation.lastUpdateTimestamp (not true if no vesting period so to fine tune)
    - total vested at any time t should always be initialAmount × (t/totalDuration)
    - if postLost and vestingGains < lossPosted => lastSharePriceBefore >= lastSharePriceAfter 
    - if _updateExchangeRate and newlyVested > 0 => lastSharePriceBefore <= lastSharePriceAfter 
- MessageLib.sol 
    - uint256ToMessage contrary as messageToUint256 
​​
### WHAT SHOULD NOT HAPPEN LIST 
​
1. BoringVault ⇔ TellerWithMultiAssetSupport ⇔ AccountantWithRateProviders
    - <span style="color:blue">Disabling deposits for an asset should NOT affect the ability to refund existing deposits in that asset

2. BoringVault ⇔ TellerWithBuffer ⇔ AccountantWithRateProviders
    - Operations from one asset's buffer helper should NEVER affect the buffer operations or state of other assets => Each asset has independent depositBufferHelper and withdrawBufferHelper configurations (sounds easy)

3. BoringVault ⇔ TellerWithMultiAssetSupport ⇔ AccountantWithYieldStreaming
    - vesting period exploitation prevention: Users could deposit right before large yield vesting completes, then immediately withdraw to capture disproportionate yield => protection with maxDeviationYield i think 
    - lost timing exit: Users could time their exits to occur after losses are absorbed by unvested gains but before they affect share price, avoiding losses that other users bear
        - same with pausing due to too much loss : Users should NEVER be able to coordinate exits with loss posting to avoid taking appropriate losses
    - Multi-timestamp consistency : System tracks: 
        - lastVestingUpdate (only updated if updateExchange rate with newlyVested) 
        - startVestingTime (only updated if vestYield called)
        - endVestingTime (only updated if vestYield called) 
        - supplyObservation.lastUpdateTimestamp (only updated if _updateCumulative and timeElapsed > 0)
        - state.lastUpdateTimestamp  (only updated if _collectFees called )
        - lastStrategistUpdateTimestamp (only updated in vestYield or postLoss || resetHighwaterMark)
    - Users entering/exiting during active vesting periods gains proportionate amount of yield regarding their deposit and current vesting
​
4. BoringVault ⇔ LayerZeroTeller ⇔ x
    - Share prices should NOT become arbitrageable between chains due to rate update propagation delays @sponsor
    - Users should not be able to bypass share lock periods by bridging locked shares to another chain
    - A user should not be able to get their deposit refunded after bridging shares to another chain, even within the lock period 
​
5. BoringVault ⇔ LayerZeroTellerWithRateLimiting ⇔ AccountantWithRateProviders
    - When AccountantWithRateProviders is paused, NO deposit or withdrawal operations should complete, even through bulk functions
​
​
# Manager
- strategist calls should be gated to what is allowed
​
# Teller 
- User is always allowed to deposit/depositWithPermit if not paused, shares minted more than minimumMint and asset supported by Teller
- Shares just minted are locked for share lock period
- Shares can be refunded during share lock period
​
# Accountant 
- Accountant must be paused if 
    - exchange rate updated before enough time passed
    - exchange rate too high 
    - exchange rate too
- Accountant pause => getRateSafe()/getRateInQuoteSafe(ERC20 quote) revert
​
# <span style="color:gray">Atomic Queue OUT OF SCOPE
- <span style="color:gray">If user creates offer that pass deadline => must not be filled
- <span style="color:gray">Offer for `offer` asset must be fulfilled with `want` assets
​
​
## LIVENESS 

- when market conditions are normal and sufficient time has passed, the Accountant must allow exchange rate updates to proceed without triggering a pause state
- valid user deposits with proper asset approvals and within allowed parameters must result in minted vault shares being credited to the user's account
- <span style="color:gray"> valid withdrawal requests submitted through the AtomicQueue must be fulfillable by authorized solvers before their specified deadline
- <span style="color:blue"> user shares locked during the shareLockPeriod must become transferable once the lock period expires and no refund has been processed
- when performance or platform fees are owed and accumulated, the Accountant must allow authorized parties to claim these fees to the designated payout address
- any legitimate rebalancing action that has a valid merkle proof must be executable by authorized strategists when the Manager is not paused
- when anomalous conditions that triggered a pause state are resolved, authorized multisig accounts must be able to unpause the system components
- <span style="color:gray">batched deposit and withdrawal operations submitted to the AtomicQueue must be processable by authorized solvers in accordance with user-specified parameters
- any external protocol interaction with valid calldata must successfully pass through the appropriate DecoderAndSanitizer validation without indefinite blocking.
​
## SAFETY
- <span style="color:blue">exchange rate should never change by more than the configured allowedExchangeRateChangeUpper or allowedExchangeRateChangeLower bounds between updates without triggering a pause
- BoringVault should only execute rebalancing operations when a valid merkle proof is provided that matches the strategist's authorized merkle root
- Locked shares should never be transferable before the shareLockPeriod expires, except through authorized refund mechanisms by permissioned accounts
- <span style="color:blue">Exchange rate updates should never occur more frequently than the minimumUpdateDelayInSeconds without triggering a pause state
- system should only accept deposits and withdrawals for assets that have been explicitly configured with proper rate provider data in the Accountant
- When any core component (Accountant, Manager, or Teller) is paused, the system should never allow operations that could compromise vault integrity or user funds [ TO BE DEFINED CLEARER ]
- Flash loan operations should only be executable within the proper context of an authorized manage call, never from external or unauthorized initiators
- Platform fees should never exceed 0.2e4 (20%) and performance fees should never be calculated on periods longer than intended, ensuring fee calculations remain within expected parameters
- <span style="color:gray">AtomicQueue bulk operations should only be executable by addresses with the proper SOLVER_ROLE authorization, never by unauthorized external accounts