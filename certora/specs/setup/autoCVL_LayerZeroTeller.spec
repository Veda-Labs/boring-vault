import "dispatching_LayerZeroTeller.spec";

/*
 * messageGasLimit == 0 => revert
 *
 * What it means: The function must revert when messageGasLimit parameter is zero
 *
 * Why it should hold: Based on the error LayerZeroTeller__ZeroMessageGasLimit and similar checks in other functions like allowMessagesToChain and setChainGasLimit, zero gas limits are explicitly forbidden as they would make cross-chain messaging impossible
 *
 * Possible consequences: Chain configuration with zero gas limit would break cross-chain messaging functionality, causing all bridge operations to that chain to fail silently or with unclear errors
 */
rule addChain_34dafd6b_zero_gas_limit_reverts(env e) {
    uint32 chainId;
    bool allowMessagesFrom;
    bool allowMessagesTo;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables

    // call function under test
    addChain@withrevert(e, chainId, allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit);
    bool addChain_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((messageGasLimit == 0) => addChain_reverted), "messageGasLimit == 0 => revert";
}

/*
 * messageGasLimit > 0 => idToChains[chainId].allowMessagesFrom@after == allowMessagesFrom
 *
 * What it means: When messageGasLimit is greater than zero, the allowMessagesFrom flag for the specified chainId must be set to the provided allowMessagesFrom parameter value
 *
 * Why it should hold: This is the core functionality of addChain - it must properly configure whether messages from the specified chain are allowed, which is essential for cross-chain security and functionality
 *
 * Possible consequences: Incorrect allowMessagesFrom configuration could either block legitimate cross-chain messages or allow unauthorized messages from untrusted chains
 */
rule addChain_34dafd6b_chain_messages_from_set(env e) {
    uint32 chainId;
    bool allowMessagesFrom;
    bool allowMessagesTo;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables

    // call function under test
    addChain(e, chainId, allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_after = currentContract.idToChains[chainId].allowMessagesFrom;

    // verify integrity
    assert ((messageGasLimit > 0) => (currentContract_idToChains_chainId__allowMessagesFrom_after == allowMessagesFrom)), "messageGasLimit > 0 => idToChains[chainId].allowMessagesFrom@after == allowMessagesFrom";
}

/*
 * messageGasLimit > 0 => idToChains[chainId].allowMessagesTo@after == allowMessagesTo
 *
 * What it means: When messageGasLimit is greater than zero, the allowMessagesTo flag for the specified chainId must be set to the provided allowMessagesTo parameter value
 *
 * Why it should hold: This configures whether the contract allows sending messages to the specified chain, which is fundamental for outbound cross-chain operations and must be set correctly for proper bridge functionality
 *
 * Possible consequences: Incorrect allowMessagesTo configuration could prevent users from bridging shares to intended destination chains or allow bridging to unauthorized/unsafe chains
 */
rule addChain_34dafd6b_chain_messages_to_set(env e) {
    uint32 chainId;
    bool allowMessagesFrom;
    bool allowMessagesTo;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables

    // call function under test
    addChain(e, chainId, allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_after = currentContract.idToChains[chainId].allowMessagesTo;

    // verify integrity
    assert ((messageGasLimit > 0) => (currentContract_idToChains_chainId__allowMessagesTo_after == allowMessagesTo)), "messageGasLimit > 0 => idToChains[chainId].allowMessagesTo@after == allowMessagesTo";
}

/*
 * messageGasLimit > 0 => idToChains[chainId].messageGasLimit@after == messageGasLimit
 *
 * What it means: When messageGasLimit is greater than zero, the messageGasLimit value must be correctly stored in the chain configuration
 *
 * Why it should hold: The gas limit is critical for LayerZero message execution on the destination chain - it must be stored accurately to ensure messages have sufficient gas to execute properly
 *
 * Possible consequences: Incorrect gas limit storage could cause cross-chain messages to fail due to insufficient gas, leading to failed bridge operations and potential fund loss
 */
rule addChain_34dafd6b_gas_limit_stored(env e) {
    uint32 chainId;
    bool allowMessagesFrom;
    bool allowMessagesTo;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables

    // call function under test
    addChain(e, chainId, allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_after = currentContract.idToChains[chainId].messageGasLimit;

    // verify integrity
    assert ((messageGasLimit > 0) => (currentContract_idToChains_chainId__messageGasLimit_after == messageGasLimit)), "messageGasLimit > 0 => idToChains[chainId].messageGasLimit@after == messageGasLimit";
}

/*
 * idToChains[chainId].messageGasLimit@before > 0 => idToChains[chainId].messageGasLimit@after == messageGasLimit
 *
 * What it means: When adding a chain that already exists (has non-zero gas limit), the new messageGasLimit value must overwrite the existing one
 *
 * Why it should hold: This ensures that chain configurations can be updated by calling addChain again, which is necessary for maintaining and adjusting cross-chain parameters as network conditions change
 *
 * Possible consequences: If existing chain configurations cannot be updated, admins would have no way to adjust gas limits for changing network conditions, potentially leading to failed cross-chain operations
 */
rule addChain_34dafd6b_duplicate_chain_overwrites(env e) {
    uint32 chainId;
    bool allowMessagesFrom;
    bool allowMessagesTo;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_before = currentContract.idToChains[chainId].messageGasLimit;

    // call function under test
    addChain(e, chainId, allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_after = currentContract.idToChains[chainId].messageGasLimit;

    // verify integrity
    assert ((currentContract_idToChains_chainId__messageGasLimit_before > 0) => (currentContract_idToChains_chainId__messageGasLimit_after == messageGasLimit)), "idToChains[chainId].messageGasLimit@before > 0 => idToChains[chainId].messageGasLimit@after == messageGasLimit";
}

/*
 * messageGasLimit > 0 && idToChains[chainId].allowMessagesFrom@before != allowMessagesFrom => idToChains[chainId].allowMessagesFrom@after == allowMessagesFrom
 *
 * What it means: When messageGasLimit is valid and the allowMessagesFrom parameter differs from the current stored value, the stored value must be updated to match the parameter
 *
 * Why it should hold: This ensures that changes to message reception permissions are properly applied when updating chain configurations, maintaining security and functionality requirements
 *
 * Possible consequences: Failure to update allowMessagesFrom could leave chains in incorrect security states, either blocking legitimate messages or allowing unauthorized ones
 */
rule addChain_34dafd6b_allow_from_updates(env e) {
    uint32 chainId;
    bool allowMessagesFrom;
    bool allowMessagesTo;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_before = currentContract.idToChains[chainId].allowMessagesFrom;

    // call function under test
    addChain(e, chainId, allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_after = currentContract.idToChains[chainId].allowMessagesFrom;

    // verify integrity
    assert (((messageGasLimit > 0) && (currentContract_idToChains_chainId__allowMessagesFrom_before != allowMessagesFrom)) => (currentContract_idToChains_chainId__allowMessagesFrom_after == allowMessagesFrom)), "messageGasLimit > 0 && idToChains[chainId].allowMessagesFrom@before != allowMessagesFrom => idToChains[chainId].allowMessagesFrom@after == allowMessagesFrom";
}

/*
 * messageGasLimit > 0 && idToChains[chainId].allowMessagesTo@before != allowMessagesTo => idToChains[chainId].allowMessagesTo@after == allowMessagesTo
 *
 * What it means: When messageGasLimit is valid and the allowMessagesTo parameter differs from the current stored value, the stored value must be updated to match the parameter
 *
 * Why it should hold: This ensures that changes to outbound message permissions are properly applied, allowing admins to enable or disable bridging to specific chains as needed for security or operational reasons
 *
 * Possible consequences: Failure to update allowMessagesTo could prevent necessary changes to outbound bridging permissions, either blocking legitimate operations or allowing bridging to unsafe destinations
 */
rule addChain_34dafd6b_allow_to_updates(env e) {
    uint32 chainId;
    bool allowMessagesFrom;
    bool allowMessagesTo;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_before = currentContract.idToChains[chainId].allowMessagesTo;

    // call function under test
    addChain(e, chainId, allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_after = currentContract.idToChains[chainId].allowMessagesTo;

    // verify integrity
    assert (((messageGasLimit > 0) && (currentContract_idToChains_chainId__allowMessagesTo_before != allowMessagesTo)) => (currentContract_idToChains_chainId__allowMessagesTo_after == allowMessagesTo)), "messageGasLimit > 0 && idToChains[chainId].allowMessagesTo@before != allowMessagesTo => idToChains[chainId].allowMessagesTo@after == allowMessagesTo";
}

/*
 * chainId != otherChainId && messageGasLimit > 0 => idToChains[otherChainId].messageGasLimit@after == idToChains[otherChainId].messageGasLimit@before
 *
 * What it means: When adding or updating a specific chain, the messageGasLimit values for all other chains must remain unchanged
 *
 * Why it should hold: Chain configurations should be isolated - modifying one chain should not affect others to prevent unintended side effects and maintain system stability
 *
 * Possible consequences: If other chains' gas limits are accidentally modified, it could cause widespread bridge failures across multiple chains simultaneously
 */
rule addChain_34dafd6b_other_chains_unchanged(env e) {
    uint32 chainId;
    bool allowMessagesFrom;
    bool allowMessagesTo;
    address targetTeller;
    uint128 messageGasLimit;
    uint32 otherChainId;

    // assign all the 'before' variables
    uint128 currentContract_idToChains_otherChainId__messageGasLimit_before = currentContract.idToChains[otherChainId].messageGasLimit;

    // call function under test
    addChain(e, chainId, allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_otherChainId__messageGasLimit_after = currentContract.idToChains[otherChainId].messageGasLimit;

    // verify integrity
    assert (((chainId != otherChainId) && (messageGasLimit > 0)) => (currentContract_idToChains_otherChainId__messageGasLimit_after == currentContract_idToChains_otherChainId__messageGasLimit_before)), "chainId != otherChainId && messageGasLimit > 0 => idToChains[otherChainId].messageGasLimit@after == idToChains[otherChainId].messageGasLimit@before";
}

/*
 * chainId != otherChainId && messageGasLimit > 0 => idToChains[otherChainId].allowMessagesFrom@after == idToChains[otherChainId].allowMessagesFrom@before
 *
 * What it means: When adding or updating a specific chain, the allowMessagesFrom flags for all other chains must remain unchanged
 *
 * Why it should hold: Message reception permissions for other chains should not be affected when configuring a specific chain, maintaining security isolation between chain configurations
 *
 * Possible consequences: Unintended changes to other chains' allowMessagesFrom flags could create security vulnerabilities or break existing cross-chain functionality
 */
rule addChain_34dafd6b_from_flag_preserved(env e) {
    uint32 chainId;
    bool allowMessagesFrom;
    bool allowMessagesTo;
    address targetTeller;
    uint128 messageGasLimit;
    uint32 otherChainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_otherChainId__allowMessagesFrom_before = currentContract.idToChains[otherChainId].allowMessagesFrom;

    // call function under test
    addChain(e, chainId, allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    bool currentContract_idToChains_otherChainId__allowMessagesFrom_after = currentContract.idToChains[otherChainId].allowMessagesFrom;

    // verify integrity
    assert (((chainId != otherChainId) && (messageGasLimit > 0)) => (currentContract_idToChains_otherChainId__allowMessagesFrom_after == currentContract_idToChains_otherChainId__allowMessagesFrom_before)), "chainId != otherChainId && messageGasLimit > 0 => idToChains[otherChainId].allowMessagesFrom@after == idToChains[otherChainId].allowMessagesFrom@before";
}

/*
 * chainId != otherChainId && messageGasLimit > 0 => idToChains[otherChainId].allowMessagesTo@after == idToChains[otherChainId].allowMessagesTo@before
 *
 * What it means: When adding or updating a specific chain, the allowMessagesTo flags for all other chains must remain unchanged
 *
 * Why it should hold: Outbound message permissions for other chains should remain isolated when configuring a specific chain, preventing unintended disruption of existing bridge routes
 *
 * Possible consequences: Accidental changes to other chains' allowMessagesTo flags could disable critical bridge routes or enable unsafe ones without admin awareness
 */
rule addChain_34dafd6b_to_flag_preserved(env e) {
    uint32 chainId;
    bool allowMessagesFrom;
    bool allowMessagesTo;
    address targetTeller;
    uint128 messageGasLimit;
    uint32 otherChainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_otherChainId__allowMessagesTo_before = currentContract.idToChains[otherChainId].allowMessagesTo;

    // call function under test
    addChain(e, chainId, allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    bool currentContract_idToChains_otherChainId__allowMessagesTo_after = currentContract.idToChains[otherChainId].allowMessagesTo;

    // verify integrity
    assert (((chainId != otherChainId) && (messageGasLimit > 0)) => (currentContract_idToChains_otherChainId__allowMessagesTo_after == currentContract_idToChains_otherChainId__allowMessagesTo_before)), "chainId != otherChainId && messageGasLimit > 0 => idToChains[otherChainId].allowMessagesTo@after == idToChains[otherChainId].allowMessagesTo@before";
}

/*
 * idToChains[chainId].allowMessagesFrom@before == false && idToChains[chainId].allowMessagesTo@before == false && idToChains[chainId].messageGasLimit@before == 0 => revert
 *
 * What it means: The function should revert if trying to remove a chain that doesn't exist (all fields are zero/false)
 *
 * Why it should hold: Since the function body is empty, it cannot actually remove anything. If a non-existent chain is passed, the function should fail rather than silently do nothing
 *
 * Possible consequences: Silent failures where admins think they've removed a chain but nothing actually happened, leading to confusion about system state
 */
rule removeChain_55a2d64d_chain_exists_required(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_before = currentContract.idToChains[chainId].allowMessagesFrom;
    bool currentContract_idToChains_chainId__allowMessagesTo_before = currentContract.idToChains[chainId].allowMessagesTo;
    uint128 currentContract_idToChains_chainId__messageGasLimit_before = currentContract.idToChains[chainId].messageGasLimit;

    // call function under test
    removeChain@withrevert(e, chainId);
    bool removeChain_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((((currentContract_idToChains_chainId__allowMessagesFrom_before == false) && (currentContract_idToChains_chainId__allowMessagesTo_before == false)) && (currentContract_idToChains_chainId__messageGasLimit_before == 0)) => removeChain_reverted), "idToChains[chainId].allowMessagesFrom@before == false && idToChains[chainId].allowMessagesTo@before == false && idToChains[chainId].messageGasLimit@before == 0 => revert";
}

/*
 * idToChains[chainId].allowMessagesFrom@before == true => idToChains[chainId].allowMessagesFrom@after == false
 *
 * What it means: If a chain currently allows messages from it, after removal it should not allow messages from it
 *
 * Why it should hold: Removing a chain should disable all message reception from that chain to prevent unauthorized cross-chain communication
 *
 * Possible consequences: Continued acceptance of messages from chains that should be blocked, potentially allowing malicious cross-chain attacks
 */
rule removeChain_55a2d64d_removes_allow_messages_from(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_before = currentContract.idToChains[chainId].allowMessagesFrom;

    // call function under test
    removeChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_after = currentContract.idToChains[chainId].allowMessagesFrom;

    // verify integrity
    assert ((currentContract_idToChains_chainId__allowMessagesFrom_before == true) => (currentContract_idToChains_chainId__allowMessagesFrom_after == false)), "idToChains[chainId].allowMessagesFrom@before == true => idToChains[chainId].allowMessagesFrom@after == false";
}

/*
 * idToChains[chainId].allowMessagesTo@before == true => idToChains[chainId].allowMessagesTo@after == false
 *
 * What it means: If a chain currently allows messages to it, after removal it should not allow messages to it
 *
 * Why it should hold: Removing a chain should disable all message sending to that chain to prevent users from losing funds by bridging to inactive chains
 *
 * Possible consequences: Users can still bridge shares to removed/inactive chains, resulting in permanent loss of funds
 */
rule removeChain_55a2d64d_removes_allow_messages_to(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_before = currentContract.idToChains[chainId].allowMessagesTo;

    // call function under test
    removeChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_after = currentContract.idToChains[chainId].allowMessagesTo;

    // verify integrity
    assert ((currentContract_idToChains_chainId__allowMessagesTo_before == true) => (currentContract_idToChains_chainId__allowMessagesTo_after == false)), "idToChains[chainId].allowMessagesTo@before == true => idToChains[chainId].allowMessagesTo@after == false";
}

/*
 * idToChains[chainId].messageGasLimit@before > 0 => idToChains[chainId].messageGasLimit@after == 0
 *
 * What it means: If a chain has a gas limit set, after removal the gas limit should be reset to zero
 *
 * Why it should hold: Removing a chain should clear all associated configuration including gas limits to ensure clean state
 *
 * Possible consequences: Stale configuration data remains in storage, potentially causing issues if the chain is re-added later
 */
rule removeChain_55a2d64d_clears_gas_limit(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_before = currentContract.idToChains[chainId].messageGasLimit;

    // call function under test
    removeChain(e, chainId);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_after = currentContract.idToChains[chainId].messageGasLimit;

    // verify integrity
    assert ((currentContract_idToChains_chainId__messageGasLimit_before > 0) => (currentContract_idToChains_chainId__messageGasLimit_after == 0)), "idToChains[chainId].messageGasLimit@before > 0 => idToChains[chainId].messageGasLimit@after == 0";
}

/*
 * chainId != otherChainId => idToChains[otherChainId].allowMessagesFrom@after == idToChains[otherChainId].allowMessagesFrom@before && idToChains[otherChainId].allowMessagesTo@after == idToChains[otherChainId].allowMessagesTo@before && idToChains[otherChainId].messageGasLimit@after == idToChains[otherChainId].messageGasLimit@before
 *
 * What it means: Removing one chain should not affect the configuration of any other chains
 *
 * Why it should hold: Chain removal should be isolated and not have side effects on other configured chains
 *
 * Possible consequences: Removing one chain could accidentally disable or modify other chains, breaking cross-chain functionality
 */
rule removeChain_55a2d64d_preserves_other_chains(env e) {
    uint32 chainId;
    uint32 otherChainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_otherChainId__allowMessagesFrom_before = currentContract.idToChains[otherChainId].allowMessagesFrom;
    bool currentContract_idToChains_otherChainId__allowMessagesTo_before = currentContract.idToChains[otherChainId].allowMessagesTo;
    uint128 currentContract_idToChains_otherChainId__messageGasLimit_before = currentContract.idToChains[otherChainId].messageGasLimit;

    // call function under test
    removeChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_idToChains_otherChainId__allowMessagesFrom_after = currentContract.idToChains[otherChainId].allowMessagesFrom;
    bool currentContract_idToChains_otherChainId__allowMessagesTo_after = currentContract.idToChains[otherChainId].allowMessagesTo;
    uint128 currentContract_idToChains_otherChainId__messageGasLimit_after = currentContract.idToChains[otherChainId].messageGasLimit;

    // verify integrity
    assert ((chainId != otherChainId) => (((currentContract_idToChains_otherChainId__allowMessagesFrom_after == currentContract_idToChains_otherChainId__allowMessagesFrom_before) && (currentContract_idToChains_otherChainId__allowMessagesTo_after == currentContract_idToChains_otherChainId__allowMessagesTo_before)) && (currentContract_idToChains_otherChainId__messageGasLimit_after == currentContract_idToChains_otherChainId__messageGasLimit_before))), "chainId != otherChainId => idToChains[otherChainId].allowMessagesFrom@after == idToChains[otherChainId].allowMessagesFrom@before && idToChains[otherChainId].allowMessagesTo@after == idToChains[otherChainId].allowMessagesTo@before && idToChains[otherChainId].messageGasLimit@after == idToChains[otherChainId].messageGasLimit@before";
}

/*
 * isPaused@after == isPaused@before
 *
 * What it means: The paused state of the contract should remain unchanged after removing a chain
 *
 * Why it should hold: Chain removal is a configuration change and should not affect the operational state of the contract
 *
 * Possible consequences: Unexpected pausing or unpausing could disrupt normal operations or emergency procedures
 */
rule removeChain_55a2d64d_no_effect_on_paused(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    removeChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_isPaused_after = currentContract.isPaused;

    // verify integrity
    assert (currentContract_isPaused_after == currentContract_isPaused_before), "isPaused@after == isPaused@before";
}

/*
 * depositNonce@after == depositNonce@before
 *
 * What it means: The deposit nonce counter should remain unchanged after removing a chain
 *
 * Why it should hold: Chain removal should not affect deposit tracking mechanisms which are independent of chain configuration
 *
 * Possible consequences: Deposit nonce manipulation could break deposit refund mechanisms or create hash collisions
 */
rule removeChain_55a2d64d_no_effect_on_deposit_nonce(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;

    // call function under test
    removeChain(e, chainId);

    // assign all the 'after' variables
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;

    // verify integrity
    assert (currentContract_depositNonce_after == currentContract_depositNonce_before), "depositNonce@after == depositNonce@before";
}

/*
 * depositCap@after == depositCap@before
 *
 * What it means: The global deposit cap should remain unchanged after removing a chain
 *
 * Why it should hold: Chain removal should not affect global vault limits which are independent of cross-chain configuration
 *
 * Possible consequences: Unexpected changes to deposit caps could allow unlimited deposits or block all deposits
 */
rule removeChain_55a2d64d_no_effect_on_deposit_cap(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint112 currentContract_depositCap_before = currentContract.depositCap;

    // call function under test
    removeChain(e, chainId);

    // assign all the 'after' variables
    uint112 currentContract_depositCap_after = currentContract.depositCap;

    // verify integrity
    assert (currentContract_depositCap_after == currentContract_depositCap_before), "depositCap@after == depositCap@before";
}

/*
 * shareLockPeriod@after == shareLockPeriod@before
 *
 * What it means: The share lock period should remain unchanged after removing a chain
 *
 * Why it should hold: Chain removal should not affect local deposit mechanics like share locking periods
 *
 * Possible consequences: Changes to lock periods could affect deposit refund mechanisms or user fund accessibility
 */
rule removeChain_55a2d64d_no_effect_on_lock_period(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;

    // call function under test
    removeChain(e, chainId);

    // assign all the 'after' variables
    uint64 currentContract_shareLockPeriod_after = currentContract.shareLockPeriod;

    // verify integrity
    assert (currentContract_shareLockPeriod_after == currentContract_shareLockPeriod_before), "shareLockPeriod@after == shareLockPeriod@before";
}

/*
 * permissionedTransfers@after == permissionedTransfers@before
 *
 * What it means: The permissioned transfers setting should remain unchanged after removing a chain
 *
 * Why it should hold: Chain removal should not affect local transfer restrictions which are independent of cross-chain configuration
 *
 * Possible consequences: Unexpected changes to transfer permissions could break access controls or allow unauthorized transfers
 */
rule removeChain_55a2d64d_no_effect_on_transfers(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    bool currentContract_permissionedTransfers_before = currentContract.permissionedTransfers;

    // call function under test
    removeChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_permissionedTransfers_after = currentContract.permissionedTransfers;

    // verify integrity
    assert (currentContract_permissionedTransfers_after == currentContract_permissionedTransfers_before), "permissionedTransfers@after == permissionedTransfers@before";
}

/*
 * idToChains[chainId].messageGasLimit@before == 0 && !idToChains[chainId].allowMessagesFrom@before && !idToChains[chainId].allowMessagesTo@before => revert
 *
 * What it means: The function should revert if trying to allow messages from a chain that doesn't exist (has all zero/false values)
 *
 * Why it should hold: The function should only operate on chains that have been properly configured through addChain, not on uninitialized chain entries
 *
 * Possible consequences: State corruption where non-existent chains appear to be configured, leading to failed message routing and potential DoS
 */
rule allowMessagesFromChain_202eac57_chain_must_exist(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_before = currentContract.idToChains[chainId].messageGasLimit;
    bool currentContract_idToChains_chainId__allowMessagesFrom_before = currentContract.idToChains[chainId].allowMessagesFrom;
    bool currentContract_idToChains_chainId__allowMessagesTo_before = currentContract.idToChains[chainId].allowMessagesTo;

    // call function under test
    allowMessagesFromChain@withrevert(e, chainId, targetTeller);
    bool allowMessagesFromChain_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((((currentContract_idToChains_chainId__messageGasLimit_before == 0) && !(currentContract_idToChains_chainId__allowMessagesFrom_before)) && !(currentContract_idToChains_chainId__allowMessagesTo_before)) => allowMessagesFromChain_reverted), "idToChains[chainId].messageGasLimit@before == 0 && !idToChains[chainId].allowMessagesFrom@before && !idToChains[chainId].allowMessagesTo@before => revert";
}

/*
 * idToChains[chainId].allowMessagesFrom@after == true
 *
 * What it means: After the function executes, the allowMessagesFrom flag for the specified chain must be set to true
 *
 * Why it should hold: This is the primary purpose of the function - to enable message reception from the specified chain
 *
 * Possible consequences: Function failure where the intended functionality is not achieved, breaking cross-chain communication
 */
rule allowMessagesFromChain_202eac57_enables_messages_from(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_after = currentContract.idToChains[chainId].allowMessagesFrom;

    // verify integrity
    assert (currentContract_idToChains_chainId__allowMessagesFrom_after == true), "idToChains[chainId].allowMessagesFrom@after == true";
}

/*
 * idToChains[chainId].allowMessagesTo@after == idToChains[chainId].allowMessagesTo@before
 *
 * What it means: The function should not modify the allowMessagesTo flag for the chain
 *
 * Why it should hold: This function is specifically for allowing messages FROM a chain, not TO a chain, so it should not affect outbound message permissions
 *
 * Possible consequences: Unintended permission changes that could enable or disable outbound messages when only inbound permissions should change
 */
rule allowMessagesFromChain_202eac57_preserves_messages_to(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_before = currentContract.idToChains[chainId].allowMessagesTo;

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_after = currentContract.idToChains[chainId].allowMessagesTo;

    // verify integrity
    assert (currentContract_idToChains_chainId__allowMessagesTo_after == currentContract_idToChains_chainId__allowMessagesTo_before), "idToChains[chainId].allowMessagesTo@after == idToChains[chainId].allowMessagesTo@before";
}

/*
 * idToChains[chainId].messageGasLimit@after == idToChains[chainId].messageGasLimit@before
 *
 * What it means: The function should not modify the messageGasLimit for the chain
 *
 * Why it should hold: Gas limits are set during chain configuration and should only be modified through dedicated gas limit functions
 *
 * Possible consequences: Incorrect gas limits could cause message failures or excessive gas consumption
 */
rule allowMessagesFromChain_202eac57_preserves_gas_limit(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_before = currentContract.idToChains[chainId].messageGasLimit;

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_after = currentContract.idToChains[chainId].messageGasLimit;

    // verify integrity
    assert (currentContract_idToChains_chainId__messageGasLimit_after == currentContract_idToChains_chainId__messageGasLimit_before), "idToChains[chainId].messageGasLimit@after == idToChains[chainId].messageGasLimit@before";
}

/*
 * targetTeller == address(0) => revert
 *
 * What it means: The function should revert if the targetTeller parameter is the zero address
 *
 * Why it should hold: Setting a peer to the zero address would break message routing and is likely an error
 *
 * Possible consequences: Messages would be routed to an invalid address, causing permanent message loss
 */
rule allowMessagesFromChain_202eac57_zero_address_rejected(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables

    // call function under test
    allowMessagesFromChain@withrevert(e, chainId, targetTeller);
    bool allowMessagesFromChain_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((targetTeller == 0) => allowMessagesFromChain_reverted), "targetTeller == address(0) => revert";
}

/*
 * peers(chainId)@after != 0x0
 *
 * What it means: After execution, the peer mapping for the chain should be set to a non-zero value
 *
 * Why it should hold: The function should update the peer mapping to establish the connection with the target teller
 *
 * Possible consequences: Failed message routing if peer mapping is not properly established
 */
rule allowMessagesFromChain_202eac57_updates_peer_state(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    bytes32 peers_e__chainId__after = peers(e, chainId);

    // verify integrity
    assert (peers_e__chainId__after != to_bytes32(0x0)), "peers(chainId)@after != 0x0";
}

/*
 * depositNonce@after == depositNonce@before
 *
 * What it means: The function should not modify the deposit nonce counter
 *
 * Why it should hold: This function is for cross-chain configuration and should not affect deposit tracking state
 *
 * Possible consequences: Deposit tracking corruption leading to incorrect deposit history or nonce conflicts
 */
rule allowMessagesFromChain_202eac57_no_deposit_state_change(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;

    // verify integrity
    assert (currentContract_depositNonce_after == currentContract_depositNonce_before), "depositNonce@after == depositNonce@before";
}

/*
 * isPaused@after == isPaused@before
 *
 * What it means: The function should not modify the contract's paused state
 *
 * Why it should hold: Pause state should only be controlled through dedicated pause/unpause functions
 *
 * Possible consequences: Unintended pausing or unpausing of contract functionality
 */
rule allowMessagesFromChain_202eac57_no_pause_state_change(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    bool currentContract_isPaused_after = currentContract.isPaused;

    // verify integrity
    assert (currentContract_isPaused_after == currentContract_isPaused_before), "isPaused@after == isPaused@before";
}

/*
 * shareLockPeriod@after == shareLockPeriod@before
 *
 * What it means: The function should not modify the share lock period setting
 *
 * Why it should hold: Share lock periods are security parameters that should only be changed through dedicated functions
 *
 * Possible consequences: Security bypass where shares become unlocked prematurely or locked longer than intended
 */
rule allowMessagesFromChain_202eac57_no_lock_period_change(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    uint64 currentContract_shareLockPeriod_after = currentContract.shareLockPeriod;

    // verify integrity
    assert (currentContract_shareLockPeriod_after == currentContract_shareLockPeriod_before), "shareLockPeriod@after == shareLockPeriod@before";
}

/*
 * depositCap@after == depositCap@before
 *
 * What it means: The function should not modify the global deposit cap
 *
 * Why it should hold: Deposit caps are risk management parameters that should only be changed through dedicated functions
 *
 * Possible consequences: Risk management bypass allowing unlimited deposits or accidentally restricting deposits
 */
rule allowMessagesFromChain_202eac57_no_deposit_cap_change(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables
    uint112 currentContract_depositCap_before = currentContract.depositCap;

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    uint112 currentContract_depositCap_after = currentContract.depositCap;

    // verify integrity
    assert (currentContract_depositCap_after == currentContract_depositCap_before), "depositCap@after == depositCap@before";
}

/*
 * permissionedTransfers@after == permissionedTransfers@before
 *
 * What it means: The function should not modify the permissioned transfers flag
 *
 * Why it should hold: Transfer permissions are access control settings that should only be changed through dedicated functions
 *
 * Possible consequences: Access control bypass or unintended restriction of transfers
 */
rule allowMessagesFromChain_202eac57_no_transfer_permission_change(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables
    bool currentContract_permissionedTransfers_before = currentContract.permissionedTransfers;

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    bool currentContract_permissionedTransfers_after = currentContract.permissionedTransfers;

    // verify integrity
    assert (currentContract_permissionedTransfers_after == currentContract_permissionedTransfers_before), "permissionedTransfers@after == permissionedTransfers@before";
}

/*
 * chainId != otherChainId => idToChains[otherChainId].allowMessagesFrom@after == idToChains[otherChainId].allowMessagesFrom@before
 *
 * What it means: The function should not modify the allowMessagesFrom setting for any chain other than the specified chainId
 *
 * Why it should hold: The function should only affect the specific chain being configured, not other chains
 *
 * Possible consequences: Unintended permission changes for other chains, potentially enabling or disabling message reception from unrelated chains
 */
rule allowMessagesFromChain_202eac57_preserves_other_chains(env e) {
    uint32 chainId;
    address targetTeller;
    uint32 otherChainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_otherChainId__allowMessagesFrom_before = currentContract.idToChains[otherChainId].allowMessagesFrom;

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    bool currentContract_idToChains_otherChainId__allowMessagesFrom_after = currentContract.idToChains[otherChainId].allowMessagesFrom;

    // verify integrity
    assert ((chainId != otherChainId) => (currentContract_idToChains_otherChainId__allowMessagesFrom_after == currentContract_idToChains_otherChainId__allowMessagesFrom_before)), "chainId != otherChainId => idToChains[otherChainId].allowMessagesFrom@after == idToChains[otherChainId].allowMessagesFrom@before";
}

/*
 * chainId != otherChainId => peers(otherChainId)@after == peers(otherChainId)@before
 *
 * What it means: The function should not modify peer mappings for any chain other than the specified chainId
 *
 * Why it should hold: The function should only update the peer for the specific chain being configured
 *
 * Possible consequences: Broken message routing for other chains if their peer mappings are corrupted
 */
rule allowMessagesFromChain_202eac57_preserves_other_peers(env e) {
    uint32 chainId;
    address targetTeller;
    uint32 otherChainId;

    // assign all the 'before' variables
    bytes32 peers_e__otherChainId__before = peers(e, otherChainId);

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    bytes32 peers_e__otherChainId__after = peers(e, otherChainId);

    // verify integrity
    assert ((chainId != otherChainId) => (peers_e__otherChainId__after == peers_e__otherChainId__before)), "chainId != otherChainId => peers(otherChainId)@after == peers(otherChainId)@before";
}

/*
 * assetData[asset].allowDeposits@after == assetData[asset].allowDeposits@before
 *
 * What it means: The function should not modify any asset configuration data
 *
 * Why it should hold: This function is for cross-chain configuration and should not affect asset-specific settings
 *
 * Possible consequences: Unintended changes to deposit/withdrawal permissions for assets
 */
rule allowMessagesFromChain_202eac57_preserves_asset_data(env e) {
    uint32 chainId;
    address targetTeller;
    address asset;

    // assign all the 'before' variables
    bool currentContract_assetData_asset__allowDeposits_before = currentContract.assetData[asset].allowDeposits;

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    bool currentContract_assetData_asset__allowDeposits_after = currentContract.assetData[asset].allowDeposits;

    // verify integrity
    assert (currentContract_assetData_asset__allowDeposits_after == currentContract_assetData_asset__allowDeposits_before), "assetData[asset].allowDeposits@after == assetData[asset].allowDeposits@before";
}

/*
 * beforeTransferData[user].denyFrom@after == beforeTransferData[user].denyFrom@before
 *
 * What it means: The function should not modify any user-specific transfer restrictions or permissions
 *
 * Why it should hold: This function is for system configuration and should not affect individual user permissions
 *
 * Possible consequences: Unintended changes to user access controls, potentially enabling or restricting user operations
 */
rule allowMessagesFromChain_202eac57_preserves_user_data(env e) {
    uint32 chainId;
    address targetTeller;
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__denyFrom_before = currentContract.beforeTransferData[user].denyFrom;

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyFrom_after = currentContract.beforeTransferData[user].denyFrom;

    // verify integrity
    assert (currentContract_beforeTransferData_user__denyFrom_after == currentContract_beforeTransferData_user__denyFrom_before), "beforeTransferData[user].denyFrom@after == beforeTransferData[user].denyFrom@before";
}

/*
 * publicDepositHistory[nonce]@after == publicDepositHistory[nonce]@before
 *
 * What it means: The function should not modify any entries in the deposit history mapping
 *
 * Why it should hold: Deposit history is critical for refund functionality and should not be affected by cross-chain configuration
 *
 * Possible consequences: Corruption of deposit history could prevent legitimate refunds or enable fraudulent refunds
 */
rule allowMessagesFromChain_202eac57_preserves_deposit_history(env e) {
    uint32 chainId;
    address targetTeller;
    uint256 nonce;

    // assign all the 'before' variables
    bytes32 currentContract_publicDepositHistory_nonce__before = currentContract.publicDepositHistory[nonce];

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    bytes32 currentContract_publicDepositHistory_nonce__after = currentContract.publicDepositHistory[nonce];

    // verify integrity
    assert (currentContract_publicDepositHistory_nonce__after == currentContract_publicDepositHistory_nonce__before), "publicDepositHistory[nonce]@after == publicDepositHistory[nonce]@before";
}

/*
 * messageGasLimit == 0 => revert
 *
 * What it means: The function must revert when messageGasLimit parameter is zero
 *
 * Why it should hold: Based on the error LayerZeroTeller__ZeroMessageGasLimit and the check pattern seen in other functions like addChain and setChainGasLimit, zero gas limits are invalid for chains that allow outgoing messages
 *
 * Possible consequences: Messages could be sent with insufficient gas, causing them to fail on the destination chain while still consuming fees, leading to fund loss and broken cross-chain functionality
 */
rule allowMessagesToChain_b5ba6182_zero_gas_limit_reverts(env e) {
    uint32 chainId;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables

    // call function under test
    allowMessagesToChain@withrevert(e, chainId, targetTeller, messageGasLimit);
    bool allowMessagesToChain_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((messageGasLimit == 0) => allowMessagesToChain_reverted), "messageGasLimit == 0 => revert";
}

/*
 * messageGasLimit > 0 => idToChains[chainId].allowMessagesTo@after == true
 *
 * What it means: When messageGasLimit is greater than zero, the chain's allowMessagesTo flag must be set to true after the function executes
 *
 * Why it should hold: The function's purpose is to enable outgoing messages to a specific chain, so it must update the allowMessagesTo flag to true when provided with a valid gas limit
 *
 * Possible consequences: Users would be unable to bridge shares to the chain even though the function appeared to succeed, causing confusion and broken functionality
 */
rule allowMessagesToChain_b5ba6182_chain_allows_messages_to(env e) {
    uint32 chainId;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables

    // call function under test
    allowMessagesToChain(e, chainId, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_after = currentContract.idToChains[chainId].allowMessagesTo;

    // verify integrity
    assert ((messageGasLimit > 0) => (currentContract_idToChains_chainId__allowMessagesTo_after == true)), "messageGasLimit > 0 => idToChains[chainId].allowMessagesTo@after == true";
}

/*
 * messageGasLimit > 0 => idToChains[chainId].messageGasLimit@after == messageGasLimit
 *
 * What it means: When messageGasLimit is greater than zero, the chain's messageGasLimit storage must be updated to the provided value
 *
 * Why it should hold: The function must store the gas limit parameter to be used for future message sending operations to ensure messages have sufficient gas to execute on the destination chain
 *
 * Possible consequences: Messages could be sent with incorrect gas limits, either wasting funds on excessive gas or failing due to insufficient gas
 */
rule allowMessagesToChain_b5ba6182_gas_limit_updated(env e) {
    uint32 chainId;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables

    // call function under test
    allowMessagesToChain(e, chainId, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_after = currentContract.idToChains[chainId].messageGasLimit;

    // verify integrity
    assert ((messageGasLimit > 0) => (currentContract_idToChains_chainId__messageGasLimit_after == messageGasLimit)), "messageGasLimit > 0 => idToChains[chainId].messageGasLimit@after == messageGasLimit";
}

/*
 * idToChains[chainId].allowMessagesFrom@after == idToChains[chainId].allowMessagesFrom@before
 *
 * What it means: The allowMessagesFrom flag for the chain should remain unchanged after function execution
 *
 * Why it should hold: This function is specifically for allowing outgoing messages (to), not incoming messages (from), so it should not modify the incoming message permission
 *
 * Possible consequences: Unintended changes to incoming message permissions could either block legitimate messages or allow unauthorized messages from that chain
 */
rule allowMessagesToChain_b5ba6182_allow_from_unchanged(env e) {
    uint32 chainId;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_before = currentContract.idToChains[chainId].allowMessagesFrom;

    // call function under test
    allowMessagesToChain(e, chainId, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_after = currentContract.idToChains[chainId].allowMessagesFrom;

    // verify integrity
    assert (currentContract_idToChains_chainId__allowMessagesFrom_after == currentContract_idToChains_chainId__allowMessagesFrom_before), "idToChains[chainId].allowMessagesFrom@after == idToChains[chainId].allowMessagesFrom@before";
}

/*
 * chainId != otherChainId => idToChains[otherChainId].allowMessagesTo@after == idToChains[otherChainId].allowMessagesTo@before
 *
 * What it means: The allowMessagesTo flag for all other chains (different chainId) should remain unchanged
 *
 * Why it should hold: The function should only modify the specific chain being configured, not affect other chains' outgoing message permissions
 *
 * Possible consequences: Could accidentally disable or enable message sending to other chains, breaking existing cross-chain functionality
 */
rule allowMessagesToChain_b5ba6182_other_chains_unchanged(env e) {
    uint32 chainId;
    address targetTeller;
    uint128 messageGasLimit;
    uint32 otherChainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_otherChainId__allowMessagesTo_before = currentContract.idToChains[otherChainId].allowMessagesTo;

    // call function under test
    allowMessagesToChain(e, chainId, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    bool currentContract_idToChains_otherChainId__allowMessagesTo_after = currentContract.idToChains[otherChainId].allowMessagesTo;

    // verify integrity
    assert ((chainId != otherChainId) => (currentContract_idToChains_otherChainId__allowMessagesTo_after == currentContract_idToChains_otherChainId__allowMessagesTo_before)), "chainId != otherChainId => idToChains[otherChainId].allowMessagesTo@after == idToChains[otherChainId].allowMessagesTo@before";
}

/*
 * chainId != otherChainId => idToChains[otherChainId].messageGasLimit@after == idToChains[otherChainId].messageGasLimit@before
 *
 * What it means: The messageGasLimit for all other chains (different chainId) should remain unchanged
 *
 * Why it should hold: The function should only update the gas limit for the specific chain being configured, not affect other chains' gas settings
 *
 * Possible consequences: Could corrupt gas limit settings for other chains, causing messages to fail or waste gas
 */
rule allowMessagesToChain_b5ba6182_other_chains_gas_unchanged(env e) {
    uint32 chainId;
    address targetTeller;
    uint128 messageGasLimit;
    uint32 otherChainId;

    // assign all the 'before' variables
    uint128 currentContract_idToChains_otherChainId__messageGasLimit_before = currentContract.idToChains[otherChainId].messageGasLimit;

    // call function under test
    allowMessagesToChain(e, chainId, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_otherChainId__messageGasLimit_after = currentContract.idToChains[otherChainId].messageGasLimit;

    // verify integrity
    assert ((chainId != otherChainId) => (currentContract_idToChains_otherChainId__messageGasLimit_after == currentContract_idToChains_otherChainId__messageGasLimit_before)), "chainId != otherChainId => idToChains[otherChainId].messageGasLimit@after == idToChains[otherChainId].messageGasLimit@before";
}

/*
 * depositNonce@after == depositNonce@before
 *
 * What it means: The depositNonce counter should not be modified by this function
 *
 * Why it should hold: This function only configures cross-chain messaging settings and should not affect deposit tracking state
 *
 * Possible consequences: Could corrupt deposit tracking, leading to deposit hash collisions or inability to refund deposits
 */
rule allowMessagesToChain_b5ba6182_deposit_state_unchanged(env e) {
    uint32 chainId;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;

    // call function under test
    allowMessagesToChain(e, chainId, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;

    // verify integrity
    assert (currentContract_depositNonce_after == currentContract_depositNonce_before), "depositNonce@after == depositNonce@before";
}

/*
 * isPaused@after == isPaused@before
 *
 * What it means: The isPaused flag should not be modified by this function
 *
 * Why it should hold: This function is for chain configuration, not pause control, and should not affect the contract's operational state
 *
 * Possible consequences: Could accidentally pause or unpause the contract, either blocking legitimate operations or allowing operations during intended maintenance
 */
rule allowMessagesToChain_b5ba6182_pause_state_unchanged(env e) {
    uint32 chainId;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    allowMessagesToChain(e, chainId, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    bool currentContract_isPaused_after = currentContract.isPaused;

    // verify integrity
    assert (currentContract_isPaused_after == currentContract_isPaused_before), "isPaused@after == isPaused@before";
}

/*
 * shareLockPeriod@after == shareLockPeriod@before
 *
 * What it means: The shareLockPeriod should not be modified by this function
 *
 * Why it should hold: This function is for cross-chain configuration and should not affect share locking mechanics
 *
 * Possible consequences: Could change share lock duration, affecting user expectations and deposit refund windows
 */
rule allowMessagesToChain_b5ba6182_lock_period_unchanged(env e) {
    uint32 chainId;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;

    // call function under test
    allowMessagesToChain(e, chainId, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    uint64 currentContract_shareLockPeriod_after = currentContract.shareLockPeriod;

    // verify integrity
    assert (currentContract_shareLockPeriod_after == currentContract_shareLockPeriod_before), "shareLockPeriod@after == shareLockPeriod@before";
}

/*
 * depositCap@after == depositCap@before
 *
 * What it means: The depositCap should not be modified by this function
 *
 * Why it should hold: This function is for cross-chain messaging configuration and should not affect deposit limits
 *
 * Possible consequences: Could accidentally change deposit limits, either blocking legitimate deposits or allowing excessive deposits beyond intended capacity
 */
rule allowMessagesToChain_b5ba6182_deposit_cap_unchanged(env e) {
    uint32 chainId;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    uint112 currentContract_depositCap_before = currentContract.depositCap;

    // call function under test
    allowMessagesToChain(e, chainId, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    uint112 currentContract_depositCap_after = currentContract.depositCap;

    // verify integrity
    assert (currentContract_depositCap_after == currentContract_depositCap_before), "depositCap@after == depositCap@before";
}

/*
 * idToChains[chainId].allowMessagesFrom@before == false && idToChains[chainId].allowMessagesTo@before == false && idToChains[chainId].messageGasLimit@before == 0 => revert
 *
 * What it means: The function should revert if the chain doesn't exist (all fields are zero/false)
 *
 * Why it should hold: The function should only operate on existing chains that have been previously configured, as operating on non-existent chains is meaningless
 *
 * Possible consequences: State corruption where the function appears to succeed but doesn't actually change anything meaningful, leading to confusion about chain status
 */
rule stopMessagesFromChain_d555f368_chain_must_exist(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_before = currentContract.idToChains[chainId].allowMessagesFrom;
    bool currentContract_idToChains_chainId__allowMessagesTo_before = currentContract.idToChains[chainId].allowMessagesTo;
    uint128 currentContract_idToChains_chainId__messageGasLimit_before = currentContract.idToChains[chainId].messageGasLimit;

    // call function under test
    stopMessagesFromChain@withrevert(e, chainId);
    bool stopMessagesFromChain_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((((currentContract_idToChains_chainId__allowMessagesFrom_before == false) && (currentContract_idToChains_chainId__allowMessagesTo_before == false)) && (currentContract_idToChains_chainId__messageGasLimit_before == 0)) => stopMessagesFromChain_reverted), "idToChains[chainId].allowMessagesFrom@before == false && idToChains[chainId].allowMessagesTo@before == false && idToChains[chainId].messageGasLimit@before == 0 => revert";
}

/*
 * idToChains[chainId].allowMessagesFrom@before == true => idToChains[chainId].allowMessagesFrom@after == false
 *
 * What it means: If messages from a chain were previously allowed, the function sets allowMessagesFrom to false
 *
 * Why it should hold: This is the core functionality of stopMessagesFromChain - it should disable incoming messages from the specified chain
 *
 * Possible consequences: Security bypass where malicious messages can still be received from chains that should be blocked
 */
rule stopMessagesFromChain_d555f368_disables_messages_from(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_before = currentContract.idToChains[chainId].allowMessagesFrom;

    // call function under test
    stopMessagesFromChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_after = currentContract.idToChains[chainId].allowMessagesFrom;

    // verify integrity
    assert ((currentContract_idToChains_chainId__allowMessagesFrom_before == true) => (currentContract_idToChains_chainId__allowMessagesFrom_after == false)), "idToChains[chainId].allowMessagesFrom@before == true => idToChains[chainId].allowMessagesFrom@after == false";
}

/*
 * idToChains[chainId].allowMessagesTo@after == idToChains[chainId].allowMessagesTo@before
 *
 * What it means: The function should not change the allowMessagesTo setting for the chain
 *
 * Why it should hold: stopMessagesFromChain should only affect incoming messages, not outgoing messages to that chain
 *
 * Possible consequences: Unintended disruption of outgoing message functionality when only incoming messages should be blocked
 */
rule stopMessagesFromChain_d555f368_preserves_messages_to(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_before = currentContract.idToChains[chainId].allowMessagesTo;

    // call function under test
    stopMessagesFromChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_after = currentContract.idToChains[chainId].allowMessagesTo;

    // verify integrity
    assert (currentContract_idToChains_chainId__allowMessagesTo_after == currentContract_idToChains_chainId__allowMessagesTo_before), "idToChains[chainId].allowMessagesTo@after == idToChains[chainId].allowMessagesTo@before";
}

/*
 * idToChains[chainId].messageGasLimit@after == idToChains[chainId].messageGasLimit@before
 *
 * What it means: The function should not modify the messageGasLimit setting for the chain
 *
 * Why it should hold: Gas limit configuration is separate from message allowance and should remain unchanged when stopping incoming messages
 *
 * Possible consequences: Corruption of gas limit settings that could affect future message sending if the chain is re-enabled
 */
rule stopMessagesFromChain_d555f368_preserves_gas_limit(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_before = currentContract.idToChains[chainId].messageGasLimit;

    // call function under test
    stopMessagesFromChain(e, chainId);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_after = currentContract.idToChains[chainId].messageGasLimit;

    // verify integrity
    assert (currentContract_idToChains_chainId__messageGasLimit_after == currentContract_idToChains_chainId__messageGasLimit_before), "idToChains[chainId].messageGasLimit@after == idToChains[chainId].messageGasLimit@before";
}

/*
 * idToChains[chainId].allowMessagesFrom@before == false => revert
 *
 * What it means: The function should revert if messages from the chain are already disabled
 *
 * Why it should hold: No-op operations should revert to prevent unnecessary state changes and gas waste
 *
 * Possible consequences: Gas waste and potential confusion about the actual state of the system
 */
rule stopMessagesFromChain_d555f368_no_change_if_already_disabled(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_before = currentContract.idToChains[chainId].allowMessagesFrom;

    // call function under test
    stopMessagesFromChain@withrevert(e, chainId);
    bool stopMessagesFromChain_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_idToChains_chainId__allowMessagesFrom_before == false) => stopMessagesFromChain_reverted), "idToChains[chainId].allowMessagesFrom@before == false => revert";
}

/*
 * chainId != otherChainId => idToChains[otherChainId].allowMessagesFrom@after == idToChains[otherChainId].allowMessagesFrom@before
 *
 * What it means: The allowMessagesFrom setting for other chains should remain unchanged
 *
 * Why it should hold: The function should only affect the specified chain, not other chains in the system
 *
 * Possible consequences: Unintended blocking of legitimate chains, causing widespread DoS
 */
rule stopMessagesFromChain_d555f368_other_chains_unchanged(env e) {
    uint32 chainId;
    uint32 otherChainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_otherChainId__allowMessagesFrom_before = currentContract.idToChains[otherChainId].allowMessagesFrom;

    // call function under test
    stopMessagesFromChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_idToChains_otherChainId__allowMessagesFrom_after = currentContract.idToChains[otherChainId].allowMessagesFrom;

    // verify integrity
    assert ((chainId != otherChainId) => (currentContract_idToChains_otherChainId__allowMessagesFrom_after == currentContract_idToChains_otherChainId__allowMessagesFrom_before)), "chainId != otherChainId => idToChains[otherChainId].allowMessagesFrom@after == idToChains[otherChainId].allowMessagesFrom@before";
}

/*
 * chainId != otherChainId => idToChains[otherChainId].allowMessagesTo@after == idToChains[otherChainId].allowMessagesTo@before
 *
 * What it means: The allowMessagesTo setting for other chains should remain unchanged
 *
 * Why it should hold: The function should only affect the specified chain's incoming messages, not outgoing messages to other chains
 *
 * Possible consequences: Unintended disruption of outgoing message functionality to unrelated chains
 */
rule stopMessagesFromChain_d555f368_other_chains_to_unchanged(env e) {
    uint32 chainId;
    uint32 otherChainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_otherChainId__allowMessagesTo_before = currentContract.idToChains[otherChainId].allowMessagesTo;

    // call function under test
    stopMessagesFromChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_idToChains_otherChainId__allowMessagesTo_after = currentContract.idToChains[otherChainId].allowMessagesTo;

    // verify integrity
    assert ((chainId != otherChainId) => (currentContract_idToChains_otherChainId__allowMessagesTo_after == currentContract_idToChains_otherChainId__allowMessagesTo_before)), "chainId != otherChainId => idToChains[otherChainId].allowMessagesTo@after == idToChains[otherChainId].allowMessagesTo@before";
}

/*
 * chainId != otherChainId => idToChains[otherChainId].messageGasLimit@after == idToChains[otherChainId].messageGasLimit@before
 *
 * What it means: The messageGasLimit setting for other chains should remain unchanged
 *
 * Why it should hold: Gas limit configurations for other chains are unrelated to stopping messages from the target chain
 *
 * Possible consequences: Corruption of gas settings for other chains, potentially causing message failures
 */
rule stopMessagesFromChain_d555f368_other_chains_gas_unchanged(env e) {
    uint32 chainId;
    uint32 otherChainId;

    // assign all the 'before' variables
    uint128 currentContract_idToChains_otherChainId__messageGasLimit_before = currentContract.idToChains[otherChainId].messageGasLimit;

    // call function under test
    stopMessagesFromChain(e, chainId);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_otherChainId__messageGasLimit_after = currentContract.idToChains[otherChainId].messageGasLimit;

    // verify integrity
    assert ((chainId != otherChainId) => (currentContract_idToChains_otherChainId__messageGasLimit_after == currentContract_idToChains_otherChainId__messageGasLimit_before)), "chainId != otherChainId => idToChains[otherChainId].messageGasLimit@after == idToChains[otherChainId].messageGasLimit@before";
}

/*
 * isPaused@after == isPaused@before
 *
 * What it means: The function should not change the global isPaused state
 *
 * Why it should hold: Chain-specific message blocking is independent of the global pause mechanism
 *
 * Possible consequences: Unintended global system shutdown or unexpected unpausing
 */
rule stopMessagesFromChain_d555f368_no_effect_on_paused(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    stopMessagesFromChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_isPaused_after = currentContract.isPaused;

    // verify integrity
    assert (currentContract_isPaused_after == currentContract_isPaused_before), "isPaused@after == isPaused@before";
}

/*
 * depositNonce@after == depositNonce@before
 *
 * What it means: The function should not change the deposit nonce counter
 *
 * Why it should hold: Deposit nonce tracking is unrelated to chain message permissions
 *
 * Possible consequences: Corruption of deposit tracking, potentially enabling replay attacks or breaking deposit history
 */
rule stopMessagesFromChain_d555f368_no_effect_on_nonce(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;

    // call function under test
    stopMessagesFromChain(e, chainId);

    // assign all the 'after' variables
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;

    // verify integrity
    assert (currentContract_depositNonce_after == currentContract_depositNonce_before), "depositNonce@after == depositNonce@before";
}

/*
 * shareLockPeriod@after == shareLockPeriod@before
 *
 * What it means: The function should not change the share lock period setting
 *
 * Why it should hold: Share lock period is a global deposit setting unrelated to chain message permissions
 *
 * Possible consequences: Unintended changes to share locking behavior affecting user fund security
 */
rule stopMessagesFromChain_d555f368_no_effect_on_lock_period(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;

    // call function under test
    stopMessagesFromChain(e, chainId);

    // assign all the 'after' variables
    uint64 currentContract_shareLockPeriod_after = currentContract.shareLockPeriod;

    // verify integrity
    assert (currentContract_shareLockPeriod_after == currentContract_shareLockPeriod_before), "shareLockPeriod@after == shareLockPeriod@before";
}

/*
 * depositCap@after == depositCap@before
 *
 * What it means: The function should not change the global deposit cap limit
 *
 * Why it should hold: Deposit cap is a global limit unrelated to chain-specific message permissions
 *
 * Possible consequences: Unintended changes to deposit limits, either blocking legitimate deposits or removing important caps
 */
rule stopMessagesFromChain_d555f368_no_effect_on_deposit_cap(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint112 currentContract_depositCap_before = currentContract.depositCap;

    // call function under test
    stopMessagesFromChain(e, chainId);

    // assign all the 'after' variables
    uint112 currentContract_depositCap_after = currentContract.depositCap;

    // verify integrity
    assert (currentContract_depositCap_after == currentContract_depositCap_before), "depositCap@after == depositCap@before";
}

/*
 * isPaused@before => revert
 *
 * What it means: The function must revert if the contract is paused before the function call
 *
 * Why it should hold: Based on the contract pattern, administrative functions should respect the paused state to prevent operations during emergency situations or maintenance
 *
 * Possible consequences: State corruption during emergency situations, bypassing of safety mechanisms, unauthorized operations during maintenance periods
 */
rule stopMessagesToChain_45ad6063_paused_reverts(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;

    // assumptions to prevent false positives
    require !(currentContract.isPaused), "Pause state must affect all contract functions consistently";

    // call function under test
    stopMessagesToChain@withrevert(e, chainId);
    bool stopMessagesToChain_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (currentContract_isPaused_before => stopMessagesToChain_reverted), "isPaused@before => revert";
}

/*
 * idToChains[chainId].allowMessagesTo@after == false
 *
 * What it means: After the function executes, the allowMessagesTo flag for the specified chainId must be set to false
 *
 * Why it should hold: This is the core functionality of stopMessagesToChain - it should disable outgoing messages to the specified chain
 *
 * Possible consequences: Function failure to perform its intended purpose, messages continuing to flow to chains that should be blocked
 */
rule stopMessagesToChain_45ad6063_chain_messages_disabled(env e) {
    uint32 chainId;

    // assign all the 'before' variables

    // call function under test
    stopMessagesToChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_after = currentContract.idToChains[chainId].allowMessagesTo;

    // verify integrity
    assert (currentContract_idToChains_chainId__allowMessagesTo_after == false), "idToChains[chainId].allowMessagesTo@after == false";
}

/*
 * idToChains[chainId].messageGasLimit@after == idToChains[chainId].messageGasLimit@before
 *
 * What it means: The messageGasLimit for the chain should remain the same before and after the function call
 *
 * Why it should hold: stopMessagesToChain should only disable messages, not modify gas limit settings which are separate configuration parameters
 *
 * Possible consequences: Unintended gas limit changes could cause message failures or excessive costs
 */
rule stopMessagesToChain_45ad6063_gas_limit_unchanged(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_before = currentContract.idToChains[chainId].messageGasLimit;

    // call function under test
    stopMessagesToChain(e, chainId);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_after = currentContract.idToChains[chainId].messageGasLimit;

    // verify integrity
    assert (currentContract_idToChains_chainId__messageGasLimit_after == currentContract_idToChains_chainId__messageGasLimit_before), "idToChains[chainId].messageGasLimit@after == idToChains[chainId].messageGasLimit@before";
}

/*
 * idToChains[chainId].allowMessagesFrom@after == idToChains[chainId].allowMessagesFrom@before
 *
 * What it means: The allowMessagesFrom flag should remain unchanged before and after the function call
 *
 * Why it should hold: stopMessagesToChain should only affect outgoing messages (allowMessagesTo), not incoming messages (allowMessagesFrom)
 *
 * Possible consequences: Unintended blocking of incoming messages could break bidirectional communication
 */
rule stopMessagesToChain_45ad6063_messages_from_unchanged(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_before = currentContract.idToChains[chainId].allowMessagesFrom;

    // call function under test
    stopMessagesToChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_after = currentContract.idToChains[chainId].allowMessagesFrom;

    // verify integrity
    assert (currentContract_idToChains_chainId__allowMessagesFrom_after == currentContract_idToChains_chainId__allowMessagesFrom_before), "idToChains[chainId].allowMessagesFrom@after == idToChains[chainId].allowMessagesFrom@before";
}

/*
 * !idToChains[chainId].allowMessagesTo@before => revert
 *
 * What it means: If messages to the chain are already disabled, the function should revert as it's a no-op
 *
 * Why it should hold: Following the no-op prevention pattern, meaningless operations should revert to prevent wasted gas and indicate incorrect usage
 *
 * Possible consequences: Wasted gas costs, unclear system state, potential for scripting errors in admin operations
 */
rule stopMessagesToChain_45ad6063_already_disabled_no_op(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_before = currentContract.idToChains[chainId].allowMessagesTo;

    // call function under test
    stopMessagesToChain@withrevert(e, chainId);
    bool stopMessagesToChain_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (!(currentContract_idToChains_chainId__allowMessagesTo_before) => stopMessagesToChain_reverted), "!idToChains[chainId].allowMessagesTo@before => revert";
}

/*
 * chainId == 0 => idToChains[0].allowMessagesTo@after == false
 *
 * What it means: The function should work correctly even when chainId is 0, setting allowMessagesTo to false
 *
 * Why it should hold: Chain ID 0 might be a valid chain identifier in LayerZero, so the function should handle it consistently
 *
 * Possible consequences: Inconsistent behavior for edge case chain IDs could lead to security gaps
 */
rule stopMessagesToChain_45ad6063_zero_chain_allowed(env e) {
    uint32 chainId;

    // assign all the 'before' variables

    // call function under test
    stopMessagesToChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_idToChains_0__allowMessagesTo_after = currentContract.idToChains[0].allowMessagesTo;

    // verify integrity
    assert ((chainId == 0) => (currentContract_idToChains_0__allowMessagesTo_after == false)), "chainId == 0 => idToChains[0].allowMessagesTo@after == false";
}

/*
 * chainId != otherChainId => idToChains[otherChainId].allowMessagesTo@after == idToChains[otherChainId].allowMessagesTo@before
 *
 * What it means: The allowMessagesTo setting for all other chains (not the target chainId) should remain unchanged
 *
 * Why it should hold: stopMessagesToChain should only affect the specified chain, not have side effects on other chains
 *
 * Possible consequences: Unintended blocking of other chains could cause widespread service disruption
 */
rule stopMessagesToChain_45ad6063_other_chains_unchanged(env e) {
    uint32 chainId;
    uint32 otherChainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_otherChainId__allowMessagesTo_before = currentContract.idToChains[otherChainId].allowMessagesTo;

    // call function under test
    stopMessagesToChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_idToChains_otherChainId__allowMessagesTo_after = currentContract.idToChains[otherChainId].allowMessagesTo;

    // verify integrity
    assert ((chainId != otherChainId) => (currentContract_idToChains_otherChainId__allowMessagesTo_after == currentContract_idToChains_otherChainId__allowMessagesTo_before)), "chainId != otherChainId => idToChains[otherChainId].allowMessagesTo@after == idToChains[otherChainId].allowMessagesTo@before";
}

/*
 * depositNonce@after == depositNonce@before
 *
 * What it means: The depositNonce counter should not change during this function call
 *
 * Why it should hold: stopMessagesToChain is a chain configuration function and should not affect deposit tracking state
 *
 * Possible consequences: Corrupted deposit tracking could lead to deposit hash collisions or replay attacks
 */
rule stopMessagesToChain_45ad6063_deposit_state_unchanged(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;

    // call function under test
    stopMessagesToChain(e, chainId);

    // assign all the 'after' variables
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;

    // verify integrity
    assert (currentContract_depositNonce_after == currentContract_depositNonce_before), "depositNonce@after == depositNonce@before";
}

/*
 * shareLockPeriod@after == shareLockPeriod@before
 *
 * What it means: The shareLockPeriod setting should remain unchanged during this function call
 *
 * Why it should hold: stopMessagesToChain should only affect chain routing, not user share lock policies
 *
 * Possible consequences: Unintended changes to lock periods could affect user fund security or withdrawal timing
 */
rule stopMessagesToChain_45ad6063_lock_period_unchanged(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;

    // call function under test
    stopMessagesToChain(e, chainId);

    // assign all the 'after' variables
    uint64 currentContract_shareLockPeriod_after = currentContract.shareLockPeriod;

    // verify integrity
    assert (currentContract_shareLockPeriod_after == currentContract_shareLockPeriod_before), "shareLockPeriod@after == shareLockPeriod@before";
}

/*
 * depositCap@after == depositCap@before
 *
 * What it means: The global deposit cap should remain unchanged during this function call
 *
 * Why it should hold: stopMessagesToChain is about message routing, not deposit limits, so it shouldn't affect the deposit cap
 *
 * Possible consequences: Unintended cap changes could either block legitimate deposits or allow excessive deposits
 */
rule stopMessagesToChain_45ad6063_deposit_cap_unchanged(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint112 currentContract_depositCap_before = currentContract.depositCap;

    // call function under test
    stopMessagesToChain(e, chainId);

    // assign all the 'after' variables
    uint112 currentContract_depositCap_after = currentContract.depositCap;

    // verify integrity
    assert (currentContract_depositCap_after == currentContract_depositCap_before), "depositCap@after == depositCap@before";
}

/*
 * permissionedTransfers@after == permissionedTransfers@before
 *
 * What it means: The permissionedTransfers flag should remain unchanged during this function call
 *
 * Why it should hold: stopMessagesToChain should only affect cross-chain messaging, not local transfer permissions
 *
 * Possible consequences: Unintended changes to transfer permissions could break access controls
 */
rule stopMessagesToChain_45ad6063_permission_transfers_unchanged(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    bool currentContract_permissionedTransfers_before = currentContract.permissionedTransfers;

    // call function under test
    stopMessagesToChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_permissionedTransfers_after = currentContract.permissionedTransfers;

    // verify integrity
    assert (currentContract_permissionedTransfers_after == currentContract_permissionedTransfers_before), "permissionedTransfers@after == permissionedTransfers@before";
}

/*
 * messageGasLimit == 0 => revert
 *
 * What it means: The function must revert when messageGasLimit parameter is zero
 *
 * Why it should hold: Based on the pattern in other functions like allowMessagesToChain which explicitly checks for zero gas limit and reverts with LayerZeroTeller__ZeroMessageGasLimit, this function should enforce the same validation to prevent invalid configurations
 *
 * Possible consequences: Setting zero gas limit would break cross-chain message delivery as LayerZero requires non-zero gas for execution, leading to failed bridging operations and potential fund loss
 */
rule setChainGasLimit_1568fc58_zero_gas_limit_reverts(env e) {
    uint32 chainId;
    uint128 messageGasLimit;

    // assign all the 'before' variables

    // call function under test
    setChainGasLimit@withrevert(e, chainId, messageGasLimit);
    bool setChainGasLimit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((messageGasLimit == 0) => setChainGasLimit_reverted), "messageGasLimit == 0 => revert";
}

/*
 * idToChains[chainId].allowMessagesTo@before == false && idToChains[chainId].allowMessagesFrom@before == false => revert
 *
 * What it means: The function must revert when trying to set gas limit for a chain that has both allowMessagesTo and allowMessagesFrom set to false
 *
 * Why it should hold: Setting gas limits for unconfigured chains is meaningless since no messages can flow in either direction, and could indicate an admin error or attempt to configure invalid state
 *
 * Possible consequences: Allows configuration of meaningless state that could confuse operators and waste gas, potentially masking real configuration errors
 */
rule setChainGasLimit_1568fc58_chain_not_configured_reverts(env e) {
    uint32 chainId;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_before = currentContract.idToChains[chainId].allowMessagesTo;
    bool currentContract_idToChains_chainId__allowMessagesFrom_before = currentContract.idToChains[chainId].allowMessagesFrom;

    // call function under test
    setChainGasLimit@withrevert(e, chainId, messageGasLimit);
    bool setChainGasLimit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((currentContract_idToChains_chainId__allowMessagesTo_before == false) && (currentContract_idToChains_chainId__allowMessagesFrom_before == false)) => setChainGasLimit_reverted), "idToChains[chainId].allowMessagesTo@before == false && idToChains[chainId].allowMessagesFrom@before == false => revert";
}

/*
 * messageGasLimit > 0 && (idToChains[chainId].allowMessagesTo@before == true || idToChains[chainId].allowMessagesFrom@before == true) => idToChains[chainId].messageGasLimit@after == messageGasLimit
 *
 * What it means: When messageGasLimit is greater than zero and the chain allows messages in at least one direction, the gas limit should be updated to the new value
 *
 * Why it should hold: This is the core functionality of the function - to update the gas limit for valid chains that can send or receive messages
 *
 * Possible consequences: If gas limit isn't updated properly, cross-chain messages could fail due to insufficient gas allocation, breaking the bridging functionality
 */
rule setChainGasLimit_1568fc58_updates_gas_limit(env e) {
    uint32 chainId;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_before = currentContract.idToChains[chainId].allowMessagesTo;
    bool currentContract_idToChains_chainId__allowMessagesFrom_before = currentContract.idToChains[chainId].allowMessagesFrom;

    // call function under test
    setChainGasLimit(e, chainId, messageGasLimit);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_after = currentContract.idToChains[chainId].messageGasLimit;

    // verify integrity
    assert (((messageGasLimit > 0) && ((currentContract_idToChains_chainId__allowMessagesTo_before == true) || (currentContract_idToChains_chainId__allowMessagesFrom_before == true))) => (currentContract_idToChains_chainId__messageGasLimit_after == messageGasLimit)), "messageGasLimit > 0 && (idToChains[chainId].allowMessagesTo@before == true || idToChains[chainId].allowMessagesFrom@before == true) => idToChains[chainId].messageGasLimit@after == messageGasLimit";
}

/*
 * idToChains[chainId].allowMessagesFrom@after == idToChains[chainId].allowMessagesFrom@before
 *
 * What it means: The allowMessagesFrom flag for the chain should remain unchanged after setting gas limit
 *
 * Why it should hold: setChainGasLimit should only modify gas limit, not message direction permissions, to maintain separation of concerns and prevent unintended permission changes
 *
 * Possible consequences: Unintended changes to message permissions could break existing bridging flows or create security vulnerabilities
 */
rule setChainGasLimit_1568fc58_preserves_allow_from(env e) {
    uint32 chainId;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_before = currentContract.idToChains[chainId].allowMessagesFrom;

    // call function under test
    setChainGasLimit(e, chainId, messageGasLimit);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_after = currentContract.idToChains[chainId].allowMessagesFrom;

    // verify integrity
    assert (currentContract_idToChains_chainId__allowMessagesFrom_after == currentContract_idToChains_chainId__allowMessagesFrom_before), "idToChains[chainId].allowMessagesFrom@after == idToChains[chainId].allowMessagesFrom@before";
}

/*
 * idToChains[chainId].allowMessagesTo@after == idToChains[chainId].allowMessagesTo@before
 *
 * What it means: The allowMessagesTo flag for the chain should remain unchanged after setting gas limit
 *
 * Why it should hold: setChainGasLimit should only modify gas limit, not message direction permissions, maintaining function scope and preventing accidental permission changes
 *
 * Possible consequences: Unintended changes to outbound message permissions could disable bridging to specific chains or create security holes
 */
rule setChainGasLimit_1568fc58_preserves_allow_to(env e) {
    uint32 chainId;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_before = currentContract.idToChains[chainId].allowMessagesTo;

    // call function under test
    setChainGasLimit(e, chainId, messageGasLimit);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_after = currentContract.idToChains[chainId].allowMessagesTo;

    // verify integrity
    assert (currentContract_idToChains_chainId__allowMessagesTo_after == currentContract_idToChains_chainId__allowMessagesTo_before), "idToChains[chainId].allowMessagesTo@after == idToChains[chainId].allowMessagesTo@before";
}

/*
 * idToChains[chainId].messageGasLimit@before == messageGasLimit => revert
 *
 * What it means: The function must revert when the new messageGasLimit is the same as the current value
 *
 * Why it should hold: Following the NO-OPS MUST REVERT principle, setting the same gas limit value is a meaningless operation that should be prevented to avoid wasted gas and indicate potential errors
 *
 * Possible consequences: Allows wasteful transactions and could mask bugs in calling code that repeatedly sets the same value
 */
rule setChainGasLimit_1568fc58_no_change_reverts(env e) {
    uint32 chainId;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_before = currentContract.idToChains[chainId].messageGasLimit;

    // call function under test
    setChainGasLimit@withrevert(e, chainId, messageGasLimit);
    bool setChainGasLimit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_idToChains_chainId__messageGasLimit_before == messageGasLimit) => setChainGasLimit_reverted), "idToChains[chainId].messageGasLimit@before == messageGasLimit => revert";
}

/*
 * chainId != otherChainId => idToChains[otherChainId].messageGasLimit@after == idToChains[otherChainId].messageGasLimit@before
 *
 * What it means: Gas limits for other chains (different chainId) should remain unchanged when updating one specific chain
 *
 * Why it should hold: Function should only affect the specified chain to prevent unintended side effects on other chain configurations
 *
 * Possible consequences: Modifying other chains' gas limits could break their bridging operations and cause widespread system failures
 */
rule setChainGasLimit_1568fc58_other_chains_unchanged(env e) {
    uint32 chainId;
    uint128 messageGasLimit;
    uint32 otherChainId;

    // assign all the 'before' variables
    uint128 currentContract_idToChains_otherChainId__messageGasLimit_before = currentContract.idToChains[otherChainId].messageGasLimit;

    // call function under test
    setChainGasLimit(e, chainId, messageGasLimit);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_otherChainId__messageGasLimit_after = currentContract.idToChains[otherChainId].messageGasLimit;

    // verify integrity
    assert ((chainId != otherChainId) => (currentContract_idToChains_otherChainId__messageGasLimit_after == currentContract_idToChains_otherChainId__messageGasLimit_before)), "chainId != otherChainId => idToChains[otherChainId].messageGasLimit@after == idToChains[otherChainId].messageGasLimit@before";
}

/*
 * isPaused@after == isPaused@before
 *
 * What it means: The global isPaused flag should not be modified by this function
 *
 * Why it should hold: setChainGasLimit is a configuration function that shouldn't affect the global pause state, maintaining separation of concerns
 *
 * Possible consequences: Unintended pause state changes could disable or enable the entire system inappropriately
 */
rule setChainGasLimit_1568fc58_paused_state_unchanged(env e) {
    uint32 chainId;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    setChainGasLimit(e, chainId, messageGasLimit);

    // assign all the 'after' variables
    bool currentContract_isPaused_after = currentContract.isPaused;

    // verify integrity
    assert (currentContract_isPaused_after == currentContract_isPaused_before), "isPaused@after == isPaused@before";
}

/*
 * depositNonce@after == depositNonce@before
 *
 * What it means: The deposit nonce counter should not be modified by this function
 *
 * Why it should hold: setChainGasLimit is unrelated to deposit operations and shouldn't affect deposit tracking mechanisms
 *
 * Possible consequences: Modifying deposit nonce could break deposit history tracking and refund mechanisms
 */
rule setChainGasLimit_1568fc58_deposit_nonce_unchanged(env e) {
    uint32 chainId;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;

    // call function under test
    setChainGasLimit(e, chainId, messageGasLimit);

    // assign all the 'after' variables
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;

    // verify integrity
    assert (currentContract_depositNonce_after == currentContract_depositNonce_before), "depositNonce@after == depositNonce@before";
}

/*
 * shareLockPeriod@after == shareLockPeriod@before
 *
 * What it means: The global shareLockPeriod should not be modified by this function
 *
 * Why it should hold: setChainGasLimit is for cross-chain configuration and shouldn't affect local share locking mechanisms
 *
 * Possible consequences: Unintended changes to share lock period could affect user fund security and deposit refund windows
 */
rule setChainGasLimit_1568fc58_share_lock_unchanged(env e) {
    uint32 chainId;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;

    // call function under test
    setChainGasLimit(e, chainId, messageGasLimit);

    // assign all the 'after' variables
    uint64 currentContract_shareLockPeriod_after = currentContract.shareLockPeriod;

    // verify integrity
    assert (currentContract_shareLockPeriod_after == currentContract_shareLockPeriod_before), "shareLockPeriod@after == shareLockPeriod@before";
}