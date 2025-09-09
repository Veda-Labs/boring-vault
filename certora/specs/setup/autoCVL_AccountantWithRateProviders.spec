import "dispatching_AccountantWithRateProviders.spec";

/*
 * accountantState.isPaused@after == true
 *
 * What it means: The pause function must always set the isPaused flag to true in the accountantState struct
 *
 * Why it should hold: This is the core functionality of the pause function - it should pause the contract by setting the isPaused flag. Without this, the function would be a no-op and fail to provide the emergency pause capability
 *
 * Possible consequences: Contract remains operational when it should be paused, allowing potentially dangerous operations like updateExchangeRate and claimFees to continue during emergency situations
 */
rule pause_8456cb59_sets_paused_true(env e) {

    // assign all the 'before' variables

    // call function under test
    pause(e);

    // assign all the 'after' variables
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;

    // verify integrity
    assert (currentContract_accountantState_isPaused_after == true), "accountantState.isPaused@after == true";
}

/*
 * accountantState.isPaused@before == true => revert
 *
 * What it means: If the contract is already paused (isPaused is true), calling pause again must revert rather than succeed as a no-op
 *
 * Why it should hold: Following the NO-OPS MUST REVERT principle, attempting to pause an already paused contract is a meaningless operation that should fail to alert the caller of the redundant action
 *
 * Possible consequences: Misleading behavior where redundant pause calls appear successful, potentially masking logic errors in calling code or admin scripts
 */
rule pause_8456cb59_already_paused_no_op(env e) {

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;

    // call function under test
    pause@withrevert(e);
    bool pause_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_accountantState_isPaused_before == true) => pause_reverted), "accountantState.isPaused@before == true => revert";
}

/*
 * !accountantState.isPaused@before => accountantState.isPaused@after != accountantState.isPaused@before
 *
 * What it means: When the contract is not already paused, calling pause must change the isPaused state from false to true
 *
 * Why it should hold: This ensures the pause function actually modifies state when it should, preventing scenarios where the function appears to work but doesn't change anything
 *
 * Possible consequences: Silent failure where pause appears successful but doesn't actually pause the contract, leaving it vulnerable during intended maintenance or emergency periods
 */
rule pause_8456cb59_changes_pause_state(env e) {

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;

    // call function under test
    pause(e);

    // assign all the 'after' variables
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;

    // verify integrity
    assert (!(currentContract_accountantState_isPaused_before) => (currentContract_accountantState_isPaused_after != currentContract_accountantState_isPaused_before)), "!accountantState.isPaused@before => accountantState.isPaused@after != accountantState.isPaused@before";
}

/*
 * accountantState.payoutAddress@after == accountantState.payoutAddress@before && accountantState.highwaterMark@after == accountantState.highwaterMark@before && accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before && accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before && accountantState.exchangeRate@after == accountantState.exchangeRate@before && accountantState.allowedExchangeRateChangeUpper@after == accountantState.allowedExchangeRateChangeUpper@before && accountantState.allowedExchangeRateChangeLower@after == accountantState.allowedExchangeRateChangeLower@before && accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before && accountantState.minimumUpdateDelayInSeconds@after == accountantState.minimumUpdateDelayInSeconds@before && accountantState.platformFee@after == accountantState.platformFee@before && accountantState.performanceFee@after == accountantState.performanceFee@before
 *
 * What it means: The pause function must not modify any other fields in the accountantState struct besides isPaused - all other state variables must remain unchanged
 *
 * Why it should hold: Pause should be a surgical operation that only affects the pause state. Modifying other critical parameters like fees, exchange rates, or addresses during pause could corrupt the contract state
 *
 * Possible consequences: State corruption where critical contract parameters are unexpectedly modified, potentially leading to incorrect fee calculations, wrong exchange rates, or broken functionality when unpaused
 */
rule pause_8456cb59_preserves_other_state(env e) {

    // assign all the 'before' variables
    address currentContract_accountantState_payoutAddress_before = currentContract.accountantState.payoutAddress;
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;
    uint128 currentContract_accountantState_feesOwedInBase_before = currentContract.accountantState.feesOwedInBase;
    uint128 currentContract_accountantState_totalSharesLastUpdate_before = currentContract.accountantState.totalSharesLastUpdate;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_before = currentContract.accountantState.allowedExchangeRateChangeUpper;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;
    uint64 currentContract_accountantState_lastUpdateTimestamp_before = currentContract.accountantState.lastUpdateTimestamp;
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_before = currentContract.accountantState.minimumUpdateDelayInSeconds;
    uint16 currentContract_accountantState_platformFee_before = currentContract.accountantState.platformFee;
    uint16 currentContract_accountantState_performanceFee_before = currentContract.accountantState.performanceFee;

    // call function under test
    pause(e);

    // assign all the 'after' variables
    address currentContract_accountantState_payoutAddress_after = currentContract.accountantState.payoutAddress;
    uint96 currentContract_accountantState_highwaterMark_after = currentContract.accountantState.highwaterMark;
    uint128 currentContract_accountantState_feesOwedInBase_after = currentContract.accountantState.feesOwedInBase;
    uint128 currentContract_accountantState_totalSharesLastUpdate_after = currentContract.accountantState.totalSharesLastUpdate;
    uint96 currentContract_accountantState_exchangeRate_after = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_after = currentContract.accountantState.allowedExchangeRateChangeUpper;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_after = currentContract.accountantState.allowedExchangeRateChangeLower;
    uint64 currentContract_accountantState_lastUpdateTimestamp_after = currentContract.accountantState.lastUpdateTimestamp;
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_after = currentContract.accountantState.minimumUpdateDelayInSeconds;
    uint16 currentContract_accountantState_platformFee_after = currentContract.accountantState.platformFee;
    uint16 currentContract_accountantState_performanceFee_after = currentContract.accountantState.performanceFee;

    // verify integrity
    assert (((((((((((currentContract_accountantState_payoutAddress_after == currentContract_accountantState_payoutAddress_before) && (currentContract_accountantState_highwaterMark_after == currentContract_accountantState_highwaterMark_before)) && (currentContract_accountantState_feesOwedInBase_after == currentContract_accountantState_feesOwedInBase_before)) && (currentContract_accountantState_totalSharesLastUpdate_after == currentContract_accountantState_totalSharesLastUpdate_before)) && (currentContract_accountantState_exchangeRate_after == currentContract_accountantState_exchangeRate_before)) && (currentContract_accountantState_allowedExchangeRateChangeUpper_after == currentContract_accountantState_allowedExchangeRateChangeUpper_before)) && (currentContract_accountantState_allowedExchangeRateChangeLower_after == currentContract_accountantState_allowedExchangeRateChangeLower_before)) && (currentContract_accountantState_lastUpdateTimestamp_after == currentContract_accountantState_lastUpdateTimestamp_before)) && (currentContract_accountantState_minimumUpdateDelayInSeconds_after == currentContract_accountantState_minimumUpdateDelayInSeconds_before)) && (currentContract_accountantState_platformFee_after == currentContract_accountantState_platformFee_before)) && (currentContract_accountantState_performanceFee_after == currentContract_accountantState_performanceFee_before)), "accountantState.payoutAddress@after == accountantState.payoutAddress@before && accountantState.highwaterMark@after == accountantState.highwaterMark@before && accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before && accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before && accountantState.exchangeRate@after == accountantState.exchangeRate@before && accountantState.allowedExchangeRateChangeUpper@after == accountantState.allowedExchangeRateChangeUpper@before && accountantState.allowedExchangeRateChangeLower@after == accountantState.allowedExchangeRateChangeLower@before && accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before && accountantState.minimumUpdateDelayInSeconds@after == accountantState.minimumUpdateDelayInSeconds@before && accountantState.platformFee@after == accountantState.platformFee@before && accountantState.performanceFee@after == accountantState.performanceFee@before";
}

/*
 * msg.sender != owner@before && !authority@before.canCall(msg.sender, address(this), msg.sig) => revert
 *
 * What it means: The unpause function must revert when called by someone who is neither the owner nor authorized by the authority contract
 *
 * Why it should hold: The unpause function is a critical administrative function that should only be callable by authorized parties. The contract inherits from Auth which implements access control through the requiresAuth modifier
 *
 * Possible consequences: Unauthorized access control bypass, allowing any user to unpause the contract when it should remain paused for security reasons
 */
rule unpause_3f4ba83a_unauthorized_reverts(env e) {

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    bool currentContract_authority_canCall_e__e_msg_sender__currentContract__to_bytes4_0x3f4ba83a___before = currentContract.isAuthorizedHarness(e, e.msg.sender, to_bytes4(0x3f4ba83a));

    // call function under test
    unpause@withrevert(e);
    bool unpause_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((e.msg.sender != currentContract_owner_before) && !(currentContract_authority_canCall_e__e_msg_sender__currentContract__to_bytes4_0x3f4ba83a___before)) => unpause_reverted), "msg.sender != owner@before && !authority@before.canCall(msg.sender, address(this), msg.sig) => revert";
}

/*
 * msg.sender == owner@before || authority@before.canCall(msg.sender, address(this), msg.sig) => accountantState.isPaused@after == false
 *
 * What it means: When called by an authorized user (owner or someone with authority permissions), the function must set accountantState.isPaused to false
 *
 * Why it should hold: This is the core functionality of the unpause function - it should actually unpause the contract when called by authorized users, as evidenced by the corresponding pause() function that sets isPaused to true
 *
 * Possible consequences: Function becomes non-functional, preventing legitimate administrators from unpausing the contract when needed
 */
rule unpause_3f4ba83a_unpauses_when_authorized(env e) {

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    bool currentContract_authority_canCall_e__e_msg_sender__currentContract__to_bytes4_0x3f4ba83a___before = currentContract.isAuthorizedHarness(e, e.msg.sender, to_bytes4(0x3f4ba83a));

    // call function under test
    unpause(e);

    // assign all the 'after' variables
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;

    // verify integrity
    assert (((e.msg.sender == currentContract_owner_before) || currentContract_authority_canCall_e__e_msg_sender__currentContract__to_bytes4_0x3f4ba83a___before) => (currentContract_accountantState_isPaused_after == false)), "msg.sender == owner@before || authority@before.canCall(msg.sender, address(this), msg.sig) => accountantState.isPaused@after == false";
}

/*
 * !accountantState.isPaused@before => revert
 *
 * What it means: The function must revert when called on a contract that is already unpaused (isPaused is false)
 *
 * Why it should hold: This prevents no-op operations which should revert according to the formal verification rules. If the contract is already unpaused, calling unpause again serves no purpose and should fail
 *
 * Possible consequences: Allows meaningless transactions that waste gas and could mask other issues or be used in complex attack scenarios
 */
rule unpause_3f4ba83a_already_unpaused_reverts(env e) {

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;

    // call function under test
    unpause@withrevert(e);
    bool unpause_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (!(currentContract_accountantState_isPaused_before) => unpause_reverted), "!accountantState.isPaused@before => revert";
}

/*
 * accountantState.payoutAddress@after == accountantState.payoutAddress@before && accountantState.highwaterMark@after == accountantState.highwaterMark@before && accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before && accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before && accountantState.exchangeRate@after == accountantState.exchangeRate@before && accountantState.allowedExchangeRateChangeUpper@after == accountantState.allowedExchangeRateChangeUpper@before && accountantState.allowedExchangeRateChangeLower@after == accountantState.allowedExchangeRateChangeLower@before && accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before && accountantState.minimumUpdateDelayInSeconds@after == accountantState.minimumUpdateDelayInSeconds@before && accountantState.platformFee@after == accountantState.platformFee@before && accountantState.performanceFee@after == accountantState.performanceFee@before
 *
 * What it means: All other fields in accountantState must remain unchanged when unpause is called - only the isPaused field should be modified
 *
 * Why it should hold: The unpause function should have a single, well-defined responsibility of changing the pause state. Modifying other state variables would indicate unintended side effects or potential vulnerabilities
 *
 * Possible consequences: State corruption, unexpected behavior in other contract functions, potential for complex attack vectors through state manipulation
 */
rule unpause_3f4ba83a_other_state_unchanged(env e) {

    // assign all the 'before' variables
    address currentContract_accountantState_payoutAddress_before = currentContract.accountantState.payoutAddress;
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;
    uint128 currentContract_accountantState_feesOwedInBase_before = currentContract.accountantState.feesOwedInBase;
    uint128 currentContract_accountantState_totalSharesLastUpdate_before = currentContract.accountantState.totalSharesLastUpdate;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_before = currentContract.accountantState.allowedExchangeRateChangeUpper;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;
    uint64 currentContract_accountantState_lastUpdateTimestamp_before = currentContract.accountantState.lastUpdateTimestamp;
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_before = currentContract.accountantState.minimumUpdateDelayInSeconds;
    uint16 currentContract_accountantState_platformFee_before = currentContract.accountantState.platformFee;
    uint16 currentContract_accountantState_performanceFee_before = currentContract.accountantState.performanceFee;

    // call function under test
    unpause(e);

    // assign all the 'after' variables
    address currentContract_accountantState_payoutAddress_after = currentContract.accountantState.payoutAddress;
    uint96 currentContract_accountantState_highwaterMark_after = currentContract.accountantState.highwaterMark;
    uint128 currentContract_accountantState_feesOwedInBase_after = currentContract.accountantState.feesOwedInBase;
    uint128 currentContract_accountantState_totalSharesLastUpdate_after = currentContract.accountantState.totalSharesLastUpdate;
    uint96 currentContract_accountantState_exchangeRate_after = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_after = currentContract.accountantState.allowedExchangeRateChangeUpper;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_after = currentContract.accountantState.allowedExchangeRateChangeLower;
    uint64 currentContract_accountantState_lastUpdateTimestamp_after = currentContract.accountantState.lastUpdateTimestamp;
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_after = currentContract.accountantState.minimumUpdateDelayInSeconds;
    uint16 currentContract_accountantState_platformFee_after = currentContract.accountantState.platformFee;
    uint16 currentContract_accountantState_performanceFee_after = currentContract.accountantState.performanceFee;

    // verify integrity
    assert (((((((((((currentContract_accountantState_payoutAddress_after == currentContract_accountantState_payoutAddress_before) && (currentContract_accountantState_highwaterMark_after == currentContract_accountantState_highwaterMark_before)) && (currentContract_accountantState_feesOwedInBase_after == currentContract_accountantState_feesOwedInBase_before)) && (currentContract_accountantState_totalSharesLastUpdate_after == currentContract_accountantState_totalSharesLastUpdate_before)) && (currentContract_accountantState_exchangeRate_after == currentContract_accountantState_exchangeRate_before)) && (currentContract_accountantState_allowedExchangeRateChangeUpper_after == currentContract_accountantState_allowedExchangeRateChangeUpper_before)) && (currentContract_accountantState_allowedExchangeRateChangeLower_after == currentContract_accountantState_allowedExchangeRateChangeLower_before)) && (currentContract_accountantState_lastUpdateTimestamp_after == currentContract_accountantState_lastUpdateTimestamp_before)) && (currentContract_accountantState_minimumUpdateDelayInSeconds_after == currentContract_accountantState_minimumUpdateDelayInSeconds_before)) && (currentContract_accountantState_platformFee_after == currentContract_accountantState_platformFee_before)) && (currentContract_accountantState_performanceFee_after == currentContract_accountantState_performanceFee_before)), "accountantState.payoutAddress@after == accountantState.payoutAddress@before && accountantState.highwaterMark@after == accountantState.highwaterMark@before && accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before && accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before && accountantState.exchangeRate@after == accountantState.exchangeRate@before && accountantState.allowedExchangeRateChangeUpper@after == accountantState.allowedExchangeRateChangeUpper@before && accountantState.allowedExchangeRateChangeLower@after == accountantState.allowedExchangeRateChangeLower@before && accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before && accountantState.minimumUpdateDelayInSeconds@after == accountantState.minimumUpdateDelayInSeconds@before && accountantState.platformFee@after == accountantState.platformFee@before && accountantState.performanceFee@after == accountantState.performanceFee@before";
}

/*
 * accountantState.minimumUpdateDelayInSeconds@after == minimumUpdateDelayInSeconds
 *
 * What it means: When updateDelay is called, the minimumUpdateDelayInSeconds field in accountantState must be updated to match the input parameter
 *
 * Why it should hold: This is the core functionality of updateDelay - it should update the minimum delay between exchange rate updates. The function name and comments indicate this is its primary purpose
 *
 * Possible consequences: If this property is violated, the delay configuration would not be updated, leading to incorrect timing constraints on exchange rate updates, potentially allowing too frequent or preventing necessary updates
 */
rule updateDelay_6a054dc9_updates_delay(env e) {
    uint24 minimumUpdateDelayInSeconds;

    // assign all the 'before' variables

    // call function under test
    updateDelay(e, minimumUpdateDelayInSeconds);

    // assign all the 'after' variables
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_after = currentContract.accountantState.minimumUpdateDelayInSeconds;

    // verify integrity
    assert (currentContract_accountantState_minimumUpdateDelayInSeconds_after == minimumUpdateDelayInSeconds), "accountantState.minimumUpdateDelayInSeconds@after == minimumUpdateDelayInSeconds";
}

/*
 * minimumUpdateDelayInSeconds == accountantState.minimumUpdateDelayInSeconds@before => revert
 *
 * What it means: If the new minimumUpdateDelayInSeconds parameter equals the current stored value, the function must revert instead of completing successfully
 *
 * Why it should hold: Following the NO-OPS MUST REVERT rule - operations that don't change state meaningfully should fail rather than succeed with no effect
 *
 * Possible consequences: If this property is violated, no-op calls would succeed, wasting gas and potentially masking configuration errors or allowing spam transactions
 */
rule updateDelay_6a054dc9_no_change_revert(env e) {
    uint24 minimumUpdateDelayInSeconds;

    // assign all the 'before' variables
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_before = currentContract.accountantState.minimumUpdateDelayInSeconds;

    // call function under test
    updateDelay@withrevert(e, minimumUpdateDelayInSeconds);
    bool updateDelay_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((minimumUpdateDelayInSeconds == currentContract_accountantState_minimumUpdateDelayInSeconds_before) => updateDelay_reverted), "minimumUpdateDelayInSeconds == accountantState.minimumUpdateDelayInSeconds@before => revert";
}

/*
 * accountantState.payoutAddress@after == accountantState.payoutAddress@before && accountantState.highwaterMark@after == accountantState.highwaterMark@before && accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before && accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before && accountantState.exchangeRate@after == accountantState.exchangeRate@before && accountantState.allowedExchangeRateChangeUpper@after == accountantState.allowedExchangeRateChangeUpper@before && accountantState.allowedExchangeRateChangeLower@after == accountantState.allowedExchangeRateChangeLower@before && accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before && accountantState.isPaused@after == accountantState.isPaused@before && accountantState.platformFee@after == accountantState.platformFee@before && accountantState.performanceFee@after == accountantState.performanceFee@before
 *
 * What it means: When updateDelay executes, all other fields in accountantState (payoutAddress, highwaterMark, feesOwedInBase, etc.) must remain exactly the same as before the call
 *
 * Why it should hold: updateDelay should only modify the minimumUpdateDelayInSeconds field and leave all other state variables untouched to maintain system integrity
 *
 * Possible consequences: If this property is violated, updateDelay could corrupt other critical system parameters like fees, exchange rates, or pause status, leading to fund loss or system malfunction
 */
rule updateDelay_6a054dc9_other_state_unchanged(env e) {
    uint24 minimumUpdateDelayInSeconds;

    // assign all the 'before' variables
    address currentContract_accountantState_payoutAddress_before = currentContract.accountantState.payoutAddress;
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;
    uint128 currentContract_accountantState_feesOwedInBase_before = currentContract.accountantState.feesOwedInBase;
    uint128 currentContract_accountantState_totalSharesLastUpdate_before = currentContract.accountantState.totalSharesLastUpdate;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_before = currentContract.accountantState.allowedExchangeRateChangeUpper;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;
    uint64 currentContract_accountantState_lastUpdateTimestamp_before = currentContract.accountantState.lastUpdateTimestamp;
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint16 currentContract_accountantState_platformFee_before = currentContract.accountantState.platformFee;
    uint16 currentContract_accountantState_performanceFee_before = currentContract.accountantState.performanceFee;

    // call function under test
    updateDelay(e, minimumUpdateDelayInSeconds);

    // assign all the 'after' variables
    address currentContract_accountantState_payoutAddress_after = currentContract.accountantState.payoutAddress;
    uint96 currentContract_accountantState_highwaterMark_after = currentContract.accountantState.highwaterMark;
    uint128 currentContract_accountantState_feesOwedInBase_after = currentContract.accountantState.feesOwedInBase;
    uint128 currentContract_accountantState_totalSharesLastUpdate_after = currentContract.accountantState.totalSharesLastUpdate;
    uint96 currentContract_accountantState_exchangeRate_after = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_after = currentContract.accountantState.allowedExchangeRateChangeUpper;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_after = currentContract.accountantState.allowedExchangeRateChangeLower;
    uint64 currentContract_accountantState_lastUpdateTimestamp_after = currentContract.accountantState.lastUpdateTimestamp;
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;
    uint16 currentContract_accountantState_platformFee_after = currentContract.accountantState.platformFee;
    uint16 currentContract_accountantState_performanceFee_after = currentContract.accountantState.performanceFee;

    // verify integrity
    assert (((((((((((currentContract_accountantState_payoutAddress_after == currentContract_accountantState_payoutAddress_before) && (currentContract_accountantState_highwaterMark_after == currentContract_accountantState_highwaterMark_before)) && (currentContract_accountantState_feesOwedInBase_after == currentContract_accountantState_feesOwedInBase_before)) && (currentContract_accountantState_totalSharesLastUpdate_after == currentContract_accountantState_totalSharesLastUpdate_before)) && (currentContract_accountantState_exchangeRate_after == currentContract_accountantState_exchangeRate_before)) && (currentContract_accountantState_allowedExchangeRateChangeUpper_after == currentContract_accountantState_allowedExchangeRateChangeUpper_before)) && (currentContract_accountantState_allowedExchangeRateChangeLower_after == currentContract_accountantState_allowedExchangeRateChangeLower_before)) && (currentContract_accountantState_lastUpdateTimestamp_after == currentContract_accountantState_lastUpdateTimestamp_before)) && (currentContract_accountantState_isPaused_after == currentContract_accountantState_isPaused_before)) && (currentContract_accountantState_platformFee_after == currentContract_accountantState_platformFee_before)) && (currentContract_accountantState_performanceFee_after == currentContract_accountantState_performanceFee_before)), "accountantState.payoutAddress@after == accountantState.payoutAddress@before && accountantState.highwaterMark@after == accountantState.highwaterMark@before && accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before && accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before && accountantState.exchangeRate@after == accountantState.exchangeRate@before && accountantState.allowedExchangeRateChangeUpper@after == accountantState.allowedExchangeRateChangeUpper@before && accountantState.allowedExchangeRateChangeLower@after == accountantState.allowedExchangeRateChangeLower@before && accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before && accountantState.isPaused@after == accountantState.isPaused@before && accountantState.platformFee@after == accountantState.platformFee@before && accountantState.performanceFee@after == accountantState.performanceFee@before";
}

/*
 * allowedExchangeRateChangeUpper < 1e4 => revert
 *
 * What it means: The function must revert if the new allowedExchangeRateChangeUpper parameter is less than 1e4 (10000 basis points or 100%)
 *
 * Why it should hold: Based on the pattern from updateLower function which checks allowedExchangeRateChangeLower > 1e4, and the error AccountantWithRateProviders__UpperBoundTooSmall, there should be a minimum threshold for the upper bound to prevent invalid configurations
 *
 * Possible consequences: Setting an upper bound below 100% could make the exchange rate update mechanism unusable, causing DoS of critical vault operations and preventing proper fee calculations
 */
rule updateUpper_634da58f_upper_bound_too_small(env e) {
    uint16 allowedExchangeRateChangeUpper;

    // assign all the 'before' variables

    // call function under test
    updateUpper@withrevert(e, allowedExchangeRateChangeUpper);
    bool updateUpper_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((allowedExchangeRateChangeUpper < (1 * 10 ^ 4)) => updateUpper_reverted), "allowedExchangeRateChangeUpper < 1e4 => revert";
}

/*
 * allowedExchangeRateChangeUpper == accountantState.allowedExchangeRateChangeUpper@before => revert
 *
 * What it means: The function must revert if the new allowedExchangeRateChangeUpper value is identical to the current value stored in accountantState
 *
 * Why it should hold: No-op operations waste gas and provide no meaningful state change. Following the defensive pattern that meaningless operations should revert rather than succeed silently
 *
 * Possible consequences: Allows wasteful transactions that consume gas without providing value, and may mask bugs where the caller thinks they're making a change but aren't
 */
rule updateUpper_634da58f_no_op_reverts(env e) {
    uint16 allowedExchangeRateChangeUpper;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_before = currentContract.accountantState.allowedExchangeRateChangeUpper;

    // call function under test
    updateUpper@withrevert(e, allowedExchangeRateChangeUpper);
    bool updateUpper_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((allowedExchangeRateChangeUpper == currentContract_accountantState_allowedExchangeRateChangeUpper_before) => updateUpper_reverted), "allowedExchangeRateChangeUpper == accountantState.allowedExchangeRateChangeUpper@before => revert";
}

/*
 * allowedExchangeRateChangeUpper >= 1e4 && allowedExchangeRateChangeUpper != accountantState.allowedExchangeRateChangeUpper@before => accountantState.allowedExchangeRateChangeUpper@after == allowedExchangeRateChangeUpper
 *
 * What it means: When the new value is valid (>= 1e4) and different from current value, the allowedExchangeRateChangeUpper field in accountantState must be updated to the new value
 *
 * Why it should hold: This is the core functionality of the updateUpper function - it must actually update the upper bound parameter when given valid input, as this controls exchange rate update validation
 *
 * Possible consequences: If the state doesn't update properly, exchange rate bounds remain incorrect, potentially allowing invalid rate updates or blocking valid ones, corrupting the fee calculation mechanism
 */
rule updateUpper_634da58f_valid_update_changes_upper(env e) {
    uint16 allowedExchangeRateChangeUpper;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_before = currentContract.accountantState.allowedExchangeRateChangeUpper;

    // call function under test
    updateUpper(e, allowedExchangeRateChangeUpper);

    // assign all the 'after' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_after = currentContract.accountantState.allowedExchangeRateChangeUpper;

    // verify integrity
    assert (((allowedExchangeRateChangeUpper >= (1 * 10 ^ 4)) && (allowedExchangeRateChangeUpper != currentContract_accountantState_allowedExchangeRateChangeUpper_before)) => (currentContract_accountantState_allowedExchangeRateChangeUpper_after == allowedExchangeRateChangeUpper)), "allowedExchangeRateChangeUpper >= 1e4 && allowedExchangeRateChangeUpper != accountantState.allowedExchangeRateChangeUpper@before => accountantState.allowedExchangeRateChangeUpper@after == allowedExchangeRateChangeUpper";
}

/*
 * accountantState.allowedExchangeRateChangeLower@after == accountantState.allowedExchangeRateChangeLower@before
 *
 * What it means: The allowedExchangeRateChangeLower field in accountantState must remain exactly the same before and after the function call
 *
 * Why it should hold: updateUpper should only modify the upper bound parameter and not affect the lower bound, maintaining separation of concerns and preventing unintended side effects
 *
 * Possible consequences: Unintended modification of the lower bound could create invalid bound configurations or unexpected exchange rate validation behavior, leading to system instability
 */
rule updateUpper_634da58f_lower_bound_unchanged(env e) {
    uint16 allowedExchangeRateChangeUpper;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;

    // call function under test
    updateUpper(e, allowedExchangeRateChangeUpper);

    // assign all the 'after' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_after = currentContract.accountantState.allowedExchangeRateChangeLower;

    // verify integrity
    assert (currentContract_accountantState_allowedExchangeRateChangeLower_after == currentContract_accountantState_allowedExchangeRateChangeLower_before), "accountantState.allowedExchangeRateChangeLower@after == accountantState.allowedExchangeRateChangeLower@before";
}

/*
 * accountantState.exchangeRate@after == accountantState.exchangeRate@before
 *
 * What it means: The current exchangeRate field in accountantState must remain exactly the same before and after the function call
 *
 * Why it should hold: updateUpper is a configuration function that should not affect the current exchange rate, only the bounds for future updates
 *
 * Possible consequences: Unintended exchange rate changes could trigger incorrect fee calculations, affect vault share pricing, and potentially cause financial losses to users
 */
rule updateUpper_634da58f_exchange_rate_unchanged(env e) {
    uint16 allowedExchangeRateChangeUpper;

    // assign all the 'before' variables
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;

    // call function under test
    updateUpper(e, allowedExchangeRateChangeUpper);

    // assign all the 'after' variables
    uint96 currentContract_accountantState_exchangeRate_after = currentContract.accountantState.exchangeRate;

    // verify integrity
    assert (currentContract_accountantState_exchangeRate_after == currentContract_accountantState_exchangeRate_before), "accountantState.exchangeRate@after == accountantState.exchangeRate@before";
}

/*
 * accountantState.isPaused@after == accountantState.isPaused@before
 *
 * What it means: The isPaused field in accountantState must remain exactly the same before and after the function call
 *
 * Why it should hold: updateUpper is a configuration function and should not affect the pause state, which is controlled by separate pause/unpause functions
 *
 * Possible consequences: Unintended pause state changes could either lock users out of the system or remove safety protections when they should be active
 */
rule updateUpper_634da58f_pause_state_unchanged(env e) {
    uint16 allowedExchangeRateChangeUpper;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;

    // call function under test
    updateUpper(e, allowedExchangeRateChangeUpper);

    // assign all the 'after' variables
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;

    // verify integrity
    assert (currentContract_accountantState_isPaused_after == currentContract_accountantState_isPaused_before), "accountantState.isPaused@after == accountantState.isPaused@before";
}

/*
 * accountantState.payoutAddress@after == accountantState.payoutAddress@before
 *
 * What it means: The payoutAddress field in accountantState must remain exactly the same before and after the function call
 *
 * Why it should hold: updateUpper should only modify exchange rate bounds and not affect fee payout configuration, which is controlled by updatePayoutAddress function
 *
 * Possible consequences: Unintended payout address changes could redirect fees to wrong recipients, causing direct financial loss
 */
rule updateUpper_634da58f_payout_address_unchanged(env e) {
    uint16 allowedExchangeRateChangeUpper;

    // assign all the 'before' variables
    address currentContract_accountantState_payoutAddress_before = currentContract.accountantState.payoutAddress;

    // call function under test
    updateUpper(e, allowedExchangeRateChangeUpper);

    // assign all the 'after' variables
    address currentContract_accountantState_payoutAddress_after = currentContract.accountantState.payoutAddress;

    // verify integrity
    assert (currentContract_accountantState_payoutAddress_after == currentContract_accountantState_payoutAddress_before), "accountantState.payoutAddress@after == accountantState.payoutAddress@before";
}

/*
 * accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before
 *
 * What it means: The feesOwedInBase field in accountantState must remain exactly the same before and after the function call
 *
 * Why it should hold: updateUpper is a configuration function and should not affect pending fee calculations, which are managed by exchange rate updates and fee claiming
 *
 * Possible consequences: Unintended fee changes could cause incorrect fee accounting, leading to over-payment or under-payment of fees
 */
rule updateUpper_634da58f_fees_owed_unchanged(env e) {
    uint16 allowedExchangeRateChangeUpper;

    // assign all the 'before' variables
    uint128 currentContract_accountantState_feesOwedInBase_before = currentContract.accountantState.feesOwedInBase;

    // call function under test
    updateUpper(e, allowedExchangeRateChangeUpper);

    // assign all the 'after' variables
    uint128 currentContract_accountantState_feesOwedInBase_after = currentContract.accountantState.feesOwedInBase;

    // verify integrity
    assert (currentContract_accountantState_feesOwedInBase_after == currentContract_accountantState_feesOwedInBase_before), "accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before";
}

/*
 * accountantState.highwaterMark@after == accountantState.highwaterMark@before
 *
 * What it means: The highwaterMark field in accountantState must remain exactly the same before and after the function call
 *
 * Why it should hold: updateUpper is a configuration function and should not affect the highwater mark used for performance fee calculations, which is managed by exchange rate updates and resetHighwaterMark function
 *
 * Possible consequences: Unintended highwater mark changes could cause incorrect performance fee calculations, either charging fees when not earned or missing fees that should be charged
 */
rule updateUpper_634da58f_highwater_mark_unchanged(env e) {
    uint16 allowedExchangeRateChangeUpper;

    // assign all the 'before' variables
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;

    // call function under test
    updateUpper(e, allowedExchangeRateChangeUpper);

    // assign all the 'after' variables
    uint96 currentContract_accountantState_highwaterMark_after = currentContract.accountantState.highwaterMark;

    // verify integrity
    assert (currentContract_accountantState_highwaterMark_after == currentContract_accountantState_highwaterMark_before), "accountantState.highwaterMark@after == accountantState.highwaterMark@before";
}

/*
 * allowedExchangeRateChangeLower > 1e4 => revert
 *
 * What it means: The function must revert if the allowedExchangeRateChangeLower parameter is greater than 1e4 (10000 basis points or 100%)
 *
 * Why it should hold: Based on the pattern from updateUpper function which has the check 'if (allowedExchangeRateChangeUpper < 1e4) revert AccountantWithRateProviders__UpperBoundTooSmall()', the updateLower function should have a corresponding validation that prevents setting a lower bound that is too large, which would be nonsensical for a lower bound constraint
 *
 * Possible consequences: Setting an invalid lower bound could allow exchange rate updates that violate the intended risk management constraints, potentially leading to incorrect fee calculations or allowing malicious exchange rate manipulations
 */
rule updateLower_207ec0e7_lower_bound_too_large(env e) {
    uint16 allowedExchangeRateChangeLower;

    // assign all the 'before' variables

    // call function under test
    updateLower@withrevert(e, allowedExchangeRateChangeLower);
    bool updateLower_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((allowedExchangeRateChangeLower > (1 * 10 ^ 4)) => updateLower_reverted), "allowedExchangeRateChangeLower > 1e4 => revert";
}

/*
 * allowedExchangeRateChangeLower <= 1e4 => accountantState.allowedExchangeRateChangeLower@after == allowedExchangeRateChangeLower
 *
 * What it means: When the input parameter is valid (≤ 1e4), the function must update the allowedExchangeRateChangeLower field in accountantState to the new value
 *
 * Why it should hold: This is the core functionality of the updateLower function - to update the lower bound parameter when given valid input. The function's purpose is to modify this specific state variable
 *
 * Possible consequences: If the state is not properly updated, the exchange rate validation logic would continue using stale lower bound values, potentially allowing or blocking exchange rate updates incorrectly
 */
rule updateLower_207ec0e7_valid_update_changes_lower(env e) {
    uint16 allowedExchangeRateChangeLower;

    // assign all the 'before' variables

    // call function under test
    updateLower(e, allowedExchangeRateChangeLower);

    // assign all the 'after' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_after = currentContract.accountantState.allowedExchangeRateChangeLower;

    // verify integrity
    assert ((allowedExchangeRateChangeLower <= (1 * 10 ^ 4)) => (currentContract_accountantState_allowedExchangeRateChangeLower_after == allowedExchangeRateChangeLower)), "allowedExchangeRateChangeLower <= 1e4 => accountantState.allowedExchangeRateChangeLower@after == allowedExchangeRateChangeLower";
}

/*
 * allowedExchangeRateChangeLower == accountantState.allowedExchangeRateChangeLower@before => revert
 *
 * What it means: The function must revert if the new allowedExchangeRateChangeLower value is the same as the current value stored in accountantState
 *
 * Why it should hold: Following the NO-OPS MUST REVERT principle, any operation that doesn't change state meaningfully should fail rather than succeed silently. This prevents wasted gas and ensures intentional state changes
 *
 * Possible consequences: Allowing no-op updates wastes gas and can mask bugs where the caller thinks they're making a change but aren't. It also violates the principle of explicit state management
 */
rule updateLower_207ec0e7_no_op_reverts(env e) {
    uint16 allowedExchangeRateChangeLower;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;

    // call function under test
    updateLower@withrevert(e, allowedExchangeRateChangeLower);
    bool updateLower_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((allowedExchangeRateChangeLower == currentContract_accountantState_allowedExchangeRateChangeLower_before) => updateLower_reverted), "allowedExchangeRateChangeLower == accountantState.allowedExchangeRateChangeLower@before => revert";
}

/*
 * allowedExchangeRateChangeLower <= 1e4 && allowedExchangeRateChangeLower != accountantState.allowedExchangeRateChangeLower@before => accountantState.exchangeRate@after == accountantState.exchangeRate@before && accountantState.allowedExchangeRateChangeUpper@after == accountantState.allowedExchangeRateChangeUpper@before
 *
 * What it means: When successfully updating the lower bound, other critical rate-related fields (exchangeRate and allowedExchangeRateChangeUpper) must remain unchanged
 *
 * Why it should hold: The updateLower function should have surgical precision - it should only modify the specific field it's designed to change. Modifying other rate parameters could disrupt the exchange rate system's integrity
 *
 * Possible consequences: Unintended changes to exchange rate or upper bound could immediately affect vault operations, potentially triggering unexpected pausing or allowing invalid rate changes
 */
rule updateLower_207ec0e7_other_fields_unchanged(env e) {
    uint16 allowedExchangeRateChangeLower;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_before = currentContract.accountantState.allowedExchangeRateChangeUpper;

    // call function under test
    updateLower(e, allowedExchangeRateChangeLower);

    // assign all the 'after' variables
    uint96 currentContract_accountantState_exchangeRate_after = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_after = currentContract.accountantState.allowedExchangeRateChangeUpper;

    // verify integrity
    assert (((allowedExchangeRateChangeLower <= (1 * 10 ^ 4)) && (allowedExchangeRateChangeLower != currentContract_accountantState_allowedExchangeRateChangeLower_before)) => ((currentContract_accountantState_exchangeRate_after == currentContract_accountantState_exchangeRate_before) && (currentContract_accountantState_allowedExchangeRateChangeUpper_after == currentContract_accountantState_allowedExchangeRateChangeUpper_before))), "allowedExchangeRateChangeLower <= 1e4 && allowedExchangeRateChangeLower != accountantState.allowedExchangeRateChangeLower@before => accountantState.exchangeRate@after == accountantState.exchangeRate@before && accountantState.allowedExchangeRateChangeUpper@after == accountantState.allowedExchangeRateChangeUpper@before";
}

/*
 * allowedExchangeRateChangeLower <= 1e4 && allowedExchangeRateChangeLower != accountantState.allowedExchangeRateChangeLower@before => accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before && accountantState.platformFee@after == accountantState.platformFee@before && accountantState.performanceFee@after == accountantState.performanceFee@before
 *
 * What it means: When successfully updating the lower bound, all fee-related fields (feesOwedInBase, platformFee, performanceFee) must remain unchanged
 *
 * Why it should hold: Fee parameters and accumulated fees are completely separate from exchange rate bounds. The updateLower function should not affect fee calculations or fee accumulation
 *
 * Possible consequences: Unintended fee changes could result in incorrect fee calculations, loss of accumulated fees, or unexpected fee rate changes that affect vault economics
 */
rule updateLower_207ec0e7_fees_unchanged(env e) {
    uint16 allowedExchangeRateChangeLower;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;
    uint128 currentContract_accountantState_feesOwedInBase_before = currentContract.accountantState.feesOwedInBase;
    uint16 currentContract_accountantState_platformFee_before = currentContract.accountantState.platformFee;
    uint16 currentContract_accountantState_performanceFee_before = currentContract.accountantState.performanceFee;

    // call function under test
    updateLower(e, allowedExchangeRateChangeLower);

    // assign all the 'after' variables
    uint128 currentContract_accountantState_feesOwedInBase_after = currentContract.accountantState.feesOwedInBase;
    uint16 currentContract_accountantState_platformFee_after = currentContract.accountantState.platformFee;
    uint16 currentContract_accountantState_performanceFee_after = currentContract.accountantState.performanceFee;

    // verify integrity
    assert (((allowedExchangeRateChangeLower <= (1 * 10 ^ 4)) && (allowedExchangeRateChangeLower != currentContract_accountantState_allowedExchangeRateChangeLower_before)) => (((currentContract_accountantState_feesOwedInBase_after == currentContract_accountantState_feesOwedInBase_before) && (currentContract_accountantState_platformFee_after == currentContract_accountantState_platformFee_before)) && (currentContract_accountantState_performanceFee_after == currentContract_accountantState_performanceFee_before))), "allowedExchangeRateChangeLower <= 1e4 && allowedExchangeRateChangeLower != accountantState.allowedExchangeRateChangeLower@before => accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before && accountantState.platformFee@after == accountantState.platformFee@before && accountantState.performanceFee@after == accountantState.performanceFee@before";
}

/*
 * allowedExchangeRateChangeLower <= 1e4 && allowedExchangeRateChangeLower != accountantState.allowedExchangeRateChangeLower@before => accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before && accountantState.minimumUpdateDelayInSeconds@after == accountantState.minimumUpdateDelayInSeconds@before
 *
 * What it means: When successfully updating the lower bound, timing-related fields (lastUpdateTimestamp, minimumUpdateDelayInSeconds) must remain unchanged
 *
 * Why it should hold: Timing parameters control when exchange rate updates are allowed and track the last update. These are unrelated to bound configuration and should not be affected by updateLower
 *
 * Possible consequences: Modifying timing fields could disrupt the exchange rate update schedule, potentially allowing too-frequent updates or resetting update history
 */
rule updateLower_207ec0e7_timing_fields_unchanged(env e) {
    uint16 allowedExchangeRateChangeLower;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;
    uint64 currentContract_accountantState_lastUpdateTimestamp_before = currentContract.accountantState.lastUpdateTimestamp;
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_before = currentContract.accountantState.minimumUpdateDelayInSeconds;

    // call function under test
    updateLower(e, allowedExchangeRateChangeLower);

    // assign all the 'after' variables
    uint64 currentContract_accountantState_lastUpdateTimestamp_after = currentContract.accountantState.lastUpdateTimestamp;
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_after = currentContract.accountantState.minimumUpdateDelayInSeconds;

    // verify integrity
    assert (((allowedExchangeRateChangeLower <= (1 * 10 ^ 4)) && (allowedExchangeRateChangeLower != currentContract_accountantState_allowedExchangeRateChangeLower_before)) => ((currentContract_accountantState_lastUpdateTimestamp_after == currentContract_accountantState_lastUpdateTimestamp_before) && (currentContract_accountantState_minimumUpdateDelayInSeconds_after == currentContract_accountantState_minimumUpdateDelayInSeconds_before))), "allowedExchangeRateChangeLower <= 1e4 && allowedExchangeRateChangeLower != accountantState.allowedExchangeRateChangeLower@before => accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before && accountantState.minimumUpdateDelayInSeconds@after == accountantState.minimumUpdateDelayInSeconds@before";
}

/*
 * allowedExchangeRateChangeLower <= 1e4 && allowedExchangeRateChangeLower != accountantState.allowedExchangeRateChangeLower@before => accountantState.payoutAddress@after == accountantState.payoutAddress@before && accountantState.isPaused@after == accountantState.isPaused@before
 *
 * What it means: When successfully updating the lower bound, administrative fields (payoutAddress, isPaused) must remain unchanged
 *
 * Why it should hold: Administrative settings like where fees are paid and the pause state are critical security parameters that should only be changed by their dedicated functions
 *
 * Possible consequences: Unintended changes to admin fields could redirect fees to wrong addresses or unexpectedly pause/unpause the system
 */
rule updateLower_207ec0e7_admin_fields_unchanged(env e) {
    uint16 allowedExchangeRateChangeLower;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;
    address currentContract_accountantState_payoutAddress_before = currentContract.accountantState.payoutAddress;
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;

    // call function under test
    updateLower(e, allowedExchangeRateChangeLower);

    // assign all the 'after' variables
    address currentContract_accountantState_payoutAddress_after = currentContract.accountantState.payoutAddress;
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;

    // verify integrity
    assert (((allowedExchangeRateChangeLower <= (1 * 10 ^ 4)) && (allowedExchangeRateChangeLower != currentContract_accountantState_allowedExchangeRateChangeLower_before)) => ((currentContract_accountantState_payoutAddress_after == currentContract_accountantState_payoutAddress_before) && (currentContract_accountantState_isPaused_after == currentContract_accountantState_isPaused_before))), "allowedExchangeRateChangeLower <= 1e4 && allowedExchangeRateChangeLower != accountantState.allowedExchangeRateChangeLower@before => accountantState.payoutAddress@after == accountantState.payoutAddress@before && accountantState.isPaused@after == accountantState.isPaused@before";
}

/*
 * allowedExchangeRateChangeLower <= 1e4 && allowedExchangeRateChangeLower != accountantState.allowedExchangeRateChangeLower@before => accountantState.highwaterMark@after == accountantState.highwaterMark@before && accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before
 *
 * What it means: When successfully updating the lower bound, performance tracking fields (highwaterMark, totalSharesLastUpdate) must remain unchanged
 *
 * Why it should hold: These fields track performance fee calculations and share supply history. They should only be modified during exchange rate updates or explicit highwater mark resets, not during parameter configuration
 *
 * Possible consequences: Modifying these fields could disrupt performance fee calculations, potentially causing incorrect fee charges or allowing fees to be avoided
 */
rule updateLower_207ec0e7_highwater_shares_unchanged(env e) {
    uint16 allowedExchangeRateChangeLower;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;
    uint128 currentContract_accountantState_totalSharesLastUpdate_before = currentContract.accountantState.totalSharesLastUpdate;

    // call function under test
    updateLower(e, allowedExchangeRateChangeLower);

    // assign all the 'after' variables
    uint96 currentContract_accountantState_highwaterMark_after = currentContract.accountantState.highwaterMark;
    uint128 currentContract_accountantState_totalSharesLastUpdate_after = currentContract.accountantState.totalSharesLastUpdate;

    // verify integrity
    assert (((allowedExchangeRateChangeLower <= (1 * 10 ^ 4)) && (allowedExchangeRateChangeLower != currentContract_accountantState_allowedExchangeRateChangeLower_before)) => ((currentContract_accountantState_highwaterMark_after == currentContract_accountantState_highwaterMark_before) && (currentContract_accountantState_totalSharesLastUpdate_after == currentContract_accountantState_totalSharesLastUpdate_before))), "allowedExchangeRateChangeLower <= 1e4 && allowedExchangeRateChangeLower != accountantState.allowedExchangeRateChangeLower@before => accountantState.highwaterMark@after == accountantState.highwaterMark@before && accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before";
}

/*
 * platformFee > 2000 => revert
 *
 * What it means: The function must revert if the platformFee parameter exceeds 2000 basis points (20%)
 *
 * Why it should hold: Based on the contract pattern seen in updatePerformanceFee which has a similar check (performanceFee > 0.5e4), and the fact that platform fees are typically capped to prevent excessive fee extraction. The 0.2e4 (2000 basis points = 20%) is a reasonable maximum for platform fees in DeFi protocols
 *
 * Possible consequences: Excessive fee extraction leading to fund drainage, making the vault economically unviable for users, potential rug pull scenarios where admins set extremely high platform fees
 */
rule updatePlatformFee_afb06952_fee_too_large_reverts(env e) {
    uint16 platformFee;

    // assign all the 'before' variables

    // call function under test
    updatePlatformFee@withrevert(e, platformFee);
    bool updatePlatformFee_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((platformFee > 2000) => updatePlatformFee_reverted), "platformFee > 2000 => revert";
}

/*
 * platformFee == accountantState.platformFee@before => revert
 *
 * What it means: The function must revert if the new platformFee is identical to the current platformFee stored in accountantState
 *
 * Why it should hold: No-op operations should revert to prevent unnecessary gas consumption and ensure meaningful state changes. This follows the defensive pattern that meaningless operations should fail rather than succeed silently
 *
 * Possible consequences: Gas waste from redundant transactions, potential griefing attacks through repeated no-op calls, unclear transaction intent leading to user confusion
 */
rule updatePlatformFee_afb06952_same_fee_reverts(env e) {
    uint16 platformFee;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_platformFee_before = currentContract.accountantState.platformFee;

    // call function under test
    updatePlatformFee@withrevert(e, platformFee);
    bool updatePlatformFee_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((platformFee == currentContract_accountantState_platformFee_before) => updatePlatformFee_reverted), "platformFee == accountantState.platformFee@before => revert";
}

/*
 * platformFee <= 2000 && platformFee != accountantState.platformFee@before => accountantState.platformFee@after == platformFee
 *
 * What it means: When platformFee is valid (≤2000) and different from current fee, the accountantState.platformFee field must be updated to the new value
 *
 * Why it should hold: This is the core functionality of the function - it must actually update the platform fee when given valid inputs. Without this, the function would not perform its intended purpose
 *
 * Possible consequences: Function appears to work but doesn't update state, leading to incorrect fee calculations, users paying wrong fees, protocol revenue miscalculation
 */
rule updatePlatformFee_afb06952_valid_fee_updates_state(env e) {
    uint16 platformFee;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_platformFee_before = currentContract.accountantState.platformFee;

    // call function under test
    updatePlatformFee(e, platformFee);

    // assign all the 'after' variables
    uint16 currentContract_accountantState_platformFee_after = currentContract.accountantState.platformFee;

    // verify integrity
    assert (((platformFee <= 2000) && (platformFee != currentContract_accountantState_platformFee_before)) => (currentContract_accountantState_platformFee_after == platformFee)), "platformFee <= 2000 && platformFee != accountantState.platformFee@before => accountantState.platformFee@after == platformFee";
}

/*
 * platformFee <= 2000 && platformFee != accountantState.platformFee@before => accountantState.performanceFee@after == accountantState.performanceFee@before && accountantState.exchangeRate@after == accountantState.exchangeRate@before && accountantState.isPaused@after == accountantState.isPaused@before
 *
 * What it means: When updating platform fee successfully, other critical fields in accountantState (performanceFee, exchangeRate, isPaused) must remain unchanged
 *
 * Why it should hold: The function should have surgical precision - only modifying the intended field while preserving all other state. This prevents unintended side effects and maintains system integrity
 *
 * Possible consequences: Unintended state corruption, system instability, incorrect fee calculations, potential pause state manipulation, exchange rate corruption leading to fund loss
 */
rule updatePlatformFee_afb06952_other_fields_unchanged(env e) {
    uint16 platformFee;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_platformFee_before = currentContract.accountantState.platformFee;
    uint16 currentContract_accountantState_performanceFee_before = currentContract.accountantState.performanceFee;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;

    // call function under test
    updatePlatformFee(e, platformFee);

    // assign all the 'after' variables
    uint16 currentContract_accountantState_performanceFee_after = currentContract.accountantState.performanceFee;
    uint96 currentContract_accountantState_exchangeRate_after = currentContract.accountantState.exchangeRate;
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;

    // verify integrity
    assert (((platformFee <= 2000) && (platformFee != currentContract_accountantState_platformFee_before)) => (((currentContract_accountantState_performanceFee_after == currentContract_accountantState_performanceFee_before) && (currentContract_accountantState_exchangeRate_after == currentContract_accountantState_exchangeRate_before)) && (currentContract_accountantState_isPaused_after == currentContract_accountantState_isPaused_before))), "platformFee <= 2000 && platformFee != accountantState.platformFee@before => accountantState.performanceFee@after == accountantState.performanceFee@before && accountantState.exchangeRate@after == accountantState.exchangeRate@before && accountantState.isPaused@after == accountantState.isPaused@before";
}

/*
 * performanceFee > 5000 => revert
 *
 * What it means: The function must revert if the performance fee parameter exceeds 5000 basis points (50%)
 *
 * Why it should hold: Based on the pattern from updatePlatformFee which has a 0.2e4 (2000 basis points) limit, performance fees should have a reasonable upper bound to prevent excessive fee extraction. The 5000 limit (50%) is a reasonable maximum for performance fees in DeFi protocols
 *
 * Possible consequences: Fund drainage through excessive performance fees, making the vault economically unviable for users, potential rug pull vector where admin sets 100% performance fee
 */
rule updatePerformanceFee_709ac1c3_fee_too_large_reverts(env e) {
    uint16 performanceFee;

    // assign all the 'before' variables

    // call function under test
    updatePerformanceFee@withrevert(e, performanceFee);
    bool updatePerformanceFee_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((performanceFee > 5000) => updatePerformanceFee_reverted), "performanceFee > 5000 => revert";
}

/*
 * performanceFee == 0 => accountantState.performanceFee@after == 0
 *
 * What it means: Setting performance fee to zero should be allowed and should update the state to zero
 *
 * Why it should hold: Zero is a valid performance fee value that allows the protocol to operate without performance fees, which is a legitimate business model choice
 *
 * Possible consequences: If zero fees are not allowed, the protocol loses flexibility to operate fee-free during certain periods or for certain strategies
 */
rule updatePerformanceFee_709ac1c3_zero_fee_allowed(env e) {
    uint16 performanceFee;

    // assign all the 'before' variables

    // call function under test
    updatePerformanceFee(e, performanceFee);

    // assign all the 'after' variables
    uint16 currentContract_accountantState_performanceFee_after = currentContract.accountantState.performanceFee;

    // verify integrity
    assert ((performanceFee == 0) => (currentContract_accountantState_performanceFee_after == 0)), "performanceFee == 0 => accountantState.performanceFee@after == 0";
}

/*
 * performanceFee == accountantState.performanceFee@before => revert
 *
 * What it means: The function must revert if the new performance fee is identical to the current performance fee (no-op prevention)
 *
 * Why it should hold: No-op operations waste gas and provide no value. They should be prevented to enforce meaningful state changes and avoid accidental duplicate transactions
 *
 * Possible consequences: Gas waste from meaningless transactions, potential for spam transactions, unclear intent when no actual change occurs
 */
rule updatePerformanceFee_709ac1c3_fee_unchanged_reverts(env e) {
    uint16 performanceFee;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_performanceFee_before = currentContract.accountantState.performanceFee;

    // call function under test
    updatePerformanceFee@withrevert(e, performanceFee);
    bool updatePerformanceFee_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((performanceFee == currentContract_accountantState_performanceFee_before) => updatePerformanceFee_reverted), "performanceFee == accountantState.performanceFee@before => revert";
}

/*
 * performanceFee <= 5000 && performanceFee != accountantState.performanceFee@before => accountantState.performanceFee@after == performanceFee
 *
 * What it means: When performance fee is within valid range and different from current fee, the accountantState.performanceFee should be updated to the new value
 *
 * Why it should hold: This is the core functionality of the function - it must actually update the performance fee when given valid input that represents a real change
 *
 * Possible consequences: Function becomes non-functional, performance fee cannot be adjusted, protocol loses ability to adapt fee structure
 */
rule updatePerformanceFee_709ac1c3_valid_fee_updates_state(env e) {
    uint16 performanceFee;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_performanceFee_before = currentContract.accountantState.performanceFee;

    // call function under test
    updatePerformanceFee(e, performanceFee);

    // assign all the 'after' variables
    uint16 currentContract_accountantState_performanceFee_after = currentContract.accountantState.performanceFee;

    // verify integrity
    assert (((performanceFee <= 5000) && (performanceFee != currentContract_accountantState_performanceFee_before)) => (currentContract_accountantState_performanceFee_after == performanceFee)), "performanceFee <= 5000 && performanceFee != accountantState.performanceFee@before => accountantState.performanceFee@after == performanceFee";
}

/*
 * accountantState.platformFee@after == accountantState.platformFee@before && accountantState.exchangeRate@after == accountantState.exchangeRate@before && accountantState.isPaused@after == accountantState.isPaused@before
 *
 * What it means: The function should only modify the performanceFee field and leave all other accountantState fields unchanged
 *
 * Why it should hold: Function should have minimal side effects and only change what it's intended to change. Modifying other state variables would violate the principle of least surprise and could cause unintended consequences
 *
 * Possible consequences: Unintended state corruption, breaking other protocol functionality, unpredictable behavior when updating performance fees
 */
rule updatePerformanceFee_709ac1c3_other_state_unchanged(env e) {
    uint16 performanceFee;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_platformFee_before = currentContract.accountantState.platformFee;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;

    // call function under test
    updatePerformanceFee(e, performanceFee);

    // assign all the 'after' variables
    uint16 currentContract_accountantState_platformFee_after = currentContract.accountantState.platformFee;
    uint96 currentContract_accountantState_exchangeRate_after = currentContract.accountantState.exchangeRate;
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;

    // verify integrity
    assert (((currentContract_accountantState_platformFee_after == currentContract_accountantState_platformFee_before) && (currentContract_accountantState_exchangeRate_after == currentContract_accountantState_exchangeRate_before)) && (currentContract_accountantState_isPaused_after == currentContract_accountantState_isPaused_before)), "accountantState.platformFee@after == accountantState.platformFee@before && accountantState.exchangeRate@after == accountantState.exchangeRate@before && accountantState.isPaused@after == accountantState.isPaused@before";
}

/*
 * payoutAddress == accountantState.payoutAddress@before => revert
 *
 * What it means: The function must revert if the new payout address is the same as the current payout address
 *
 * Why it should hold: Setting the payout address to its current value is a meaningless operation that wastes gas and provides no functional benefit. Following the NO-OP MUST REVERT principle, such operations should fail to prevent accidental calls and ensure intentional state changes
 *
 * Possible consequences: Gas waste, potential griefing attacks where malicious actors repeatedly call the function with the same address, and unclear intent in transaction logs
 */
rule updatePayoutAddress_56200819_no_op_reverts(env e) {
    address payoutAddress;

    // assign all the 'before' variables
    address currentContract_accountantState_payoutAddress_before = currentContract.accountantState.payoutAddress;

    // call function under test
    updatePayoutAddress@withrevert(e, payoutAddress);
    bool updatePayoutAddress_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((payoutAddress == currentContract_accountantState_payoutAddress_before) => updatePayoutAddress_reverted), "payoutAddress == accountantState.payoutAddress@before => revert";
}

/*
 * payoutAddress == address(0) => revert
 *
 * What it means: The function must revert if the new payout address is the zero address (0x0)
 *
 * Why it should hold: Setting the payout address to zero would make fee collection impossible since fees cannot be sent to the zero address. This would effectively break the fee mechanism and lock fees in the contract permanently
 *
 * Possible consequences: Complete loss of fee collection functionality, permanent locking of accumulated fees in the contract, and inability to recover platform/performance fees
 */
rule updatePayoutAddress_56200819_zero_address_reverts(env e) {
    address payoutAddress;

    // assign all the 'before' variables

    // call function under test
    updatePayoutAddress@withrevert(e, payoutAddress);
    bool updatePayoutAddress_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((payoutAddress == 0) => updatePayoutAddress_reverted), "payoutAddress == address(0) => revert";
}

/*
 * payoutAddress != address(0) && payoutAddress != accountantState.payoutAddress@before => accountantState.payoutAddress@after == payoutAddress
 *
 * What it means: When given a valid non-zero address different from the current one, the function must update the payout address in the accountant state
 *
 * Why it should hold: This is the core functionality of the function - it must actually update the payout address when provided with valid input. This ensures the fee collection mechanism can be properly maintained and updated
 *
 * Possible consequences: If the update fails, fee collection would continue going to the old address, potentially sending fees to compromised or incorrect addresses
 */
rule updatePayoutAddress_56200819_updates_payout_address(env e) {
    address payoutAddress;

    // assign all the 'before' variables
    address currentContract_accountantState_payoutAddress_before = currentContract.accountantState.payoutAddress;

    // call function under test
    updatePayoutAddress(e, payoutAddress);

    // assign all the 'after' variables
    address currentContract_accountantState_payoutAddress_after = currentContract.accountantState.payoutAddress;

    // verify integrity
    assert (((payoutAddress != 0) && (payoutAddress != currentContract_accountantState_payoutAddress_before)) => (currentContract_accountantState_payoutAddress_after == payoutAddress)), "payoutAddress != address(0) && payoutAddress != accountantState.payoutAddress@before => accountantState.payoutAddress@after == payoutAddress";
}

/*
 * accountantState.highwaterMark@after == accountantState.highwaterMark@before
 *
 * What it means: The function must not modify the highwater mark value in the accountant state
 *
 * Why it should hold: The highwater mark tracks the highest exchange rate achieved and is critical for performance fee calculations. Updating the payout address should not affect this financial tracking mechanism
 *
 * Possible consequences: Incorrect performance fee calculations, potential loss of fee revenue, or unfair fee charging to users
 */
rule updatePayoutAddress_56200819_preserves_highwater_mark(env e) {
    address payoutAddress;

    // assign all the 'before' variables
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;

    // call function under test
    updatePayoutAddress(e, payoutAddress);

    // assign all the 'after' variables
    uint96 currentContract_accountantState_highwaterMark_after = currentContract.accountantState.highwaterMark;

    // verify integrity
    assert (currentContract_accountantState_highwaterMark_after == currentContract_accountantState_highwaterMark_before), "accountantState.highwaterMark@after == accountantState.highwaterMark@before";
}

/*
 * accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before
 *
 * What it means: The function must not modify the accumulated fees owed in base currency
 *
 * Why it should hold: The fees owed represent earned but unclaimed revenue. Changing the payout address should not affect the amount of fees that have been calculated and are pending collection
 *
 * Possible consequences: Loss of accumulated fee revenue, incorrect fee accounting, or inability to claim legitimately earned fees
 */
rule updatePayoutAddress_56200819_preserves_fees_owed(env e) {
    address payoutAddress;

    // assign all the 'before' variables
    uint128 currentContract_accountantState_feesOwedInBase_before = currentContract.accountantState.feesOwedInBase;

    // call function under test
    updatePayoutAddress(e, payoutAddress);

    // assign all the 'after' variables
    uint128 currentContract_accountantState_feesOwedInBase_after = currentContract.accountantState.feesOwedInBase;

    // verify integrity
    assert (currentContract_accountantState_feesOwedInBase_after == currentContract_accountantState_feesOwedInBase_before), "accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before";
}

/*
 * accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before
 *
 * What it means: The function must not modify the total shares value used for fee calculations
 *
 * Why it should hold: The total shares from the last update is used in fee calculations to ensure accurate platform and performance fee computation. This value should only be updated during exchange rate updates, not payout address changes
 *
 * Possible consequences: Incorrect fee calculations, potential manipulation of fee amounts, or broken fee accounting logic
 */
rule updatePayoutAddress_56200819_preserves_total_shares(env e) {
    address payoutAddress;

    // assign all the 'before' variables
    uint128 currentContract_accountantState_totalSharesLastUpdate_before = currentContract.accountantState.totalSharesLastUpdate;

    // call function under test
    updatePayoutAddress(e, payoutAddress);

    // assign all the 'after' variables
    uint128 currentContract_accountantState_totalSharesLastUpdate_after = currentContract.accountantState.totalSharesLastUpdate;

    // verify integrity
    assert (currentContract_accountantState_totalSharesLastUpdate_after == currentContract_accountantState_totalSharesLastUpdate_before), "accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before";
}

/*
 * accountantState.exchangeRate@after == accountantState.exchangeRate@before
 *
 * What it means: The function must not modify the current exchange rate stored in the accountant state
 *
 * Why it should hold: The exchange rate is a critical financial parameter that determines the value of vault shares. It should only be updated through the dedicated updateExchangeRate function, not during administrative changes like payout address updates
 *
 * Possible consequences: Incorrect share valuations, broken fee calculations, potential market manipulation, or loss of user funds
 */
rule updatePayoutAddress_56200819_preserves_exchange_rate(env e) {
    address payoutAddress;

    // assign all the 'before' variables
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;

    // call function under test
    updatePayoutAddress(e, payoutAddress);

    // assign all the 'after' variables
    uint96 currentContract_accountantState_exchangeRate_after = currentContract.accountantState.exchangeRate;

    // verify integrity
    assert (currentContract_accountantState_exchangeRate_after == currentContract_accountantState_exchangeRate_before), "accountantState.exchangeRate@after == accountantState.exchangeRate@before";
}

/*
 * accountantState.allowedExchangeRateChangeUpper@after == accountantState.allowedExchangeRateChangeUpper@before && accountantState.allowedExchangeRateChangeLower@after == accountantState.allowedExchangeRateChangeLower@before
 *
 * What it means: The function must not modify the allowed upper and lower bounds for exchange rate changes
 *
 * Why it should hold: These bounds are safety mechanisms that prevent excessive exchange rate changes and protect against manipulation. They should only be updated through dedicated admin functions, not during payout address changes
 *
 * Possible consequences: Removal of safety mechanisms, potential for exchange rate manipulation, or system instability
 */
rule updatePayoutAddress_56200819_preserves_rate_bounds(env e) {
    address payoutAddress;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_before = currentContract.accountantState.allowedExchangeRateChangeUpper;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;

    // call function under test
    updatePayoutAddress(e, payoutAddress);

    // assign all the 'after' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_after = currentContract.accountantState.allowedExchangeRateChangeUpper;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_after = currentContract.accountantState.allowedExchangeRateChangeLower;

    // verify integrity
    assert ((currentContract_accountantState_allowedExchangeRateChangeUpper_after == currentContract_accountantState_allowedExchangeRateChangeUpper_before) && (currentContract_accountantState_allowedExchangeRateChangeLower_after == currentContract_accountantState_allowedExchangeRateChangeLower_before)), "accountantState.allowedExchangeRateChangeUpper@after == accountantState.allowedExchangeRateChangeUpper@before && accountantState.allowedExchangeRateChangeLower@after == accountantState.allowedExchangeRateChangeLower@before";
}

/*
 * accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before
 *
 * What it means: The function must not modify the timestamp of the last exchange rate update
 *
 * Why it should hold: The last update timestamp is used to enforce minimum delays between exchange rate updates and for time-based fee calculations. It should only be updated during actual exchange rate updates
 *
 * Possible consequences: Broken timing controls, incorrect fee calculations, or ability to bypass update delay protections
 */
rule updatePayoutAddress_56200819_preserves_timestamp(env e) {
    address payoutAddress;

    // assign all the 'before' variables
    uint64 currentContract_accountantState_lastUpdateTimestamp_before = currentContract.accountantState.lastUpdateTimestamp;

    // call function under test
    updatePayoutAddress(e, payoutAddress);

    // assign all the 'after' variables
    uint64 currentContract_accountantState_lastUpdateTimestamp_after = currentContract.accountantState.lastUpdateTimestamp;

    // verify integrity
    assert (currentContract_accountantState_lastUpdateTimestamp_after == currentContract_accountantState_lastUpdateTimestamp_before), "accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before";
}

/*
 * accountantState.isPaused@after == accountantState.isPaused@before
 *
 * What it means: The function must not modify whether the contract is paused or unpaused
 *
 * Why it should hold: The pause state is a critical safety mechanism that should only be controlled through dedicated pause/unpause functions. Changing payout addresses should not affect the contract's operational state
 *
 * Possible consequences: Accidental pausing or unpausing of the contract, bypassing safety mechanisms, or operational disruption
 */
rule updatePayoutAddress_56200819_preserves_pause_state(env e) {
    address payoutAddress;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;

    // call function under test
    updatePayoutAddress(e, payoutAddress);

    // assign all the 'after' variables
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;

    // verify integrity
    assert (currentContract_accountantState_isPaused_after == currentContract_accountantState_isPaused_before), "accountantState.isPaused@after == accountantState.isPaused@before";
}

/*
 * accountantState.minimumUpdateDelayInSeconds@after == accountantState.minimumUpdateDelayInSeconds@before
 *
 * What it means: The function must not modify the minimum delay required between exchange rate updates
 *
 * Why it should hold: The minimum update delay is a safety mechanism that prevents too-frequent exchange rate updates. This parameter should only be changed through the dedicated updateDelay function
 *
 * Possible consequences: Removal of rate limiting protections, potential for exchange rate manipulation, or system instability
 */
rule updatePayoutAddress_56200819_preserves_delay(env e) {
    address payoutAddress;

    // assign all the 'before' variables
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_before = currentContract.accountantState.minimumUpdateDelayInSeconds;

    // call function under test
    updatePayoutAddress(e, payoutAddress);

    // assign all the 'after' variables
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_after = currentContract.accountantState.minimumUpdateDelayInSeconds;

    // verify integrity
    assert (currentContract_accountantState_minimumUpdateDelayInSeconds_after == currentContract_accountantState_minimumUpdateDelayInSeconds_before), "accountantState.minimumUpdateDelayInSeconds@after == accountantState.minimumUpdateDelayInSeconds@before";
}

/*
 * accountantState.platformFee@after == accountantState.platformFee@before && accountantState.performanceFee@after == accountantState.performanceFee@before
 *
 * What it means: The function must not modify the platform fee and performance fee percentages
 *
 * Why it should hold: Fee percentages are critical economic parameters that determine protocol revenue. They should only be updated through dedicated fee update functions with proper validation, not during payout address changes
 *
 * Possible consequences: Incorrect fee collection, loss of protocol revenue, or unfair charging of users
 */
rule updatePayoutAddress_56200819_preserves_fees(env e) {
    address payoutAddress;

    // assign all the 'before' variables
    uint16 currentContract_accountantState_platformFee_before = currentContract.accountantState.platformFee;
    uint16 currentContract_accountantState_performanceFee_before = currentContract.accountantState.performanceFee;

    // call function under test
    updatePayoutAddress(e, payoutAddress);

    // assign all the 'after' variables
    uint16 currentContract_accountantState_platformFee_after = currentContract.accountantState.platformFee;
    uint16 currentContract_accountantState_performanceFee_after = currentContract.accountantState.performanceFee;

    // verify integrity
    assert ((currentContract_accountantState_platformFee_after == currentContract_accountantState_platformFee_before) && (currentContract_accountantState_performanceFee_after == currentContract_accountantState_performanceFee_before)), "accountantState.platformFee@after == accountantState.platformFee@before && accountantState.performanceFee@after == accountantState.performanceFee@before";
}

/*
 * owner@after == owner@before
 *
 * What it means: The function must not modify the contract owner address
 *
 * Why it should hold: The owner has critical administrative privileges and should only be changed through dedicated ownership transfer mechanisms. Payout address updates should not affect ownership
 *
 * Possible consequences: Accidental ownership transfer, loss of administrative control, or unauthorized privilege escalation
 */
rule updatePayoutAddress_56200819_preserves_owner(env e) {
    address payoutAddress;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;

    // call function under test
    updatePayoutAddress(e, payoutAddress);

    // assign all the 'after' variables
    address currentContract_owner_after = currentContract.owner;

    // verify integrity
    assert (currentContract_owner_after == currentContract_owner_before), "owner@after == owner@before";
}

/*
 * authority@after == authority@before
 *
 * What it means: The function must not modify the authority contract address used for access control
 *
 * Why it should hold: The authority contract manages access control permissions and should only be changed through dedicated authority management functions. Payout address updates should not affect the access control system
 *
 * Possible consequences: Broken access control, unauthorized privilege escalation, or loss of permission management
 */
rule updatePayoutAddress_56200819_preserves_authority(env e) {
    address payoutAddress;

    // assign all the 'before' variables
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    updatePayoutAddress(e, payoutAddress);

    // assign all the 'after' variables
    address currentContract_authority_after = currentContract.authority;

    // verify integrity
    assert (currentContract_authority_after == currentContract_authority_before), "authority@after == authority@before";
}

/*
 * msg.sender != owner@before => revert
 *
 * What it means: The function must revert if called by anyone other than the contract owner
 *
 * Why it should hold: This function configures critical rate provider data that affects exchange rate calculations. The contract inherits from Auth and uses requiresAuth modifier, indicating only authorized users should modify this sensitive configuration
 *
 * Possible consequences: Unauthorized configuration changes leading to incorrect exchange rates, manipulation of fee calculations, or complete system compromise
 */
rule setRateProviderData_4d8be07e_unauthorized_reverts(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;

    // call function under test
    setRateProviderData@withrevert(e, asset, isPeggedToBase, rateProvider);
    bool setRateProviderData_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((e.msg.sender != currentContract_owner_before) => setRateProviderData_reverted), "msg.sender != owner@before => revert";
}

/*
 * accountantState.isPaused@before => revert
 *
 * What it means: The function must revert if the contract is in a paused state
 *
 * Why it should hold: When paused, the contract should prevent all configuration changes to maintain system stability. Other functions like getRateSafe explicitly check pause state and revert
 *
 * Possible consequences: Configuration changes during emergency pause could worsen the situation that caused the pause or interfere with recovery procedures
 */
rule setRateProviderData_4d8be07e_paused_reverts(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;

    // call function under test
    setRateProviderData@withrevert(e, asset, isPeggedToBase, rateProvider);
    bool setRateProviderData_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (currentContract_accountantState_isPaused_before => setRateProviderData_reverted), "accountantState.isPaused@before => revert";
}

/*
 * rateProviderData[asset].isPeggedToBase@before == isPeggedToBase && rateProviderData[asset].rateProvider@before == IRateProvider(rateProvider) => revert
 *
 * What it means: The function must revert if both the isPeggedToBase flag and rateProvider address are unchanged from their current values
 *
 * Why it should hold: No-op operations waste gas and indicate potential bugs or misuse. If nothing changes, the operation serves no purpose and should be rejected
 *
 * Possible consequences: Gas waste, potential indication of buggy calling code, or attempts to trigger events without actual state changes
 */
rule setRateProviderData_4d8be07e_no_op_reverts(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_rateProviderData_asset__isPeggedToBase_before = currentContract.rateProviderData[asset].isPeggedToBase;
    address currentContract_rateProviderData_asset__rateProvider_before = currentContract.rateProviderData[asset].rateProvider;

    // call function under test
    setRateProviderData@withrevert(e, asset, isPeggedToBase, rateProvider);
    bool setRateProviderData_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((currentContract_rateProviderData_asset__isPeggedToBase_before == isPeggedToBase) && (currentContract_rateProviderData_asset__rateProvider_before == rateProvider)) => setRateProviderData_reverted), "rateProviderData[asset].isPeggedToBase@before == isPeggedToBase && rateProviderData[asset].rateProvider@before == IRateProvider(rateProvider) => revert";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before && (rateProviderData[asset].isPeggedToBase@before != isPeggedToBase || rateProviderData[asset].rateProvider@before != IRateProvider(rateProvider)) => rateProviderData[asset].isPeggedToBase@after == isPeggedToBase
 *
 * What it means: When authorized and not paused, if there's an actual change in configuration, the isPeggedToBase flag must be updated to the provided value
 *
 * Why it should hold: This ensures the function actually performs its intended state change when called with valid parameters. The isPeggedToBase flag is critical for rate calculations
 *
 * Possible consequences: Function appears to succeed but doesn't update state, leading to incorrect rate calculations and potential fund loss
 */
rule setRateProviderData_4d8be07e_updates_pegged_status(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;
    bool currentContract_rateProviderData_asset__isPeggedToBase_before = currentContract.rateProviderData[asset].isPeggedToBase;
    address currentContract_rateProviderData_asset__rateProvider_before = currentContract.rateProviderData[asset].rateProvider;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    bool currentContract_rateProviderData_asset__isPeggedToBase_after = currentContract.rateProviderData[asset].isPeggedToBase;

    // verify integrity
    assert (((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) && ((currentContract_rateProviderData_asset__isPeggedToBase_before != isPeggedToBase) || (currentContract_rateProviderData_asset__rateProvider_before != rateProvider))) => (currentContract_rateProviderData_asset__isPeggedToBase_after == isPeggedToBase)), "!accountantState.isPaused@before && msg.sender == owner@before && (rateProviderData[asset].isPeggedToBase@before != isPeggedToBase || rateProviderData[asset].rateProvider@before != IRateProvider(rateProvider)) => rateProviderData[asset].isPeggedToBase@after == isPeggedToBase";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before && (rateProviderData[asset].isPeggedToBase@before != isPeggedToBase || rateProviderData[asset].rateProvider@before != IRateProvider(rateProvider)) => rateProviderData[asset].rateProvider@after == IRateProvider(rateProvider)
 *
 * What it means: When authorized and not paused, if there's an actual change in configuration, the rateProvider address must be updated to the provided value
 *
 * Why it should hold: This ensures the rate provider address is properly updated when the function is called with valid parameters. The rate provider is essential for non-pegged assets
 *
 * Possible consequences: Function appears to succeed but uses old rate provider, leading to stale or incorrect rates and potential arbitrage opportunities
 */
rule setRateProviderData_4d8be07e_updates_rate_provider(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;
    bool currentContract_rateProviderData_asset__isPeggedToBase_before = currentContract.rateProviderData[asset].isPeggedToBase;
    address currentContract_rateProviderData_asset__rateProvider_before = currentContract.rateProviderData[asset].rateProvider;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    address currentContract_rateProviderData_asset__rateProvider_after = currentContract.rateProviderData[asset].rateProvider;

    // verify integrity
    assert (((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) && ((currentContract_rateProviderData_asset__isPeggedToBase_before != isPeggedToBase) || (currentContract_rateProviderData_asset__rateProvider_before != rateProvider))) => (currentContract_rateProviderData_asset__rateProvider_after == rateProvider)), "!accountantState.isPaused@before && msg.sender == owner@before && (rateProviderData[asset].isPeggedToBase@before != isPeggedToBase || rateProviderData[asset].rateProvider@before != IRateProvider(rateProvider)) => rateProviderData[asset].rateProvider@after == IRateProvider(rateProvider)";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before && otherAsset != asset => rateProviderData[otherAsset].isPeggedToBase@after == rateProviderData[otherAsset].isPeggedToBase@before
 *
 * What it means: When updating rate provider data for one asset, the isPeggedToBase status of all other assets must remain unchanged
 *
 * Why it should hold: The function should only modify the specific asset being configured, not affect other assets' configurations. This prevents unintended side effects
 *
 * Possible consequences: Unintended changes to other assets' pegged status could cause incorrect rate calculations across multiple assets
 */
rule setRateProviderData_4d8be07e_preserves_other_pegged_status(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;
    address otherAsset;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;
    bool currentContract_rateProviderData_otherAsset__isPeggedToBase_before = currentContract.rateProviderData[otherAsset].isPeggedToBase;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    bool currentContract_rateProviderData_otherAsset__isPeggedToBase_after = currentContract.rateProviderData[otherAsset].isPeggedToBase;

    // verify integrity
    assert (((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) && (otherAsset != asset)) => (currentContract_rateProviderData_otherAsset__isPeggedToBase_after == currentContract_rateProviderData_otherAsset__isPeggedToBase_before)), "!accountantState.isPaused@before && msg.sender == owner@before && otherAsset != asset => rateProviderData[otherAsset].isPeggedToBase@after == rateProviderData[otherAsset].isPeggedToBase@before";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before && otherAsset != asset => rateProviderData[otherAsset].rateProvider@after == rateProviderData[otherAsset].rateProvider@before
 *
 * What it means: When updating rate provider data for one asset, the rateProvider addresses of all other assets must remain unchanged
 *
 * Why it should hold: The function should only modify the specific asset being configured, ensuring other assets continue using their correct rate providers
 *
 * Possible consequences: Other assets could start using wrong rate providers, leading to incorrect exchange rates and arbitrage opportunities
 */
rule setRateProviderData_4d8be07e_preserves_other_rate_provider(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;
    address otherAsset;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;
    address currentContract_rateProviderData_otherAsset__rateProvider_before = currentContract.rateProviderData[otherAsset].rateProvider;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    address currentContract_rateProviderData_otherAsset__rateProvider_after = currentContract.rateProviderData[otherAsset].rateProvider;

    // verify integrity
    assert (((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) && (otherAsset != asset)) => (currentContract_rateProviderData_otherAsset__rateProvider_after == currentContract_rateProviderData_otherAsset__rateProvider_before)), "!accountantState.isPaused@before && msg.sender == owner@before && otherAsset != asset => rateProviderData[otherAsset].rateProvider@after == rateProviderData[otherAsset].rateProvider@before";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before => accountantState.payoutAddress@after == accountantState.payoutAddress@before
 *
 * What it means: The function must not modify the payout address where fees are sent
 *
 * Why it should hold: setRateProviderData should only affect rate provider configuration, not fee-related settings. Unintended changes could redirect fees
 *
 * Possible consequences: Fees could be redirected to wrong address, causing fund loss for intended recipients
 */
rule setRateProviderData_4d8be07e_preserves_payout_address(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;
    address currentContract_accountantState_payoutAddress_before = currentContract.accountantState.payoutAddress;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    address currentContract_accountantState_payoutAddress_after = currentContract.accountantState.payoutAddress;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) => (currentContract_accountantState_payoutAddress_after == currentContract_accountantState_payoutAddress_before)), "!accountantState.isPaused@before && msg.sender == owner@before => accountantState.payoutAddress@after == accountantState.payoutAddress@before";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before => accountantState.highwaterMark@after == accountantState.highwaterMark@before
 *
 * What it means: The function must not modify the highwater mark used for performance fee calculations
 *
 * Why it should hold: Rate provider configuration should not affect fee calculation parameters. Changes could disrupt performance fee logic
 *
 * Possible consequences: Performance fees could be calculated incorrectly, either overcharging or undercharging users
 */
rule setRateProviderData_4d8be07e_preserves_highwater_mark(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    uint96 currentContract_accountantState_highwaterMark_after = currentContract.accountantState.highwaterMark;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) => (currentContract_accountantState_highwaterMark_after == currentContract_accountantState_highwaterMark_before)), "!accountantState.isPaused@before && msg.sender == owner@before => accountantState.highwaterMark@after == accountantState.highwaterMark@before";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before => accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before
 *
 * What it means: The function must not modify the accumulated fees owed in base currency
 *
 * Why it should hold: Rate provider configuration should not affect pending fee balances. Changes could cause fee loss or incorrect accounting
 *
 * Possible consequences: Pending fees could be lost or incorrectly modified, affecting fee recipients' expected payments
 */
rule setRateProviderData_4d8be07e_preserves_fees_owed(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;
    uint128 currentContract_accountantState_feesOwedInBase_before = currentContract.accountantState.feesOwedInBase;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    uint128 currentContract_accountantState_feesOwedInBase_after = currentContract.accountantState.feesOwedInBase;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) => (currentContract_accountantState_feesOwedInBase_after == currentContract_accountantState_feesOwedInBase_before)), "!accountantState.isPaused@before && msg.sender == owner@before => accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before => accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before
 *
 * What it means: The function must not modify the total shares count from the last update
 *
 * Why it should hold: This value is used for fee calculations and should only be updated during exchange rate updates, not rate provider configuration
 *
 * Possible consequences: Fee calculations could become incorrect if the share count baseline is modified unexpectedly
 */
rule setRateProviderData_4d8be07e_preserves_total_shares(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;
    uint128 currentContract_accountantState_totalSharesLastUpdate_before = currentContract.accountantState.totalSharesLastUpdate;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    uint128 currentContract_accountantState_totalSharesLastUpdate_after = currentContract.accountantState.totalSharesLastUpdate;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) => (currentContract_accountantState_totalSharesLastUpdate_after == currentContract_accountantState_totalSharesLastUpdate_before)), "!accountantState.isPaused@before && msg.sender == owner@before => accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before => accountantState.exchangeRate@after == accountantState.exchangeRate@before
 *
 * What it means: The function must not modify the current exchange rate
 *
 * Why it should hold: Exchange rates should only be updated through dedicated updateExchangeRate function, not through rate provider configuration
 *
 * Possible consequences: Unintended exchange rate changes could cause immediate arbitrage opportunities or break rate update logic
 */
rule setRateProviderData_4d8be07e_preserves_exchange_rate(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    uint96 currentContract_accountantState_exchangeRate_after = currentContract.accountantState.exchangeRate;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) => (currentContract_accountantState_exchangeRate_after == currentContract_accountantState_exchangeRate_before)), "!accountantState.isPaused@before && msg.sender == owner@before => accountantState.exchangeRate@after == accountantState.exchangeRate@before";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before => accountantState.allowedExchangeRateChangeUpper@after == accountantState.allowedExchangeRateChangeUpper@before
 *
 * What it means: The function must not modify the upper bound limit for exchange rate changes
 *
 * Why it should hold: Rate change bounds are critical safety parameters that should only be modified through dedicated functions, not rate provider configuration
 *
 * Possible consequences: Safety limits could be compromised, allowing dangerous exchange rate updates that should trigger pausing
 */
rule setRateProviderData_4d8be07e_preserves_upper_bound(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_before = currentContract.accountantState.allowedExchangeRateChangeUpper;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_after = currentContract.accountantState.allowedExchangeRateChangeUpper;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) => (currentContract_accountantState_allowedExchangeRateChangeUpper_after == currentContract_accountantState_allowedExchangeRateChangeUpper_before)), "!accountantState.isPaused@before && msg.sender == owner@before => accountantState.allowedExchangeRateChangeUpper@after == accountantState.allowedExchangeRateChangeUpper@before";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before => accountantState.allowedExchangeRateChangeLower@after == accountantState.allowedExchangeRateChangeLower@before
 *
 * What it means: The function must not modify the lower bound limit for exchange rate changes
 *
 * Why it should hold: Rate change bounds are safety parameters that protect against extreme rate movements and should not be affected by rate provider configuration
 *
 * Possible consequences: Safety limits could be compromised, allowing dangerous exchange rate drops that should trigger pausing
 */
rule setRateProviderData_4d8be07e_preserves_lower_bound(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_after = currentContract.accountantState.allowedExchangeRateChangeLower;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) => (currentContract_accountantState_allowedExchangeRateChangeLower_after == currentContract_accountantState_allowedExchangeRateChangeLower_before)), "!accountantState.isPaused@before && msg.sender == owner@before => accountantState.allowedExchangeRateChangeLower@after == accountantState.allowedExchangeRateChangeLower@before";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before => accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before
 *
 * What it means: The function must not modify the timestamp of the last exchange rate update
 *
 * Why it should hold: Update timestamps are used to enforce minimum delays between rate updates and should only be modified during actual rate updates
 *
 * Possible consequences: Rate update timing controls could be bypassed, allowing rapid rate manipulation
 */
rule setRateProviderData_4d8be07e_preserves_last_update(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;
    uint64 currentContract_accountantState_lastUpdateTimestamp_before = currentContract.accountantState.lastUpdateTimestamp;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    uint64 currentContract_accountantState_lastUpdateTimestamp_after = currentContract.accountantState.lastUpdateTimestamp;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) => (currentContract_accountantState_lastUpdateTimestamp_after == currentContract_accountantState_lastUpdateTimestamp_before)), "!accountantState.isPaused@before && msg.sender == owner@before => accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before => accountantState.isPaused@after == accountantState.isPaused@before
 *
 * What it means: The function must not modify whether the contract is paused or not
 *
 * Why it should hold: Pause state should only be controlled through dedicated pause/unpause functions, not through rate provider configuration
 *
 * Possible consequences: Unintended pause state changes could disrupt operations or bypass emergency controls
 */
rule setRateProviderData_4d8be07e_preserves_pause_state(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) => (currentContract_accountantState_isPaused_after == currentContract_accountantState_isPaused_before)), "!accountantState.isPaused@before && msg.sender == owner@before => accountantState.isPaused@after == accountantState.isPaused@before";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before => accountantState.minimumUpdateDelayInSeconds@after == accountantState.minimumUpdateDelayInSeconds@before
 *
 * What it means: The function must not modify the minimum delay required between exchange rate updates
 *
 * Why it should hold: Update delays are safety parameters that prevent rapid rate manipulation and should only be modified through dedicated functions
 *
 * Possible consequences: Safety delays could be bypassed, enabling rapid rate manipulation attacks
 */
rule setRateProviderData_4d8be07e_preserves_update_delay(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_before = currentContract.accountantState.minimumUpdateDelayInSeconds;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_after = currentContract.accountantState.minimumUpdateDelayInSeconds;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) => (currentContract_accountantState_minimumUpdateDelayInSeconds_after == currentContract_accountantState_minimumUpdateDelayInSeconds_before)), "!accountantState.isPaused@before && msg.sender == owner@before => accountantState.minimumUpdateDelayInSeconds@after == accountantState.minimumUpdateDelayInSeconds@before";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before => accountantState.platformFee@after == accountantState.platformFee@before
 *
 * What it means: The function must not modify the platform fee percentage
 *
 * Why it should hold: Fee parameters should only be modified through dedicated fee update functions, not through rate provider configuration
 *
 * Possible consequences: Unintended fee changes could cause incorrect fee calculations or loss of expected revenue
 */
rule setRateProviderData_4d8be07e_preserves_platform_fee(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;
    uint16 currentContract_accountantState_platformFee_before = currentContract.accountantState.platformFee;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    uint16 currentContract_accountantState_platformFee_after = currentContract.accountantState.platformFee;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) => (currentContract_accountantState_platformFee_after == currentContract_accountantState_platformFee_before)), "!accountantState.isPaused@before && msg.sender == owner@before => accountantState.platformFee@after == accountantState.platformFee@before";
}

/*
 * !accountantState.isPaused@before && msg.sender == owner@before => accountantState.performanceFee@after == accountantState.performanceFee@before
 *
 * What it means: The function must not modify the performance fee percentage
 *
 * Why it should hold: Fee parameters should only be modified through dedicated fee update functions, not through rate provider configuration
 *
 * Possible consequences: Unintended performance fee changes could cause incorrect fee calculations or unexpected charges to users
 */
rule setRateProviderData_4d8be07e_preserves_performance_fee(env e) {
    address asset;
    bool isPeggedToBase;
    address rateProvider;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_owner_before = currentContract.owner;
    uint16 currentContract_accountantState_performanceFee_before = currentContract.accountantState.performanceFee;

    // call function under test
    setRateProviderData(e, asset, isPeggedToBase, rateProvider);

    // assign all the 'after' variables
    uint16 currentContract_accountantState_performanceFee_after = currentContract.accountantState.performanceFee;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (e.msg.sender == currentContract_owner_before)) => (currentContract_accountantState_performanceFee_after == currentContract_accountantState_performanceFee_before)), "!accountantState.isPaused@before && msg.sender == owner@before => accountantState.performanceFee@after == accountantState.performanceFee@before";
}

/*
 * accountantState.isPaused@before => revert
 *
 * What it means: The function must revert if the contract is in a paused state
 *
 * Why it should hold: Based on the contract pattern, paused state prevents critical operations. The function modifies important fee calculation state (highwater mark) which should be blocked when paused for safety
 *
 * Possible consequences: State corruption during emergency situations, bypassing pause protection mechanisms, unauthorized state modifications during maintenance
 */
rule resetHighwaterMark_e059ac07_paused_reverts(env e) {

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;

    // call function under test
    resetHighwaterMark@withrevert(e);
    bool resetHighwaterMark_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (currentContract_accountantState_isPaused_before => resetHighwaterMark_reverted), "accountantState.isPaused@before => revert";
}

/*
 * !accountantState.isPaused@before => accountantState.highwaterMark@after == accountantState.exchangeRate@before
 *
 * What it means: When not paused, the function must set the highwater mark equal to the current exchange rate
 *
 * Why it should hold: This is the core functionality of resetHighwaterMark - it should reset the performance fee baseline to the current exchange rate. This is evident from the function name and the contract's fee calculation logic
 *
 * Possible consequences: Broken fee calculation mechanism, incorrect performance fee collection, loss of fee revenue
 */
rule resetHighwaterMark_e059ac07_sets_highwater_to_rate(env e) {

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;

    // call function under test
    resetHighwaterMark(e);

    // assign all the 'after' variables
    uint96 currentContract_accountantState_highwaterMark_after = currentContract.accountantState.highwaterMark;

    // verify integrity
    assert (!(currentContract_accountantState_isPaused_before) => (currentContract_accountantState_highwaterMark_after == currentContract_accountantState_exchangeRate_before)), "!accountantState.isPaused@before => accountantState.highwaterMark@after == accountantState.exchangeRate@before";
}

/*
 * accountantState.exchangeRate@before < accountantState.highwaterMark@before => revert
 *
 * What it means: The function must revert if the current exchange rate is below the existing highwater mark
 *
 * Why it should hold: Resetting highwater mark to a lower value would be economically nonsensical and could be used to manipulate performance fees. Highwater marks should only move up or reset to current rate when appropriate
 *
 * Possible consequences: Performance fee manipulation, economic attacks on fee structure, loss of protocol revenue
 */
rule resetHighwaterMark_e059ac07_rate_below_highwater_reverts(env e) {

    // assign all the 'before' variables
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;

    // call function under test
    resetHighwaterMark@withrevert(e);
    bool resetHighwaterMark_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_accountantState_exchangeRate_before < currentContract_accountantState_highwaterMark_before) => resetHighwaterMark_reverted), "accountantState.exchangeRate@before < accountantState.highwaterMark@before => revert";
}

/*
 * accountantState.exchangeRate@before == accountantState.highwaterMark@before => revert
 *
 * What it means: The function must revert if the current exchange rate equals the existing highwater mark (no-op scenario)
 *
 * Why it should hold: Following the NO-OPS MUST REVERT rule - if the operation would result in no actual change to state, it should revert rather than waste gas and potentially mask bugs
 *
 * Possible consequences: Gas waste, potential masking of logic errors, unclear contract behavior
 */
rule resetHighwaterMark_e059ac07_no_change_reverts(env e) {

    // assign all the 'before' variables
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;

    // call function under test
    resetHighwaterMark@withrevert(e);
    bool resetHighwaterMark_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_accountantState_exchangeRate_before == currentContract_accountantState_highwaterMark_before) => resetHighwaterMark_reverted), "accountantState.exchangeRate@before == accountantState.highwaterMark@before => revert";
}

/*
 * !accountantState.isPaused@before && accountantState.exchangeRate@before > accountantState.highwaterMark@before => accountantState.exchangeRate@after == accountantState.exchangeRate@before
 *
 * What it means: The function must not modify the current exchange rate when executing successfully
 *
 * Why it should hold: resetHighwaterMark should only affect the highwater mark, not the exchange rate. The exchange rate represents current vault value and should only be changed by updateExchangeRate function
 *
 * Possible consequences: Incorrect vault valuation, broken exchange rate mechanism, fund loss or gain
 */
rule resetHighwaterMark_e059ac07_exchange_rate_unchanged(env e) {

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;

    // call function under test
    resetHighwaterMark(e);

    // assign all the 'after' variables
    uint96 currentContract_accountantState_exchangeRate_after = currentContract.accountantState.exchangeRate;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (currentContract_accountantState_exchangeRate_before > currentContract_accountantState_highwaterMark_before)) => (currentContract_accountantState_exchangeRate_after == currentContract_accountantState_exchangeRate_before)), "!accountantState.isPaused@before && accountantState.exchangeRate@before > accountantState.highwaterMark@before => accountantState.exchangeRate@after == accountantState.exchangeRate@before";
}

/*
 * !accountantState.isPaused@before && accountantState.exchangeRate@before > accountantState.highwaterMark@before => accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before
 *
 * What it means: The function must not modify the amount of fees currently owed when executing successfully
 *
 * Why it should hold: resetHighwaterMark should only reset the performance fee baseline, not affect already accrued fees. Existing fee obligations should remain intact
 *
 * Possible consequences: Loss of accrued fees, incorrect fee accounting, revenue loss for protocol
 */
rule resetHighwaterMark_e059ac07_fees_owed_unchanged(env e) {

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;
    uint128 currentContract_accountantState_feesOwedInBase_before = currentContract.accountantState.feesOwedInBase;

    // call function under test
    resetHighwaterMark(e);

    // assign all the 'after' variables
    uint128 currentContract_accountantState_feesOwedInBase_after = currentContract.accountantState.feesOwedInBase;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (currentContract_accountantState_exchangeRate_before > currentContract_accountantState_highwaterMark_before)) => (currentContract_accountantState_feesOwedInBase_after == currentContract_accountantState_feesOwedInBase_before)), "!accountantState.isPaused@before && accountantState.exchangeRate@before > accountantState.highwaterMark@before => accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before";
}

/*
 * !accountantState.isPaused@before && accountantState.exchangeRate@before > accountantState.highwaterMark@before => accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before
 *
 * What it means: The function must not modify the total shares from the last update when executing successfully
 *
 * Why it should hold: resetHighwaterMark should only affect highwater mark, not the share tracking used for fee calculations. This value is critical for platform fee calculations
 *
 * Possible consequences: Incorrect platform fee calculations, broken fee accounting, revenue loss or overcharging
 */
rule resetHighwaterMark_e059ac07_total_shares_unchanged(env e) {

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;
    uint128 currentContract_accountantState_totalSharesLastUpdate_before = currentContract.accountantState.totalSharesLastUpdate;

    // call function under test
    resetHighwaterMark(e);

    // assign all the 'after' variables
    uint128 currentContract_accountantState_totalSharesLastUpdate_after = currentContract.accountantState.totalSharesLastUpdate;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (currentContract_accountantState_exchangeRate_before > currentContract_accountantState_highwaterMark_before)) => (currentContract_accountantState_totalSharesLastUpdate_after == currentContract_accountantState_totalSharesLastUpdate_before)), "!accountantState.isPaused@before && accountantState.exchangeRate@before > accountantState.highwaterMark@before => accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before";
}

/*
 * !accountantState.isPaused@before && accountantState.exchangeRate@before > accountantState.highwaterMark@before => accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before
 *
 * What it means: The function must not modify the last update timestamp when executing successfully
 *
 * Why it should hold: resetHighwaterMark should only affect highwater mark, not the timing mechanism used for fee calculations and update delays. The timestamp is critical for platform fee time-based calculations
 *
 * Possible consequences: Incorrect time-based fee calculations, bypassing update delay protections, broken fee accounting
 */
rule resetHighwaterMark_e059ac07_timestamp_unchanged(env e) {

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;
    uint64 currentContract_accountantState_lastUpdateTimestamp_before = currentContract.accountantState.lastUpdateTimestamp;

    // call function under test
    resetHighwaterMark(e);

    // assign all the 'after' variables
    uint64 currentContract_accountantState_lastUpdateTimestamp_after = currentContract.accountantState.lastUpdateTimestamp;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (currentContract_accountantState_exchangeRate_before > currentContract_accountantState_highwaterMark_before)) => (currentContract_accountantState_lastUpdateTimestamp_after == currentContract_accountantState_lastUpdateTimestamp_before)), "!accountantState.isPaused@before && accountantState.exchangeRate@before > accountantState.highwaterMark@before => accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before";
}

/*
 * !accountantState.isPaused@before && accountantState.exchangeRate@before > accountantState.highwaterMark@before => accountantState.isPaused@after == accountantState.isPaused@before
 *
 * What it means: The function must not modify the paused state of the contract when executing successfully
 *
 * Why it should hold: resetHighwaterMark should only affect highwater mark, not the contract's pause state. Pause state should only be controlled by dedicated pause/unpause functions
 *
 * Possible consequences: Unauthorized state changes, bypassing access controls, breaking pause mechanism
 */
rule resetHighwaterMark_e059ac07_paused_state_unchanged(env e) {

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;

    // call function under test
    resetHighwaterMark(e);

    // assign all the 'after' variables
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;

    // verify integrity
    assert ((!(currentContract_accountantState_isPaused_before) && (currentContract_accountantState_exchangeRate_before > currentContract_accountantState_highwaterMark_before)) => (currentContract_accountantState_isPaused_after == currentContract_accountantState_isPaused_before)), "!accountantState.isPaused@before && accountantState.exchangeRate@before > accountantState.highwaterMark@before => accountantState.isPaused@after == accountantState.isPaused@before";
}

/*
 * accountantState.isPaused@before => revert
 *
 * What it means: If the contract is already paused, any call to updateExchangeRate must revert
 *
 * Why it should hold: The contract has a pause mechanism for emergency situations. When paused, no exchange rate updates should be allowed to prevent further damage or manipulation during crisis situations
 *
 * Possible consequences: If this fails, attackers could continue manipulating exchange rates even during emergency pauses, leading to continued fund drainage or price manipulation
 */
rule updateExchangeRate_3458113d_paused_reverts(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;

    // call function under test
    updateExchangeRate@withrevert(e, newExchangeRate);
    bool updateExchangeRate_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (currentContract_accountantState_isPaused_before => updateExchangeRate_reverted), "accountantState.isPaused@before => revert";
}

/*
 * msg.sender != owner@before => revert
 *
 * What it means: Only the authorized owner can call updateExchangeRate, all other callers must be rejected
 *
 * Why it should hold: Exchange rate updates directly affect vault valuation and fee calculations. This is a critical privileged operation that must be restricted to authorized entities only
 *
 * Possible consequences: Unauthorized users could manipulate exchange rates to steal funds, avoid fees, or cause incorrect vault valuations
 */
rule updateExchangeRate_3458113d_no_auth_reverts(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;

    // call function under test
    updateExchangeRate@withrevert(e, newExchangeRate);
    bool updateExchangeRate_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((e.msg.sender != currentContract_owner_before) => updateExchangeRate_reverted), "msg.sender != owner@before => revert";
}

/*
 * newExchangeRate > accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeUpper@before / 10000 => accountantState.isPaused@after
 *
 * What it means: If the new exchange rate exceeds the allowed upper bound, the contract must be paused as a safety mechanism
 *
 * Why it should hold: Large upward rate changes could indicate manipulation or oracle failures. The contract should pause to prevent exploitation until the situation is investigated
 *
 * Possible consequences: Without this protection, malicious or erroneous large rate increases could lead to incorrect fee calculations and vault overvaluation
 */
rule updateExchangeRate_3458113d_rate_too_high_pauses(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_before = currentContract.accountantState.allowedExchangeRateChangeUpper;

    // call function under test
    updateExchangeRate(e, newExchangeRate);

    // assign all the 'after' variables
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;

    // verify integrity
    assert ((newExchangeRate > currentContract_accountantState_exchangeRate_before * currentContract_accountantState_allowedExchangeRateChangeUpper_before / 10000) => currentContract_accountantState_isPaused_after), "newExchangeRate > accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeUpper@before / 10000 => accountantState.isPaused@after";
}

/*
 * newExchangeRate < accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeLower@before / 10000 => accountantState.isPaused@after
 *
 * What it means: If the new exchange rate falls below the allowed lower bound, the contract must be paused as a safety mechanism
 *
 * Why it should hold: Large downward rate changes could indicate manipulation, oracle failures, or attacks. Pausing prevents further damage until the issue is resolved
 *
 * Possible consequences: Without this protection, malicious rate decreases could undervalue the vault, allowing attackers to acquire shares at unfair prices
 */
rule updateExchangeRate_3458113d_rate_too_low_pauses(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;

    // call function under test
    updateExchangeRate(e, newExchangeRate);

    // assign all the 'after' variables
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;

    // verify integrity
    assert ((newExchangeRate < currentContract_accountantState_exchangeRate_before * currentContract_accountantState_allowedExchangeRateChangeLower_before / 10000) => currentContract_accountantState_isPaused_after), "newExchangeRate < accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeLower@before / 10000 => accountantState.isPaused@after";
}

/*
 * block.timestamp < accountantState.lastUpdateTimestamp@before + accountantState.minimumUpdateDelayInSeconds@before => accountantState.isPaused@after
 *
 * What it means: If an update is attempted before the minimum delay period has passed, the contract must pause to prevent rapid manipulation
 *
 * Why it should hold: The minimum delay prevents rapid-fire rate updates that could be used for manipulation or to avoid proper fee calculations between updates
 *
 * Possible consequences: Without delay enforcement, attackers could rapidly update rates to manipulate fee calculations or exploit timing-based vulnerabilities
 */
rule updateExchangeRate_3458113d_update_too_soon_pauses(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    uint64 currentContract_accountantState_lastUpdateTimestamp_before = currentContract.accountantState.lastUpdateTimestamp;
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_before = currentContract.accountantState.minimumUpdateDelayInSeconds;

    // call function under test
    updateExchangeRate(e, newExchangeRate);

    // assign all the 'after' variables
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;

    // verify integrity
    assert ((e.block.timestamp < currentContract_accountantState_lastUpdateTimestamp_before + currentContract_accountantState_minimumUpdateDelayInSeconds_before) => currentContract_accountantState_isPaused_after), "block.timestamp < accountantState.lastUpdateTimestamp@before + accountantState.minimumUpdateDelayInSeconds@before => accountantState.isPaused@after";
}

/*
 * !accountantState.isPaused@before && block.timestamp >= accountantState.lastUpdateTimestamp@before + accountantState.minimumUpdateDelayInSeconds@before && newExchangeRate <= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeUpper@before / 10000 && newExchangeRate >= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeLower@before / 10000 => accountantState.exchangeRate@after == newExchangeRate
 *
 * What it means: When all conditions are met (not paused, sufficient time passed, rate within bounds), the exchange rate must be updated to the new value
 *
 * Why it should hold: This ensures that legitimate rate updates actually take effect when they should, maintaining the core functionality of the exchange rate mechanism
 *
 * Possible consequences: If valid updates don't set the rate, the exchange rate becomes stale, leading to incorrect vault valuations and fee calculations
 */
rule updateExchangeRate_3458113d_valid_update_sets_rate(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint64 currentContract_accountantState_lastUpdateTimestamp_before = currentContract.accountantState.lastUpdateTimestamp;
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_before = currentContract.accountantState.minimumUpdateDelayInSeconds;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_before = currentContract.accountantState.allowedExchangeRateChangeUpper;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;

    // call function under test
    updateExchangeRate(e, newExchangeRate);

    // assign all the 'after' variables
    uint96 currentContract_accountantState_exchangeRate_after = currentContract.accountantState.exchangeRate;

    // verify integrity
    assert ((((!(currentContract_accountantState_isPaused_before) && (e.block.timestamp >= currentContract_accountantState_lastUpdateTimestamp_before + currentContract_accountantState_minimumUpdateDelayInSeconds_before)) && (newExchangeRate <= currentContract_accountantState_exchangeRate_before * currentContract_accountantState_allowedExchangeRateChangeUpper_before / 10000)) && (newExchangeRate >= currentContract_accountantState_exchangeRate_before * currentContract_accountantState_allowedExchangeRateChangeLower_before / 10000)) => (currentContract_accountantState_exchangeRate_after == newExchangeRate)), "!accountantState.isPaused@before && block.timestamp >= accountantState.lastUpdateTimestamp@before + accountantState.minimumUpdateDelayInSeconds@before && newExchangeRate <= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeUpper@before / 10000 && newExchangeRate >= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeLower@before / 10000 => accountantState.exchangeRate@after == newExchangeRate";
}

/*
 * !accountantState.isPaused@before && block.timestamp >= accountantState.lastUpdateTimestamp@before + accountantState.minimumUpdateDelayInSeconds@before && newExchangeRate <= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeUpper@before / 10000 && newExchangeRate >= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeLower@before / 10000 => accountantState.lastUpdateTimestamp@after == block.timestamp
 *
 * What it means: When a valid update occurs, the last update timestamp must be set to the current block timestamp
 *
 * Why it should hold: Accurate timestamps are crucial for fee calculations and enforcing minimum delays between updates
 *
 * Possible consequences: Incorrect timestamps could break fee calculations, allow bypassing of update delays, or cause timing-based vulnerabilities
 */
rule updateExchangeRate_3458113d_valid_update_timestamp(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint64 currentContract_accountantState_lastUpdateTimestamp_before = currentContract.accountantState.lastUpdateTimestamp;
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_before = currentContract.accountantState.minimumUpdateDelayInSeconds;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_before = currentContract.accountantState.allowedExchangeRateChangeUpper;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;

    // call function under test
    updateExchangeRate(e, newExchangeRate);

    // assign all the 'after' variables
    uint64 currentContract_accountantState_lastUpdateTimestamp_after = currentContract.accountantState.lastUpdateTimestamp;

    // verify integrity
    assert ((((!(currentContract_accountantState_isPaused_before) && (e.block.timestamp >= currentContract_accountantState_lastUpdateTimestamp_before + currentContract_accountantState_minimumUpdateDelayInSeconds_before)) && (newExchangeRate <= currentContract_accountantState_exchangeRate_before * currentContract_accountantState_allowedExchangeRateChangeUpper_before / 10000)) && (newExchangeRate >= currentContract_accountantState_exchangeRate_before * currentContract_accountantState_allowedExchangeRateChangeLower_before / 10000)) => (currentContract_accountantState_lastUpdateTimestamp_after == e.block.timestamp)), "!accountantState.isPaused@before && block.timestamp >= accountantState.lastUpdateTimestamp@before + accountantState.minimumUpdateDelayInSeconds@before && newExchangeRate <= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeUpper@before / 10000 && newExchangeRate >= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeLower@before / 10000 => accountantState.lastUpdateTimestamp@after == block.timestamp";
}

/*
 * !accountantState.isPaused@before && block.timestamp >= accountantState.lastUpdateTimestamp@before + accountantState.minimumUpdateDelayInSeconds@before && newExchangeRate <= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeUpper@before / 10000 && newExchangeRate >= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeLower@before / 10000 => accountantState.totalSharesLastUpdate@after == vault.totalSupply()@after
 *
 * What it means: When a valid update occurs, the recorded total shares must be updated to the current vault total supply
 *
 * Why it should hold: Share count is used in fee calculations. It must be current to ensure fees are calculated correctly based on the actual share supply
 *
 * Possible consequences: Stale share counts lead to incorrect fee calculations, potentially allowing fee avoidance or causing excessive fee charges
 */
rule updateExchangeRate_3458113d_valid_update_shares(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint64 currentContract_accountantState_lastUpdateTimestamp_before = currentContract.accountantState.lastUpdateTimestamp;
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_before = currentContract.accountantState.minimumUpdateDelayInSeconds;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_before = currentContract.accountantState.allowedExchangeRateChangeUpper;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;

    // call function under test
    updateExchangeRate(e, newExchangeRate);

    // assign all the 'after' variables
    uint128 currentContract_accountantState_totalSharesLastUpdate_after = currentContract.accountantState.totalSharesLastUpdate;
    uint256 currentContract_vault_totalSupply_e__after = currentContract.vault.totalSupply(e);

    // verify integrity
    assert ((((!(currentContract_accountantState_isPaused_before) && (e.block.timestamp >= currentContract_accountantState_lastUpdateTimestamp_before + currentContract_accountantState_minimumUpdateDelayInSeconds_before)) && (newExchangeRate <= currentContract_accountantState_exchangeRate_before * currentContract_accountantState_allowedExchangeRateChangeUpper_before / 10000)) && (newExchangeRate >= currentContract_accountantState_exchangeRate_before * currentContract_accountantState_allowedExchangeRateChangeLower_before / 10000)) => (currentContract_accountantState_totalSharesLastUpdate_after == currentContract_vault_totalSupply_e__after)), "!accountantState.isPaused@before && block.timestamp >= accountantState.lastUpdateTimestamp@before + accountantState.minimumUpdateDelayInSeconds@before && newExchangeRate <= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeUpper@before / 10000 && newExchangeRate >= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeLower@before / 10000 => accountantState.totalSharesLastUpdate@after == vault.totalSupply()@after";
}

/*
 * !accountantState.isPaused@before && block.timestamp >= accountantState.lastUpdateTimestamp@before + accountantState.minimumUpdateDelayInSeconds@before && newExchangeRate <= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeUpper@before / 10000 && newExchangeRate >= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeLower@before / 10000 && newExchangeRate > accountantState.highwaterMark@before => accountantState.highwaterMark@after == newExchangeRate
 *
 * What it means: When the new exchange rate exceeds the current highwater mark, the highwater mark must be updated to the new rate
 *
 * Why it should hold: The highwater mark is used for performance fee calculations. It must track the highest rate achieved to ensure performance fees are only charged on actual gains
 *
 * Possible consequences: If highwater mark doesn't update, performance fees could be charged multiple times on the same gains or not charged when they should be
 */
rule updateExchangeRate_3458113d_highwater_increases(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint64 currentContract_accountantState_lastUpdateTimestamp_before = currentContract.accountantState.lastUpdateTimestamp;
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_before = currentContract.accountantState.minimumUpdateDelayInSeconds;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_before = currentContract.accountantState.allowedExchangeRateChangeUpper;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;

    // call function under test
    updateExchangeRate(e, newExchangeRate);

    // assign all the 'after' variables
    uint96 currentContract_accountantState_highwaterMark_after = currentContract.accountantState.highwaterMark;

    // verify integrity
    assert (((((!(currentContract_accountantState_isPaused_before) && (e.block.timestamp >= currentContract_accountantState_lastUpdateTimestamp_before + currentContract_accountantState_minimumUpdateDelayInSeconds_before)) && (newExchangeRate <= currentContract_accountantState_exchangeRate_before * currentContract_accountantState_allowedExchangeRateChangeUpper_before / 10000)) && (newExchangeRate >= currentContract_accountantState_exchangeRate_before * currentContract_accountantState_allowedExchangeRateChangeLower_before / 10000)) && (newExchangeRate > currentContract_accountantState_highwaterMark_before)) => (currentContract_accountantState_highwaterMark_after == newExchangeRate)), "!accountantState.isPaused@before && block.timestamp >= accountantState.lastUpdateTimestamp@before + accountantState.minimumUpdateDelayInSeconds@before && newExchangeRate <= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeUpper@before / 10000 && newExchangeRate >= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeLower@before / 10000 && newExchangeRate > accountantState.highwaterMark@before => accountantState.highwaterMark@after == newExchangeRate";
}

/*
 * !accountantState.isPaused@before && block.timestamp >= accountantState.lastUpdateTimestamp@before + accountantState.minimumUpdateDelayInSeconds@before && newExchangeRate <= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeUpper@before / 10000 && newExchangeRate >= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeLower@before / 10000 && newExchangeRate <= accountantState.highwaterMark@before => accountantState.highwaterMark@after == accountantState.highwaterMark@before
 *
 * What it means: When the new exchange rate is at or below the current highwater mark, the highwater mark must remain unchanged
 *
 * Why it should hold: Performance fees should only be charged when the rate exceeds previous highs. The highwater mark must not decrease to prevent incorrect fee calculations
 *
 * Possible consequences: If highwater mark changes when it shouldn't, performance fees could be incorrectly calculated, leading to overcharging or undercharging
 */
rule updateExchangeRate_3458113d_highwater_unchanged(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint64 currentContract_accountantState_lastUpdateTimestamp_before = currentContract.accountantState.lastUpdateTimestamp;
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_before = currentContract.accountantState.minimumUpdateDelayInSeconds;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_before = currentContract.accountantState.allowedExchangeRateChangeUpper;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;

    // call function under test
    updateExchangeRate(e, newExchangeRate);

    // assign all the 'after' variables
    uint96 currentContract_accountantState_highwaterMark_after = currentContract.accountantState.highwaterMark;

    // verify integrity
    assert (((((!(currentContract_accountantState_isPaused_before) && (e.block.timestamp >= currentContract_accountantState_lastUpdateTimestamp_before + currentContract_accountantState_minimumUpdateDelayInSeconds_before)) && (newExchangeRate <= currentContract_accountantState_exchangeRate_before * currentContract_accountantState_allowedExchangeRateChangeUpper_before / 10000)) && (newExchangeRate >= currentContract_accountantState_exchangeRate_before * currentContract_accountantState_allowedExchangeRateChangeLower_before / 10000)) && (newExchangeRate <= currentContract_accountantState_highwaterMark_before)) => (currentContract_accountantState_highwaterMark_after == currentContract_accountantState_highwaterMark_before)), "!accountantState.isPaused@before && block.timestamp >= accountantState.lastUpdateTimestamp@before + accountantState.minimumUpdateDelayInSeconds@before && newExchangeRate <= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeUpper@before / 10000 && newExchangeRate >= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeLower@before / 10000 && newExchangeRate <= accountantState.highwaterMark@before => accountantState.highwaterMark@after == accountantState.highwaterMark@before";
}

/*
 * !accountantState.isPaused@before && block.timestamp >= accountantState.lastUpdateTimestamp@before + accountantState.minimumUpdateDelayInSeconds@before && newExchangeRate <= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeUpper@before / 10000 && newExchangeRate >= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeLower@before / 10000 => accountantState.feesOwedInBase@after >= accountantState.feesOwedInBase@before
 *
 * What it means: Valid updates must never decrease the total fees owed, they can only increase or stay the same
 *
 * Why it should hold: Fees accumulate over time and should never be reduced by rate updates. This ensures fee integrity and prevents fee manipulation
 *
 * Possible consequences: If fees can decrease during updates, attackers could manipulate rates to reduce their fee obligations
 */
rule updateExchangeRate_3458113d_fees_increase_or_same(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint64 currentContract_accountantState_lastUpdateTimestamp_before = currentContract.accountantState.lastUpdateTimestamp;
    uint24 currentContract_accountantState_minimumUpdateDelayInSeconds_before = currentContract.accountantState.minimumUpdateDelayInSeconds;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;
    uint16 currentContract_accountantState_allowedExchangeRateChangeUpper_before = currentContract.accountantState.allowedExchangeRateChangeUpper;
    uint16 currentContract_accountantState_allowedExchangeRateChangeLower_before = currentContract.accountantState.allowedExchangeRateChangeLower;
    uint128 currentContract_accountantState_feesOwedInBase_before = currentContract.accountantState.feesOwedInBase;

    // call function under test
    updateExchangeRate(e, newExchangeRate);

    // assign all the 'after' variables
    uint128 currentContract_accountantState_feesOwedInBase_after = currentContract.accountantState.feesOwedInBase;

    // verify integrity
    assert ((((!(currentContract_accountantState_isPaused_before) && (e.block.timestamp >= currentContract_accountantState_lastUpdateTimestamp_before + currentContract_accountantState_minimumUpdateDelayInSeconds_before)) && (newExchangeRate <= currentContract_accountantState_exchangeRate_before * currentContract_accountantState_allowedExchangeRateChangeUpper_before / 10000)) && (newExchangeRate >= currentContract_accountantState_exchangeRate_before * currentContract_accountantState_allowedExchangeRateChangeLower_before / 10000)) => (currentContract_accountantState_feesOwedInBase_after >= currentContract_accountantState_feesOwedInBase_before)), "!accountantState.isPaused@before && block.timestamp >= accountantState.lastUpdateTimestamp@before + accountantState.minimumUpdateDelayInSeconds@before && newExchangeRate <= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeUpper@before / 10000 && newExchangeRate >= accountantState.exchangeRate@before * accountantState.allowedExchangeRateChangeLower@before / 10000 => accountantState.feesOwedInBase@after >= accountantState.feesOwedInBase@before";
}

/*
 * accountantState.isPaused@after && !accountantState.isPaused@before => accountantState.exchangeRate@after == accountantState.exchangeRate@before
 *
 * What it means: When the contract gets paused due to invalid conditions, the exchange rate must remain unchanged
 *
 * Why it should hold: Pausing should preserve the current state to prevent further damage. The rate should not change when pausing occurs
 *
 * Possible consequences: If rate changes during pause, it could worsen the situation that caused the pause or create additional manipulation opportunities
 */
rule updateExchangeRate_3458113d_pause_preserves_rate(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint96 currentContract_accountantState_exchangeRate_before = currentContract.accountantState.exchangeRate;

    // call function under test
    updateExchangeRate(e, newExchangeRate);

    // assign all the 'after' variables
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;
    uint96 currentContract_accountantState_exchangeRate_after = currentContract.accountantState.exchangeRate;

    // verify integrity
    assert ((currentContract_accountantState_isPaused_after && !(currentContract_accountantState_isPaused_before)) => (currentContract_accountantState_exchangeRate_after == currentContract_accountantState_exchangeRate_before)), "accountantState.isPaused@after && !accountantState.isPaused@before => accountantState.exchangeRate@after == accountantState.exchangeRate@before";
}

/*
 * accountantState.isPaused@after && !accountantState.isPaused@before => accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before
 *
 * What it means: When the contract gets paused, the accumulated fees owed must remain unchanged
 *
 * Why it should hold: Pausing should freeze the state including fee obligations. Fees shouldn't change when the contract is being protected by pause
 *
 * Possible consequences: If fees change during pause, it could allow fee manipulation or loss of accumulated fees during emergency situations
 */
rule updateExchangeRate_3458113d_pause_preserves_fees(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint128 currentContract_accountantState_feesOwedInBase_before = currentContract.accountantState.feesOwedInBase;

    // call function under test
    updateExchangeRate(e, newExchangeRate);

    // assign all the 'after' variables
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;
    uint128 currentContract_accountantState_feesOwedInBase_after = currentContract.accountantState.feesOwedInBase;

    // verify integrity
    assert ((currentContract_accountantState_isPaused_after && !(currentContract_accountantState_isPaused_before)) => (currentContract_accountantState_feesOwedInBase_after == currentContract_accountantState_feesOwedInBase_before)), "accountantState.isPaused@after && !accountantState.isPaused@before => accountantState.feesOwedInBase@after == accountantState.feesOwedInBase@before";
}

/*
 * accountantState.isPaused@after && !accountantState.isPaused@before => accountantState.highwaterMark@after == accountantState.highwaterMark@before
 *
 * What it means: When the contract gets paused, the highwater mark must remain unchanged
 *
 * Why it should hold: The highwater mark is critical for performance fee calculations and should be preserved during pause to maintain fee calculation integrity
 *
 * Possible consequences: If highwater mark changes during pause, future performance fee calculations could be incorrect
 */
rule updateExchangeRate_3458113d_pause_preserves_highwater(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint96 currentContract_accountantState_highwaterMark_before = currentContract.accountantState.highwaterMark;

    // call function under test
    updateExchangeRate(e, newExchangeRate);

    // assign all the 'after' variables
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;
    uint96 currentContract_accountantState_highwaterMark_after = currentContract.accountantState.highwaterMark;

    // verify integrity
    assert ((currentContract_accountantState_isPaused_after && !(currentContract_accountantState_isPaused_before)) => (currentContract_accountantState_highwaterMark_after == currentContract_accountantState_highwaterMark_before)), "accountantState.isPaused@after && !accountantState.isPaused@before => accountantState.highwaterMark@after == accountantState.highwaterMark@before";
}

/*
 * accountantState.isPaused@after && !accountantState.isPaused@before => accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before
 *
 * What it means: When the contract gets paused, the last update timestamp must remain unchanged
 *
 * Why it should hold: Timestamp preservation during pause ensures that when operations resume, the timing constraints and fee calculations remain accurate
 *
 * Possible consequences: If timestamp changes during pause, it could affect delay calculations and fee computations when the contract resumes
 */
rule updateExchangeRate_3458113d_pause_preserves_timestamp(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint64 currentContract_accountantState_lastUpdateTimestamp_before = currentContract.accountantState.lastUpdateTimestamp;

    // call function under test
    updateExchangeRate(e, newExchangeRate);

    // assign all the 'after' variables
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;
    uint64 currentContract_accountantState_lastUpdateTimestamp_after = currentContract.accountantState.lastUpdateTimestamp;

    // verify integrity
    assert ((currentContract_accountantState_isPaused_after && !(currentContract_accountantState_isPaused_before)) => (currentContract_accountantState_lastUpdateTimestamp_after == currentContract_accountantState_lastUpdateTimestamp_before)), "accountantState.isPaused@after && !accountantState.isPaused@before => accountantState.lastUpdateTimestamp@after == accountantState.lastUpdateTimestamp@before";
}

/*
 * accountantState.isPaused@after && !accountantState.isPaused@before => accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before
 *
 * What it means: When the contract gets paused, the recorded total shares count must remain unchanged
 *
 * Why it should hold: Share count is used in fee calculations and should be preserved during pause to maintain calculation accuracy when operations resume
 *
 * Possible consequences: If share count changes during pause, fee calculations could be incorrect when the contract resumes operation
 */
rule updateExchangeRate_3458113d_pause_preserves_shares(env e) {
    uint96 newExchangeRate;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    uint128 currentContract_accountantState_totalSharesLastUpdate_before = currentContract.accountantState.totalSharesLastUpdate;

    // call function under test
    updateExchangeRate(e, newExchangeRate);

    // assign all the 'after' variables
    bool currentContract_accountantState_isPaused_after = currentContract.accountantState.isPaused;
    uint128 currentContract_accountantState_totalSharesLastUpdate_after = currentContract.accountantState.totalSharesLastUpdate;

    // verify integrity
    assert ((currentContract_accountantState_isPaused_after && !(currentContract_accountantState_isPaused_before)) => (currentContract_accountantState_totalSharesLastUpdate_after == currentContract_accountantState_totalSharesLastUpdate_before)), "accountantState.isPaused@after && !accountantState.isPaused@before => accountantState.totalSharesLastUpdate@after == accountantState.totalSharesLastUpdate@before";
}

/*
 * msg.sender != address(vault) => revert
 *
 * What it means: The claimFees function can only be called by the vault contract address, any other caller must cause a revert
 *
 * Why it should hold: The devdoc explicitly states 'This function must be called by the BoringVault' and this is a critical access control requirement. The vault is the only entity that should be able to trigger fee claims as it manages the overall system state
 *
 * Possible consequences: Unauthorized fee claiming leading to fund drainage, manipulation of fee accounting, potential reentrancy attacks if arbitrary callers can trigger fee transfers
 */
rule claimFees_15a0ea6a_only_vault_can_call(env e) {
    address feeAsset;

    // assign all the 'before' variables

    // call function under test
    claimFees@withrevert(e, feeAsset);
    bool claimFees_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((e.msg.sender != currentContract.vault) => claimFees_reverted), "msg.sender != address(vault) => revert";
}

/*
 * accountantState.feesOwedInBase@before == 0 => revert
 *
 * What it means: If there are no fees owed (feesOwedInBase equals zero), the function must revert rather than performing a no-op
 *
 * Why it should hold: This follows the NO-OPS MUST REVERT principle. If no fees are owed, there's no meaningful work to do, so the function should fail rather than pretend to claim zero fees
 *
 * Possible consequences: Gas waste from meaningless transactions, potential confusion in fee accounting, masking of bugs where fee calculation logic fails to accumulate fees properly
 */
rule claimFees_15a0ea6a_no_fees_revert(env e) {
    address feeAsset;

    // assign all the 'before' variables
    uint128 currentContract_accountantState_feesOwedInBase_before = currentContract.accountantState.feesOwedInBase;

    // call function under test
    claimFees@withrevert(e, feeAsset);
    bool claimFees_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_accountantState_feesOwedInBase_before == 0) => claimFees_reverted), "accountantState.feesOwedInBase@before == 0 => revert";
}

/*
 * accountantState.isPaused@before => revert
 *
 * What it means: If the contract is in a paused state, the claimFees function must revert and not allow any fee claiming operations
 *
 * Why it should hold: The contract has a pause mechanism for emergency situations. When paused, critical operations like fee claiming should be disabled to prevent potential issues during emergency states or maintenance
 *
 * Possible consequences: Bypassing emergency pause controls, allowing fee operations during critical system failures, potential fund loss during emergency situations
 */
rule claimFees_15a0ea6a_paused_revert(env e) {
    address feeAsset;

    // assign all the 'before' variables
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;

    // call function under test
    claimFees@withrevert(e, feeAsset);
    bool claimFees_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (currentContract_accountantState_isPaused_before => claimFees_reverted), "accountantState.isPaused@before => revert";
}

/*
 * accountantState.feesOwedInBase@before > 0 && msg.sender == address(vault) && !accountantState.isPaused@before => accountantState.feesOwedInBase@after == 0
 *
 * What it means: When fees are successfully claimed (fees > 0, called by vault, not paused), the feesOwedInBase counter must be reset to zero after the operation
 *
 * Why it should hold: This ensures proper fee accounting - once fees are claimed and transferred out, the internal counter must be reset to prevent double-claiming and maintain accurate accounting of what fees are still owed
 *
 * Possible consequences: Double-spending of fees, accounting corruption, infinite fee claiming leading to fund drainage beyond what was actually earned
 */
rule claimFees_15a0ea6a_fees_reset_after_claim(env e) {
    address feeAsset;

    // assign all the 'before' variables
    uint128 currentContract_accountantState_feesOwedInBase_before = currentContract.accountantState.feesOwedInBase;
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;

    // call function under test
    claimFees(e, feeAsset);

    // assign all the 'after' variables
    uint128 currentContract_accountantState_feesOwedInBase_after = currentContract.accountantState.feesOwedInBase;

    // verify integrity
    assert ((((currentContract_accountantState_feesOwedInBase_before > 0) && (e.msg.sender == currentContract.vault)) && !(currentContract_accountantState_isPaused_before)) => (currentContract_accountantState_feesOwedInBase_after == 0)), "accountantState.feesOwedInBase@before > 0 && msg.sender == address(vault) && !accountantState.isPaused@before => accountantState.feesOwedInBase@after == 0";
}

/*
 * accountantState.feesOwedInBase@before > 0 && msg.sender == address(vault) && !accountantState.isPaused@before => feeAsset.balanceOf(accountantState.payoutAddress@before)@after > feeAsset.balanceOf(accountantState.payoutAddress@before)@before
 *
 * What it means: When fees are successfully claimed, the payout address must receive an increase in the fee asset balance, confirming that fees were actually transferred
 *
 * Why it should hold: This ensures the core functionality works - claiming fees must actually result in the designated payout address receiving the fee tokens. Without this, the fee claiming mechanism would be broken
 *
 * Possible consequences: Fee claiming that doesn't actually transfer funds, broken fee distribution mechanism, loss of earned fees
 */
rule claimFees_15a0ea6a_payout_receives_fees(env e) {
    address feeAsset;

    // assign all the 'before' variables
    uint128 currentContract_accountantState_feesOwedInBase_before = currentContract.accountantState.feesOwedInBase;
    bool currentContract_accountantState_isPaused_before = currentContract.accountantState.isPaused;
    address currentContract_accountantState_payoutAddress_before = currentContract.accountantState.payoutAddress;
    uint256 feeAsset_balanceOf_e__currentContract_accountantState_payoutAddress_before__before = feeAsset.balanceOf(e, currentContract_accountantState_payoutAddress_before);

    // call function under test
    claimFees(e, feeAsset);

    // assign all the 'after' variables
    uint256 feeAsset_balanceOf_e__currentContract_accountantState_payoutAddress_before__after = feeAsset.balanceOf(e, currentContract_accountantState_payoutAddress_before);

    // verify integrity
    assert ((((currentContract_accountantState_feesOwedInBase_before > 0) && (e.msg.sender == currentContract.vault)) && !(currentContract_accountantState_isPaused_before)) => (feeAsset_balanceOf_e__currentContract_accountantState_payoutAddress_before__after > feeAsset_balanceOf_e__currentContract_accountantState_payoutAddress_before__before)), "accountantState.feesOwedInBase@before > 0 && msg.sender == address(vault) && !accountantState.isPaused@before => feeAsset.balanceOf(accountantState.payoutAddress@before)@after > feeAsset.balanceOf(accountantState.payoutAddress@before)@before";
}