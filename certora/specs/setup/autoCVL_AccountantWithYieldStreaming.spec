import "dispatching_AccountantWithYieldStreaming.spec";

/*
 * yieldAmount <= 0 => revert
 *
 * What it means: The function must revert when yieldAmount is zero or negative
 *
 * Why it should hold: Based on the error AccountantWithYieldStreaming__ZeroYieldUpdate in the contract and the principle that no-op operations should revert. Vesting zero or negative yield serves no meaningful purpose and could indicate an error condition.
 *
 * Possible consequences: State corruption, gas waste, and potential manipulation of vesting schedules without actual yield being added
 */
rule vestYield_ec0f6e8e_zero_or_negative_yield_reverts(env e) {
    uint256 yieldAmount;
    uint256 duration;

    // assign all the 'before' variables

    // call function under test
    vestYield@withrevert(e, yieldAmount, duration);
    bool vestYield_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((yieldAmount <= 0) => vestYield_reverted), "yieldAmount <= 0 => revert";
}

/*
 * duration < minimumVestingTime@before || duration > maximumVestingTime@before => revert
 *
 * What it means: The function must revert when duration is outside the valid range defined by minimumVestingTime and maximumVestingTime
 *
 * Why it should hold: The contract has explicit bounds checking with errors AccountantWithYieldStreaming__DurationExceedsMaximum and AccountantWithYieldStreaming__DurationUnderMinimum, indicating these are critical validation requirements
 *
 * Possible consequences: Yield vesting periods that are too short could cause excessive gas costs from frequent updates, while periods too long could lock yield for unreasonable timeframes
 */
rule vestYield_ec0f6e8e_invalid_duration_reverts(env e) {
    uint256 yieldAmount;
    uint256 duration;

    // assign all the 'before' variables
    uint256 currentContract_minimumVestingTime_before = currentContract.minimumVestingTime;
    uint256 currentContract_maximumVestingTime_before = currentContract.maximumVestingTime;

    // call function under test
    vestYield@withrevert(e, yieldAmount, duration);
    bool vestYield_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((duration < currentContract_minimumVestingTime_before) || (duration > currentContract_maximumVestingTime_before)) => vestYield_reverted), "duration < minimumVestingTime@before || duration > maximumVestingTime@before => revert";
}

/*
 * yieldAmount > 0 && duration >= minimumVestingTime@before && duration <= maximumVestingTime@before => vestingState.vestingGains@after == vestingState.vestingGains@before + yieldAmount
 *
 * What it means: For valid inputs, the vestingGains should increase by exactly the yieldAmount
 *
 * Why it should hold: This is the core functionality of vestYield - it should accumulate the new yield amount into the total pending vesting gains that will be distributed over time
 *
 * Possible consequences: Incorrect yield accounting could lead to users receiving more or less yield than they're entitled to, breaking the economic model
 */
rule vestYield_ec0f6e8e_updates_vesting_gains(env e) {
    uint256 yieldAmount;
    uint256 duration;

    // assign all the 'before' variables
    uint256 currentContract_minimumVestingTime_before = currentContract.minimumVestingTime;
    uint256 currentContract_maximumVestingTime_before = currentContract.maximumVestingTime;
    uint128 currentContract_vestingState_vestingGains_before = currentContract.vestingState.vestingGains;

    // call function under test
    vestYield(e, yieldAmount, duration);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_vestingGains_after = currentContract.vestingState.vestingGains;

    // verify integrity
    assert ((((yieldAmount > 0) && (duration >= currentContract_minimumVestingTime_before)) && (duration <= currentContract_maximumVestingTime_before)) => (currentContract_vestingState_vestingGains_after == currentContract_vestingState_vestingGains_before + yieldAmount)), "yieldAmount > 0 && duration >= minimumVestingTime@before && duration <= maximumVestingTime@before => vestingState.vestingGains@after == vestingState.vestingGains@before + yieldAmount";
}

/*
 * yieldAmount > 0 && duration >= minimumVestingTime@before && duration <= maximumVestingTime@before => vestingState.startVestingTime@after == block.timestamp
 *
 * What it means: For valid inputs, the startVestingTime should be set to the current block timestamp
 *
 * Why it should hold: Each new yield vesting period should start from the current moment to ensure proper linear vesting calculations in getPendingVestingGains()
 *
 * Possible consequences: Incorrect start times could cause yield to vest too quickly or too slowly, disrupting the intended distribution schedule
 */
rule vestYield_ec0f6e8e_updates_start_time(env e) {
    uint256 yieldAmount;
    uint256 duration;

    // assign all the 'before' variables
    uint256 currentContract_minimumVestingTime_before = currentContract.minimumVestingTime;
    uint256 currentContract_maximumVestingTime_before = currentContract.maximumVestingTime;

    // call function under test
    vestYield(e, yieldAmount, duration);

    // assign all the 'after' variables
    uint64 currentContract_vestingState_startVestingTime_after = currentContract.vestingState.startVestingTime;

    // verify integrity
    assert ((((yieldAmount > 0) && (duration >= currentContract_minimumVestingTime_before)) && (duration <= currentContract_maximumVestingTime_before)) => (currentContract_vestingState_startVestingTime_after == e.block.timestamp)), "yieldAmount > 0 && duration >= minimumVestingTime@before && duration <= maximumVestingTime@before => vestingState.startVestingTime@after == block.timestamp";
}

/*
 * yieldAmount > 0 && duration >= minimumVestingTime@before && duration <= maximumVestingTime@before => vestingState.endVestingTime@after == block.timestamp + duration
 *
 * What it means: For valid inputs, the endVestingTime should be set to current timestamp plus the duration
 *
 * Why it should hold: The end time defines when all yield will be fully vested and is critical for the linear interpolation in getPendingVestingGains()
 *
 * Possible consequences: Wrong end times would cause yield to vest over incorrect periods, potentially making yield available too early or too late
 */
rule vestYield_ec0f6e8e_updates_end_time(env e) {
    uint256 yieldAmount;
    uint256 duration;

    // assign all the 'before' variables
    uint256 currentContract_minimumVestingTime_before = currentContract.minimumVestingTime;
    uint256 currentContract_maximumVestingTime_before = currentContract.maximumVestingTime;

    // call function under test
    vestYield(e, yieldAmount, duration);

    // assign all the 'after' variables
    uint64 currentContract_vestingState_endVestingTime_after = currentContract.vestingState.endVestingTime;

    // verify integrity
    assert ((((yieldAmount > 0) && (duration >= currentContract_minimumVestingTime_before)) && (duration <= currentContract_maximumVestingTime_before)) => (currentContract_vestingState_endVestingTime_after == e.block.timestamp + duration)), "yieldAmount > 0 && duration >= minimumVestingTime@before && duration <= maximumVestingTime@before => vestingState.endVestingTime@after == block.timestamp + duration";
}

/*
 * yieldAmount > 0 && duration >= minimumVestingTime@before && duration <= maximumVestingTime@before => vestingState.lastVestingUpdate@after == block.timestamp
 *
 * What it means: For valid inputs, the lastVestingUpdate should be set to the current block timestamp
 *
 * Why it should hold: This timestamp is used in getPendingVestingGains() to calculate how much time has passed since the last update, ensuring accurate vesting calculations
 *
 * Possible consequences: Incorrect lastVestingUpdate could cause vesting calculations to be wrong, leading to over or under-distribution of yield
 */
rule vestYield_ec0f6e8e_updates_last_vesting(env e) {
    uint256 yieldAmount;
    uint256 duration;

    // assign all the 'before' variables
    uint256 currentContract_minimumVestingTime_before = currentContract.minimumVestingTime;
    uint256 currentContract_maximumVestingTime_before = currentContract.maximumVestingTime;

    // call function under test
    vestYield(e, yieldAmount, duration);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_lastVestingUpdate_after = currentContract.vestingState.lastVestingUpdate;

    // verify integrity
    assert ((((yieldAmount > 0) && (duration >= currentContract_minimumVestingTime_before)) && (duration <= currentContract_maximumVestingTime_before)) => (currentContract_vestingState_lastVestingUpdate_after == e.block.timestamp)), "yieldAmount > 0 && duration >= minimumVestingTime@before && duration <= maximumVestingTime@before => vestingState.lastVestingUpdate@after == block.timestamp";
}

/*
 * vestingState.lastSharePrice@after == vestingState.lastSharePrice@before
 *
 * What it means: The lastSharePrice should remain unchanged during vestYield execution
 *
 * Why it should hold: vestYield only adds pending yield to be vested over time, it shouldn't immediately affect the current share price. The share price should only change when updateExchangeRate() is called to move vested gains into the price
 *
 * Possible consequences: Premature share price updates could cause accounting inconsistencies and incorrect fee calculations
 */
rule vestYield_ec0f6e8e_preserves_last_share_price(env e) {
    uint256 yieldAmount;
    uint256 duration;

    // assign all the 'before' variables
    uint128 currentContract_vestingState_lastSharePrice_before = currentContract.vestingState.lastSharePrice;

    // call function under test
    vestYield(e, yieldAmount, duration);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_lastSharePrice_after = currentContract.vestingState.lastSharePrice;

    // verify integrity
    assert (currentContract_vestingState_lastSharePrice_after == currentContract_vestingState_lastSharePrice_before), "vestingState.lastSharePrice@after == vestingState.lastSharePrice@before";
}

/*
 * lossAmount == 0 => revert
 *
 * What it means: The function must revert when lossAmount is zero, preventing meaningless no-op operations
 *
 * Why it should hold: Based on the contract pattern where vestYield reverts on zero amounts, and the function should only be called when there's actual loss to record. Empty function body suggests it should validate inputs and revert on invalid ones
 *
 * Possible consequences: Gas waste, misleading events, state inconsistency where zero losses are recorded as valid operations
 */
rule postLoss_57545af7_zero_loss_reverts(env e) {
    uint256 lossAmount;

    // assign all the 'before' variables

    // call function under test
    postLoss@withrevert(e, lossAmount);
    bool postLoss_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((lossAmount == 0) => postLoss_reverted), "lossAmount == 0 => revert";
}

/*
 * lossAmount > totalAssets()@before => revert
 *
 * What it means: The function must revert if the loss amount exceeds the total assets available in the vault
 *
 * Why it should hold: A loss cannot be greater than the total assets in the vault - this would be mathematically impossible and indicates either a calculation error or malicious input
 *
 * Possible consequences: Arithmetic underflow, negative share prices, vault insolvency, complete breakdown of the accounting system
 */
rule postLoss_57545af7_loss_exceeds_assets_reverts(env e) {
    uint256 lossAmount;

    // assign all the 'before' variables
    uint256 totalAssets_e__before = totalAssets(e);

    // call function under test
    postLoss@withrevert(e, lossAmount);
    bool postLoss_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((lossAmount > totalAssets_e__before) => postLoss_reverted), "lossAmount > totalAssets()@before => revert";
}

/*
 * lossAmount > 0 && lossAmount <= totalAssets()@before => vestingState.lastSharePrice@after < vestingState.lastSharePrice@before
 *
 * What it means: When recording a valid loss, the share price (lastSharePrice) must decrease from its previous value
 *
 * Why it should hold: Losses should reduce the value per share since the same number of shares now represent fewer underlying assets. This is fundamental to proper accounting
 *
 * Possible consequences: Incorrect share valuations, users not bearing their fair share of losses, arbitrage opportunities
 */
rule postLoss_57545af7_updates_exchange_rate(env e) {
    uint256 lossAmount;

    // assign all the 'before' variables
    uint256 totalAssets_e__before = totalAssets(e);
    uint128 currentContract_vestingState_lastSharePrice_before = currentContract.vestingState.lastSharePrice;

    // call function under test
    postLoss(e, lossAmount);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_lastSharePrice_after = currentContract.vestingState.lastSharePrice;

    // verify integrity
    assert (((lossAmount > 0) && (lossAmount <= totalAssets_e__before)) => (currentContract_vestingState_lastSharePrice_after < currentContract_vestingState_lastSharePrice_before)), "lossAmount > 0 && lossAmount <= totalAssets()@before => vestingState.lastSharePrice@after < vestingState.lastSharePrice@before";
}

/*
 * lossAmount > 0 && lossAmount <= totalAssets()@before => vestingState.lastSharePrice@after == ((totalAssets()@before - lossAmount) * (10^decimals)) / vault.totalSupply()@before
 *
 * What it means: The new share price must equal the reduced total assets (original assets minus loss) divided by total shares outstanding
 *
 * Why it should hold: This is the correct mathematical formula for share price after accounting for losses, ensuring accurate valuation of each share
 *
 * Possible consequences: Incorrect share pricing, value extraction, unfair distribution of losses among shareholders
 */
rule postLoss_57545af7_decreases_share_price(env e) {
    uint256 lossAmount;

    // assign all the 'before' variables
    uint256 totalAssets_e__before = totalAssets(e);
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);

    // call function under test
    postLoss(e, lossAmount);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_lastSharePrice_after = currentContract.vestingState.lastSharePrice;

    // verify integrity
    assert (((lossAmount > 0) && (lossAmount <= totalAssets_e__before)) => (currentContract_vestingState_lastSharePrice_after == totalAssets_e__before - lossAmount * 10 ^ currentContract.decimals / currentContract_vault_totalSupply_e__before)), "lossAmount > 0 && lossAmount <= totalAssets()@before => vestingState.lastSharePrice@after == ((totalAssets()@before - lossAmount) * (10^decimals)) / vault.totalSupply()@before";
}

/*
 * lossAmount > 0 => vestingState.vestingGains@after == 0
 *
 * What it means: When recording a loss, any pending vesting gains should be cleared (set to zero)
 *
 * Why it should hold: Losses should offset or eliminate pending gains since they represent negative performance that contradicts the positive yield being vested
 *
 * Possible consequences: Double counting of gains, inflated share prices, users receiving yield that doesn't exist
 */
rule postLoss_57545af7_clears_vesting_gains(env e) {
    uint256 lossAmount;

    // assign all the 'before' variables

    // call function under test
    postLoss(e, lossAmount);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_vestingGains_after = currentContract.vestingState.vestingGains;

    // verify integrity
    assert ((lossAmount > 0) => (currentContract_vestingState_vestingGains_after == 0)), "lossAmount > 0 => vestingState.vestingGains@after == 0";
}

/*
 * lossAmount > 0 && lossAmount <= totalAssets()@before => vestingState.lastVestingUpdate@after == block.timestamp
 *
 * What it means: The lastVestingUpdate timestamp should be set to the current block timestamp when recording a valid loss
 *
 * Why it should hold: This resets the vesting timeline and ensures future vesting calculations start from the loss recording time, preventing incorrect yield calculations
 *
 * Possible consequences: Incorrect yield vesting calculations, temporal arbitrage opportunities, accounting inconsistencies
 */
rule postLoss_57545af7_updates_vesting_timestamp(env e) {
    uint256 lossAmount;

    // assign all the 'before' variables
    uint256 totalAssets_e__before = totalAssets(e);

    // call function under test
    postLoss(e, lossAmount);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_lastVestingUpdate_after = currentContract.vestingState.lastVestingUpdate;

    // verify integrity
    assert (((lossAmount > 0) && (lossAmount <= totalAssets_e__before)) => (currentContract_vestingState_lastVestingUpdate_after == e.block.timestamp)), "lossAmount > 0 && lossAmount <= totalAssets()@before => vestingState.lastVestingUpdate@after == block.timestamp";
}

/*
 * accountantState.isPaused@before => revert
 *
 * What it means: The function must revert if the accountant contract is in a paused state
 *
 * Why it should hold: Following the contract's pause mechanism pattern seen in other functions - when paused, state-changing operations should be blocked for security
 *
 * Possible consequences: Unauthorized state changes during emergency situations, bypassing of security controls
 */
rule postLoss_57545af7_paused_reverts(env e) {
    uint256 lossAmount;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;

    // call function under test
    postLoss@withrevert(e, lossAmount);
    bool postLoss_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (currentContract_accountantState_isPaused_before => postLoss_reverted), "accountantState.isPaused@before => revert";
}

/*
 * vault.totalSupply()@before == 0 => revert
 *
 * What it means: The function must revert if there are no shares outstanding in the vault
 *
 * Why it should hold: Cannot calculate meaningful share price changes when there are no shares - division by zero would occur in price calculations
 *
 * Possible consequences: Division by zero errors, contract failure, undefined behavior in share price calculations
 */
rule postLoss_57545af7_zero_supply_reverts(env e) {
    uint256 lossAmount;

    // assign all the 'before' variables
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);

    // call function under test
    postLoss@withrevert(e, lossAmount);
    bool postLoss_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_vault_totalSupply_e__before == 0) => postLoss_reverted), "vault.totalSupply()@before == 0 => revert";
}

/*
 * lossAmount > 0 && lossAmount <= totalAssets()@before => vestingState.startVestingTime@after == vestingState.startVestingTime@before && vestingState.endVestingTime@after == vestingState.endVestingTime@before
 *
 * What it means: The start and end vesting times should remain unchanged when recording a loss
 *
 * Why it should hold: Loss recording shouldn't affect the timing parameters of existing vesting schedules - only the amounts and update timestamps should change
 *
 * Possible consequences: Disruption of vesting schedules, incorrect yield distribution timing, temporal manipulation of rewards
 */
rule postLoss_57545af7_preserves_vesting_times(env e) {
    uint256 lossAmount;

    // assign all the 'before' variables
    uint256 totalAssets_e__before = totalAssets(e);
    uint64 currentContract_vestingState_startVestingTime_before = currentContract.vestingState.startVestingTime;
    uint64 currentContract_vestingState_endVestingTime_before = currentContract.vestingState.endVestingTime;

    // call function under test
    postLoss(e, lossAmount);

    // assign all the 'after' variables
    uint64 currentContract_vestingState_startVestingTime_after = currentContract.vestingState.startVestingTime;
    uint64 currentContract_vestingState_endVestingTime_after = currentContract.vestingState.endVestingTime;

    // verify integrity
    assert (((lossAmount > 0) && (lossAmount <= totalAssets_e__before)) => ((currentContract_vestingState_startVestingTime_after == currentContract_vestingState_startVestingTime_before) && (currentContract_vestingState_endVestingTime_after == currentContract_vestingState_endVestingTime_before))), "lossAmount > 0 && lossAmount <= totalAssets()@before => vestingState.startVestingTime@after == vestingState.startVestingTime@before && vestingState.endVestingTime@after == vestingState.endVestingTime@before";
}

/*
 * vestingState.lastSharePrice@after >= vestingState.lastSharePrice@before
 *
 * What it means: The last share price in vestingState must increase or stay the same after calling updateExchangeRate
 *
 * Why it should hold: The function is designed to move vested gains into the share price calculation. Since gains are positive yield, the share price should never decrease when vesting gains are applied
 *
 * Possible consequences: Share price manipulation, incorrect valuation of vault shares, potential fund loss for users
 */
rule updateExchangeRate_02ce728f_updates_last_share_price(env e) {

    // assign all the 'before' variables
    uint128 currentContract_vestingState_lastSharePrice_before = currentContract.vestingState.lastSharePrice;

    // call function under test
    updateExchangeRate(e);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_lastSharePrice_after = currentContract.vestingState.lastSharePrice;

    // verify integrity
    assert (currentContract_vestingState_lastSharePrice_after >= currentContract_vestingState_lastSharePrice_before), "vestingState.lastSharePrice@after >= vestingState.lastSharePrice@before";
}

/*
 * vestingState.vestingGains@before > 0 => vestingState.vestingGains@after <= vestingState.vestingGains@before
 *
 * What it means: If there were vesting gains before the call, the amount of unvested gains must decrease or become zero after the call
 *
 * Why it should hold: The function moves vested gains from the vestingGains storage into the share price calculation. As time passes and gains vest, the unvested portion should decrease
 *
 * Possible consequences: Incorrect yield distribution, double-counting of gains, inflation of vault value
 */
rule updateExchangeRate_02ce728f_reduces_vesting_gains(env e) {

    // assign all the 'before' variables
    uint128 currentContract_vestingState_vestingGains_before = currentContract.vestingState.vestingGains;

    // call function under test
    updateExchangeRate(e);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_vestingGains_after = currentContract.vestingState.vestingGains;

    // verify integrity
    assert ((currentContract_vestingState_vestingGains_before > 0) => (currentContract_vestingState_vestingGains_after <= currentContract_vestingState_vestingGains_before)), "vestingState.vestingGains@before > 0 => vestingState.vestingGains@after <= vestingState.vestingGains@before";
}

/*
 * vestingState.lastVestingUpdate@after == block.timestamp
 *
 * What it means: The lastVestingUpdate timestamp in vestingState must be set to the current block timestamp after the function executes
 *
 * Why it should hold: This timestamp tracks when vesting calculations were last performed, which is crucial for linear vesting math in subsequent calls
 *
 * Possible consequences: Incorrect vesting calculations, potential for gaming vesting schedules, yield distribution errors
 */
rule updateExchangeRate_02ce728f_updates_last_vesting_update(env e) {

    // assign all the 'before' variables

    // call function under test
    updateExchangeRate(e);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_lastVestingUpdate_after = currentContract.vestingState.lastVestingUpdate;

    // verify integrity
    assert (currentContract_vestingState_lastVestingUpdate_after == e.block.timestamp), "vestingState.lastVestingUpdate@after == block.timestamp";
}

/*
 * vestingState.vestingGains@before == 0 => vestingState.lastSharePrice@after == vestingState.lastSharePrice@before
 *
 * What it means: If there are no vesting gains to process, the share price should remain unchanged
 *
 * Why it should hold: When vestingGains is zero, there's no yield to vest into the share price, so the price should stay constant to maintain accurate valuation
 *
 * Possible consequences: Artificial price movements, incorrect share valuations, potential arbitrage opportunities
 */
rule updateExchangeRate_02ce728f_no_change_when_no_gains(env e) {

    // assign all the 'before' variables
    uint128 currentContract_vestingState_vestingGains_before = currentContract.vestingState.vestingGains;
    uint128 currentContract_vestingState_lastSharePrice_before = currentContract.vestingState.lastSharePrice;

    // call function under test
    updateExchangeRate(e);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_lastSharePrice_after = currentContract.vestingState.lastSharePrice;

    // verify integrity
    assert ((currentContract_vestingState_vestingGains_before == 0) => (currentContract_vestingState_lastSharePrice_after == currentContract_vestingState_lastSharePrice_before)), "vestingState.vestingGains@before == 0 => vestingState.lastSharePrice@after == vestingState.lastSharePrice@before";
}

/*
 * vestingState.startVestingTime@after == vestingState.startVestingTime@before && vestingState.endVestingTime@after == vestingState.endVestingTime@before
 *
 * What it means: The start and end times for the current vesting period must remain unchanged after the function call
 *
 * Why it should hold: These timestamps define the vesting schedule boundaries and should only be modified when new yield is posted via vestYield, not during routine vesting updates
 *
 * Possible consequences: Vesting schedule manipulation, incorrect yield distribution timing, potential for extending or shortening vesting periods
 */
rule updateExchangeRate_02ce728f_preserves_vesting_times(env e) {

    // assign all the 'before' variables
    uint64 currentContract_vestingState_startVestingTime_before = currentContract.vestingState.startVestingTime;
    uint64 currentContract_vestingState_endVestingTime_before = currentContract.vestingState.endVestingTime;

    // call function under test
    updateExchangeRate(e);

    // assign all the 'after' variables
    uint64 currentContract_vestingState_startVestingTime_after = currentContract.vestingState.startVestingTime;
    uint64 currentContract_vestingState_endVestingTime_after = currentContract.vestingState.endVestingTime;

    // verify integrity
    assert ((currentContract_vestingState_startVestingTime_after == currentContract_vestingState_startVestingTime_before) && (currentContract_vestingState_endVestingTime_after == currentContract_vestingState_endVestingTime_before)), "vestingState.startVestingTime@after == vestingState.startVestingTime@before && vestingState.endVestingTime@after == vestingState.endVestingTime@before";
}

/*
 * accountantState.exchangeRate@after == vestingState.lastSharePrice@after
 *
 * What it means: The exchange rate in accountantState must be synchronized with the updated lastSharePrice after the function executes
 *
 * Why it should hold: The accountant's exchange rate must reflect the current share price including any newly vested gains to maintain consistency across the system
 *
 * Possible consequences: Desynchronization between pricing systems, incorrect fee calculations, arbitrage opportunities
 */
rule updateExchangeRate_02ce728f_updates_exchange_rate(env e) {

    // assign all the 'before' variables

    // call function under test
    updateExchangeRate(e);

    // assign all the 'after' variables
    uint96 currentContract_accountantState_exchangeRate_after = currentContract.accountantState.exchangeRate;
    uint128 currentContract_vestingState_lastSharePrice_after = currentContract.vestingState.lastSharePrice;

    // verify integrity
    assert (currentContract_accountantState_exchangeRate_after == currentContract_vestingState_lastSharePrice_after), "accountantState.exchangeRate@after == vestingState.lastSharePrice@after";
}

/*
 * accountantState.lastUpdateTimestamp@after == block.timestamp
 *
 * What it means: The accountant's last update timestamp must be set to the current block timestamp
 *
 * Why it should hold: This timestamp is used for fee calculations and rate limiting, so it must be current to prevent manipulation of time-based logic
 *
 * Possible consequences: Fee calculation errors, bypass of rate limiting mechanisms, temporal manipulation attacks
 */
rule updateExchangeRate_02ce728f_updates_accountant_timestamp(env e) {

    // assign all the 'before' variables

    // call function under test
    updateExchangeRate(e);

    // assign all the 'after' variables
    uint64 currentContract_accountantState_lastUpdateTimestamp_after = currentContract.accountantState.lastUpdateTimestamp;

    // verify integrity
    assert (currentContract_accountantState_lastUpdateTimestamp_after == e.block.timestamp), "accountantState.lastUpdateTimestamp@after == block.timestamp";
}

/*
 * block.timestamp >= vestingState.endVestingTime@before => vestingState.vestingGains@after == 0
 *
 * What it means: If the current time is past the vesting end time, all remaining vesting gains must be fully vested (set to zero)
 *
 * Why it should hold: Once the vesting period ends, all scheduled gains should be immediately available and moved into the share price calculation
 *
 * Possible consequences: Incomplete yield distribution, locked yield that should be available to users, incorrect share valuations
 */
rule updateExchangeRate_02ce728f_zero_gains_after_vesting_end(env e) {

    // assign all the 'before' variables
    uint64 currentContract_vestingState_endVestingTime_before = currentContract.vestingState.endVestingTime;

    // call function under test
    updateExchangeRate(e);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_vestingGains_after = currentContract.vestingState.vestingGains;

    // verify integrity
    assert ((e.block.timestamp >= currentContract_vestingState_endVestingTime_before) => (currentContract_vestingState_vestingGains_after == 0)), "block.timestamp >= vestingState.endVestingTime@before => vestingState.vestingGains@after == 0";
}

/*
 * block.timestamp < vestingState.endVestingTime@before && vestingState.vestingGains@before > 0 => vestingState.vestingGains@after < vestingState.vestingGains@before
 *
 * What it means: If the current time is before the vesting end time and there are gains to vest, only a portion should be vested (gains should decrease but not reach zero)
 *
 * Why it should hold: Linear vesting means gains should be released gradually over time, not all at once before the vesting period ends
 *
 * Possible consequences: Premature yield distribution, incorrect vesting schedules, unfair advantage to early callers
 */
rule updateExchangeRate_02ce728f_partial_vesting_before_end(env e) {

    // assign all the 'before' variables
    uint64 currentContract_vestingState_endVestingTime_before = currentContract.vestingState.endVestingTime;
    uint128 currentContract_vestingState_vestingGains_before = currentContract.vestingState.vestingGains;

    // call function under test
    updateExchangeRate(e);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_vestingGains_after = currentContract.vestingState.vestingGains;

    // verify integrity
    assert (((e.block.timestamp < currentContract_vestingState_endVestingTime_before) && (currentContract_vestingState_vestingGains_before > 0)) => (currentContract_vestingState_vestingGains_after < currentContract_vestingState_vestingGains_before)), "block.timestamp < vestingState.endVestingTime@before && vestingState.vestingGains@before > 0 => vestingState.vestingGains@after < vestingState.vestingGains@before";
}

/*
 * vestingState.lastSharePrice@after > vestingState.lastSharePrice@before => accountantState.feesOwedInBase@after >= accountantState.feesOwedInBase@before
 *
 * What it means: When the share price increases due to vested gains, the fees owed should increase or stay the same
 *
 * Why it should hold: Performance fees are typically calculated on gains, so when share price rises due to vested yield, additional fees should be owed to the protocol
 *
 * Possible consequences: Fee avoidance, reduced protocol revenue, unfair distribution of costs
 */
rule updateExchangeRate_02ce728f_fees_increase_on_price_rise(env e) {

    // assign all the 'before' variables
    uint128 currentContract_vestingState_lastSharePrice_before = currentContract.vestingState.lastSharePrice;
    uint128 currentContract_accountantState_feesOwedInBase_before = currentContract.accountantState.feesOwedInBase;

    // call function under test
    updateExchangeRate(e);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_lastSharePrice_after = currentContract.vestingState.lastSharePrice;
    uint128 currentContract_accountantState_feesOwedInBase_after = currentContract.accountantState.feesOwedInBase;

    // verify integrity
    assert ((currentContract_vestingState_lastSharePrice_after > currentContract_vestingState_lastSharePrice_before) => (currentContract_accountantState_feesOwedInBase_after >= currentContract_accountantState_feesOwedInBase_before)), "vestingState.lastSharePrice@after > vestingState.lastSharePrice@before => accountantState.feesOwedInBase@after >= accountantState.feesOwedInBase@before";
}

/*
 * maximumVestingTime@after == newMaximum
 *
 * What it means: When updateMaximumVestDuration is called with a newMaximum value, the maximumVestingTime storage variable must be updated to exactly that value
 *
 * Why it should hold: This is the core functionality of the function - it exists solely to update the maximum vesting duration. The function body is empty in the provided code, so this property ensures the intended behavior is implemented
 *
 * Possible consequences: If this property is violated, the function becomes a no-op that doesn't actually update the maximum vesting time, breaking the admin's ability to configure vesting parameters and potentially leaving the system with inappropriate time limits
 */
rule updateMaximumVestDuration_eee00042_updates_maximum_vesting_time(env e) {
    uint64 newMaximum;

    // assign all the 'before' variables

    // call function under test
    updateMaximumVestDuration(e, newMaximum);

    // assign all the 'after' variables
    uint64 currentContract_maximumVestingTime_after = currentContract.maximumVestingTime;

    // verify integrity
    assert (currentContract_maximumVestingTime_after == newMaximum), "maximumVestingTime@after == newMaximum";
}

/*
 * newMaximum == 0 => revert
 *
 * What it means: The function must revert if called with newMaximum equal to zero, preventing the maximum vesting time from being set to zero
 *
 * Why it should hold: A zero maximum vesting time would make the vestYield function unusable since any positive duration would exceed the maximum. This violates the business logic that requires meaningful vesting periods
 *
 * Possible consequences: Setting maximumVestingTime to zero would permanently break the vestYield function, causing DoS of the core yield streaming functionality and preventing any future yield from being vested
 */
rule updateMaximumVestDuration_eee00042_zero_maximum_reverts(env e) {
    uint64 newMaximum;

    // assign all the 'before' variables

    // call function under test
    updateMaximumVestDuration@withrevert(e, newMaximum);
    bool updateMaximumVestDuration_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((newMaximum == 0) => updateMaximumVestDuration_reverted), "newMaximum == 0 => revert";
}

/*
 * newMaximum < minimumVestingTime@before => revert
 *
 * What it means: The function must revert if newMaximum is less than the current minimumVestingTime, maintaining the invariant that maximum >= minimum
 *
 * Why it should hold: The contract logic requires that maximumVestingTime >= minimumVestingTime for the vestYield function to work properly. If maximum < minimum, there would be no valid duration range for vesting
 *
 * Possible consequences: Violating this invariant would create an impossible state where no duration could satisfy both the minimum and maximum constraints, causing permanent DoS of the vestYield function
 */
rule updateMaximumVestDuration_eee00042_below_minimum_reverts(env e) {
    uint64 newMaximum;

    // assign all the 'before' variables
    uint64 currentContract_minimumVestingTime_before = currentContract.minimumVestingTime;

    // call function under test
    updateMaximumVestDuration@withrevert(e, newMaximum);
    bool updateMaximumVestDuration_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((newMaximum < currentContract_minimumVestingTime_before) => updateMaximumVestDuration_reverted), "newMaximum < minimumVestingTime@before => revert";
}

/*
 * newMaximum == maximumVestingTime@before => revert
 *
 * What it means: The function must revert if newMaximum equals the current maximumVestingTime value, preventing no-op updates that don't change the state
 *
 * Why it should hold: Following the NO-OPS MUST REVERT principle, operations that don't meaningfully change state should revert to prevent accidental calls and ensure intentional state changes
 *
 * Possible consequences: Allowing no-op updates wastes gas and can mask bugs where the caller thinks they're changing a value but aren't. It also violates the principle that successful transactions should have meaningful effects
 */
rule updateMaximumVestDuration_eee00042_same_value_reverts(env e) {
    uint64 newMaximum;

    // assign all the 'before' variables
    uint64 currentContract_maximumVestingTime_before = currentContract.maximumVestingTime;

    // call function under test
    updateMaximumVestDuration@withrevert(e, newMaximum);
    bool updateMaximumVestDuration_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((newMaximum == currentContract_maximumVestingTime_before) => updateMaximumVestDuration_reverted), "newMaximum == maximumVestingTime@before => revert";
}

/*
 * newMinimum >= 0 => minimumVestingTime@after == newMinimum
 *
 * What it means: When a valid newMinimum value is provided, the minimumVestingTime storage variable must be updated to exactly that value
 *
 * Why it should hold: This is the core functionality of the function - it exists solely to update the minimum vesting time configuration. The function should perform its intended state change when called with valid parameters
 *
 * Possible consequences: Configuration drift where the intended minimum vesting time is not applied, leading to inconsistent yield vesting behavior and potential bypass of time-based security controls
 */
rule updateMinimumVestDuration_96297efc_updates_minimum_vesting_time(env e) {
    uint64 newMinimum;

    // assign all the 'before' variables

    // call function under test
    updateMinimumVestDuration(e, newMinimum);

    // assign all the 'after' variables
    uint64 currentContract_minimumVestingTime_after = currentContract.minimumVestingTime;

    // verify integrity
    assert ((newMinimum >= 0) => (currentContract_minimumVestingTime_after == newMinimum)), "newMinimum >= 0 => minimumVestingTime@after == newMinimum";
}

/*
 * newMinimum == minimumVestingTime@before => revert
 *
 * What it means: If the new minimum value is the same as the current minimum vesting time, the function must revert instead of succeeding with no changes
 *
 * Why it should hold: Following the NO-OPS MUST REVERT principle, meaningless operations should fail rather than appear successful. This prevents confusion and ensures intentional state changes
 *
 * Possible consequences: Gas waste from successful but meaningless transactions, potential confusion in monitoring systems that expect state changes, and masking of logic errors in calling code
 */
rule updateMinimumVestDuration_96297efc_no_op_reverts(env e) {
    uint64 newMinimum;

    // assign all the 'before' variables
    uint64 currentContract_minimumVestingTime_before = currentContract.minimumVestingTime;

    // call function under test
    updateMinimumVestDuration@withrevert(e, newMinimum);
    bool updateMinimumVestDuration_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((newMinimum == currentContract_minimumVestingTime_before) => updateMinimumVestDuration_reverted), "newMinimum == minimumVestingTime@before => revert";
}

/*
 * newMinimum != minimumVestingTime@before => maximumVestingTime@after == maximumVestingTime@before
 *
 * What it means: When the minimum vesting time is actually changed, the maximum vesting time must remain unchanged
 *
 * Why it should hold: This function should only modify the minimum vesting time and not affect other configuration parameters. Unintended changes to maximum vesting time could break the vesting system
 *
 * Possible consequences: Corruption of vesting configuration where maximum vesting time is accidentally modified, potentially allowing excessively long or short vesting periods that break the economic model
 */
rule updateMinimumVestDuration_96297efc_preserves_maximum_vesting(env e) {
    uint64 newMinimum;

    // assign all the 'before' variables
    uint64 currentContract_minimumVestingTime_before = currentContract.minimumVestingTime;
    uint64 currentContract_maximumVestingTime_before = currentContract.maximumVestingTime;

    // call function under test
    updateMinimumVestDuration(e, newMinimum);

    // assign all the 'after' variables
    uint64 currentContract_maximumVestingTime_after = currentContract.maximumVestingTime;

    // verify integrity
    assert ((newMinimum != currentContract_minimumVestingTime_before) => (currentContract_maximumVestingTime_after == currentContract_maximumVestingTime_before)), "newMinimum != minimumVestingTime@before => maximumVestingTime@after == maximumVestingTime@before";
}

/*
 * newMinimum != minimumVestingTime@before => vestingState.vestingGains@after == vestingState.vestingGains@before
 *
 * What it means: When updating the minimum vesting duration, the amount of currently vesting gains must remain unchanged
 *
 * Why it should hold: This administrative function should not affect active yield vesting. The vestingGains represents user funds that are in the process of being vested and must not be corrupted
 *
 * Possible consequences: Loss or corruption of user funds that are currently vesting, leading to incorrect share prices and potential fund loss for vault participants
 */
rule updateMinimumVestDuration_96297efc_preserves_vesting_gains(env e) {
    uint64 newMinimum;

    // assign all the 'before' variables
    uint64 currentContract_minimumVestingTime_before = currentContract.minimumVestingTime;
    uint128 currentContract_vestingState_vestingGains_before = currentContract.vestingState.vestingGains;

    // call function under test
    updateMinimumVestDuration(e, newMinimum);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_vestingGains_after = currentContract.vestingState.vestingGains;

    // verify integrity
    assert ((newMinimum != currentContract_minimumVestingTime_before) => (currentContract_vestingState_vestingGains_after == currentContract_vestingState_vestingGains_before)), "newMinimum != minimumVestingTime@before => vestingState.vestingGains@after == vestingState.vestingGains@before";
}

/*
 * newMinimum != minimumVestingTime@before => vestingState.lastSharePrice@after == vestingState.lastSharePrice@before
 *
 * What it means: When updating the minimum vesting duration, the last recorded share price must remain unchanged
 *
 * Why it should hold: This administrative function should not affect the share price calculation. The lastSharePrice is critical for determining current vault valuation and must not be corrupted by configuration changes
 *
 * Possible consequences: Share price manipulation or corruption leading to incorrect vault valuations, unfair minting/burning of shares, and potential arbitrage opportunities
 */
rule updateMinimumVestDuration_96297efc_preserves_last_share_price(env e) {
    uint64 newMinimum;

    // assign all the 'before' variables
    uint64 currentContract_minimumVestingTime_before = currentContract.minimumVestingTime;
    uint128 currentContract_vestingState_lastSharePrice_before = currentContract.vestingState.lastSharePrice;

    // call function under test
    updateMinimumVestDuration(e, newMinimum);

    // assign all the 'after' variables
    uint128 currentContract_vestingState_lastSharePrice_after = currentContract.vestingState.lastSharePrice;

    // verify integrity
    assert ((newMinimum != currentContract_minimumVestingTime_before) => (currentContract_vestingState_lastSharePrice_after == currentContract_vestingState_lastSharePrice_before)), "newMinimum != minimumVestingTime@before => vestingState.lastSharePrice@after == vestingState.lastSharePrice@before";
}

/*
 * newMinimum != minimumVestingTime@before => vestingState.startVestingTime@after == vestingState.startVestingTime@before && vestingState.endVestingTime@after == vestingState.endVestingTime@before
 *
 * What it means: When updating the minimum vesting duration, both the start and end times of the current vesting period must remain unchanged
 *
 * Why it should hold: This administrative function should not interfere with active vesting schedules. The vesting timeline represents committed yield distribution that users are expecting to receive
 *
 * Possible consequences: Disruption of active yield vesting schedules, potentially accelerating or delaying yield distribution in ways that break the economic model and user expectations
 */
rule updateMinimumVestDuration_96297efc_preserves_vesting_times(env e) {
    uint64 newMinimum;

    // assign all the 'before' variables
    uint64 currentContract_minimumVestingTime_before = currentContract.minimumVestingTime;
    uint64 currentContract_vestingState_startVestingTime_before = currentContract.vestingState.startVestingTime;
    uint64 currentContract_vestingState_endVestingTime_before = currentContract.vestingState.endVestingTime;

    // call function under test
    updateMinimumVestDuration(e, newMinimum);

    // assign all the 'after' variables
    uint64 currentContract_vestingState_startVestingTime_after = currentContract.vestingState.startVestingTime;
    uint64 currentContract_vestingState_endVestingTime_after = currentContract.vestingState.endVestingTime;

    // verify integrity
    assert ((newMinimum != currentContract_minimumVestingTime_before) => ((currentContract_vestingState_startVestingTime_after == currentContract_vestingState_startVestingTime_before) && (currentContract_vestingState_endVestingTime_after == currentContract_vestingState_endVestingTime_before))), "newMinimum != minimumVestingTime@before => vestingState.startVestingTime@after == vestingState.startVestingTime@before && vestingState.endVestingTime@after == vestingState.endVestingTime@before";
}