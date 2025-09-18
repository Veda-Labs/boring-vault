import "dispatching_LayerZeroTellerWithRateLimiting.spec";

/*
 * chainId == 0 => revert
 *
 * What it means: The function must revert when chainId parameter is zero
 *
 * Why it should hold: Chain ID 0 is typically reserved or invalid in LayerZero protocol, and allowing it could cause routing issues or conflicts with default mappings
 *
 * Possible consequences: State corruption, message routing failures, potential conflicts with uninitialized chain mappings
 */
// gereon: is it true, that zero is usually invalid?
rule __addChain_34dafd6b_zero_chain_id_reverts(env e) {
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
    assert ((chainId == 0) => addChain_reverted), "chainId == 0 => revert";
}

/*
 * messageGasLimit == 0 => revert
 *
 * What it means: The function must revert when messageGasLimit parameter is zero
 *
 * Why it should hold: Zero gas limit would make cross-chain messages fail on the destination chain due to insufficient gas for execution
 *
 * Possible consequences: DoS of cross-chain functionality, stuck messages, user funds locked in failed bridge transactions
 */
// only when allowMessagesTo is true
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
    assert ((allowMessagesTo && messageGasLimit == 0) => addChain_reverted), "messageGasLimit == 0 => revert";
}

/*
 * targetTeller == address(0) => revert
 *
 * What it means: The function must revert when targetTeller parameter is the zero address
 *
 * Why it should hold: Zero address as target teller would make cross-chain messages undeliverable and could cause message routing failures
 *
 * Possible consequences: DoS of cross-chain bridging, messages sent to invalid addresses, potential fund loss
 */
// gereon: probably true
rule __addChain_34dafd6b_zero_target_teller_reverts(env e) {
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
    assert ((targetTeller == 0) => addChain_reverted), "targetTeller == address(0) => revert";
}

/*
 * allowMessagesFrom => idToChains[chainId].allowMessagesFrom@after == true
 *
 * What it means: When allowMessagesFrom is true, the chain's allowMessagesFrom flag must be set to true after execution
 *
 * Why it should hold: This ensures the intended configuration is properly stored and messages from the specified chain will be accepted
 *
 * Possible consequences: Configuration mismatch, unexpected message rejections, broken cross-chain functionality
 */
rule addChain_34dafd6b_chain_allow_from_set(env e) {
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
    assert (allowMessagesFrom => (currentContract_idToChains_chainId__allowMessagesFrom_after == true)), "allowMessagesFrom => idToChains[chainId].allowMessagesFrom@after == true";
}

/*
 * allowMessagesTo => idToChains[chainId].allowMessagesTo@after == true
 *
 * What it means: When allowMessagesTo is true, the chain's allowMessagesTo flag must be set to true after execution
 *
 * Why it should hold: This ensures the intended configuration is properly stored and messages to the specified chain will be allowed
 *
 * Possible consequences: Configuration mismatch, unexpected message sending failures, broken cross-chain functionality
 */
rule addChain_34dafd6b_chain_allow_to_set(env e) {
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
    assert (allowMessagesTo => (currentContract_idToChains_chainId__allowMessagesTo_after == true)), "allowMessagesTo => idToChains[chainId].allowMessagesTo@after == true";
}

/*
 * !allowMessagesFrom => idToChains[chainId].allowMessagesFrom@after == false
 *
 * What it means: When allowMessagesFrom is false, the chain's allowMessagesFrom flag must be set to false after execution
 *
 * Why it should hold: This ensures security restrictions are properly enforced and unwanted messages from untrusted chains are blocked
 *
 * Possible consequences: Security bypass, acceptance of messages from untrusted chains, potential governance attacks
 */
rule addChain_34dafd6b_chain_deny_from_set(env e) {
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
    assert (!(allowMessagesFrom) => (currentContract_idToChains_chainId__allowMessagesFrom_after == false)), "!allowMessagesFrom => idToChains[chainId].allowMessagesFrom@after == false";
}

/*
 * !allowMessagesTo => idToChains[chainId].allowMessagesTo@after == false
 *
 * What it means: When allowMessagesTo is false, the chain's allowMessagesTo flag must be set to false after execution
 *
 * Why it should hold: This ensures security restrictions are properly enforced and messages to untrusted or problematic chains are blocked
 *
 * Possible consequences: Security bypass, messages sent to compromised chains, potential fund loss
 */
rule addChain_34dafd6b_chain_deny_to_set(env e) {
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
    assert (!(allowMessagesTo) => (currentContract_idToChains_chainId__allowMessagesTo_after == false)), "!allowMessagesTo => idToChains[chainId].allowMessagesTo@after == false";
}

/*
 * idToChains[chainId].messageGasLimit@after == messageGasLimit
 *
 * What it means: The messageGasLimit parameter must be correctly stored in the chain configuration after execution
 *
 * Why it should hold: Proper gas limit storage is essential for successful cross-chain message execution on the destination chain
 *
 * Possible consequences: Message execution failures, stuck transactions, fund loss from failed bridge operations
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
    assert (currentContract_idToChains_chainId__messageGasLimit_after == messageGasLimit), "idToChains[chainId].messageGasLimit@after == messageGasLimit";
}

/*
 * idToChains[chainId].allowMessagesFrom@before || idToChains[chainId].allowMessagesTo@before => idToChains[chainId].messageGasLimit@after == messageGasLimit
 *
 * What it means: When updating an existing chain configuration, the new gas limit must be properly stored regardless of previous settings
 *
 * Why it should hold: Chain configurations must be updatable to handle changing network conditions or fix misconfigurations
 *
 * Possible consequences: Inability to fix misconfigurations, stuck with suboptimal gas limits, potential DoS
 */
rule addChain_34dafd6b_existing_chain_overwritten(env e) {
    uint32 chainId;
    bool allowMessagesFrom;
    bool allowMessagesTo;
    address targetTeller;
    uint128 messageGasLimit;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_before = currentContract.idToChains[chainId].allowMessagesFrom;
    bool currentContract_idToChains_chainId__allowMessagesTo_before = currentContract.idToChains[chainId].allowMessagesTo;

    // call function under test
    addChain(e, chainId, allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_after = currentContract.idToChains[chainId].messageGasLimit;

    // verify integrity
    assert ((currentContract_idToChains_chainId__allowMessagesFrom_before || currentContract_idToChains_chainId__allowMessagesTo_before) => (currentContract_idToChains_chainId__messageGasLimit_after == messageGasLimit)), "idToChains[chainId].allowMessagesFrom@before || idToChains[chainId].allowMessagesTo@before => idToChains[chainId].messageGasLimit@after == messageGasLimit";
}

/*
 * chainId != otherChainId => idToChains[chainId].messageGasLimit@after != idToChains[otherChainId].messageGasLimit@after || messageGasLimit == idToChains[otherChainId].messageGasLimit@after
 *
 * What it means: Different chain IDs should maintain distinct gas limit configurations unless explicitly set to the same value
 *
 * Why it should hold: Each chain may have different gas requirements and costs, so configurations should remain independent
 *
 * Possible consequences: Incorrect gas limits applied to wrong chains, message failures, suboptimal gas usage
 */
rule addChain_34dafd6b_chain_uniqueness_preserved(env e) {
    uint32 chainId;
    bool allowMessagesFrom;
    bool allowMessagesTo;
    address targetTeller;
    uint128 messageGasLimit;
    uint32 otherChainId;

    // assign all the 'before' variables

    // call function under test
    addChain(e, chainId, allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_after = currentContract.idToChains[chainId].messageGasLimit;
    uint128 currentContract_idToChains_otherChainId__messageGasLimit_after = currentContract.idToChains[otherChainId].messageGasLimit;

    // verify integrity
    assert ((chainId != otherChainId) => ((currentContract_idToChains_chainId__messageGasLimit_after != currentContract_idToChains_otherChainId__messageGasLimit_after) || (messageGasLimit == currentContract_idToChains_otherChainId__messageGasLimit_after))), "chainId != otherChainId => idToChains[chainId].messageGasLimit@after != idToChains[otherChainId].messageGasLimit@after || messageGasLimit == idToChains[otherChainId].messageGasLimit@after";
}

/*
 * idToChains[chainId].allowMessagesFrom@before == false && idToChains[chainId].allowMessagesTo@before == false && idToChains[chainId].messageGasLimit@before == 0 => revert
 *
 * What it means: The function should revert if trying to remove a chain that doesn't exist (all chain data is already zero/false)
 *
 * Why it should hold: Removing a non-existent chain is a no-op operation that provides no meaningful functionality and indicates a programming error or misuse
 *
 * Possible consequences: Silent failures where admins think they've removed a chain but nothing actually happened, leading to confusion about system state
 */
// gereon: maybe, but the function is pretty cheap
rule __removeChain_55a2d64d_chain_must_exist(env e) {
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
 * What it means: If a chain currently allows incoming messages, removeChain should disable incoming messages from that chain
 *
 * Why it should hold: This is the core functionality of removeChain - it should completely disconnect the chain by disabling message reception
 *
 * Possible consequences: Chain removal would be incomplete, leaving the bridge partially functional and potentially allowing unwanted cross-chain operations
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
 * What it means: If a chain currently allows outgoing messages, removeChain should disable outgoing messages to that chain
 *
 * Why it should hold: This completes the chain disconnection by preventing users from sending messages to the removed chain
 *
 * Possible consequences: Users could continue bridging to a removed/compromised chain, potentially losing funds or having shares stuck
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
 * What it means: If a chain has a configured gas limit, removeChain should reset it to zero
 *
 * Why it should hold: Gas limit configuration is part of the chain setup and should be cleared when the chain is removed to prevent any residual configuration
 *
 * Possible consequences: Stale configuration could cause issues if the chain is re-added later with different requirements
 */
rule removeChain_55a2d64d_clears_message_gas_limit(env e) {
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
 * otherChainId != chainId => idToChains[otherChainId].allowMessagesFrom@after == idToChains[otherChainId].allowMessagesFrom@before && idToChains[otherChainId].allowMessagesTo@after == idToChains[otherChainId].allowMessagesTo@before && idToChains[otherChainId].messageGasLimit@after == idToChains[otherChainId].messageGasLimit@before
 *
 * What it means: Removing one chain should not affect the configuration of any other chains
 *
 * Why it should hold: Chain removal should be isolated and not have side effects on unrelated chains to maintain system integrity
 *
 * Possible consequences: Accidental disruption of other bridge routes, potentially breaking legitimate cross-chain operations
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
    assert ((otherChainId != chainId) => (((currentContract_idToChains_otherChainId__allowMessagesFrom_after == currentContract_idToChains_otherChainId__allowMessagesFrom_before) && (currentContract_idToChains_otherChainId__allowMessagesTo_after == currentContract_idToChains_otherChainId__allowMessagesTo_before)) && (currentContract_idToChains_otherChainId__messageGasLimit_after == currentContract_idToChains_otherChainId__messageGasLimit_before))), "otherChainId != chainId => idToChains[otherChainId].allowMessagesFrom@after == idToChains[otherChainId].allowMessagesFrom@before && idToChains[otherChainId].allowMessagesTo@after == idToChains[otherChainId].allowMessagesTo@before && idToChains[otherChainId].messageGasLimit@after == idToChains[otherChainId].messageGasLimit@before";
}

/*
 * outboundRateLimits[chainId].limit@before > 0 || outboundRateLimits[chainId].window@before > 0 => outboundRateLimits[chainId].limit@after == 0 && outboundRateLimits[chainId].window@after == 0
 *
 * What it means: If a chain has outbound rate limiting configured, removeChain should clear the rate limit settings
 *
 * Why it should hold: Rate limits are chain-specific security measures that should be removed when the chain is disconnected
 *
 * Possible consequences: Stale rate limit data could interfere with future chain re-addition or cause confusion about system state
 */
// gereon: this sounds reasonable. Otherwise a newly added chain might start with non-default values.
rule __removeChain_55a2d64d_clears_outbound_rate_limit(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint256 currentContract_outboundRateLimits_chainId__limit_before = currentContract.outboundRateLimits[chainId].limit;
    uint256 currentContract_outboundRateLimits_chainId__window_before = currentContract.outboundRateLimits[chainId].window;

    // call function under test
    removeChain(e, chainId);

    // assign all the 'after' variables
    uint256 currentContract_outboundRateLimits_chainId__limit_after = currentContract.outboundRateLimits[chainId].limit;
    uint256 currentContract_outboundRateLimits_chainId__window_after = currentContract.outboundRateLimits[chainId].window;

    // verify integrity
    assert (((currentContract_outboundRateLimits_chainId__limit_before > 0) || (currentContract_outboundRateLimits_chainId__window_before > 0)) => ((currentContract_outboundRateLimits_chainId__limit_after == 0) && (currentContract_outboundRateLimits_chainId__window_after == 0))), "outboundRateLimits[chainId].limit@before > 0 || outboundRateLimits[chainId].window@before > 0 => outboundRateLimits[chainId].limit@after == 0 && outboundRateLimits[chainId].window@after == 0";
}

/*
 * inboundRateLimits[chainId].limit@before > 0 || inboundRateLimits[chainId].window@before > 0 => inboundRateLimits[chainId].limit@after == 0 && inboundRateLimits[chainId].window@after == 0
 *
 * What it means: If a chain has inbound rate limiting configured, removeChain should clear the rate limit settings
 *
 * Why it should hold: Inbound rate limits should be cleared when a chain is removed to prevent stale security configurations
 *
 * Possible consequences: Residual rate limit state could cause issues with chain re-addition or system maintenance
 */
// gereon: this sounds reasonable. Otherwise a newly added chain might start with non-default values.
rule __removeChain_55a2d64d_clears_inbound_rate_limit(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint256 currentContract_inboundRateLimits_chainId__limit_before = currentContract.inboundRateLimits[chainId].limit;
    uint256 currentContract_inboundRateLimits_chainId__window_before = currentContract.inboundRateLimits[chainId].window;

    // call function under test
    removeChain(e, chainId);

    // assign all the 'after' variables
    uint256 currentContract_inboundRateLimits_chainId__limit_after = currentContract.inboundRateLimits[chainId].limit;
    uint256 currentContract_inboundRateLimits_chainId__window_after = currentContract.inboundRateLimits[chainId].window;

    // verify integrity
    assert (((currentContract_inboundRateLimits_chainId__limit_before > 0) || (currentContract_inboundRateLimits_chainId__window_before > 0)) => ((currentContract_inboundRateLimits_chainId__limit_after == 0) && (currentContract_inboundRateLimits_chainId__window_after == 0))), "inboundRateLimits[chainId].limit@before > 0 || inboundRateLimits[chainId].window@before > 0 => inboundRateLimits[chainId].limit@after == 0 && inboundRateLimits[chainId].window@after == 0";
}

/*
 * outboundRateLimits[chainId].lastUpdated@before > 0 => outboundRateLimits[chainId].lastUpdated@after == 0
 *
 * What it means: If outbound rate limits have timestamp data, removeChain should reset the lastUpdated timestamp to zero
 *
 * Why it should hold: Timestamp data is part of rate limiting state that should be cleared when removing a chain
 *
 * Possible consequences: Stale timestamps could cause incorrect rate limit calculations if the chain is re-added
 */
// gereon: this sounds reasonable. Otherwise a newly added chain might start with non-default values.
rule __removeChain_55a2d64d_resets_rate_limit_timestamps(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint256 currentContract_outboundRateLimits_chainId__lastUpdated_before = currentContract.outboundRateLimits[chainId].lastUpdated;

    // call function under test
    removeChain(e, chainId);

    // assign all the 'after' variables
    uint256 currentContract_outboundRateLimits_chainId__lastUpdated_after = currentContract.outboundRateLimits[chainId].lastUpdated;

    // verify integrity
    assert ((currentContract_outboundRateLimits_chainId__lastUpdated_before > 0) => (currentContract_outboundRateLimits_chainId__lastUpdated_after == 0)), "outboundRateLimits[chainId].lastUpdated@before > 0 => outboundRateLimits[chainId].lastUpdated@after == 0";
}

/*
 * outboundRateLimits[chainId].amountInFlight@before > 0 => outboundRateLimits[chainId].amountInFlight@after == 0
 *
 * What it means: If outbound rate limits have tracked amounts in flight, removeChain should reset this to zero
 *
 * Why it should hold: Amount in flight tracking is part of rate limiting that should be cleared when a chain is removed
 *
 * Possible consequences: Stale amount tracking could cause incorrect rate limit enforcement if the chain is re-added
 */
// gereon: this sounds reasonable. Otherwise a newly added chain might start with non-default values.
rule __removeChain_55a2d64d_resets_amount_in_flight(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint256 currentContract_outboundRateLimits_chainId__amountInFlight_before = currentContract.outboundRateLimits[chainId].amountInFlight;

    // call function under test
    removeChain(e, chainId);

    // assign all the 'after' variables
    uint256 currentContract_outboundRateLimits_chainId__amountInFlight_after = currentContract.outboundRateLimits[chainId].amountInFlight;

    // verify integrity
    assert ((currentContract_outboundRateLimits_chainId__amountInFlight_before > 0) => (currentContract_outboundRateLimits_chainId__amountInFlight_after == 0)), "outboundRateLimits[chainId].amountInFlight@before > 0 => outboundRateLimits[chainId].amountInFlight@after == 0";
}

/*
 * isPaused@after == isPaused@before
 *
 * What it means: Removing a chain should not change the overall paused state of the contract
 *
 * Why it should hold: Chain removal is a configuration change that should not affect the global operational state of the contract
 *
 * Possible consequences: Unexpected state changes could disrupt ongoing operations or security measures
 */
rule removeChain_55a2d64d_preserves_paused_state(env e) {
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
 * What it means: Removing a chain should not affect the deposit nonce counter used for tracking deposits
 *
 * Why it should hold: Deposit nonce is a global counter unrelated to specific chains and should remain unchanged
 *
 * Possible consequences: Nonce manipulation could cause deposit tracking issues or replay attacks
 */
rule removeChain_55a2d64d_preserves_deposit_nonce(env e) {
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
 * shareLockPeriod@after == shareLockPeriod@before
 *
 * What it means: Removing a chain should not change the global share lock period configuration
 *
 * Why it should hold: Share lock period is a global security parameter unrelated to specific chain configurations
 *
 * Possible consequences: Unexpected changes to share locking could compromise user fund security or system integrity
 */
rule removeChain_55a2d64d_preserves_share_lock_period(env e) {
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
 * chainId == 0 => revert
 *
 * What it means: The function must revert when chainId parameter is zero
 *
 * Why it should hold: Chain ID zero is typically reserved as an invalid/null identifier in cross-chain protocols and should not be used for legitimate chain configurations
 *
 * Possible consequences: State corruption, invalid chain configurations, potential routing failures in cross-chain messaging
 */
// gereon: is it true, that zero is usually invalid?
rule __allowMessagesFromChain_202eac57_chain_id_zero_reverts(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables

    // call function under test
    allowMessagesFromChain@withrevert(e, chainId, targetTeller);
    bool allowMessagesFromChain_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((chainId == 0) => allowMessagesFromChain_reverted), "chainId == 0 => revert";
}

/*
 * targetTeller == address(0) => revert
 *
 * What it means: The function must revert when targetTeller parameter is the zero address
 *
 * Why it should hold: Zero address is invalid for a target teller contract and would break cross-chain messaging functionality
 *
 * Possible consequences: Messages could be sent to or expected from the zero address, causing permanent loss of bridged assets
 */
// gereon: would probably make sense
rule __allowMessagesFromChain_202eac57_target_teller_zero_reverts(env e) {
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
 * idToChains[chainId].allowMessagesFrom@after == true
 *
 * What it means: After execution, the allowMessagesFrom flag for the specified chain must be set to true
 *
 * Why it should hold: This is the primary purpose of the function - to enable message reception from a specific chain
 *
 * Possible consequences: Function would be non-functional, breaking the intended cross-chain communication setup
 */
rule allowMessagesFromChain_202eac57_allows_messages_from_chain(env e) {
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
 * What it means: The allowMessagesTo flag for the chain should remain unchanged after function execution
 *
 * Why it should hold: This function should only affect inbound message permissions, not outbound permissions
 *
 * Possible consequences: Unintended changes to outbound message permissions could break existing functionality
 */
rule allowMessagesFromChain_202eac57_preserves_allow_messages_to(env e) {
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
 * What it means: The messageGasLimit for the chain should remain unchanged after function execution
 *
 * Why it should hold: This function should only affect message permissions, not gas configuration parameters
 *
 * Possible consequences: Unintended gas limit changes could cause message failures or excessive costs
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
 * outboundRateLimits[chainId].limit@after == outboundRateLimits[chainId].limit@before
 *
 * What it means: Outbound rate limits should not be modified by this function
 *
 * Why it should hold: This function is for enabling message reception, not for configuring rate limiting parameters
 *
 * Possible consequences: Unintended rate limit changes could enable DoS attacks or break existing rate limiting protections
 */
rule allowMessagesFromChain_202eac57_no_rate_limit_change(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables
    uint256 currentContract_outboundRateLimits_chainId__limit_before = currentContract.outboundRateLimits[chainId].limit;

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    uint256 currentContract_outboundRateLimits_chainId__limit_after = currentContract.outboundRateLimits[chainId].limit;

    // verify integrity
    assert (currentContract_outboundRateLimits_chainId__limit_after == currentContract_outboundRateLimits_chainId__limit_before), "outboundRateLimits[chainId].limit@after == outboundRateLimits[chainId].limit@before";
}

/*
 * inboundRateLimits[chainId].limit@after == inboundRateLimits[chainId].limit@before
 *
 * What it means: Inbound rate limits should not be modified by this function
 *
 * Why it should hold: Rate limiting configuration should be handled by dedicated functions, not by message permission functions
 *
 * Possible consequences: Unintended rate limit changes could enable DoS attacks or break existing protections
 */
rule allowMessagesFromChain_202eac57_no_inbound_limit_change(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables
    uint256 currentContract_inboundRateLimits_chainId__limit_before = currentContract.inboundRateLimits[chainId].limit;

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    uint256 currentContract_inboundRateLimits_chainId__limit_after = currentContract.inboundRateLimits[chainId].limit;

    // verify integrity
    assert (currentContract_inboundRateLimits_chainId__limit_after == currentContract_inboundRateLimits_chainId__limit_before), "inboundRateLimits[chainId].limit@after == inboundRateLimits[chainId].limit@before";
}

/*
 * depositCap@after == depositCap@before
 *
 * What it means: The global deposit cap should remain unchanged
 *
 * Why it should hold: Deposit caps are unrelated to cross-chain message permissions and should not be affected
 *
 * Possible consequences: Unintended deposit cap changes could break deposit functionality or security limits
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
 * isPaused@after == isPaused@before
 *
 * What it means: The contract's pause state should not be affected by this function
 *
 * Why it should hold: Pause functionality should be controlled by dedicated pause/unpause functions, not by configuration functions
 *
 * Possible consequences: Unintended pause state changes could disrupt contract operations
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
 * What it means: The share lock period should remain unchanged
 *
 * Why it should hold: Share locking parameters are unrelated to cross-chain message permissions
 *
 * Possible consequences: Unintended lock period changes could affect user fund accessibility
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
 * depositNonce@after == depositNonce@before
 *
 * What it means: The deposit nonce counter should not be affected
 *
 * Why it should hold: Deposit nonces are for tracking deposits and should not be modified by message permission functions
 *
 * Possible consequences: Nonce manipulation could break deposit tracking and refund mechanisms
 */
rule allowMessagesFromChain_202eac57_no_nonce_change(env e) {
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
 * permissionedTransfers@after == permissionedTransfers@before
 *
 * What it means: The permissioned transfers flag should remain unchanged
 *
 * Why it should hold: Transfer permissions are unrelated to cross-chain message configuration
 *
 * Possible consequences: Unintended changes could break transfer restrictions or accidentally enable restricted transfers
 */
rule allowMessagesFromChain_202eac57_no_permissioned_transfer_change(env e) {
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
 * idToChains[chainId].allowMessagesFrom@before && targetTeller == address(0) => revert
 *
 * What it means: If messages are already allowed from a chain and targetTeller is zero address, the function should revert
 *
 * Why it should hold: This prevents meaningless operations and enforces that a valid target teller must be provided
 *
 * Possible consequences: Allows no-op calls that waste gas and don't provide meaningful configuration changes
 */
// gereon: not sure if it's worth the effort/gas
rule __allowMessagesFromChain_202eac57_already_allowed_no_op(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_before = currentContract.idToChains[chainId].allowMessagesFrom;

    // call function under test
    allowMessagesFromChain@withrevert(e, chainId, targetTeller);
    bool allowMessagesFromChain_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_idToChains_chainId__allowMessagesFrom_before && (targetTeller == 0)) => allowMessagesFromChain_reverted), "idToChains[chainId].allowMessagesFrom@before && targetTeller == address(0) => revert";
}

/*
 * chainId != 0 => idToChains[0].allowMessagesFrom@after == idToChains[0].allowMessagesFrom@before
 *
 * What it means: Configuring one chain should not affect the configuration of other chains (specifically chain 0)
 *
 * Why it should hold: Chain configurations should be independent to prevent cross-contamination of settings
 *
 * Possible consequences: Configuration changes could accidentally affect other chains, breaking their functionality
 */
rule allowMessagesFromChain_202eac57_chain_uniqueness_preserved(env e) {
    uint32 chainId;
    address targetTeller;

    // assign all the 'before' variables
    bool currentContract_idToChains_0__allowMessagesFrom_before = currentContract.idToChains[0].allowMessagesFrom;

    // call function under test
    allowMessagesFromChain(e, chainId, targetTeller);

    // assign all the 'after' variables
    bool currentContract_idToChains_0__allowMessagesFrom_after = currentContract.idToChains[0].allowMessagesFrom;

    // verify integrity
    assert ((chainId != 0) => (currentContract_idToChains_0__allowMessagesFrom_after == currentContract_idToChains_0__allowMessagesFrom_before)), "chainId != 0 => idToChains[0].allowMessagesFrom@after == idToChains[0].allowMessagesFrom@before";
}

/*
 * messageGasLimit == 0 => revert
 *
 * What it means: The function must revert when messageGasLimit parameter is zero
 *
 * Why it should hold: Based on the error LayerZeroTeller__ZeroMessageGasLimit and the check in addChain function, zero gas limits are explicitly forbidden for chains that allow outbound messages
 *
 * Possible consequences: State corruption where chains are configured to allow messages but have zero gas limit, causing all cross-chain message attempts to fail silently or behave unpredictably
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
 * What it means: When messageGasLimit is greater than zero, the function must set allowMessagesTo to true for the specified chainId
 *
 * Why it should hold: The function name 'allowMessagesToChain' implies it should enable outbound messaging to the specified chain, and this is the core functionality expected
 *
 * Possible consequences: Function becomes a no-op, failing to enable cross-chain messaging when intended, breaking the bridge functionality
 */
rule allowMessagesToChain_b5ba6182_updates_allow_messages_to(env e) {
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
 * What it means: When messageGasLimit is greater than zero, the function must update the messageGasLimit field for the specified chainId to the provided value
 *
 * Why it should hold: The gas limit parameter is essential for LayerZero message execution on the destination chain, and the function should configure this value as specified
 *
 * Possible consequences: Cross-chain messages may fail due to incorrect gas allocation, or previous gas limits remain unchanged leading to execution failures
 */
rule allowMessagesToChain_b5ba6182_updates_gas_limit(env e) {
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
 * What it means: The function must not modify the allowMessagesFrom field for the specified chainId
 *
 * Why it should hold: This function is specifically for allowing outbound messages, not inbound messages. Modifying inbound permissions would be outside its scope and could cause unintended security implications
 *
 * Possible consequences: Unintended modification of inbound message permissions could either block legitimate incoming messages or allow unauthorized incoming messages
 */
rule allowMessagesToChain_b5ba6182_preserves_allow_from(env e) {
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
 * What it means: The function must only modify the allowMessagesTo setting for the specified chainId and not affect other chains
 *
 * Why it should hold: Chain configurations should be independent - enabling messaging to one chain should not impact messaging permissions for other chains
 *
 * Possible consequences: Unintended modification of other chains' permissions could disrupt existing cross-chain operations or create security vulnerabilities
 */
rule allowMessagesToChain_b5ba6182_different_chains_independent(env e) {
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
 * What it means: The function must only modify the messageGasLimit for the specified chainId and not affect gas limits for other chains
 *
 * Why it should hold: Each chain has different gas requirements and costs - modifying gas limits for unintended chains could cause message execution failures
 *
 * Possible consequences: Cross-chain messages to other chains may fail due to incorrect gas allocation, or become more expensive than intended
 */
rule allowMessagesToChain_b5ba6182_different_chains_gas_independent(env e) {
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
 * idToChains[chainId].allowMessagesFrom@before == false && idToChains[chainId].allowMessagesTo@before == false && idToChains[chainId].messageGasLimit@before == 0 => revert
 *
 * What it means: The function should revert if trying to stop messages from a chain that doesn't exist or is already completely disabled (all flags false and gas limit zero)
 *
 * Why it should hold: Since the function body is empty, it cannot perform any meaningful operation on non-existent chains. Operating on non-existent chains is a no-op that should revert according to the NO-OPS MUST REVERT rule
 *
 * Possible consequences: Silent failures where administrators think they've disabled a chain but the operation had no effect, leading to continued message processing from unwanted chains
 */
// gereon: maybe, but the function is pretty cheap
rule __stopMessagesFromChain_d555f368_chain_must_exist(env e) {
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
 * What it means: When the function is called on a chain that currently allows messages from it, the allowMessagesFrom flag should be set to false after execution
 *
 * Why it should hold: This is the core functionality that the function name implies - it should stop messages from the specified chain by disabling the allowMessagesFrom flag
 *
 * Possible consequences: Function fails to perform its intended purpose, leaving chains enabled when they should be disabled, potentially allowing unwanted cross-chain message processing
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
 * What it means: The function should not modify the allowMessagesTo flag - it should remain unchanged after execution
 *
 * Why it should hold: The function is specifically for stopping messages FROM a chain, not TO a chain. Modifying the allowMessagesTo flag would be outside the function's intended scope
 *
 * Possible consequences: Unintended disruption of outbound message functionality, breaking legitimate cross-chain operations
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
 * Why it should hold: The function's purpose is to control message flow direction, not gas configuration. Gas limits are operational parameters that should remain unchanged
 *
 * Possible consequences: Unintended modification of gas settings could break future message sending when the chain is re-enabled
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
 * What it means: If messages from a chain are already disabled (allowMessagesFrom is false), the function should revert as it's a no-op
 *
 * Why it should hold: According to the NO-OPS MUST REVERT rule, operations that don't change state meaningfully should revert rather than succeed silently
 *
 * Possible consequences: Silent success on meaningless operations can mask configuration errors and make system state unclear
 */
// gereon: not sure if it's worth the effort/gas
rule __stopMessagesFromChain_d555f368_no_effect_if_disabled(env e) {
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
 * What it means: The function should only affect the specified chainId and not modify the allowMessagesFrom setting for any other chains
 *
 * Why it should hold: The function takes a specific chainId parameter and should have surgical precision - affecting other chains would be a serious bug
 *
 * Possible consequences: Collateral damage to other chain configurations, potentially disrupting legitimate cross-chain operations
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
 * inboundRateLimits[chainId].limit@after == inboundRateLimits[chainId].limit@before
 *
 * What it means: The function should not modify the inbound rate limit configuration for the chain
 *
 * Why it should hold: Rate limiting is a separate concern from message enabling/disabling. The function should only control the boolean flag, not the rate limiting parameters
 *
 * Possible consequences: Unintended modification of rate limits could affect future operations when the chain is re-enabled
 */
rule stopMessagesFromChain_d555f368_rate_limits_unchanged(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint256 currentContract_inboundRateLimits_chainId__limit_before = currentContract.inboundRateLimits[chainId].limit;

    // call function under test
    stopMessagesFromChain(e, chainId);

    // assign all the 'after' variables
    uint256 currentContract_inboundRateLimits_chainId__limit_after = currentContract.inboundRateLimits[chainId].limit;

    // verify integrity
    assert (currentContract_inboundRateLimits_chainId__limit_after == currentContract_inboundRateLimits_chainId__limit_before), "inboundRateLimits[chainId].limit@after == inboundRateLimits[chainId].limit@before";
}

/*
 * outboundRateLimits[chainId].limit@after == outboundRateLimits[chainId].limit@before
 *
 * What it means: The function should not modify the outbound rate limit configuration for the chain
 *
 * Why it should hold: The function is for stopping inbound messages, not outbound. Outbound rate limits are independent configuration that should remain intact
 *
 * Possible consequences: Disruption of outbound rate limiting could affect message sending capabilities when needed
 */
rule stopMessagesFromChain_d555f368_outbound_limits_unchanged(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint256 currentContract_outboundRateLimits_chainId__limit_before = currentContract.outboundRateLimits[chainId].limit;

    // call function under test
    stopMessagesFromChain(e, chainId);

    // assign all the 'after' variables
    uint256 currentContract_outboundRateLimits_chainId__limit_after = currentContract.outboundRateLimits[chainId].limit;

    // verify integrity
    assert (currentContract_outboundRateLimits_chainId__limit_after == currentContract_outboundRateLimits_chainId__limit_before), "outboundRateLimits[chainId].limit@after == outboundRateLimits[chainId].limit@before";
}

/*
 * idToChains[chainId].allowMessagesFrom@before || idToChains[chainId].allowMessagesTo@before || idToChains[chainId].messageGasLimit@before > 0 => idToChains[chainId].allowMessagesTo@after == false
 *
 * What it means: If a chain exists (has any configuration set), then calling stopMessagesToChain must disable outbound messages to that chain
 *
 * Why it should hold: The function's purpose is to stop messages to a chain, so it should only succeed if the chain actually exists and has some configuration. This prevents meaningless operations on non-existent chains.
 *
 * Possible consequences: State corruption where the function appears to succeed but doesn't actually change anything meaningful, leading to confusion about which chains are configured
 */
rule stopMessagesToChain_45ad6063_chain_must_exist(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_chainId__allowMessagesFrom_before = currentContract.idToChains[chainId].allowMessagesFrom;
    bool currentContract_idToChains_chainId__allowMessagesTo_before = currentContract.idToChains[chainId].allowMessagesTo;
    uint128 currentContract_idToChains_chainId__messageGasLimit_before = currentContract.idToChains[chainId].messageGasLimit;

    // call function under test
    stopMessagesToChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_idToChains_chainId__allowMessagesTo_after = currentContract.idToChains[chainId].allowMessagesTo;

    // verify integrity
    assert (((currentContract_idToChains_chainId__allowMessagesFrom_before || currentContract_idToChains_chainId__allowMessagesTo_before) || (currentContract_idToChains_chainId__messageGasLimit_before > 0)) => (currentContract_idToChains_chainId__allowMessagesTo_after == false)), "idToChains[chainId].allowMessagesFrom@before || idToChains[chainId].allowMessagesTo@before || idToChains[chainId].messageGasLimit@before > 0 => idToChains[chainId].allowMessagesTo@after == false";
}

/*
 * idToChains[chainId].allowMessagesTo@after == false
 *
 * What it means: After calling stopMessagesToChain, the allowMessagesTo flag for the specified chain must be set to false
 *
 * Why it should hold: This is the core functionality of the function - it must actually disable outbound messages to the target chain
 *
 * Possible consequences: Critical security failure where messages continue to be sent to chains that should be blocked, potentially sending funds to compromised or malicious chains
 */
rule stopMessagesToChain_45ad6063_disables_messages_to(env e) {
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
 * idToChains[chainId].allowMessagesFrom@after == idToChains[chainId].allowMessagesFrom@before
 *
 * What it means: The allowMessagesFrom flag should remain unchanged when stopping messages to a chain
 *
 * Why it should hold: Stopping outbound messages should not affect inbound message permissions - these are independent security controls
 *
 * Possible consequences: Unintended blocking of legitimate inbound messages or unexpected enabling of inbound messages from blocked chains
 */
rule stopMessagesToChain_45ad6063_preserves_messages_from(env e) {
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
 * idToChains[chainId].messageGasLimit@after == idToChains[chainId].messageGasLimit@before
 *
 * What it means: The messageGasLimit for the chain should remain unchanged when stopping messages to that chain
 *
 * Why it should hold: Gas limit configuration is independent of whether messages are currently allowed - it's a technical parameter that should persist
 *
 * Possible consequences: Loss of gas limit configuration that would need to be reconfigured when messages are re-enabled
 */
rule stopMessagesToChain_45ad6063_preserves_gas_limit(env e) {
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
 * !idToChains[chainId].allowMessagesTo@before => revert
 *
 * What it means: If messages to the chain are already disabled, the function should revert rather than succeed with no effect
 *
 * Why it should hold: Following the NO-OPS MUST REVERT principle - operations that don't change state meaningfully should fail to prevent confusion
 *
 * Possible consequences: Confusion about system state and wasted gas on meaningless operations
 */
// gereon: not sure if it's worth the effort/gas
rule __stopMessagesToChain_45ad6063_no_op_reverts(env e) {
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
 * chainId != otherChainId => idToChains[otherChainId].allowMessagesTo@after == idToChains[otherChainId].allowMessagesTo@before
 *
 * What it means: Stopping messages to one chain should not affect the allowMessagesTo setting for any other chains
 *
 * Why it should hold: Chain configurations should be independent - modifying one chain's settings should not have side effects on others
 *
 * Possible consequences: Unintended blocking or enabling of messages to other chains, disrupting legitimate cross-chain operations
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
 * chainId != otherChainId => idToChains[otherChainId].allowMessagesFrom@after == idToChains[otherChainId].allowMessagesFrom@before
 *
 * What it means: Stopping messages to one chain should not affect the allowMessagesFrom setting for any other chains
 *
 * Why it should hold: Inbound message permissions for other chains should remain independent and unaffected
 *
 * Possible consequences: Disruption of legitimate inbound message flows from other chains or unexpected opening of blocked inbound channels
 */
rule stopMessagesToChain_45ad6063_other_chain_from_unchanged(env e) {
    uint32 chainId;
    uint32 otherChainId;

    // assign all the 'before' variables
    bool currentContract_idToChains_otherChainId__allowMessagesFrom_before = currentContract.idToChains[otherChainId].allowMessagesFrom;

    // call function under test
    stopMessagesToChain(e, chainId);

    // assign all the 'after' variables
    bool currentContract_idToChains_otherChainId__allowMessagesFrom_after = currentContract.idToChains[otherChainId].allowMessagesFrom;

    // verify integrity
    assert ((chainId != otherChainId) => (currentContract_idToChains_otherChainId__allowMessagesFrom_after == currentContract_idToChains_otherChainId__allowMessagesFrom_before)), "chainId != otherChainId => idToChains[otherChainId].allowMessagesFrom@after == idToChains[otherChainId].allowMessagesFrom@before";
}

/*
 * chainId != otherChainId => idToChains[otherChainId].messageGasLimit@after == idToChains[otherChainId].messageGasLimit@before
 *
 * What it means: Stopping messages to one chain should not affect the gas limit settings for any other chains
 *
 * Why it should hold: Gas limit configurations are chain-specific technical parameters that should remain isolated
 *
 * Possible consequences: Disruption of message delivery to other chains due to incorrect gas limits
 */
rule stopMessagesToChain_45ad6063_other_chain_gas_unchanged(env e) {
    uint32 chainId;
    uint32 otherChainId;

    // assign all the 'before' variables
    uint128 currentContract_idToChains_otherChainId__messageGasLimit_before = currentContract.idToChains[otherChainId].messageGasLimit;

    // call function under test
    stopMessagesToChain(e, chainId);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_otherChainId__messageGasLimit_after = currentContract.idToChains[otherChainId].messageGasLimit;

    // verify integrity
    assert ((chainId != otherChainId) => (currentContract_idToChains_otherChainId__messageGasLimit_after == currentContract_idToChains_otherChainId__messageGasLimit_before)), "chainId != otherChainId => idToChains[otherChainId].messageGasLimit@after == idToChains[otherChainId].messageGasLimit@before";
}

/*
 * outboundRateLimits[chainId].limit@after == outboundRateLimits[chainId].limit@before
 *
 * What it means: Outbound rate limit configurations should not be modified when stopping messages to a chain
 *
 * Why it should hold: Rate limiting is a separate security mechanism from message enabling/disabling and should be preserved
 *
 * Possible consequences: Loss of rate limiting protection when messages are re-enabled
 */
rule stopMessagesToChain_45ad6063_rate_limits_unchanged(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint256 currentContract_outboundRateLimits_chainId__limit_before = currentContract.outboundRateLimits[chainId].limit;

    // call function under test
    stopMessagesToChain(e, chainId);

    // assign all the 'after' variables
    uint256 currentContract_outboundRateLimits_chainId__limit_after = currentContract.outboundRateLimits[chainId].limit;

    // verify integrity
    assert (currentContract_outboundRateLimits_chainId__limit_after == currentContract_outboundRateLimits_chainId__limit_before), "outboundRateLimits[chainId].limit@after == outboundRateLimits[chainId].limit@before";
}

/*
 * inboundRateLimits[chainId].limit@after == inboundRateLimits[chainId].limit@before
 *
 * What it means: Inbound rate limit configurations should not be modified when stopping messages to a chain
 *
 * Why it should hold: Inbound rate limits are independent security controls that should persist regardless of outbound message status
 *
 * Possible consequences: Loss of inbound rate limiting protection
 */
rule stopMessagesToChain_45ad6063_inbound_limits_unchanged(env e) {
    uint32 chainId;

    // assign all the 'before' variables
    uint256 currentContract_inboundRateLimits_chainId__limit_before = currentContract.inboundRateLimits[chainId].limit;

    // call function under test
    stopMessagesToChain(e, chainId);

    // assign all the 'after' variables
    uint256 currentContract_inboundRateLimits_chainId__limit_after = currentContract.inboundRateLimits[chainId].limit;

    // verify integrity
    assert (currentContract_inboundRateLimits_chainId__limit_after == currentContract_inboundRateLimits_chainId__limit_before), "inboundRateLimits[chainId].limit@after == inboundRateLimits[chainId].limit@before";
}

/*
 * _rateLimitConfigs.length == 0 => revert
 *
 * What it means: The function should revert when called with an empty array of rate limit configurations
 *
 * Why it should hold: An empty function body means no logic is implemented to handle the configurations. Calling with empty configs would be a no-op that wastes gas and provides no value
 *
 * Possible consequences: Gas waste, misleading function behavior, potential for users to think they've configured rate limits when they haven't
 */
// gereon: not sure if it's worth the effort
rule __setOutboundRateLimits_e96e38e2_empty_configs_revert(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables

    // call function under test
    setOutboundRateLimits@withrevert(e, _rateLimitConfigs);
    bool setOutboundRateLimits_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((_rateLimitConfigs.length == 0) => setOutboundRateLimits_reverted), "_rateLimitConfigs.length == 0 => revert";
}

/*
 * _rateLimitConfigs.length > 0 => outboundRateLimits[_rateLimitConfigs[0].peerEid].limit@after == _rateLimitConfigs[0].limit
 *
 * What it means: When configurations are provided, the outbound rate limit for the first peer endpoint should be updated to the new limit value
 *
 * Why it should hold: This is the core functionality of the function - to update outbound rate limits. The function should actually modify the storage to reflect the new configuration
 *
 * Possible consequences: Rate limiting would not work properly, allowing unlimited message sending which could overwhelm destination chains or bypass intended restrictions
 */
// gereon: need to exclude overwriting...
rule setOutboundRateLimits_e96e38e2_updates_outbound_limits(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables
    require(forall uint256 i. (0 < i && i < _rateLimitConfigs.length) => (_rateLimitConfigs[0].peerEid != _rateLimitConfigs[i].peerEid));

    // call function under test
    setOutboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__limit_after = currentContract.outboundRateLimits[_rateLimitConfigs[0].peerEid].limit;

    // verify integrity
    assert ((_rateLimitConfigs.length > 0) => (currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__limit_after == _rateLimitConfigs[0].limit)), "_rateLimitConfigs.length > 0 => outboundRateLimits[_rateLimitConfigs[0].peerEid].limit@after == _rateLimitConfigs[0].limit";
}

/*
 * _rateLimitConfigs.length > 0 => outboundRateLimits[_rateLimitConfigs[0].peerEid].window@after == _rateLimitConfigs[0].window
 *
 * What it means: When configurations are provided, the outbound rate limit window for the first peer endpoint should be updated to the new window value
 *
 * Why it should hold: The window parameter defines the time period over which the rate limit applies. This must be updated for rate limiting to function correctly
 *
 * Possible consequences: Incorrect rate limiting behavior where limits apply over wrong time periods, potentially allowing burst attacks or being too restrictive
 */
// gereon: need to exclude overwriting...
rule setOutboundRateLimits_e96e38e2_updates_outbound_window(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables
    require(forall uint256 i. (0 < i && i < _rateLimitConfigs.length) => (_rateLimitConfigs[0].peerEid != _rateLimitConfigs[i].peerEid));

    // call function under test
    setOutboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__window_after = currentContract.outboundRateLimits[_rateLimitConfigs[0].peerEid].window;

    // verify integrity
    assert ((_rateLimitConfigs.length > 0) => (currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__window_after == _rateLimitConfigs[0].window)), "_rateLimitConfigs.length > 0 => outboundRateLimits[_rateLimitConfigs[0].peerEid].window@after == _rateLimitConfigs[0].window";
}

/*
 * _rateLimitConfigs.length > 0 => outboundRateLimits[_rateLimitConfigs[0].peerEid].amountInFlight@after == outboundRateLimits[_rateLimitConfigs[0].peerEid].amountInFlight@before
 *
 * What it means: The current amount in flight should remain unchanged when updating rate limit configurations
 *
 * Why it should hold: Updating configuration parameters shouldn't reset the current usage tracking, as this would allow bypassing existing rate limits
 *
 * Possible consequences: Rate limit bypass where users could reset their current usage by triggering configuration updates
 */
// gereon: sounds plausible, but _checkAndUpdateOutboundRateLimit explicitly changes this (and its documented behavior)
rule __setOutboundRateLimits_e96e38e2_preserves_amount_in_flight(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables
    uint256 currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__amountInFlight_before = currentContract.outboundRateLimits[_rateLimitConfigs[0].peerEid].amountInFlight;

    // call function under test
    setOutboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__amountInFlight_after = currentContract.outboundRateLimits[_rateLimitConfigs[0].peerEid].amountInFlight;

    // verify integrity
    assert ((_rateLimitConfigs.length > 0) => (currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__amountInFlight_after == currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__amountInFlight_before)), "_rateLimitConfigs.length > 0 => outboundRateLimits[_rateLimitConfigs[0].peerEid].amountInFlight@after == outboundRateLimits[_rateLimitConfigs[0].peerEid].amountInFlight@before";
}

/*
 * _rateLimitConfigs.length > 0 => outboundRateLimits[_rateLimitConfigs[0].peerEid].lastUpdated@after == outboundRateLimits[_rateLimitConfigs[0].peerEid].lastUpdated@before
 *
 * What it means: The lastUpdated timestamp should remain the same when only updating configuration parameters
 *
 * Why it should hold: Configuration updates shouldn't affect the timing of when rate limits were last checked, as this could interfere with decay calculations
 *
 * Possible consequences: Incorrect rate limit decay calculations leading to either too restrictive or too permissive rate limiting
 */
// gereon: lastUpdated is when the config was last updated. This rule is BS
//rule setOutboundRateLimits_e96e38e2_updates_last_updated_timestamp(env e) {
//    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;
//
//    // assign all the 'before' variables
//    uint256 currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__lastUpdated_before = currentContract.outboundRateLimits[_rateLimitConfigs[0].peerEid].lastUpdated;
//
//    // call function under test
//    setOutboundRateLimits(e, _rateLimitConfigs);
//
//    // assign all the 'after' variables
//    uint256 currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__lastUpdated_after = currentContract.outboundRateLimits[_rateLimitConfigs[0].peerEid].lastUpdated;
//
//    // verify integrity
//    assert ((_rateLimitConfigs.length > 0) => (currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__lastUpdated_after == currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__lastUpdated_before)), "_rateLimitConfigs.length > 0 => outboundRateLimits[_rateLimitConfigs[0].peerEid].lastUpdated@after == outboundRateLimits[_rateLimitConfigs[0].peerEid].lastUpdated@before";
//}

/*
 * _rateLimitConfigs.length > 1 => outboundRateLimits[_rateLimitConfigs[1].peerEid].limit@after == _rateLimitConfigs[1].limit
 *
 * What it means: When multiple configurations are provided, all of them should be processed and updated, not just the first one
 *
 * Why it should hold: The function should handle batch updates correctly to allow efficient configuration of multiple peer endpoints
 *
 * Possible consequences: Incomplete rate limit configuration where some peers have outdated or missing rate limits
 */
rule setOutboundRateLimits_e96e38e2_multiple_configs_all_updated(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables

    // call function under test
    setOutboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_outboundRateLimits__rateLimitConfigs_1__peerEid__limit_after = currentContract.outboundRateLimits[_rateLimitConfigs[1].peerEid].limit;

    // verify integrity
    assert ((_rateLimitConfigs.length > 1) => (currentContract_outboundRateLimits__rateLimitConfigs_1__peerEid__limit_after == _rateLimitConfigs[1].limit)), "_rateLimitConfigs.length > 1 => outboundRateLimits[_rateLimitConfigs[1].peerEid].limit@after == _rateLimitConfigs[1].limit";
}

/*
 * _rateLimitConfigs.length > 0 && _rateLimitConfigs[0].limit == 0 => outboundRateLimits[_rateLimitConfigs[0].peerEid].limit@after == 0
 *
 * What it means: The function should allow setting a rate limit of zero, which effectively blocks all outbound messages to that peer
 *
 * Why it should hold: Zero limits are a valid configuration for completely blocking message flow to specific peers during emergencies or maintenance
 *
 * Possible consequences: Inability to emergency-stop message flow to compromised or problematic destination chains
 */
// gereon: need to exclude overwriting...
rule setOutboundRateLimits_e96e38e2_zero_limit_allowed(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables
    require(forall uint256 i. (0 < i && i < _rateLimitConfigs.length) => (_rateLimitConfigs[0].peerEid != _rateLimitConfigs[i].peerEid));

    // call function under test
    setOutboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__limit_after = currentContract.outboundRateLimits[_rateLimitConfigs[0].peerEid].limit;

    // verify integrity
    assert (((_rateLimitConfigs.length > 0) && (_rateLimitConfigs[0].limit == 0)) => (currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__limit_after == 0)), "_rateLimitConfigs.length > 0 && _rateLimitConfigs[0].limit == 0 => outboundRateLimits[_rateLimitConfigs[0].peerEid].limit@after == 0";
}

/*
 * _rateLimitConfigs.length > 0 && _rateLimitConfigs[0].window == 0 => outboundRateLimits[_rateLimitConfigs[0].peerEid].window@after == 0
 *
 * What it means: The function should allow setting a window of zero, which could represent instantaneous rate limiting or special handling
 *
 * Why it should hold: Zero windows might be used for special rate limiting behaviors or to disable time-based decay
 *
 * Possible consequences: Inability to configure certain types of rate limiting behaviors that require zero windows
 */
// gereon: need to exclude overwriting...
rule setOutboundRateLimits_e96e38e2_zero_window_allowed(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables
    require(forall uint256 i. (0 < i && i < _rateLimitConfigs.length) => (_rateLimitConfigs[0].peerEid != _rateLimitConfigs[i].peerEid));

    // call function under test
    setOutboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__window_after = currentContract.outboundRateLimits[_rateLimitConfigs[0].peerEid].window;

    // verify integrity
    assert (((_rateLimitConfigs.length > 0) && (_rateLimitConfigs[0].window == 0)) => (currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__window_after == 0)), "_rateLimitConfigs.length > 0 && _rateLimitConfigs[0].window == 0 => outboundRateLimits[_rateLimitConfigs[0].peerEid].window@after == 0";
}

/*
 * _rateLimitConfigs.length > 0 && _rateLimitConfigs[0].peerEid != 1 => outboundRateLimits[1].limit@after == outboundRateLimits[1].limit@before
 *
 * What it means: Updating rate limits for one peer endpoint should not affect the rate limits of other unrelated peer endpoints
 *
 * Why it should hold: Rate limit configurations should be isolated per peer to avoid unintended side effects on other channels
 *
 * Possible consequences: Unintended rate limit changes affecting legitimate message channels when only specific peers should be modified
 */
// gereon: AI has no idea how to do these kinds of rules
rule setOutboundRateLimits_e96e38e2_different_eids_independent(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;
    uint32 eid;

    require(forall uint256 i. (i < _rateLimitConfigs.length => _rateLimitConfigs[i].peerEid != eid));

    // assign all the 'before' variables
    uint256 currentContract_outboundRateLimits_1__limit_before = currentContract.outboundRateLimits[eid].limit;

    // call function under test
    setOutboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_outboundRateLimits_1__limit_after = currentContract.outboundRateLimits[eid].limit;

    // verify integrity
    assert (((_rateLimitConfigs.length > 0) && (_rateLimitConfigs[0].peerEid != 1)) => (currentContract_outboundRateLimits_1__limit_after == currentContract_outboundRateLimits_1__limit_before)), "_rateLimitConfigs.length > 0 && _rateLimitConfigs[0].peerEid != 1 => outboundRateLimits[1].limit@after == outboundRateLimits[1].limit@before";
}

/*
 * _rateLimitConfigs.length > 0 => inboundRateLimits[_rateLimitConfigs[0].peerEid].limit@after == inboundRateLimits[_rateLimitConfigs[0].peerEid].limit@before
 *
 * What it means: Setting outbound rate limits should not modify inbound rate limits for the same or any peer endpoints
 *
 * Why it should hold: Outbound and inbound rate limits serve different purposes and should be configured independently
 *
 * Possible consequences: Unintended modification of inbound rate limits could allow message flooding from external sources or block legitimate incoming messages
 */
rule setOutboundRateLimits_e96e38e2_inbound_limits_unchanged(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables
    uint256 currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__limit_before = currentContract.inboundRateLimits[_rateLimitConfigs[0].peerEid].limit;

    // call function under test
    setOutboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__limit_after = currentContract.inboundRateLimits[_rateLimitConfigs[0].peerEid].limit;

    // verify integrity
    assert ((_rateLimitConfigs.length > 0) => (currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__limit_after == currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__limit_before)), "_rateLimitConfigs.length > 0 => inboundRateLimits[_rateLimitConfigs[0].peerEid].limit@after == inboundRateLimits[_rateLimitConfigs[0].peerEid].limit@before";
}

/*
 * _rateLimitConfigs.length == 0 => revert
 *
 * What it means: The function must revert when called with an empty configuration array, preventing meaningless operations
 *
 * Why it should hold: Based on the NO-OPS MUST REVERT rule, any function call that performs no meaningful state changes should revert. An empty array would result in no rate limit updates
 *
 * Possible consequences: Gas waste, potential griefing attacks where users repeatedly call the function with empty arrays, and violation of the contract's design principle that all operations should be meaningful
 */
// gereon: not sure, probably not worth the effort/gas
rule __setInboundRateLimits_f51b1aca_empty_config_no_op(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables

    // call function under test
    setInboundRateLimits@withrevert(e, _rateLimitConfigs);
    bool setInboundRateLimits_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((_rateLimitConfigs.length == 0) => setInboundRateLimits_reverted), "_rateLimitConfigs.length == 0 => revert";
}

/*
 * _rateLimitConfigs.length > 0 => inboundRateLimits[_rateLimitConfigs[0].peerEid].limit@after == _rateLimitConfigs[0].limit
 *
 * What it means: When configuration array is non-empty, the limit field of the first rate limit configuration must be properly updated in storage
 *
 * Why it should hold: This is the core functionality of the function - it must actually update the inbound rate limits as specified in the configuration array
 *
 * Possible consequences: Rate limiting would not work correctly, potentially allowing unlimited inbound message flow which could overwhelm the system or bypass intended security controls
 */
// gereon: need to exclude overwriting...
rule setInboundRateLimits_f51b1aca_updates_inbound_limits(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables
    require(forall uint256 i. (0 < i && i < _rateLimitConfigs.length) => (_rateLimitConfigs[0].peerEid != _rateLimitConfigs[i].peerEid));

    // call function under test
    setInboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__limit_after = currentContract.inboundRateLimits[_rateLimitConfigs[0].peerEid].limit;

    // verify integrity
    assert ((_rateLimitConfigs.length > 0) => (currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__limit_after == _rateLimitConfigs[0].limit)), "_rateLimitConfigs.length > 0 => inboundRateLimits[_rateLimitConfigs[0].peerEid].limit@after == _rateLimitConfigs[0].limit";
}

/*
 * _rateLimitConfigs.length > 0 => inboundRateLimits[_rateLimitConfigs[0].peerEid].window@after == _rateLimitConfigs[0].window
 *
 * What it means: When configuration array is non-empty, the window field of the first rate limit configuration must be properly updated in storage
 *
 * Why it should hold: The time window is crucial for rate limiting calculations - it defines the period over which the rate limit applies
 *
 * Possible consequences: Incorrect rate limiting behavior where limits are applied over wrong time periods, potentially making rate limiting too restrictive or too permissive
 */
// gereon: need to exclude overwriting...
rule setInboundRateLimits_f51b1aca_updates_inbound_windows(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables
    require(forall uint256 i. (0 < i && i < _rateLimitConfigs.length) => (_rateLimitConfigs[0].peerEid != _rateLimitConfigs[i].peerEid));

    // call function under test
    setInboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__window_after = currentContract.inboundRateLimits[_rateLimitConfigs[0].peerEid].window;

    // verify integrity
    assert ((_rateLimitConfigs.length > 0) => (currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__window_after == _rateLimitConfigs[0].window)), "_rateLimitConfigs.length > 0 => inboundRateLimits[_rateLimitConfigs[0].peerEid].window@after == _rateLimitConfigs[0].window";
}

/*
 * _rateLimitConfigs.length > 0 && inboundRateLimits[_rateLimitConfigs[0].peerEid].amountInFlight@before > 0 => inboundRateLimits[_rateLimitConfigs[0].peerEid].amountInFlight@after <= inboundRateLimits[_rateLimitConfigs[0].peerEid].amountInFlight@before
 *
 * What it means: The amount currently in flight should not increase when updating rate limit configurations, and may decrease due to natural decay
 *
 * Why it should hold: The amountInFlight represents current usage and should only change through natural decay or actual message processing, not through configuration updates
 *
 * Possible consequences: Incorrect rate limit calculations leading to either overly restrictive or overly permissive rate limiting
 */
rule setInboundRateLimits_f51b1aca_preserves_amount_in_flight(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables
    uint256 currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__amountInFlight_before = currentContract.inboundRateLimits[_rateLimitConfigs[0].peerEid].amountInFlight;

    // call function under test
    setInboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__amountInFlight_after = currentContract.inboundRateLimits[_rateLimitConfigs[0].peerEid].amountInFlight;

    // verify integrity
    assert (((_rateLimitConfigs.length > 0) && (currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__amountInFlight_before > 0)) => (currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__amountInFlight_after <= currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__amountInFlight_before)), "_rateLimitConfigs.length > 0 && inboundRateLimits[_rateLimitConfigs[0].peerEid].amountInFlight@before > 0 => inboundRateLimits[_rateLimitConfigs[0].peerEid].amountInFlight@after <= inboundRateLimits[_rateLimitConfigs[0].peerEid].amountInFlight@before";
}

/*
 * _rateLimitConfigs.length > 0 && inboundRateLimits[_rateLimitConfigs[0].peerEid].limit@before > 0 => inboundRateLimits[_rateLimitConfigs[0].peerEid].lastUpdated@after >= inboundRateLimits[_rateLimitConfigs[0].peerEid].lastUpdated@before
 *
 * What it means: When updating an existing rate limit configuration, the lastUpdated timestamp should be updated to prevent retroactive application of new decay rates
 *
 * Why it should hold: This prevents retroactive application of new rate limit parameters, ensuring fair and predictable rate limiting behavior
 *
 * Possible consequences: Retroactive rate limit changes could unfairly penalize or benefit users based on past activity under different rate limit parameters
 */
rule setInboundRateLimits_f51b1aca_updates_last_timestamp(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables
    uint256 currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__limit_before = currentContract.inboundRateLimits[_rateLimitConfigs[0].peerEid].limit;
    uint256 currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__lastUpdated_before = currentContract.inboundRateLimits[_rateLimitConfigs[0].peerEid].lastUpdated;

    // call function under test
    setInboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__lastUpdated_after = currentContract.inboundRateLimits[_rateLimitConfigs[0].peerEid].lastUpdated;

    // verify integrity
    assert (((_rateLimitConfigs.length > 0) && (currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__limit_before > 0)) => (currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__lastUpdated_after >= currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__lastUpdated_before)), "_rateLimitConfigs.length > 0 && inboundRateLimits[_rateLimitConfigs[0].peerEid].limit@before > 0 => inboundRateLimits[_rateLimitConfigs[0].peerEid].lastUpdated@after >= inboundRateLimits[_rateLimitConfigs[0].peerEid].lastUpdated@before";
}

/*
 * _rateLimitConfigs.length > 1 => inboundRateLimits[_rateLimitConfigs[1].peerEid].limit@after == _rateLimitConfigs[1].limit
 *
 * What it means: When multiple configurations are provided, all of them must be processed and updated, not just the first one
 *
 * Why it should hold: The function should handle batch updates correctly, processing all provided configurations rather than silently ignoring some
 *
 * Possible consequences: Incomplete rate limit updates could leave some chains with outdated or incorrect rate limiting parameters
 */
rule setInboundRateLimits_f51b1aca_multiple_configs_all_update(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables

    // call function under test
    setInboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_inboundRateLimits__rateLimitConfigs_1__peerEid__limit_after = currentContract.inboundRateLimits[_rateLimitConfigs[1].peerEid].limit;

    // verify integrity
    assert ((_rateLimitConfigs.length > 1) => (currentContract_inboundRateLimits__rateLimitConfigs_1__peerEid__limit_after == _rateLimitConfigs[1].limit)), "_rateLimitConfigs.length > 1 => inboundRateLimits[_rateLimitConfigs[1].peerEid].limit@after == _rateLimitConfigs[1].limit";
}

/*
 * _rateLimitConfigs.length > 0 && _rateLimitConfigs[0].limit == 0 => inboundRateLimits[_rateLimitConfigs[0].peerEid].limit@after == 0
 *
 * What it means: The function should allow setting rate limits to zero, effectively disabling inbound messages from that chain
 *
 * Why it should hold: Zero limits are a valid configuration for completely blocking inbound messages from specific chains, which is important for emergency responses
 *
 * Possible consequences: If zero limits are not properly handled, it could prevent emergency shutdowns of problematic chains or cause unexpected behavior
 */
// gereon: need to exclude overwriting...
rule setInboundRateLimits_f51b1aca_zero_limit_allowed(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables
    require(forall uint256 i. (0 < i && i < _rateLimitConfigs.length) => (_rateLimitConfigs[0].peerEid != _rateLimitConfigs[i].peerEid));

    // call function under test
    setInboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__limit_after = currentContract.inboundRateLimits[_rateLimitConfigs[0].peerEid].limit;

    // verify integrity
    assert (((_rateLimitConfigs.length > 0) && (_rateLimitConfigs[0].limit == 0)) => (currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__limit_after == 0)), "_rateLimitConfigs.length > 0 && _rateLimitConfigs[0].limit == 0 => inboundRateLimits[_rateLimitConfigs[0].peerEid].limit@after == 0";
}

/*
 * _rateLimitConfigs.length > 0 && _rateLimitConfigs[0].window == 0 => inboundRateLimits[_rateLimitConfigs[0].peerEid].window@after == 0
 *
 * What it means: The function should allow setting time windows to zero, which may have special meaning in the rate limiting logic
 *
 * Why it should hold: Zero windows might be used for special rate limiting behaviors or to disable time-based decay, and should be handled correctly
 *
 * Possible consequences: Incorrect handling of zero windows could cause division by zero errors or unexpected rate limiting behavior
 */
// gereon: need to exclude overwriting...
rule setInboundRateLimits_f51b1aca_zero_window_allowed(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables
    require(forall uint256 i. (0 < i && i < _rateLimitConfigs.length) => (_rateLimitConfigs[0].peerEid != _rateLimitConfigs[i].peerEid));

    // call function under test
    setInboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__window_after = currentContract.inboundRateLimits[_rateLimitConfigs[0].peerEid].window;

    // verify integrity
    assert (((_rateLimitConfigs.length > 0) && (_rateLimitConfigs[0].window == 0)) => (currentContract_inboundRateLimits__rateLimitConfigs_0__peerEid__window_after == 0)), "_rateLimitConfigs.length > 0 && _rateLimitConfigs[0].window == 0 => inboundRateLimits[_rateLimitConfigs[0].peerEid].window@after == 0";
}

/*
 * _rateLimitConfigs.length > 0 && _rateLimitConfigs[0].peerEid != 1 => inboundRateLimits[1].limit@after == inboundRateLimits[1].limit@before
 *
 * What it means: Updating rate limits for one peer should not affect the rate limits of other peers that are not being updated
 *
 * Why it should hold: Rate limit configurations should be independent per peer to maintain proper isolation and prevent unintended side effects
 *
 * Possible consequences: Cross-contamination of rate limit settings could affect unrelated chains, potentially blocking legitimate traffic or allowing excessive traffic
 */
// gereon: AI has no idea how to do these kinds of rules
rule setInboundRateLimits_f51b1aca_different_peers_independent(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    uint32 eid;

    require(forall uint256 i. (i < _rateLimitConfigs.length => _rateLimitConfigs[i].peerEid != eid));

    // assign all the 'before' variables
    uint256 currentContract_inboundRateLimits_1__limit_before = currentContract.inboundRateLimits[eid].limit;

    // call function under test
    setInboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_inboundRateLimits_1__limit_after = currentContract.inboundRateLimits[eid].limit;

    // verify integrity
    assert (currentContract_inboundRateLimits_1__limit_after == currentContract_inboundRateLimits_1__limit_before), "_rateLimitConfigs.length > 0 && _rateLimitConfigs[0].peerEid != 1 => inboundRateLimits[1].limit@after == inboundRateLimits[1].limit@before";
}

/*
 * _rateLimitConfigs.length > 0 => outboundRateLimits[_rateLimitConfigs[0].peerEid].limit@after == outboundRateLimits[_rateLimitConfigs[0].peerEid].limit@before
 *
 * What it means: Setting inbound rate limits should not modify outbound rate limits for the same or any other peer
 *
 * Why it should hold: Inbound and outbound rate limits serve different purposes and should be managed independently to maintain proper separation of concerns
 *
 * Possible consequences: Unintended modification of outbound limits could disrupt legitimate outbound message flow or create security vulnerabilities
 */
rule setInboundRateLimits_f51b1aca_preserves_outbound_limits(env e) {
    PairwiseRateLimiter.RateLimitConfig[] _rateLimitConfigs;

    // assign all the 'before' variables
    uint256 currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__limit_before = currentContract.outboundRateLimits[_rateLimitConfigs[0].peerEid].limit;

    // call function under test
    setInboundRateLimits(e, _rateLimitConfigs);

    // assign all the 'after' variables
    uint256 currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__limit_after = currentContract.outboundRateLimits[_rateLimitConfigs[0].peerEid].limit;

    // verify integrity
    assert ((_rateLimitConfigs.length > 0) => (currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__limit_after == currentContract_outboundRateLimits__rateLimitConfigs_0__peerEid__limit_before)), "_rateLimitConfigs.length > 0 => outboundRateLimits[_rateLimitConfigs[0].peerEid].limit@after == outboundRateLimits[_rateLimitConfigs[0].peerEid].limit@before";
}

/*
 * messageGasLimit == 0 => revert
 *
 * What it means: The function must revert when messageGasLimit parameter is zero
 *
 * Why it should hold: Based on the pattern in addChain and allowMessagesToChain functions which both check 'if (messageGasLimit == 0) revert LayerZeroTeller__ZeroMessageGasLimit()', this validation should be consistent across all functions that set gas limits
 *
 * Possible consequences: Setting zero gas limit would cause cross-chain message failures, leading to DoS of bridging functionality and potential loss of user funds stuck in failed transactions
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
 * messageGasLimit > 0 => idToChains[chainId].messageGasLimit@after == messageGasLimit
 *
 * What it means: When messageGasLimit is greater than zero, the function should update the messageGasLimit field in the Chain struct for the specified chainId
 *
 * Why it should hold: This is the core functionality of setChainGasLimit - to update the gas limit configuration for cross-chain messages to a specific chain
 *
 * Possible consequences: If gas limit is not updated, cross-chain messages would continue using old gas limits which could be insufficient for message execution, causing message failures and fund loss
 */
rule setChainGasLimit_1568fc58_updates_chain_gas_limit(env e) {
    uint32 chainId;
    uint128 messageGasLimit;

    // assign all the 'before' variables

    // call function under test
    setChainGasLimit(e, chainId, messageGasLimit);

    // assign all the 'after' variables
    uint128 currentContract_idToChains_chainId__messageGasLimit_after = currentContract.idToChains[chainId].messageGasLimit;

    // verify integrity
    assert ((messageGasLimit > 0) => (currentContract_idToChains_chainId__messageGasLimit_after == messageGasLimit)), "messageGasLimit > 0 => idToChains[chainId].messageGasLimit@after == messageGasLimit";
}

/*
 * idToChains[chainId].allowMessagesFrom@after == idToChains[chainId].allowMessagesFrom@before
 *
 * What it means: The allowMessagesFrom flag in the Chain struct should remain unchanged after calling setChainGasLimit
 *
 * Why it should hold: setChainGasLimit should only modify gas limit settings and not affect message direction permissions, maintaining separation of concerns
 *
 * Possible consequences: Unintended changes to message permissions could disable inbound bridging or enable it when it should be disabled, breaking access controls
 */
rule setChainGasLimit_1568fc58_preserves_messages_from_flag(env e) {
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
 * What it means: The allowMessagesTo flag in the Chain struct should remain unchanged after calling setChainGasLimit
 *
 * Why it should hold: setChainGasLimit should only modify gas limit settings and not affect message direction permissions, maintaining function scope isolation
 *
 * Possible consequences: Unintended changes to outbound message permissions could disable bridging to specific chains or enable it when it should be restricted
 */
rule setChainGasLimit_1568fc58_preserves_messages_to_flag(env e) {
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
 * chainId != otherChainId => idToChains[otherChainId].messageGasLimit@after == idToChains[otherChainId].messageGasLimit@before
 *
 * What it means: The messageGasLimit for chains other than the specified chainId should remain unchanged
 *
 * Why it should hold: The function should only affect the specific chain being configured, not have side effects on other chain configurations
 *
 * Possible consequences: Unintended changes to other chains' gas limits could cause message failures or excessive gas costs for unrelated chains
 */
rule setChainGasLimit_1568fc58_no_change_other_chains(env e) {
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
 * idToChains[chainId].allowMessagesTo@before == false && idToChains[chainId].allowMessagesFrom@before == false => revert
 *
 * What it means: The function should revert when trying to set gas limit for a chain that has not been properly initialized (both allowMessagesFrom and allowMessagesTo are false)
 *
 * Why it should hold: Setting gas limits for uninitialized chains could lead to inconsistent state where gas limit exists but the chain is not properly configured for messaging
 *
 * Possible consequences: Could create phantom chain configurations that appear valid but are not fully functional, leading to user confusion and potential failed transactions
 */
// gereon: not sure if it's worth the effort/gas
rule __setChainGasLimit_1568fc58_uninitialized_chain_reverts(env e) {
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