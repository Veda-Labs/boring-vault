

/*
 * !allowedBufferHelpers[_asset][_depositBufferHelper]@before && _depositBufferHelper != address(0) => revert
 *
 * What it means: The function must revert when trying to set a non-zero buffer helper address that is not in the allowedBufferHelpers mapping for the given asset
 *
 * Why it should hold: This enforces the allowlist mechanism - only pre-approved buffer helpers can be set. The contract has an explicit allowBufferHelper function to manage this allowlist, indicating strict access control is intended
 *
 * Possible consequences: Malicious or untested buffer helpers could be set, leading to fund loss through malicious manage() calls, DoS through reverting buffer helpers, or unauthorized vault operations
 */
rule setDepositBufferHelper_b4bf379c_disallowed_non_zero_helper_reverts(env e) {
    address _asset;
    address _depositBufferHelper;

    // assign all the 'before' variables
    bool currentContract_allowedBufferHelpers__asset___depositBufferHelper__before = currentContract.allowedBufferHelpers[_asset][_depositBufferHelper];

    // call function under test
    setDepositBufferHelper@withrevert(e, _asset, _depositBufferHelper);
    bool setDepositBufferHelper_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((!(currentContract_allowedBufferHelpers__asset___depositBufferHelper__before) && (_depositBufferHelper != 0)) => setDepositBufferHelper_reverted), "!allowedBufferHelpers[_asset][_depositBufferHelper]@before && _depositBufferHelper != address(0) => revert";
}

/*
 * allowedBufferHelpers[_asset][_depositBufferHelper]@before || _depositBufferHelper == address(0) => currentBufferHelpers[_asset].depositBufferHelper@after == _depositBufferHelper
 *
 * What it means: When a buffer helper is either allowlisted or is address(0), the currentBufferHelpers mapping should be updated to store the new helper address
 *
 * Why it should hold: This is the core functionality - the function should actually update the storage when valid parameters are provided. Setting to address(0) should always work as it disables the buffer helper
 *
 * Possible consequences: Function becomes non-functional, buffer helpers cannot be updated, deposits may continue using old/wrong buffer helpers leading to incorrect vault management
 */
rule setDepositBufferHelper_b4bf379c_allowed_helper_updates_storage(env e) {
    address _asset;
    address _depositBufferHelper;

    // assign all the 'before' variables
    bool currentContract_allowedBufferHelpers__asset___depositBufferHelper__before = currentContract.allowedBufferHelpers[_asset][_depositBufferHelper];

    // call function under test
    setDepositBufferHelper(e, _asset, _depositBufferHelper);

    // assign all the 'after' variables
    address currentContract_currentBufferHelpers__asset__depositBufferHelper_after = currentContract.currentBufferHelpers[_asset].depositBufferHelper;

    // verify integrity
    assert ((currentContract_allowedBufferHelpers__asset___depositBufferHelper__before || (_depositBufferHelper == 0)) => (currentContract_currentBufferHelpers__asset__depositBufferHelper_after == _depositBufferHelper)), "allowedBufferHelpers[_asset][_depositBufferHelper]@before || _depositBufferHelper == address(0) => currentBufferHelpers[_asset].depositBufferHelper@after == _depositBufferHelper";
}

/*
 * _asset != otherAsset => currentBufferHelpers[otherAsset].depositBufferHelper@after == currentBufferHelpers[otherAsset].depositBufferHelper@before
 *
 * What it means: Setting a buffer helper for one asset should not affect the buffer helper configuration for any other assets
 *
 * Why it should hold: Asset isolation is critical - each asset should have independent buffer helper configuration. Cross-asset interference would violate the design principle of per-asset management
 *
 * Possible consequences: Setting buffer helper for one asset accidentally changes configuration for other assets, leading to wrong management calls for unrelated deposits
 */
rule setDepositBufferHelper_b4bf379c_storage_unchanged_for_other_assets(env e) {
    address _asset;
    address _depositBufferHelper;
    address otherAsset;

    // assign all the 'before' variables
    address currentContract_currentBufferHelpers_otherAsset__depositBufferHelper_before = currentContract.currentBufferHelpers[otherAsset].depositBufferHelper;

    // call function under test
    setDepositBufferHelper(e, _asset, _depositBufferHelper);

    // assign all the 'after' variables
    address currentContract_currentBufferHelpers_otherAsset__depositBufferHelper_after = currentContract.currentBufferHelpers[otherAsset].depositBufferHelper;

    // verify integrity
    assert ((_asset != otherAsset) => (currentContract_currentBufferHelpers_otherAsset__depositBufferHelper_after == currentContract_currentBufferHelpers_otherAsset__depositBufferHelper_before)), "_asset != otherAsset => currentBufferHelpers[otherAsset].depositBufferHelper@after == currentBufferHelpers[otherAsset].depositBufferHelper@before";
}

/*
 * currentBufferHelpers[_asset].withdrawBufferHelper@after == currentBufferHelpers[_asset].withdrawBufferHelper@before
 *
 * What it means: Setting the deposit buffer helper should not modify the withdraw buffer helper for the same asset
 *
 * Why it should hold: Deposit and withdraw operations have separate buffer helpers stored in the same struct. The function should only modify the depositBufferHelper field, leaving withdrawBufferHelper intact
 *
 * Possible consequences: Withdraw functionality gets disrupted when only trying to update deposit functionality, breaking the separation of concerns between deposit and withdraw operations
 */
rule setDepositBufferHelper_b4bf379c_withdraw_helper_unchanged(env e) {
    address _asset;
    address _depositBufferHelper;

    // assign all the 'before' variables
    address currentContract_currentBufferHelpers__asset__withdrawBufferHelper_before = currentContract.currentBufferHelpers[_asset].withdrawBufferHelper;

    // call function under test
    setDepositBufferHelper(e, _asset, _depositBufferHelper);

    // assign all the 'after' variables
    address currentContract_currentBufferHelpers__asset__withdrawBufferHelper_after = currentContract.currentBufferHelpers[_asset].withdrawBufferHelper;

    // verify integrity
    assert (currentContract_currentBufferHelpers__asset__withdrawBufferHelper_after == currentContract_currentBufferHelpers__asset__withdrawBufferHelper_before), "currentBufferHelpers[_asset].withdrawBufferHelper@after == currentBufferHelpers[_asset].withdrawBufferHelper@before";
}

/*
 * allowedBufferHelpers[_asset][_depositBufferHelper]@after == allowedBufferHelpers[_asset][_depositBufferHelper]@before
 *
 * What it means: The function should not modify the allowedBufferHelpers mapping - it should only read from it to check permissions
 *
 * Why it should hold: This function is for setting current helpers, not for managing the allowlist. The allowlist should only be modified through dedicated allowBufferHelper/disallowBufferHelper functions
 *
 * Possible consequences: Unauthorized modification of the allowlist, bypassing the intended access control mechanism for buffer helper approval
 */
rule setDepositBufferHelper_b4bf379c_allowedBufferHelpers_unchanged(env e) {
    address _asset;
    address _depositBufferHelper;

    // assign all the 'before' variables
    bool currentContract_allowedBufferHelpers__asset___depositBufferHelper__before = currentContract.allowedBufferHelpers[_asset][_depositBufferHelper];

    // call function under test
    setDepositBufferHelper(e, _asset, _depositBufferHelper);

    // assign all the 'after' variables
    bool currentContract_allowedBufferHelpers__asset___depositBufferHelper__after = currentContract.allowedBufferHelpers[_asset][_depositBufferHelper];

    // verify integrity
    assert (currentContract_allowedBufferHelpers__asset___depositBufferHelper__after == currentContract_allowedBufferHelpers__asset___depositBufferHelper__before), "allowedBufferHelpers[_asset][_depositBufferHelper]@after == allowedBufferHelpers[_asset][_depositBufferHelper]@before";
}

/*
 * _asset != otherAsset => allowedBufferHelpers[otherAsset][_depositBufferHelper]@after == allowedBufferHelpers[otherAsset][_depositBufferHelper]@before
 *
 * What it means: Setting a buffer helper for one asset should not affect the allowedBufferHelpers mapping for any other assets
 *
 * Why it should hold: The allowlist is asset-specific, and modifying one asset's buffer helper should not interfere with the allowlist configuration of other assets
 *
 * Possible consequences: Cross-asset allowlist corruption, where setting helpers for one asset accidentally modifies permissions for other assets
 */
rule setDepositBufferHelper_b4bf379c_other_asset_allowances_unchanged(env e) {
    address _asset;
    address _depositBufferHelper;
    address otherAsset;

    // assign all the 'before' variables
    bool currentContract_allowedBufferHelpers_otherAsset___depositBufferHelper__before = currentContract.allowedBufferHelpers[otherAsset][_depositBufferHelper];

    // call function under test
    setDepositBufferHelper(e, _asset, _depositBufferHelper);

    // assign all the 'after' variables
    bool currentContract_allowedBufferHelpers_otherAsset___depositBufferHelper__after = currentContract.allowedBufferHelpers[otherAsset][_depositBufferHelper];

    // verify integrity
    assert ((_asset != otherAsset) => (currentContract_allowedBufferHelpers_otherAsset___depositBufferHelper__after == currentContract_allowedBufferHelpers_otherAsset___depositBufferHelper__before)), "_asset != otherAsset => allowedBufferHelpers[otherAsset][_depositBufferHelper]@after == allowedBufferHelpers[otherAsset][_depositBufferHelper]@before";
}

/*
 * msg.sender != owner@before && msg.sender != authority@before => revert
 *
 * What it means: The function must revert if called by an address that is neither the owner nor the authority
 *
 * Why it should hold: The function has a requiresAuth modifier which should enforce access control. Only authorized addresses should be able to set buffer helpers as this controls critical vault management operations
 *
 * Possible consequences: Unauthorized access control bypass, allowing attackers to set malicious buffer helpers that could drain funds or manipulate vault operations
 */
rule setWithdrawBufferHelper_9428fcd4_unauthorized_reverts(env e) {
    address _asset;
    address _withdrawBufferHelper;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    setWithdrawBufferHelper@withrevert(e, _asset, _withdrawBufferHelper);
    bool setWithdrawBufferHelper_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((e.msg.sender != currentContract_owner_before) && (e.msg.sender != currentContract_authority_before)) => setWithdrawBufferHelper_reverted), "msg.sender != owner@before && msg.sender != authority@before => revert";
}

/*
 * !allowedBufferHelpers[_asset][_withdrawBufferHelper]@before && _withdrawBufferHelper != address(0) => revert
 *
 * What it means: The function must revert if the buffer helper is not in the allowlist and is not the zero address
 *
 * Why it should hold: Based on the setDepositBufferHelper implementation, buffer helpers must be pre-approved via allowBufferHelper before they can be set. The zero address is always allowed to disable the helper
 *
 * Possible consequences: Malicious buffer helper injection, allowing unauthorized contracts to execute arbitrary code during withdrawal operations
 */
rule setWithdrawBufferHelper_9428fcd4_helper_must_be_allowed(env e) {
    address _asset;
    address _withdrawBufferHelper;

    // assign all the 'before' variables
    bool currentContract_allowedBufferHelpers__asset___withdrawBufferHelper__before = currentContract.allowedBufferHelpers[_asset][_withdrawBufferHelper];

    // call function under test
    setWithdrawBufferHelper@withrevert(e, _asset, _withdrawBufferHelper);
    bool setWithdrawBufferHelper_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((!(currentContract_allowedBufferHelpers__asset___withdrawBufferHelper__before) && (_withdrawBufferHelper != 0)) => setWithdrawBufferHelper_reverted), "!allowedBufferHelpers[_asset][_withdrawBufferHelper]@before && _withdrawBufferHelper != address(0) => revert";
}

/*
 * allowedBufferHelpers[_asset][_withdrawBufferHelper]@before || _withdrawBufferHelper == address(0) => currentBufferHelpers[_asset].withdrawBufferHelper@after == _withdrawBufferHelper
 *
 * What it means: When the buffer helper is allowed or is zero address, the currentBufferHelpers mapping should be updated with the new helper
 *
 * Why it should hold: This is the core functionality - the function should actually update the withdraw buffer helper when valid parameters are provided
 *
 * Possible consequences: Function becomes non-functional, buffer helpers cannot be updated, withdrawal management becomes stuck with old or incorrect helpers
 */
rule setWithdrawBufferHelper_9428fcd4_updates_withdraw_helper(env e) {
    address _asset;
    address _withdrawBufferHelper;

    // assign all the 'before' variables
    bool currentContract_allowedBufferHelpers__asset___withdrawBufferHelper__before = currentContract.allowedBufferHelpers[_asset][_withdrawBufferHelper];

    // call function under test
    setWithdrawBufferHelper(e, _asset, _withdrawBufferHelper);

    // assign all the 'after' variables
    address currentContract_currentBufferHelpers__asset__withdrawBufferHelper_after = currentContract.currentBufferHelpers[_asset].withdrawBufferHelper;

    // verify integrity
    assert ((currentContract_allowedBufferHelpers__asset___withdrawBufferHelper__before || (_withdrawBufferHelper == 0)) => (currentContract_currentBufferHelpers__asset__withdrawBufferHelper_after == _withdrawBufferHelper)), "allowedBufferHelpers[_asset][_withdrawBufferHelper]@before || _withdrawBufferHelper == address(0) => currentBufferHelpers[_asset].withdrawBufferHelper@after == _withdrawBufferHelper";
}

/*
 * currentBufferHelpers[_asset].depositBufferHelper@after == currentBufferHelpers[_asset].depositBufferHelper@before
 *
 * What it means: The deposit buffer helper for the asset should remain unchanged when setting the withdraw buffer helper
 *
 * Why it should hold: This function should only modify the withdraw helper, not affect the deposit helper configuration
 *
 * Possible consequences: Unintended side effects where setting withdraw helpers breaks deposit functionality
 */
rule setWithdrawBufferHelper_9428fcd4_preserves_deposit_helper(env e) {
    address _asset;
    address _withdrawBufferHelper;

    // assign all the 'before' variables
    address currentContract_currentBufferHelpers__asset__depositBufferHelper_before = currentContract.currentBufferHelpers[_asset].depositBufferHelper;

    // call function under test
    setWithdrawBufferHelper(e, _asset, _withdrawBufferHelper);

    // assign all the 'after' variables
    address currentContract_currentBufferHelpers__asset__depositBufferHelper_after = currentContract.currentBufferHelpers[_asset].depositBufferHelper;

    // verify integrity
    assert (currentContract_currentBufferHelpers__asset__depositBufferHelper_after == currentContract_currentBufferHelpers__asset__depositBufferHelper_before), "currentBufferHelpers[_asset].depositBufferHelper@after == currentBufferHelpers[_asset].depositBufferHelper@before";
}

/*
 * currentBufferHelpers[_asset].withdrawBufferHelper@before == _withdrawBufferHelper => revert
 *
 * What it means: The function must revert if trying to set the same buffer helper that is already configured
 *
 * Why it should hold: No-op operations should revert to prevent wasted gas and indicate that no meaningful change occurred
 *
 * Possible consequences: Gas waste, unclear transaction outcomes, potential for griefing attacks through repeated no-op calls
 */
rule setWithdrawBufferHelper_9428fcd4_no_change_reverts(env e) {
    address _asset;
    address _withdrawBufferHelper;

    // assign all the 'before' variables
    address currentContract_currentBufferHelpers__asset__withdrawBufferHelper_before = currentContract.currentBufferHelpers[_asset].withdrawBufferHelper;

    // call function under test
    setWithdrawBufferHelper@withrevert(e, _asset, _withdrawBufferHelper);
    bool setWithdrawBufferHelper_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_currentBufferHelpers__asset__withdrawBufferHelper_before == _withdrawBufferHelper) => setWithdrawBufferHelper_reverted), "currentBufferHelpers[_asset].withdrawBufferHelper@before == _withdrawBufferHelper => revert";
}

/*
 * otherAsset != _asset => currentBufferHelpers[otherAsset].withdrawBufferHelper@after == currentBufferHelpers[otherAsset].withdrawBufferHelper@before
 *
 * What it means: Buffer helpers for other assets should not be affected when setting the helper for a specific asset
 *
 * Why it should hold: The function should only modify the buffer helper for the specified asset, maintaining isolation between different asset configurations
 *
 * Possible consequences: Cross-asset contamination where changing one asset's helper affects others, breaking multi-asset functionality
 */
rule setWithdrawBufferHelper_9428fcd4_other_assets_unchanged(env e) {
    address _asset;
    address _withdrawBufferHelper;
    address otherAsset;

    // assign all the 'before' variables
    address currentContract_currentBufferHelpers_otherAsset__withdrawBufferHelper_before = currentContract.currentBufferHelpers[otherAsset].withdrawBufferHelper;

    // call function under test
    setWithdrawBufferHelper(e, _asset, _withdrawBufferHelper);

    // assign all the 'after' variables
    address currentContract_currentBufferHelpers_otherAsset__withdrawBufferHelper_after = currentContract.currentBufferHelpers[otherAsset].withdrawBufferHelper;

    // verify integrity
    assert ((otherAsset != _asset) => (currentContract_currentBufferHelpers_otherAsset__withdrawBufferHelper_after == currentContract_currentBufferHelpers_otherAsset__withdrawBufferHelper_before)), "otherAsset != _asset => currentBufferHelpers[otherAsset].withdrawBufferHelper@after == currentBufferHelpers[otherAsset].withdrawBufferHelper@before";
}

/*
 * allowedBufferHelpers[_asset][_withdrawBufferHelper]@after == allowedBufferHelpers[_asset][_withdrawBufferHelper]@before
 *
 * What it means: The allowedBufferHelpers mapping should not be modified by this function
 *
 * Why it should hold: This function only sets active helpers, it should not modify the allowlist which is managed by separate allowBufferHelper/disallowBufferHelper functions
 *
 * Possible consequences: Privilege escalation where setting helpers also grants allowlist permissions, bypassing proper authorization flow
 */
rule setWithdrawBufferHelper_9428fcd4_allowlist_unchanged(env e) {
    address _asset;
    address _withdrawBufferHelper;

    // assign all the 'before' variables
    bool currentContract_allowedBufferHelpers__asset___withdrawBufferHelper__before = currentContract.allowedBufferHelpers[_asset][_withdrawBufferHelper];

    // call function under test
    setWithdrawBufferHelper(e, _asset, _withdrawBufferHelper);

    // assign all the 'after' variables
    bool currentContract_allowedBufferHelpers__asset___withdrawBufferHelper__after = currentContract.allowedBufferHelpers[_asset][_withdrawBufferHelper];

    // verify integrity
    assert (currentContract_allowedBufferHelpers__asset___withdrawBufferHelper__after == currentContract_allowedBufferHelpers__asset___withdrawBufferHelper__before), "allowedBufferHelpers[_asset][_withdrawBufferHelper]@after == allowedBufferHelpers[_asset][_withdrawBufferHelper]@before";
}

/*
 * helper != _withdrawBufferHelper => allowedBufferHelpers[_asset][helper]@after == allowedBufferHelpers[_asset][helper]@before
 *
 * What it means: The allowlist status of other buffer helpers should remain unchanged
 *
 * Why it should hold: Setting one helper should not affect the allowlist permissions of other helpers
 *
 * Possible consequences: Unintended permission changes affecting other buffer helpers' allowlist status
 */
rule setWithdrawBufferHelper_9428fcd4_other_helper_allowlist_unchanged(env e) {
    address _asset;
    address _withdrawBufferHelper;
    address helper;

    // assign all the 'before' variables
    bool currentContract_allowedBufferHelpers__asset__helper__before = currentContract.allowedBufferHelpers[_asset][helper];

    // call function under test
    setWithdrawBufferHelper(e, _asset, _withdrawBufferHelper);

    // assign all the 'after' variables
    bool currentContract_allowedBufferHelpers__asset__helper__after = currentContract.allowedBufferHelpers[_asset][helper];

    // verify integrity
    assert ((helper != _withdrawBufferHelper) => (currentContract_allowedBufferHelpers__asset__helper__after == currentContract_allowedBufferHelpers__asset__helper__before)), "helper != _withdrawBufferHelper => allowedBufferHelpers[_asset][helper]@after == allowedBufferHelpers[_asset][helper]@before";
}

/*
 * allowedBufferHelpers[_asset][_bufferHelper]@after == true
 *
 * What it means: When allowBufferHelper is called, it must set the allowedBufferHelpers mapping to true for the specified asset and buffer helper combination
 *
 * Why it should hold: This is the core functionality of the allowBufferHelper function - to mark a buffer helper as allowed for a specific asset. Without this state change, the function would be a no-op and fail to serve its intended purpose
 *
 * Possible consequences: If this property is violated, buffer helpers cannot be properly allowlisted, preventing the setDepositBufferHelper and setWithdrawBufferHelper functions from working correctly, leading to DoS of buffer management functionality
 */
rule allowBufferHelper_0d1598dd_sets_buffer_helper_allowed(env e) {
    address _asset;
    address _bufferHelper;

    // assign all the 'before' variables

    // call function under test
    allowBufferHelper(e, _asset, _bufferHelper);

    // assign all the 'after' variables
    bool currentContract_allowedBufferHelpers__asset___bufferHelper__after = currentContract.allowedBufferHelpers[_asset][_bufferHelper];

    // verify integrity
    assert (currentContract_allowedBufferHelpers__asset___bufferHelper__after == true), "allowedBufferHelpers[_asset][_bufferHelper]@after == true";
}

/*
 * otherAsset != _asset => allowedBufferHelpers[otherAsset][_bufferHelper]@after == allowedBufferHelpers[otherAsset][_bufferHelper]@before
 *
 * What it means: When allowing a buffer helper for one asset, the allowedBufferHelpers mapping for all other assets should remain unchanged
 *
 * Why it should hold: The allowBufferHelper function should only affect the specific asset-helper combination being modified. Changing permissions for other assets would violate the principle of least privilege and could cause unintended side effects
 *
 * Possible consequences: If this property is violated, allowing a buffer helper for one asset could accidentally modify permissions for other assets, leading to unauthorized access or denial of service for buffer helpers on unrelated assets
 */
rule allowBufferHelper_0d1598dd_preserves_other_asset_helpers(env e) {
    address _asset;
    address _bufferHelper;
    address otherAsset;

    // assign all the 'before' variables
    bool currentContract_allowedBufferHelpers_otherAsset___bufferHelper__before = currentContract.allowedBufferHelpers[otherAsset][_bufferHelper];

    // call function under test
    allowBufferHelper(e, _asset, _bufferHelper);

    // assign all the 'after' variables
    bool currentContract_allowedBufferHelpers_otherAsset___bufferHelper__after = currentContract.allowedBufferHelpers[otherAsset][_bufferHelper];

    // verify integrity
    assert ((otherAsset != _asset) => (currentContract_allowedBufferHelpers_otherAsset___bufferHelper__after == currentContract_allowedBufferHelpers_otherAsset___bufferHelper__before)), "otherAsset != _asset => allowedBufferHelpers[otherAsset][_bufferHelper]@after == allowedBufferHelpers[otherAsset][_bufferHelper]@before";
}

/*
 * otherHelper != _bufferHelper => allowedBufferHelpers[_asset][otherHelper]@after == allowedBufferHelpers[_asset][otherHelper]@before
 *
 * What it means: When allowing a specific buffer helper for an asset, the permission status of all other buffer helpers for that same asset should remain unchanged
 *
 * Why it should hold: The function should only modify the permission for the specific buffer helper being allowed, not affect other buffer helpers for the same asset. This ensures granular control over buffer helper permissions
 *
 * Possible consequences: If this property is violated, allowing one buffer helper could accidentally change permissions for other buffer helpers on the same asset, potentially granting or revoking access unintentionally
 */
rule allowBufferHelper_0d1598dd_preserves_other_buffer_helpers(env e) {
    address _asset;
    address _bufferHelper;
    address otherHelper;

    // assign all the 'before' variables
    bool currentContract_allowedBufferHelpers__asset__otherHelper__before = currentContract.allowedBufferHelpers[_asset][otherHelper];

    // call function under test
    allowBufferHelper(e, _asset, _bufferHelper);

    // assign all the 'after' variables
    bool currentContract_allowedBufferHelpers__asset__otherHelper__after = currentContract.allowedBufferHelpers[_asset][otherHelper];

    // verify integrity
    assert ((otherHelper != _bufferHelper) => (currentContract_allowedBufferHelpers__asset__otherHelper__after == currentContract_allowedBufferHelpers__asset__otherHelper__before)), "otherHelper != _bufferHelper => allowedBufferHelpers[_asset][otherHelper]@after == allowedBufferHelpers[_asset][otherHelper]@before";
}

/*
 * currentBufferHelpers[_asset].depositBufferHelper@after == currentBufferHelpers[_asset].depositBufferHelper@before
 *
 * What it means: The allowBufferHelper function should not modify which buffer helper is currently set as the deposit buffer helper for any asset
 *
 * Why it should hold: allowBufferHelper only manages the allowlist of buffer helpers, it should not change which helpers are currently active. The currentBufferHelpers mapping should only be modified by setDepositBufferHelper function
 *
 * Possible consequences: If this property is violated, allowing a buffer helper could accidentally change the active deposit buffer helper, disrupting ongoing deposit operations and potentially causing unexpected behavior in deposit processing
 */
rule allowBufferHelper_0d1598dd_preserves_current_deposit_helper(env e) {
    address _asset;
    address _bufferHelper;

    // assign all the 'before' variables
    address currentContract_currentBufferHelpers__asset__depositBufferHelper_before = currentContract.currentBufferHelpers[_asset].depositBufferHelper;

    // call function under test
    allowBufferHelper(e, _asset, _bufferHelper);

    // assign all the 'after' variables
    address currentContract_currentBufferHelpers__asset__depositBufferHelper_after = currentContract.currentBufferHelpers[_asset].depositBufferHelper;

    // verify integrity
    assert (currentContract_currentBufferHelpers__asset__depositBufferHelper_after == currentContract_currentBufferHelpers__asset__depositBufferHelper_before), "currentBufferHelpers[_asset].depositBufferHelper@after == currentBufferHelpers[_asset].depositBufferHelper@before";
}

/*
 * currentBufferHelpers[_asset].withdrawBufferHelper@after == currentBufferHelpers[_asset].withdrawBufferHelper@before
 *
 * What it means: The allowBufferHelper function should not modify which buffer helper is currently set as the withdrawal buffer helper for any asset
 *
 * Why it should hold: Similar to deposit helpers, allowBufferHelper should only manage permissions and not change active configurations. The currentBufferHelpers mapping should only be modified by setWithdrawBufferHelper function
 *
 * Possible consequences: If this property is violated, allowing a buffer helper could accidentally change the active withdrawal buffer helper, disrupting ongoing withdrawal operations and potentially causing unexpected behavior in withdrawal processing
 */
rule allowBufferHelper_0d1598dd_preserves_current_withdraw_helper(env e) {
    address _asset;
    address _bufferHelper;

    // assign all the 'before' variables
    address currentContract_currentBufferHelpers__asset__withdrawBufferHelper_before = currentContract.currentBufferHelpers[_asset].withdrawBufferHelper;

    // call function under test
    allowBufferHelper(e, _asset, _bufferHelper);

    // assign all the 'after' variables
    address currentContract_currentBufferHelpers__asset__withdrawBufferHelper_after = currentContract.currentBufferHelpers[_asset].withdrawBufferHelper;

    // verify integrity
    assert (currentContract_currentBufferHelpers__asset__withdrawBufferHelper_after == currentContract_currentBufferHelpers__asset__withdrawBufferHelper_before), "currentBufferHelpers[_asset].withdrawBufferHelper@after == currentBufferHelpers[_asset].withdrawBufferHelper@before";
}

/*
 * msg.sender != owner@before && msg.sender != authority@before => revert
 *
 * What it means: The function must revert if called by anyone other than the owner or authority
 *
 * Why it should hold: This is an admin-only function with the requiresAuth modifier that should only allow authorized users to modify buffer helper permissions
 *
 * Possible consequences: Unauthorized access control manipulation, allowing attackers to disable legitimate buffer helpers or enable malicious ones
 */
rule disallowBufferHelper_b032299c_unauthorized_reverts(env e) {
    address _asset;
    address _bufferHelper;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    disallowBufferHelper@withrevert(e, _asset, _bufferHelper);
    bool disallowBufferHelper_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((e.msg.sender != currentContract_owner_before) && (e.msg.sender != currentContract_authority_before)) => disallowBufferHelper_reverted), "msg.sender != owner@before && msg.sender != authority@before => revert";
}

/*
 * msg.sender == owner@before || msg.sender == authority@before => allowedBufferHelpers[_asset][_bufferHelper]@after == false
 *
 * What it means: When called by authorized users, the function must set the allowedBufferHelpers mapping to false for the specified asset and buffer helper
 *
 * Why it should hold: This is the core functionality of the disallow function - it should actually disallow the buffer helper by setting its permission to false
 *
 * Possible consequences: Function becomes non-functional, unable to revoke buffer helper permissions when needed
 */
rule disallowBufferHelper_b032299c_disallow_sets_false(env e) {
    address _asset;
    address _bufferHelper;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    disallowBufferHelper(e, _asset, _bufferHelper);

    // assign all the 'after' variables
    bool currentContract_allowedBufferHelpers__asset___bufferHelper__after = currentContract.allowedBufferHelpers[_asset][_bufferHelper];

    // verify integrity
    assert (((e.msg.sender == currentContract_owner_before) || (e.msg.sender == currentContract_authority_before)) => (currentContract_allowedBufferHelpers__asset___bufferHelper__after == false)), "msg.sender == owner@before || msg.sender == authority@before => allowedBufferHelpers[_asset][_bufferHelper]@after == false";
}

/*
 * !allowedBufferHelpers[_asset][_bufferHelper]@before => revert
 *
 * What it means: The function must revert if the buffer helper is already disallowed (already false in the mapping)
 *
 * Why it should hold: No-op operations should revert to prevent wasted gas and indicate that the operation has no meaningful effect
 *
 * Possible consequences: Gas waste and unclear contract state, making it difficult to determine if operations were successful
 */
rule disallowBufferHelper_b032299c_already_false_no_op(env e) {
    address _asset;
    address _bufferHelper;

    // assign all the 'before' variables
    bool currentContract_allowedBufferHelpers__asset___bufferHelper__before = currentContract.allowedBufferHelpers[_asset][_bufferHelper];

    // call function under test
    disallowBufferHelper@withrevert(e, _asset, _bufferHelper);
    bool disallowBufferHelper_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (!(currentContract_allowedBufferHelpers__asset___bufferHelper__before) => disallowBufferHelper_reverted), "!allowedBufferHelpers[_asset][_bufferHelper]@before => revert";
}

/*
 * _asset == address(0) => revert
 *
 * What it means: The function must revert if the asset parameter is the zero address
 *
 * Why it should hold: Zero address is not a valid ERC20 token and should not be used in buffer helper mappings
 *
 * Possible consequences: Invalid state entries and potential issues with buffer helper logic that expects valid asset addresses
 */
rule disallowBufferHelper_b032299c_zero_asset_reverts(env e) {
    address _asset;
    address _bufferHelper;

    // assign all the 'before' variables

    // call function under test
    disallowBufferHelper@withrevert(e, _asset, _bufferHelper);
    bool disallowBufferHelper_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((_asset == 0) => disallowBufferHelper_reverted), "_asset == address(0) => revert";
}

/*
 * _bufferHelper == address(0) => revert
 *
 * What it means: The function must revert if the buffer helper parameter is the zero address
 *
 * Why it should hold: Zero address is not a valid buffer helper contract and disallowing it serves no purpose since it's already effectively disabled
 *
 * Possible consequences: Meaningless operations and potential confusion about buffer helper states
 */
rule disallowBufferHelper_b032299c_zero_helper_reverts(env e) {
    address _asset;
    address _bufferHelper;

    // assign all the 'before' variables

    // call function under test
    disallowBufferHelper@withrevert(e, _asset, _bufferHelper);
    bool disallowBufferHelper_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((_bufferHelper == 0) => disallowBufferHelper_reverted), "_bufferHelper == address(0) => revert";
}

/*
 * (msg.sender == owner@before || msg.sender == authority@before) && otherAsset != _asset => allowedBufferHelpers[otherAsset][_bufferHelper]@after == allowedBufferHelpers[otherAsset][_bufferHelper]@before
 *
 * What it means: When authorized users call the function, buffer helper permissions for other assets should remain unchanged
 *
 * Why it should hold: The function should only affect the specific asset-helper combination provided, not other assets
 *
 * Possible consequences: Unintended side effects where disallowing one buffer helper affects permissions for other assets
 */
rule disallowBufferHelper_b032299c_other_assets_unchanged(env e) {
    address _asset;
    address _bufferHelper;
    address otherAsset;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    bool currentContract_allowedBufferHelpers_otherAsset___bufferHelper__before = currentContract.allowedBufferHelpers[otherAsset][_bufferHelper];

    // call function under test
    disallowBufferHelper(e, _asset, _bufferHelper);

    // assign all the 'after' variables
    bool currentContract_allowedBufferHelpers_otherAsset___bufferHelper__after = currentContract.allowedBufferHelpers[otherAsset][_bufferHelper];

    // verify integrity
    assert ((((e.msg.sender == currentContract_owner_before) || (e.msg.sender == currentContract_authority_before)) && (otherAsset != _asset)) => (currentContract_allowedBufferHelpers_otherAsset___bufferHelper__after == currentContract_allowedBufferHelpers_otherAsset___bufferHelper__before)), "(msg.sender == owner@before || msg.sender == authority@before) && otherAsset != _asset => allowedBufferHelpers[otherAsset][_bufferHelper]@after == allowedBufferHelpers[otherAsset][_bufferHelper]@before";
}

/*
 * (msg.sender == owner@before || msg.sender == authority@before) && otherHelper != _bufferHelper => allowedBufferHelpers[_asset][otherHelper]@after == allowedBufferHelpers[_asset][otherHelper]@before
 *
 * What it means: When authorized users call the function, permissions for other buffer helpers of the same asset should remain unchanged
 *
 * Why it should hold: The function should only affect the specific buffer helper provided, not other helpers for the same asset
 *
 * Possible consequences: Unintended side effects where disallowing one buffer helper affects permissions for other helpers of the same asset
 */
rule disallowBufferHelper_b032299c_other_helpers_unchanged(env e) {
    address _asset;
    address _bufferHelper;
    address otherHelper;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    bool currentContract_allowedBufferHelpers__asset__otherHelper__before = currentContract.allowedBufferHelpers[_asset][otherHelper];

    // call function under test
    disallowBufferHelper(e, _asset, _bufferHelper);

    // assign all the 'after' variables
    bool currentContract_allowedBufferHelpers__asset__otherHelper__after = currentContract.allowedBufferHelpers[_asset][otherHelper];

    // verify integrity
    assert ((((e.msg.sender == currentContract_owner_before) || (e.msg.sender == currentContract_authority_before)) && (otherHelper != _bufferHelper)) => (currentContract_allowedBufferHelpers__asset__otherHelper__after == currentContract_allowedBufferHelpers__asset__otherHelper__before)), "(msg.sender == owner@before || msg.sender == authority@before) && otherHelper != _bufferHelper => allowedBufferHelpers[_asset][otherHelper]@after == allowedBufferHelpers[_asset][otherHelper]@before";
}

/*
 * msg.sender == owner@before || msg.sender == authority@before => currentBufferHelpers[_asset].depositBufferHelper@after == currentBufferHelpers[_asset].depositBufferHelper@before
 *
 * What it means: The function should not modify the currently active deposit buffer helper configuration
 *
 * Why it should hold: Disallowing a buffer helper only affects the allowlist, not the currently configured active helpers
 *
 * Possible consequences: Unexpected changes to active buffer helper configuration when only permission changes were intended
 */
rule disallowBufferHelper_b032299c_current_deposit_helper_unchanged(env e) {
    address _asset;
    address _bufferHelper;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    address currentContract_currentBufferHelpers__asset__depositBufferHelper_before = currentContract.currentBufferHelpers[_asset].depositBufferHelper;

    // call function under test
    disallowBufferHelper(e, _asset, _bufferHelper);

    // assign all the 'after' variables
    address currentContract_currentBufferHelpers__asset__depositBufferHelper_after = currentContract.currentBufferHelpers[_asset].depositBufferHelper;

    // verify integrity
    assert (((e.msg.sender == currentContract_owner_before) || (e.msg.sender == currentContract_authority_before)) => (currentContract_currentBufferHelpers__asset__depositBufferHelper_after == currentContract_currentBufferHelpers__asset__depositBufferHelper_before)), "msg.sender == owner@before || msg.sender == authority@before => currentBufferHelpers[_asset].depositBufferHelper@after == currentBufferHelpers[_asset].depositBufferHelper@before";
}

/*
 * msg.sender == owner@before || msg.sender == authority@before => currentBufferHelpers[_asset].withdrawBufferHelper@after == currentBufferHelpers[_asset].withdrawBufferHelper@before
 *
 * What it means: The function should not modify the currently active withdrawal buffer helper configuration
 *
 * Why it should hold: Disallowing a buffer helper only affects the allowlist, not the currently configured active helpers
 *
 * Possible consequences: Unexpected changes to active buffer helper configuration when only permission changes were intended
 */
rule disallowBufferHelper_b032299c_current_withdraw_helper_unchanged(env e) {
    address _asset;
    address _bufferHelper;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    address currentContract_currentBufferHelpers__asset__withdrawBufferHelper_before = currentContract.currentBufferHelpers[_asset].withdrawBufferHelper;

    // call function under test
    disallowBufferHelper(e, _asset, _bufferHelper);

    // assign all the 'after' variables
    address currentContract_currentBufferHelpers__asset__withdrawBufferHelper_after = currentContract.currentBufferHelpers[_asset].withdrawBufferHelper;

    // verify integrity
    assert (((e.msg.sender == currentContract_owner_before) || (e.msg.sender == currentContract_authority_before)) => (currentContract_currentBufferHelpers__asset__withdrawBufferHelper_after == currentContract_currentBufferHelpers__asset__withdrawBufferHelper_before)), "msg.sender == owner@before || msg.sender == authority@before => currentBufferHelpers[_asset].withdrawBufferHelper@after == currentBufferHelpers[_asset].withdrawBufferHelper@before";
}