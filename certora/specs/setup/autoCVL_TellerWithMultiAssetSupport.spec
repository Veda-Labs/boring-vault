import "dispatching_TellerWithMultiAssetSupport.spec";

/*
 * isPaused@after == true
 *
 * What it means: After calling pause(), the isPaused state variable must always be set to true
 *
 * Why it should hold: The pause() function's core purpose is to pause the contract by setting isPaused to true. Looking at the contract, isPaused is checked in deposit functions to prevent operations when paused. The unpause() function sets isPaused to false, so pause() must do the opposite.
 *
 * Possible consequences: If pause() doesn't set isPaused to true, the contract cannot be effectively paused, allowing deposits and other operations to continue during emergency situations, potentially leading to fund loss or exploitation during known vulnerabilities.
 */
rule pause_8456cb59_sets_paused_true(env e) {

    // assign all the 'before' variables

    // call function under test
    pause(e);

    // assign all the 'after' variables
    bool currentContract_isPaused_after = currentContract.isPaused;

    // verify integrity
    assert (currentContract_isPaused_after == true), "isPaused@after == true";
}

/*
 * isPaused@before == true => revert
 *
 * What it means: If the contract is already paused (isPaused is true), calling pause() again should revert rather than being a no-op
 *
 * Why it should hold: Following the NO-OPS MUST REVERT principle, if pause() is called when the contract is already paused, it performs no meaningful state change and should revert. This prevents wasted gas and ensures clear contract state management.
 *
 * Possible consequences: If pause() allows redundant calls, it wastes gas and creates unclear contract behavior. Admins might think they're taking emergency action when they're actually doing nothing, leading to confusion during critical situations.
 */
rule pause_8456cb59_already_paused_reverts(env e) {

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    pause@withrevert(e);
    bool pause_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_isPaused_before == true) => pause_reverted), "isPaused@before == true => revert";
}

/*
 * isPaused@before == false => isPaused@after == true
 *
 * What it means: When pause() is called on an unpaused contract (isPaused is false), it must transition the state to paused (isPaused becomes true)
 *
 * Why it should hold: This property ensures the correct state transition from unpaused to paused. It's the fundamental behavior expected from a pause function - to change the contract from operational to paused state when called on an active contract.
 *
 * Possible consequences: If this transition fails, the pause mechanism is broken, leaving the contract unable to be paused during emergencies, potentially allowing continued exploitation of vulnerabilities or preventing proper maintenance procedures.
 */
rule pause_8456cb59_unpaused_to_paused(env e) {

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    pause(e);

    // assign all the 'after' variables
    bool currentContract_isPaused_after = currentContract.isPaused;

    // verify integrity
    assert ((currentContract_isPaused_before == false) => (currentContract_isPaused_after == true)), "isPaused@before == false => isPaused@after == true";
}

/*
 * !isPaused@before => revert
 *
 * What it means: If the contract is already unpaused (isPaused is false), calling unpause() must revert
 *
 * Why it should hold: The unpause function should only succeed when there's meaningful work to do - transitioning from paused to unpaused state. If already unpaused, this is a no-op that should revert according to the NO-OPS MUST REVERT rule
 *
 * Possible consequences: Gas waste, unclear contract state, potential for griefing attacks where users repeatedly call unpause when already unpaused, and violation of expected contract behavior patterns
 */
rule unpause_3f4ba83a_already_unpaused_reverts(env e) {

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    unpause@withrevert(e);
    bool unpause_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (!(currentContract_isPaused_before) => unpause_reverted), "!isPaused@before => revert";
}

/*
 * isPaused@before => !isPaused@after
 *
 * What it means: When unpause() is called on a paused contract, it must set isPaused to false
 *
 * Why it should hold: This is the core functionality of unpause() - it should transition the contract from paused to unpaused state by setting the isPaused flag to false. Without this, the function doesn't fulfill its intended purpose
 *
 * Possible consequences: Contract remains permanently paused, users cannot deposit or use depositWithPermit functions, complete DoS of core contract functionality, funds could be locked if no other unpause mechanism exists
 */
rule unpause_3f4ba83a_sets_isPaused_false(env e) {

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    unpause(e);

    // assign all the 'after' variables
    bool currentContract_isPaused_after = currentContract.isPaused;

    // verify integrity
    assert (currentContract_isPaused_before => !(currentContract_isPaused_after)), "isPaused@before => !isPaused@after";
}

/*
 * isPaused@before => !isPaused@after
 *
 * What it means: When the contract is paused before the call, unpause() must result in the contract being unpaused after the call
 *
 * Why it should hold: This property ensures the state transition works correctly - from paused (true) to unpaused (false). It's the fundamental requirement for the unpause functionality to work as intended
 *
 * Possible consequences: Broken pause/unpause mechanism, inability to restore contract functionality after pausing, potential permanent DoS if contract gets stuck in paused state
 */
rule unpause_3f4ba83a_paused_to_unpaused(env e) {

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    unpause(e);

    // assign all the 'after' variables
    bool currentContract_isPaused_after = currentContract.isPaused;

    // verify integrity
    assert (currentContract_isPaused_before => !(currentContract_isPaused_after)), "isPaused@before => !isPaused@after";
}

/*
 * sharePremium > 1000 => revert
 *
 * What it means: The function must revert if the sharePremium parameter exceeds 1000 basis points (10%)
 *
 * Why it should hold: The contract defines MAX_SHARE_PREMIUM as 1000 to prevent excessive premiums that would make deposits uneconomical or allow admin abuse. The error TellerWithMultiAssetSupport__SharePremiumTooLarge exists specifically for this validation
 *
 * Possible consequences: Economic exploitation where admins set extremely high premiums (e.g., 99%) effectively stealing user deposits by minting almost no shares in return
 */
rule updateAssetData_8dfd8ba1_premium_too_large(env e) {
    address asset;
    bool allowDeposits;
    bool allowWithdraws;
    uint16 sharePremium;

    // assign all the 'before' variables

    // call function under test
    updateAssetData@withrevert(e, asset, allowDeposits, allowWithdraws, sharePremium);
    bool updateAssetData_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((sharePremium > 1000) => updateAssetData_reverted), "sharePremium > 1000 => revert";
}

/*
 * sharePremium <= 1000 => assetData[asset].allowDeposits@after == allowDeposits
 *
 * What it means: When sharePremium is valid (≤1000), the function must update the allowDeposits flag for the specified asset to match the input parameter
 *
 * Why it should hold: This is the core functionality of updateAssetData - to configure whether deposits are allowed for specific assets. The assetData mapping stores this configuration and deposit functions check this flag
 *
 * Possible consequences: Asset configuration corruption where deposits remain enabled/disabled contrary to admin intentions, leading to operational failures or security bypasses
 */
rule updateAssetData_8dfd8ba1_updates_asset_deposits(env e) {
    address asset;
    bool allowDeposits;
    bool allowWithdraws;
    uint16 sharePremium;

    // assign all the 'before' variables

    // call function under test
    updateAssetData(e, asset, allowDeposits, allowWithdraws, sharePremium);

    // assign all the 'after' variables
    bool currentContract_assetData_asset__allowDeposits_after = currentContract.assetData[asset].allowDeposits;

    // verify integrity
    assert ((sharePremium <= 1000) => (currentContract_assetData_asset__allowDeposits_after == allowDeposits)), "sharePremium <= 1000 => assetData[asset].allowDeposits@after == allowDeposits";
}

/*
 * sharePremium <= 1000 => assetData[asset].allowWithdraws@after == allowWithdraws
 *
 * What it means: When sharePremium is valid (≤1000), the function must update the allowWithdraws flag for the specified asset to match the input parameter
 *
 * Why it should hold: Similar to deposits, this configures withdrawal permissions for assets. The bulkWithdraw function checks this flag before allowing withdrawals
 *
 * Possible consequences: Withdrawal configuration failures leading to either permanent fund lockup or unauthorized withdrawals when they should be disabled
 */
rule updateAssetData_8dfd8ba1_updates_asset_withdraws(env e) {
    address asset;
    bool allowDeposits;
    bool allowWithdraws;
    uint16 sharePremium;

    // assign all the 'before' variables

    // call function under test
    updateAssetData(e, asset, allowDeposits, allowWithdraws, sharePremium);

    // assign all the 'after' variables
    bool currentContract_assetData_asset__allowWithdraws_after = currentContract.assetData[asset].allowWithdraws;

    // verify integrity
    assert ((sharePremium <= 1000) => (currentContract_assetData_asset__allowWithdraws_after == allowWithdraws)), "sharePremium <= 1000 => assetData[asset].allowWithdraws@after == allowWithdraws";
}

/*
 * sharePremium <= 1000 => assetData[asset].sharePremium@after == sharePremium
 *
 * What it means: When sharePremium is valid (≤1000), the function must update the sharePremium field for the specified asset to match the input parameter
 *
 * Why it should hold: The sharePremium affects how many shares users receive during deposits - it's applied in _erc20Deposit to reduce shares minted. Incorrect updates would break deposit economics
 *
 * Possible consequences: Incorrect premium application leading to users receiving wrong share amounts, either overpaying (too high premium) or underpaying (too low premium) for their vault ownership
 */
rule updateAssetData_8dfd8ba1_updates_share_premium(env e) {
    address asset;
    bool allowDeposits;
    bool allowWithdraws;
    uint16 sharePremium;

    // assign all the 'before' variables

    // call function under test
    updateAssetData(e, asset, allowDeposits, allowWithdraws, sharePremium);

    // assign all the 'after' variables
    uint16 currentContract_assetData_asset__sharePremium_after = currentContract.assetData[asset].sharePremium;

    // verify integrity
    assert ((sharePremium <= 1000) => (currentContract_assetData_asset__sharePremium_after == sharePremium)), "sharePremium <= 1000 => assetData[asset].sharePremium@after == sharePremium";
}

/*
 * sharePremium <= 1000 && assetData[asset].allowDeposits@before == allowDeposits && assetData[asset].allowWithdraws@before == allowWithdraws && assetData[asset].sharePremium@before == sharePremium => revert
 *
 * What it means: If all three parameters (allowDeposits, allowWithdraws, sharePremium) match their current stored values and sharePremium is valid, the function must revert as it's a no-op
 *
 * Why it should hold: Following the NO-OPS MUST REVERT principle - operations that don't change state should fail to prevent wasted gas and indicate potential errors in caller logic
 *
 * Possible consequences: Gas waste and potential masking of integration bugs where callers think they're making changes but aren't
 */
rule updateAssetData_8dfd8ba1_no_change_reverts(env e) {
    address asset;
    bool allowDeposits;
    bool allowWithdraws;
    uint16 sharePremium;

    // assign all the 'before' variables
    bool currentContract_assetData_asset__allowDeposits_before = currentContract.assetData[asset].allowDeposits;
    bool currentContract_assetData_asset__allowWithdraws_before = currentContract.assetData[asset].allowWithdraws;
    uint16 currentContract_assetData_asset__sharePremium_before = currentContract.assetData[asset].sharePremium;

    // call function under test
    updateAssetData@withrevert(e, asset, allowDeposits, allowWithdraws, sharePremium);
    bool updateAssetData_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((((sharePremium <= 1000) && (currentContract_assetData_asset__allowDeposits_before == allowDeposits)) && (currentContract_assetData_asset__allowWithdraws_before == allowWithdraws)) && (currentContract_assetData_asset__sharePremium_before == sharePremium)) => updateAssetData_reverted), "sharePremium <= 1000 && assetData[asset].allowDeposits@before == allowDeposits && assetData[asset].allowWithdraws@before == allowWithdraws && assetData[asset].sharePremium@before == sharePremium => revert";
}

/*
 * sharePremium <= 1000 && otherAsset != asset => assetData[otherAsset].allowDeposits@after == assetData[otherAsset].allowDeposits@before
 *
 * What it means: When updating one asset's configuration, the allowDeposits flag for all other assets must remain unchanged
 *
 * Why it should hold: Asset configurations should be independent - updating one asset shouldn't affect others. This prevents unintended side effects and maintains system integrity
 *
 * Possible consequences: Cascading configuration corruption where updating one asset accidentally disables/enables deposits for unrelated assets
 */
rule updateAssetData_8dfd8ba1_other_deposits_unchanged(env e) {
    address asset;
    bool allowDeposits;
    bool allowWithdraws;
    uint16 sharePremium;
    address otherAsset;

    // assign all the 'before' variables
    bool currentContract_assetData_otherAsset__allowDeposits_before = currentContract.assetData[otherAsset].allowDeposits;

    // call function under test
    updateAssetData(e, asset, allowDeposits, allowWithdraws, sharePremium);

    // assign all the 'after' variables
    bool currentContract_assetData_otherAsset__allowDeposits_after = currentContract.assetData[otherAsset].allowDeposits;

    // verify integrity
    assert (((sharePremium <= 1000) && (otherAsset != asset)) => (currentContract_assetData_otherAsset__allowDeposits_after == currentContract_assetData_otherAsset__allowDeposits_before)), "sharePremium <= 1000 && otherAsset != asset => assetData[otherAsset].allowDeposits@after == assetData[otherAsset].allowDeposits@before";
}

/*
 * sharePremium <= 1000 && otherAsset != asset => assetData[otherAsset].allowWithdraws@after == assetData[otherAsset].allowWithdraws@before
 *
 * What it means: When updating one asset's configuration, the allowWithdraws flag for all other assets must remain unchanged
 *
 * Why it should hold: Similar to deposits, withdrawal permissions should be asset-specific and independent to prevent unintended operational impacts
 *
 * Possible consequences: Unintended withdrawal restrictions or permissions affecting assets that weren't meant to be modified
 */
rule updateAssetData_8dfd8ba1_other_withdraws_unchanged(env e) {
    address asset;
    bool allowDeposits;
    bool allowWithdraws;
    uint16 sharePremium;
    address otherAsset;

    // assign all the 'before' variables
    bool currentContract_assetData_otherAsset__allowWithdraws_before = currentContract.assetData[otherAsset].allowWithdraws;

    // call function under test
    updateAssetData(e, asset, allowDeposits, allowWithdraws, sharePremium);

    // assign all the 'after' variables
    bool currentContract_assetData_otherAsset__allowWithdraws_after = currentContract.assetData[otherAsset].allowWithdraws;

    // verify integrity
    assert (((sharePremium <= 1000) && (otherAsset != asset)) => (currentContract_assetData_otherAsset__allowWithdraws_after == currentContract_assetData_otherAsset__allowWithdraws_before)), "sharePremium <= 1000 && otherAsset != asset => assetData[otherAsset].allowWithdraws@after == assetData[otherAsset].allowWithdraws@before";
}

/*
 * sharePremium <= 1000 && otherAsset != asset => assetData[otherAsset].sharePremium@after == assetData[otherAsset].sharePremium@before
 *
 * What it means: When updating one asset's configuration, the sharePremium for all other assets must remain unchanged
 *
 * Why it should hold: Premium rates should be asset-specific based on individual risk profiles and market conditions. Cross-contamination would break deposit economics
 *
 * Possible consequences: Incorrect premium application across multiple assets, leading to unfair share distribution and economic imbalances
 */
rule updateAssetData_8dfd8ba1_other_premiums_unchanged(env e) {
    address asset;
    bool allowDeposits;
    bool allowWithdraws;
    uint16 sharePremium;
    address otherAsset;

    // assign all the 'before' variables
    uint16 currentContract_assetData_otherAsset__sharePremium_before = currentContract.assetData[otherAsset].sharePremium;

    // call function under test
    updateAssetData(e, asset, allowDeposits, allowWithdraws, sharePremium);

    // assign all the 'after' variables
    uint16 currentContract_assetData_otherAsset__sharePremium_after = currentContract.assetData[otherAsset].sharePremium;

    // verify integrity
    assert (((sharePremium <= 1000) && (otherAsset != asset)) => (currentContract_assetData_otherAsset__sharePremium_after == currentContract_assetData_otherAsset__sharePremium_before)), "sharePremium <= 1000 && otherAsset != asset => assetData[otherAsset].sharePremium@after == assetData[otherAsset].sharePremium@before";
}

/*
 * sharePremium <= 1000 && asset == address(0) => assetData[address(0)].allowDeposits@after == allowDeposits
 *
 * What it means: The function should accept address(0) as a valid asset parameter and update its configuration normally when sharePremium is valid
 *
 * Why it should hold: Zero address might be used as a special marker or placeholder in the system. The function should handle it gracefully rather than reverting, as there's no explicit zero address check in the visible code
 *
 * Possible consequences: System inflexibility where legitimate zero address configurations are rejected, potentially breaking special asset handling or placeholder mechanisms
 */
rule updateAssetData_8dfd8ba1_zero_address_allowed(env e) {
    address asset;
    bool allowDeposits;
    bool allowWithdraws;
    uint16 sharePremium;

    // assign all the 'before' variables

    // call function under test
    updateAssetData(e, asset, allowDeposits, allowWithdraws, sharePremium);

    // assign all the 'after' variables
    bool currentContract_assetData_0__allowDeposits_after = currentContract.getAssetData(e, 0).allowDeposits;

    // verify integrity
    assert (((sharePremium <= 1000) && (asset == 0)) => (currentContract_assetData_0__allowDeposits_after == allowDeposits)), "sharePremium <= 1000 && asset == address(0) => assetData[address(0)].allowDeposits@after == allowDeposits";
}

/*
 * _shareLockPeriod > 259200 => revert
 *
 * What it means: The function must revert if the new share lock period exceeds the maximum allowed period of 259200 seconds (3 days)
 *
 * Why it should hold: The contract defines MAX_SHARE_LOCK_PERIOD as 3 days to prevent excessively long lock periods that could trap user funds indefinitely. This is a critical safety mechanism.
 *
 * Possible consequences: Users could have their shares locked for unreasonably long periods, effectively creating a denial of service where funds become inaccessible for extended timeframes, potentially causing financial harm and loss of user trust.
 */
rule setShareLockPeriod_12056e2d_period_exceeds_max_reverts(env e) {
    uint64 _shareLockPeriod;

    // assign all the 'before' variables

    // call function under test
    setShareLockPeriod@withrevert(e, _shareLockPeriod);
    bool setShareLockPeriod_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((_shareLockPeriod > 259200) => setShareLockPeriod_reverted), "_shareLockPeriod > 259200 => revert";
}

/*
 * _shareLockPeriod <= 259200 => shareLockPeriod@after == _shareLockPeriod
 *
 * What it means: When a valid share lock period is provided (within the maximum limit), the shareLockPeriod storage variable must be updated to the new value
 *
 * Why it should hold: This is the core functionality of the function - it must actually update the storage when given valid input, otherwise the function would be non-functional.
 *
 * Possible consequences: If the storage is not updated properly, the contract would continue using the old lock period, leading to inconsistent behavior and potential security issues where lock periods don't match admin intentions.
 */
rule setShareLockPeriod_12056e2d_valid_period_updates_storage(env e) {
    uint64 _shareLockPeriod;

    // assign all the 'before' variables

    // call function under test
    setShareLockPeriod(e, _shareLockPeriod);

    // assign all the 'after' variables
    uint64 currentContract_shareLockPeriod_after = currentContract.shareLockPeriod;

    // verify integrity
    assert ((_shareLockPeriod <= 259200) => (currentContract_shareLockPeriod_after == _shareLockPeriod)), "_shareLockPeriod <= 259200 => shareLockPeriod@after == _shareLockPeriod";
}

/*
 * _shareLockPeriod == shareLockPeriod@before => revert
 *
 * What it means: The function must revert if the new share lock period is identical to the current one, preventing no-op operations
 *
 * Why it should hold: No-op operations waste gas and provide no meaningful state change. They should be prevented to ensure efficient contract usage and clear intent from callers.
 *
 * Possible consequences: Wasted gas costs for users and potential confusion about whether the operation succeeded or had any effect on the contract state.
 */
rule setShareLockPeriod_12056e2d_no_change_reverts(env e) {
    uint64 _shareLockPeriod;

    // assign all the 'before' variables
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;

    // call function under test
    setShareLockPeriod@withrevert(e, _shareLockPeriod);
    bool setShareLockPeriod_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((_shareLockPeriod == currentContract_shareLockPeriod_before) => setShareLockPeriod_reverted), "_shareLockPeriod == shareLockPeriod@before => revert";
}

/*
 * _shareLockPeriod <= 259200 => isPaused@after == isPaused@before && depositNonce@after == depositNonce@before && depositCap@after == depositCap@before && permissionedTransfers@after == permissionedTransfers@before
 *
 * What it means: When successfully updating the share lock period, all other core storage variables (isPaused, depositNonce, depositCap, permissionedTransfers) must remain unchanged
 *
 * Why it should hold: The function should have surgical precision - only modifying the intended storage variable while preserving all other contract state to maintain system integrity.
 *
 * Possible consequences: Unintended state changes could corrupt the contract's operational state, leading to broken functionality, incorrect access controls, or compromised deposit/withdrawal mechanisms.
 */
rule setShareLockPeriod_12056e2d_other_storage_unchanged(env e) {
    uint64 _shareLockPeriod;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    bool currentContract_permissionedTransfers_before = currentContract.permissionedTransfers;

    // call function under test
    setShareLockPeriod(e, _shareLockPeriod);

    // assign all the 'after' variables
    bool currentContract_isPaused_after = currentContract.isPaused;
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;
    uint112 currentContract_depositCap_after = currentContract.depositCap;
    bool currentContract_permissionedTransfers_after = currentContract.permissionedTransfers;

    // verify integrity
    assert ((_shareLockPeriod <= 259200) => ((((currentContract_isPaused_after == currentContract_isPaused_before) && (currentContract_depositNonce_after == currentContract_depositNonce_before)) && (currentContract_depositCap_after == currentContract_depositCap_before)) && (currentContract_permissionedTransfers_after == currentContract_permissionedTransfers_before))), "_shareLockPeriod <= 259200 => isPaused@after == isPaused@before && depositNonce@after == depositNonce@before && depositCap@after == depositCap@before && permissionedTransfers@after == permissionedTransfers@before";
}

/*
 * _shareLockPeriod <= 259200 => owner@after == owner@before && authority@after == authority@before
 *
 * What it means: The function must not modify the owner or authority addresses when updating the share lock period
 *
 * Why it should hold: Access control variables are critical security components that should never be modified by unrelated functions to prevent privilege escalation or loss of control.
 *
 * Possible consequences: Unauthorized changes to ownership could lead to complete loss of admin control or transfer of control to malicious actors, compromising the entire contract.
 */
rule setShareLockPeriod_12056e2d_owner_unchanged(env e) {
    uint64 _shareLockPeriod;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    setShareLockPeriod(e, _shareLockPeriod);

    // assign all the 'after' variables
    address currentContract_owner_after = currentContract.owner;
    address currentContract_authority_after = currentContract.authority;

    // verify integrity
    assert ((_shareLockPeriod <= 259200) => ((currentContract_owner_after == currentContract_owner_before) && (currentContract_authority_after == currentContract_authority_before))), "_shareLockPeriod <= 259200 => owner@after == owner@before && authority@after == authority@before";
}

/*
 * _shareLockPeriod <= 259200 => locked@after == locked@before
 *
 * What it means: The reentrancy guard state (locked variable) must remain unchanged when updating the share lock period
 *
 * Why it should hold: The reentrancy guard is a critical security mechanism that should only be modified by the ReentrancyGuard's internal logic, not by administrative functions.
 *
 * Possible consequences: Corruption of the reentrancy guard could disable reentrancy protection or cause legitimate transactions to fail, creating security vulnerabilities or denial of service.
 */
rule setShareLockPeriod_12056e2d_reentrancy_guard_unchanged(env e) {
    uint64 _shareLockPeriod;

    // assign all the 'before' variables
    uint256 currentContract_locked_before = currentContract.locked;

    // call function under test
    setShareLockPeriod(e, _shareLockPeriod);

    // assign all the 'after' variables
    uint256 currentContract_locked_after = currentContract.locked;

    // verify integrity
    assert ((_shareLockPeriod <= 259200) => (currentContract_locked_after == currentContract_locked_before)), "_shareLockPeriod <= 259200 => locked@after == locked@before";
}

/*
 * user == address(0) => revert
 *
 * What it means: The function must revert when called with the zero address as the user parameter
 *
 * Why it should hold: Zero address is typically used as a null value in Ethereum and should not be a valid user address for access control operations. The contract likely has validation to prevent operations on the zero address.
 *
 * Possible consequences: State corruption where the zero address gets deny flags set, potentially breaking internal logic that relies on zero address having default/clean state
 */
rule denyAll_18aed921_zero_address_reverts(env e) {
    address user;

    // assign all the 'before' variables

    // call function under test
    denyAll@withrevert(e, user);
    bool denyAll_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((user == 0) => denyAll_reverted), "user == address(0) => revert";
}

/*
 * user != address(0) => beforeTransferData[user].denyFrom@after == true
 *
 * What it means: For valid non-zero addresses, the function must set the denyFrom flag to true in the user's beforeTransferData
 *
 * Why it should hold: This is the core functionality of denyAll - it should deny the user from transferring shares by setting the denyFrom flag
 *
 * Possible consequences: Access control bypass where users who should be denied from transferring shares can still transfer them
 */
rule denyAll_18aed921_sets_deny_from(env e) {
    address user;

    // assign all the 'before' variables

    // call function under test
    denyAll(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyFrom_after = currentContract.beforeTransferData[user].denyFrom;

    // verify integrity
    assert ((user != 0) => (currentContract_beforeTransferData_user__denyFrom_after == true)), "user != address(0) => beforeTransferData[user].denyFrom@after == true";
}

/*
 * user != address(0) => beforeTransferData[user].denyTo@after == true
 *
 * What it means: For valid non-zero addresses, the function must set the denyTo flag to true in the user's beforeTransferData
 *
 * Why it should hold: This is part of the core functionality of denyAll - it should deny the user from receiving shares by setting the denyTo flag
 *
 * Possible consequences: Access control bypass where users who should be denied from receiving shares can still receive them
 */
rule denyAll_18aed921_sets_deny_to(env e) {
    address user;

    // assign all the 'before' variables

    // call function under test
    denyAll(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyTo_after = currentContract.beforeTransferData[user].denyTo;

    // verify integrity
    assert ((user != 0) => (currentContract_beforeTransferData_user__denyTo_after == true)), "user != address(0) => beforeTransferData[user].denyTo@after == true";
}

/*
 * user != address(0) => beforeTransferData[user].denyOperator@after == true
 *
 * What it means: For valid non-zero addresses, the function must set the denyOperator flag to true in the user's beforeTransferData
 *
 * Why it should hold: This completes the denyAll functionality - it should deny the user from acting as an operator in transfers by setting the denyOperator flag
 *
 * Possible consequences: Access control bypass where denied users can still act as operators to facilitate transfers
 */
rule denyAll_18aed921_sets_deny_operator(env e) {
    address user;

    // assign all the 'before' variables

    // call function under test
    denyAll(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyOperator_after = currentContract.beforeTransferData[user].denyOperator;

    // verify integrity
    assert ((user != 0) => (currentContract_beforeTransferData_user__denyOperator_after == true)), "user != address(0) => beforeTransferData[user].denyOperator@after == true";
}

/*
 * beforeTransferData[user].permissionedOperator@after == beforeTransferData[user].permissionedOperator@before
 *
 * What it means: The function must not modify the permissionedOperator flag - it should remain the same before and after the function call
 *
 * Why it should hold: denyAll should only affect the deny flags, not the permissioned operator status. These are separate access control mechanisms that should be managed independently
 *
 * Possible consequences: Unintended privilege escalation or loss where permissioned operator status is incorrectly modified
 */
rule denyAll_18aed921_preserves_permissioned_operator(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__permissionedOperator_before = currentContract.beforeTransferData[user].permissionedOperator;

    // call function under test
    denyAll(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__permissionedOperator_after = currentContract.beforeTransferData[user].permissionedOperator;

    // verify integrity
    assert (currentContract_beforeTransferData_user__permissionedOperator_after == currentContract_beforeTransferData_user__permissionedOperator_before), "beforeTransferData[user].permissionedOperator@after == beforeTransferData[user].permissionedOperator@before";
}

/*
 * beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before
 *
 * What it means: The function must not modify the shareUnlockTime field - it should remain the same before and after the function call
 *
 * Why it should hold: denyAll should only affect deny flags, not share lock timing. Share unlock times are related to deposit lock periods and should be managed separately from access control
 *
 * Possible consequences: Disruption of share lock mechanisms where users' shares become unlocked prematurely or locked longer than intended
 */
rule denyAll_18aed921_preserves_share_unlock_time(env e) {
    address user;

    // assign all the 'before' variables
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_before = currentContract.beforeTransferData[user].shareUnlockTime;

    // call function under test
    denyAll(e, user);

    // assign all the 'after' variables
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_after = currentContract.beforeTransferData[user].shareUnlockTime;

    // verify integrity
    assert (currentContract_beforeTransferData_user__shareUnlockTime_after == currentContract_beforeTransferData_user__shareUnlockTime_before), "beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before";
}

/*
 * otherUser != user => beforeTransferData[otherUser].denyFrom@after == beforeTransferData[otherUser].denyFrom@before
 *
 * What it means: The denyFrom flag for all other users (not the target user) must remain unchanged
 *
 * Why it should hold: denyAll should only affect the specified user, not other users in the system. This ensures surgical precision in access control operations
 *
 * Possible consequences: Mass access control corruption where innocent users get denied or un-denied unintentionally
 */
rule denyAll_18aed921_other_users_deny_from_unchanged(env e) {
    address user;
    address otherUser;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_otherUser__denyFrom_before = currentContract.beforeTransferData[otherUser].denyFrom;

    // call function under test
    denyAll(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_otherUser__denyFrom_after = currentContract.beforeTransferData[otherUser].denyFrom;

    // verify integrity
    assert ((otherUser != user) => (currentContract_beforeTransferData_otherUser__denyFrom_after == currentContract_beforeTransferData_otherUser__denyFrom_before)), "otherUser != user => beforeTransferData[otherUser].denyFrom@after == beforeTransferData[otherUser].denyFrom@before";
}

/*
 * otherUser != user => beforeTransferData[otherUser].denyTo@after == beforeTransferData[otherUser].denyTo@before
 *
 * What it means: The denyTo flag for all other users (not the target user) must remain unchanged
 *
 * Why it should hold: denyAll should only affect the specified user, not other users in the system. This maintains isolation between user access control states
 *
 * Possible consequences: Collateral damage where other users' ability to receive shares is incorrectly modified
 */
rule denyAll_18aed921_other_users_deny_to_unchanged(env e) {
    address user;
    address otherUser;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_otherUser__denyTo_before = currentContract.beforeTransferData[otherUser].denyTo;

    // call function under test
    denyAll(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_otherUser__denyTo_after = currentContract.beforeTransferData[otherUser].denyTo;

    // verify integrity
    assert ((otherUser != user) => (currentContract_beforeTransferData_otherUser__denyTo_after == currentContract_beforeTransferData_otherUser__denyTo_before)), "otherUser != user => beforeTransferData[otherUser].denyTo@after == beforeTransferData[otherUser].denyTo@before";
}

/*
 * otherUser != user => beforeTransferData[otherUser].denyOperator@after == beforeTransferData[otherUser].denyOperator@before
 *
 * What it means: The denyOperator flag for all other users (not the target user) must remain unchanged
 *
 * Why it should hold: denyAll should only affect the specified user, not other users. Operator privileges for other users should remain intact
 *
 * Possible consequences: Disruption of legitimate operator functionality where other operators lose or gain privileges incorrectly
 */
rule denyAll_18aed921_other_users_deny_operator_unchanged(env e) {
    address user;
    address otherUser;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_otherUser__denyOperator_before = currentContract.beforeTransferData[otherUser].denyOperator;

    // call function under test
    denyAll(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_otherUser__denyOperator_after = currentContract.beforeTransferData[otherUser].denyOperator;

    // verify integrity
    assert ((otherUser != user) => (currentContract_beforeTransferData_otherUser__denyOperator_after == currentContract_beforeTransferData_otherUser__denyOperator_before)), "otherUser != user => beforeTransferData[otherUser].denyOperator@after == beforeTransferData[otherUser].denyOperator@before";
}

/*
 * beforeTransferData[user].denyFrom@before && beforeTransferData[user].denyTo@before && beforeTransferData[user].denyOperator@before => revert
 *
 * What it means: If a user already has all three deny flags set to true, calling denyAll on them again must revert as it would be a no-operation
 *
 * Why it should hold: Following the NO-OPS MUST REVERT rule, if the function would not change any state (user is already fully denied), it should revert rather than succeed with no effect
 *
 * Possible consequences: Gas waste and potential logic errors where callers assume state changes occurred when none actually happened
 */
rule denyAll_18aed921_already_denied_no_op(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__denyFrom_before = currentContract.beforeTransferData[user].denyFrom;
    bool currentContract_beforeTransferData_user__denyTo_before = currentContract.beforeTransferData[user].denyTo;
    bool currentContract_beforeTransferData_user__denyOperator_before = currentContract.beforeTransferData[user].denyOperator;

    // call function under test
    denyAll@withrevert(e, user);
    bool denyAll_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((currentContract_beforeTransferData_user__denyFrom_before && currentContract_beforeTransferData_user__denyTo_before) && currentContract_beforeTransferData_user__denyOperator_before) => denyAll_reverted), "beforeTransferData[user].denyFrom@before && beforeTransferData[user].denyTo@before && beforeTransferData[user].denyOperator@before => revert";
}

/*
 * beforeTransferData[user].denyFrom@after == false && beforeTransferData[user].denyTo@after == false && beforeTransferData[user].denyOperator@after == false
 *
 * What it means: The function must set denyFrom, denyTo, and denyOperator flags to false for the specified user address
 *
 * Why it should hold: Based on the contract pattern where denyAll sets all three flags to true and individual allow functions (allowFrom, allowTo, allowOperator) set their respective flags to false, allowAll should set all three flags to false to reverse the effect of denyAll
 *
 * Possible consequences: Users remain blocked from transferring or receiving shares even after calling allowAll, breaking the intended functionality and potentially locking users out of their assets permanently
 */
rule allowAll_c29d2f10_sets_all_deny_flags_false(env e) {
    address user;

    // assign all the 'before' variables

    // call function under test
    allowAll(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyFrom_after = currentContract.beforeTransferData[user].denyFrom;
    bool currentContract_beforeTransferData_user__denyTo_after = currentContract.beforeTransferData[user].denyTo;
    bool currentContract_beforeTransferData_user__denyOperator_after = currentContract.beforeTransferData[user].denyOperator;

    // verify integrity
    assert (((currentContract_beforeTransferData_user__denyFrom_after == false) && (currentContract_beforeTransferData_user__denyTo_after == false)) && (currentContract_beforeTransferData_user__denyOperator_after == false)), "beforeTransferData[user].denyFrom@after == false && beforeTransferData[user].denyTo@after == false && beforeTransferData[user].denyOperator@after == false";
}

/*
 * beforeTransferData[user].permissionedOperator@after == beforeTransferData[user].permissionedOperator@before && beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before
 *
 * What it means: The function must not modify the permissionedOperator flag or shareUnlockTime for the user, only changing the deny flags
 *
 * Why it should hold: The allowAll function should only affect the deny flags (denyFrom, denyTo, denyOperator) and not interfere with other user data like operator permissions or share lock timing, which are managed by separate functions
 *
 * Possible consequences: Unintended modification of operator permissions or share unlock times could grant unauthorized access or prematurely unlock shares, breaking the security model
 */
rule allowAll_c29d2f10_preserves_permission_and_unlock(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__permissionedOperator_before = currentContract.beforeTransferData[user].permissionedOperator;
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_before = currentContract.beforeTransferData[user].shareUnlockTime;

    // call function under test
    allowAll(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__permissionedOperator_after = currentContract.beforeTransferData[user].permissionedOperator;
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_after = currentContract.beforeTransferData[user].shareUnlockTime;

    // verify integrity
    assert ((currentContract_beforeTransferData_user__permissionedOperator_after == currentContract_beforeTransferData_user__permissionedOperator_before) && (currentContract_beforeTransferData_user__shareUnlockTime_after == currentContract_beforeTransferData_user__shareUnlockTime_before)), "beforeTransferData[user].permissionedOperator@after == beforeTransferData[user].permissionedOperator@before && beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before";
}

/*
 * otherUser != user => beforeTransferData[otherUser].denyFrom@after == beforeTransferData[otherUser].denyFrom@before && beforeTransferData[otherUser].denyTo@after == beforeTransferData[otherUser].denyTo@before && beforeTransferData[otherUser].denyOperator@after == beforeTransferData[otherUser].denyOperator@before && beforeTransferData[otherUser].permissionedOperator@after == beforeTransferData[otherUser].permissionedOperator@before && beforeTransferData[otherUser].shareUnlockTime@after == beforeTransferData[otherUser].shareUnlockTime@before
 *
 * What it means: The function must only modify the beforeTransferData for the specified user and leave all other users' data completely unchanged
 *
 * Why it should hold: The allowAll function takes a specific user parameter and should only affect that user's permissions, not interfere with any other user's transfer restrictions or permissions
 *
 * Possible consequences: Modifying other users' data could accidentally grant or revoke permissions for unintended users, breaking access control and potentially allowing unauthorized transfers or blocking legitimate ones
 */
rule allowAll_c29d2f10_no_change_to_others(env e) {
    address user;
    address otherUser;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_otherUser__denyFrom_before = currentContract.beforeTransferData[otherUser].denyFrom;
    bool currentContract_beforeTransferData_otherUser__denyTo_before = currentContract.beforeTransferData[otherUser].denyTo;
    bool currentContract_beforeTransferData_otherUser__denyOperator_before = currentContract.beforeTransferData[otherUser].denyOperator;
    bool currentContract_beforeTransferData_otherUser__permissionedOperator_before = currentContract.beforeTransferData[otherUser].permissionedOperator;
    uint256 currentContract_beforeTransferData_otherUser__shareUnlockTime_before = currentContract.beforeTransferData[otherUser].shareUnlockTime;

    // call function under test
    allowAll(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_otherUser__denyFrom_after = currentContract.beforeTransferData[otherUser].denyFrom;
    bool currentContract_beforeTransferData_otherUser__denyTo_after = currentContract.beforeTransferData[otherUser].denyTo;
    bool currentContract_beforeTransferData_otherUser__denyOperator_after = currentContract.beforeTransferData[otherUser].denyOperator;
    bool currentContract_beforeTransferData_otherUser__permissionedOperator_after = currentContract.beforeTransferData[otherUser].permissionedOperator;
    uint256 currentContract_beforeTransferData_otherUser__shareUnlockTime_after = currentContract.beforeTransferData[otherUser].shareUnlockTime;

    // verify integrity
    assert ((otherUser != user) => (((((currentContract_beforeTransferData_otherUser__denyFrom_after == currentContract_beforeTransferData_otherUser__denyFrom_before) && (currentContract_beforeTransferData_otherUser__denyTo_after == currentContract_beforeTransferData_otherUser__denyTo_before)) && (currentContract_beforeTransferData_otherUser__denyOperator_after == currentContract_beforeTransferData_otherUser__denyOperator_before)) && (currentContract_beforeTransferData_otherUser__permissionedOperator_after == currentContract_beforeTransferData_otherUser__permissionedOperator_before)) && (currentContract_beforeTransferData_otherUser__shareUnlockTime_after == currentContract_beforeTransferData_otherUser__shareUnlockTime_before))), "otherUser != user => beforeTransferData[otherUser].denyFrom@after == beforeTransferData[otherUser].denyFrom@before && beforeTransferData[otherUser].denyTo@after == beforeTransferData[otherUser].denyTo@before && beforeTransferData[otherUser].denyOperator@after == beforeTransferData[otherUser].denyOperator@before && beforeTransferData[otherUser].permissionedOperator@after == beforeTransferData[otherUser].permissionedOperator@before && beforeTransferData[otherUser].shareUnlockTime@after == beforeTransferData[otherUser].shareUnlockTime@before";
}

/*
 * beforeTransferData[user].denyFrom@before == true => revert
 *
 * What it means: If a user is already denied from transferring shares (denyFrom is true), calling denyFrom again must revert instead of succeeding with no effect
 *
 * Why it should hold: The contract should prevent meaningless operations that waste gas and could be used to spam the system. If denyFrom is already true, calling it again accomplishes nothing and should fail
 *
 * Possible consequences: Gas griefing attacks where attackers repeatedly call denyFrom on already-denied users to waste gas and clog the network. Also allows for misleading transaction logs that suggest state changes when none occurred
 */
// gereon: not sure if this simple function warrants a no-op check
rule __denyFrom_2c524c42_no_op_reverts(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__denyFrom_before = currentContract.beforeTransferData[user].denyFrom;

    // call function under test
    denyFrom@withrevert(e, user);
    bool denyFrom_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_beforeTransferData_user__denyFrom_before == true) => denyFrom_reverted), "beforeTransferData[user].denyFrom@before == true => revert";
}

/*
 * beforeTransferData[user].denyFrom@before == false => beforeTransferData[user].denyFrom@after == true
 *
 * What it means: When denyFrom is called on a user who is not currently denied (denyFrom is false), it must set their denyFrom flag to true
 *
 * Why it should hold: This is the core functionality of denyFrom - it must actually deny users from transferring shares when they weren't previously denied. Without this, the function serves no purpose
 *
 * Possible consequences: Complete failure of access control system. Users who should be blocked from transferring shares can continue to do so, potentially allowing sanctioned or malicious users to move funds freely
 */
rule denyFrom_2c524c42_state_change(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__denyFrom_before = currentContract.beforeTransferData[user].denyFrom;

    // call function under test
    denyFrom(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyFrom_after = currentContract.beforeTransferData[user].denyFrom;

    // verify integrity
    assert ((currentContract_beforeTransferData_user__denyFrom_before == false) => (currentContract_beforeTransferData_user__denyFrom_after == true)), "beforeTransferData[user].denyFrom@before == false => beforeTransferData[user].denyFrom@after == true";
}

/*
 * beforeTransferData[user].denyTo@after == beforeTransferData[user].denyTo@before && beforeTransferData[user].denyOperator@after == beforeTransferData[user].denyOperator@before && beforeTransferData[user].permissionedOperator@after == beforeTransferData[user].permissionedOperator@before && beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before
 *
 * What it means: When denyFrom is called, only the denyFrom field should change - all other fields in the user's BeforeTransferData struct (denyTo, denyOperator, permissionedOperator, shareUnlockTime) must remain unchanged
 *
 * Why it should hold: denyFrom should have surgical precision - it only affects the user's ability to send shares, not receive them, operate on behalf of others, or their share unlock timing. Changing other fields would be a serious bug
 *
 * Possible consequences: Unintended privilege escalation or restriction. Users could lose permissions they should keep, or gain permissions they shouldn't have. Share unlock times could be corrupted, affecting deposit refund mechanisms
 */
rule denyFrom_2c524c42_other_fields_unchanged(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__denyTo_before = currentContract.beforeTransferData[user].denyTo;
    bool currentContract_beforeTransferData_user__denyOperator_before = currentContract.beforeTransferData[user].denyOperator;
    bool currentContract_beforeTransferData_user__permissionedOperator_before = currentContract.beforeTransferData[user].permissionedOperator;
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_before = currentContract.beforeTransferData[user].shareUnlockTime;

    // call function under test
    denyFrom(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyTo_after = currentContract.beforeTransferData[user].denyTo;
    bool currentContract_beforeTransferData_user__denyOperator_after = currentContract.beforeTransferData[user].denyOperator;
    bool currentContract_beforeTransferData_user__permissionedOperator_after = currentContract.beforeTransferData[user].permissionedOperator;
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_after = currentContract.beforeTransferData[user].shareUnlockTime;

    // verify integrity
    assert ((((currentContract_beforeTransferData_user__denyTo_after == currentContract_beforeTransferData_user__denyTo_before) && (currentContract_beforeTransferData_user__denyOperator_after == currentContract_beforeTransferData_user__denyOperator_before)) && (currentContract_beforeTransferData_user__permissionedOperator_after == currentContract_beforeTransferData_user__permissionedOperator_before)) && (currentContract_beforeTransferData_user__shareUnlockTime_after == currentContract_beforeTransferData_user__shareUnlockTime_before)), "beforeTransferData[user].denyTo@after == beforeTransferData[user].denyTo@before && beforeTransferData[user].denyOperator@after == beforeTransferData[user].denyOperator@before && beforeTransferData[user].permissionedOperator@after == beforeTransferData[user].permissionedOperator@before && beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before";
}

/*
 * user == address(0) => beforeTransferData[address(0)].denyFrom@after == true
 *
 * What it means: The denyFrom function must accept address(0) as a valid input and set the denyFrom flag to true for the zero address
 *
 * Why it should hold: There's no explicit validation preventing zero address in the function signature, and the mapping can store data for any address including zero. The function should handle all valid address inputs consistently
 *
 * Possible consequences: Inconsistent behavior and potential DoS if the function reverts on zero address when it shouldn't. Could break admin workflows or automated systems that might pass zero address
 */
rule denyFrom_2c524c42_zero_address_allowed(env e) {
    address user;

    // assign all the 'before' variables

    // call function under test
    denyFrom(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_0__denyFrom_after = currentContract.beforeTransferData[0].denyFrom;

    // verify integrity
    assert ((user == 0) => (currentContract_beforeTransferData_0__denyFrom_after == true)), "user == address(0) => beforeTransferData[address(0)].denyFrom@after == true";
}

/*
 * beforeTransferData[user].denyFrom@before == true => beforeTransferData[user].denyFrom@after == true
 *
 * What it means: If denyFrom is already true for a user, calling denyFrom again should maintain that true state (though the no-op revert property says this shouldn't happen)
 *
 * Why it should hold: This property ensures that even if the no-op revert fails, the state remains consistent. It's a safety net to prevent the denyFrom flag from being accidentally cleared
 *
 * Possible consequences: If this property fails along with no-op revert, repeated calls could flip the denyFrom flag back to false, accidentally re-enabling transfers for denied users
 */
rule denyFrom_2c524c42_idempotent_operation(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__denyFrom_before = currentContract.beforeTransferData[user].denyFrom;

    // call function under test
    denyFrom(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyFrom_after = currentContract.beforeTransferData[user].denyFrom;

    // verify integrity
    assert ((currentContract_beforeTransferData_user__denyFrom_before == true) => (currentContract_beforeTransferData_user__denyFrom_after == true)), "beforeTransferData[user].denyFrom@before == true => beforeTransferData[user].denyFrom@after == true";
}

/*
 * msg.sender != owner@before && authority@before == address(0) => revert
 *
 * What it means: The function must revert if called by someone who is not the owner and when no authority contract is set
 *
 * Why it should hold: The function has a requiresAuth modifier which enforces access control. Only authorized users (owner or authority) should be able to modify user permissions
 *
 * Possible consequences: Unauthorized privilege escalation where any user can remove transfer restrictions from any address, breaking the entire access control system
 */
rule allowFrom_a924bf61_unauthorized_reverts(env e) {
    address user;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    allowFrom@withrevert(e, user);
    bool allowFrom_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((e.msg.sender != currentContract_owner_before) && (currentContract_authority_before == 0)) => allowFrom_reverted), "msg.sender != owner@before && authority@before == address(0) => revert";
}

/*
 * user == address(0) => revert
 *
 * What it means: The function must revert when trying to allow transfers from the zero address
 *
 * Why it should hold: Zero address operations are typically meaningless and should be prevented to avoid confusion and potential bugs in the system
 *
 * Possible consequences: State corruption and wasted gas on meaningless operations that could mask real bugs or create unexpected behavior
 */
// gereon: might be useful, but probably not worth it
rule __allowFrom_a924bf61_zero_address_reverts(env e) {
    address user;

    // assign all the 'before' variables

    // call function under test
    allowFrom@withrevert(e, user);
    bool allowFrom_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((user == 0) => allowFrom_reverted), "user == address(0) => revert";
}

/*
 * msg.sender == owner@before || authority@before != address(0) => beforeTransferData[user].denyFrom@after == false
 *
 * What it means: When called by an authorized user, the function must set the denyFrom flag to false for the specified user
 *
 * Why it should hold: This is the core functionality of allowFrom - it should remove the transfer restriction by setting denyFrom to false
 *
 * Possible consequences: Function fails to perform its intended purpose, leaving users unable to transfer shares when they should be allowed to
 */
rule allowFrom_a924bf61_sets_denyFrom_false(env e) {
    address user;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    allowFrom(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyFrom_after = currentContract.beforeTransferData[user].denyFrom;

    // verify integrity
    assert (((e.msg.sender == currentContract_owner_before) || (currentContract_authority_before != 0)) => (currentContract_beforeTransferData_user__denyFrom_after == false)), "msg.sender == owner@before || authority@before != address(0) => beforeTransferData[user].denyFrom@after == false";
}

/*
 * msg.sender == owner@before || authority@before != address(0) => beforeTransferData[user].denyTo@after == beforeTransferData[user].denyTo@before
 *
 * What it means: The function must not modify the denyTo flag for the user - it should remain unchanged
 *
 * Why it should hold: allowFrom should only affect the user's ability to send transfers, not receive them. Other restrictions should remain intact
 *
 * Possible consequences: Unintended privilege escalation where users gain more permissions than intended, breaking fine-grained access control
 */
rule allowFrom_a924bf61_preserves_denyTo(env e) {
    address user;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    bool currentContract_beforeTransferData_user__denyTo_before = currentContract.beforeTransferData[user].denyTo;

    // call function under test
    allowFrom(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyTo_after = currentContract.beforeTransferData[user].denyTo;

    // verify integrity
    assert (((e.msg.sender == currentContract_owner_before) || (currentContract_authority_before != 0)) => (currentContract_beforeTransferData_user__denyTo_after == currentContract_beforeTransferData_user__denyTo_before)), "msg.sender == owner@before || authority@before != address(0) => beforeTransferData[user].denyTo@after == beforeTransferData[user].denyTo@before";
}

/*
 * msg.sender == owner@before || authority@before != address(0) => beforeTransferData[user].denyOperator@after == beforeTransferData[user].denyOperator@before
 *
 * What it means: The function must not modify the denyOperator flag for the user - it should remain unchanged
 *
 * Why it should hold: allowFrom should only affect the user's ability to send transfers directly, not their ability to act as an operator for others
 *
 * Possible consequences: Unintended privilege escalation where restricted operators gain the ability to transfer on behalf of others
 */
rule allowFrom_a924bf61_preserves_denyOperator(env e) {
    address user;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    bool currentContract_beforeTransferData_user__denyOperator_before = currentContract.beforeTransferData[user].denyOperator;

    // call function under test
    allowFrom(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyOperator_after = currentContract.beforeTransferData[user].denyOperator;

    // verify integrity
    assert (((e.msg.sender == currentContract_owner_before) || (currentContract_authority_before != 0)) => (currentContract_beforeTransferData_user__denyOperator_after == currentContract_beforeTransferData_user__denyOperator_before)), "msg.sender == owner@before || authority@before != address(0) => beforeTransferData[user].denyOperator@after == beforeTransferData[user].denyOperator@before";
}

/*
 * msg.sender == owner@before || authority@before != address(0) => beforeTransferData[user].permissionedOperator@after == beforeTransferData[user].permissionedOperator@before
 *
 * What it means: The function must not modify the permissionedOperator flag for the user - it should remain unchanged
 *
 * Why it should hold: allowFrom should only affect basic transfer restrictions, not special operator permissions which are managed separately
 *
 * Possible consequences: Unintended modification of operator permissions could break the permissioned transfer system
 */
rule allowFrom_a924bf61_preserves_permissionedOperator(env e) {
    address user;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    bool currentContract_beforeTransferData_user__permissionedOperator_before = currentContract.beforeTransferData[user].permissionedOperator;

    // call function under test
    allowFrom(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__permissionedOperator_after = currentContract.beforeTransferData[user].permissionedOperator;

    // verify integrity
    assert (((e.msg.sender == currentContract_owner_before) || (currentContract_authority_before != 0)) => (currentContract_beforeTransferData_user__permissionedOperator_after == currentContract_beforeTransferData_user__permissionedOperator_before)), "msg.sender == owner@before || authority@before != address(0) => beforeTransferData[user].permissionedOperator@after == beforeTransferData[user].permissionedOperator@before";
}

/*
 * msg.sender == owner@before || authority@before != address(0) => beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before
 *
 * What it means: The function must not modify the shareUnlockTime for the user - it should remain unchanged
 *
 * Why it should hold: allowFrom should only affect permanent deny/allow status, not time-based locks which have separate logic and purposes
 *
 * Possible consequences: Bypassing time-based security mechanisms like share lock periods after deposits
 */
rule allowFrom_a924bf61_preserves_shareUnlockTime(env e) {
    address user;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_before = currentContract.beforeTransferData[user].shareUnlockTime;

    // call function under test
    allowFrom(e, user);

    // assign all the 'after' variables
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_after = currentContract.beforeTransferData[user].shareUnlockTime;

    // verify integrity
    assert (((e.msg.sender == currentContract_owner_before) || (currentContract_authority_before != 0)) => (currentContract_beforeTransferData_user__shareUnlockTime_after == currentContract_beforeTransferData_user__shareUnlockTime_before)), "msg.sender == owner@before || authority@before != address(0) => beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before";
}

/*
 * (msg.sender == owner@before || authority@before != address(0)) && beforeTransferData[user].denyFrom@before == false => revert
 *
 * What it means: The function must revert if called by an authorized user when the user's denyFrom flag is already false
 *
 * Why it should hold: No-op operations should revert to prevent wasted gas and indicate that the operation is meaningless
 *
 * Possible consequences: Wasted gas costs and potential masking of logic errors where the caller thinks they're changing state but aren't
 */
// gereon: not sure if this simple function warrants a no-op check
rule __allowFrom_a924bf61_no_op_reverts(env e) {
    address user;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    bool currentContract_beforeTransferData_user__denyFrom_before = currentContract.beforeTransferData[user].denyFrom;

    // call function under test
    allowFrom@withrevert(e, user);
    bool allowFrom_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((((e.msg.sender == currentContract_owner_before) || (currentContract_authority_before != 0)) && (currentContract_beforeTransferData_user__denyFrom_before == false)) => allowFrom_reverted), "(msg.sender == owner@before || authority@before != address(0)) && beforeTransferData[user].denyFrom@before == false => revert";
}

/*
 * (msg.sender == owner@before || authority@before != address(0)) && otherUser != user => beforeTransferData[otherUser].denyFrom@after == beforeTransferData[otherUser].denyFrom@before
 *
 * What it means: The function must not modify the denyFrom flag for any user other than the one specified in the parameter
 *
 * Why it should hold: The function should have precise targeting - only affecting the specified user to prevent unintended side effects
 *
 * Possible consequences: Mass privilege escalation where multiple users gain transfer rights unintentionally
 */
rule allowFrom_a924bf61_other_users_unchanged(env e) {
    address user;
    address otherUser;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    bool currentContract_beforeTransferData_otherUser__denyFrom_before = currentContract.beforeTransferData[otherUser].denyFrom;

    // call function under test
    allowFrom(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_otherUser__denyFrom_after = currentContract.beforeTransferData[otherUser].denyFrom;

    // verify integrity
    assert ((((e.msg.sender == currentContract_owner_before) || (currentContract_authority_before != 0)) && (otherUser != user)) => (currentContract_beforeTransferData_otherUser__denyFrom_after == currentContract_beforeTransferData_otherUser__denyFrom_before)), "(msg.sender == owner@before || authority@before != address(0)) && otherUser != user => beforeTransferData[otherUser].denyFrom@after == beforeTransferData[otherUser].denyFrom@before";
}

/*
 * (msg.sender == owner@before || authority@before != address(0)) && otherUser != user => beforeTransferData[otherUser].denyTo@after == beforeTransferData[otherUser].denyTo@before && beforeTransferData[otherUser].denyOperator@after == beforeTransferData[otherUser].denyOperator@before
 *
 * What it means: The function must not modify the denyTo or denyOperator flags for any user other than the one specified
 *
 * Why it should hold: The function should have surgical precision, only affecting the intended user and only the intended field
 *
 * Possible consequences: Widespread privilege escalation affecting multiple users and multiple permission types
 */
rule allowFrom_a924bf61_preserves_other_user_data(env e) {
    address user;
    address otherUser;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    bool currentContract_beforeTransferData_otherUser__denyTo_before = currentContract.beforeTransferData[otherUser].denyTo;
    bool currentContract_beforeTransferData_otherUser__denyOperator_before = currentContract.beforeTransferData[otherUser].denyOperator;

    // call function under test
    allowFrom(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_otherUser__denyTo_after = currentContract.beforeTransferData[otherUser].denyTo;
    bool currentContract_beforeTransferData_otherUser__denyOperator_after = currentContract.beforeTransferData[otherUser].denyOperator;

    // verify integrity
    assert ((((e.msg.sender == currentContract_owner_before) || (currentContract_authority_before != 0)) && (otherUser != user)) => ((currentContract_beforeTransferData_otherUser__denyTo_after == currentContract_beforeTransferData_otherUser__denyTo_before) && (currentContract_beforeTransferData_otherUser__denyOperator_after == currentContract_beforeTransferData_otherUser__denyOperator_before))), "(msg.sender == owner@before || authority@before != address(0)) && otherUser != user => beforeTransferData[otherUser].denyTo@after == beforeTransferData[otherUser].denyTo@before && beforeTransferData[otherUser].denyOperator@after == beforeTransferData[otherUser].denyOperator@before";
}

/*
 * msg.sender == owner@before || authority@before != address(0) => isPaused@after == isPaused@before && permissionedTransfers@after == permissionedTransfers@before && depositCap@after == depositCap@before && shareLockPeriod@after == shareLockPeriod@before && depositNonce@after == depositNonce@before
 *
 * What it means: The function must not modify any global contract state like pause status, deposit caps, or other system-wide settings
 *
 * Why it should hold: allowFrom is a user-specific permission function and should not affect global contract parameters
 *
 * Possible consequences: Unintended system-wide changes that could break core contract functionality or security mechanisms
 */
rule allowFrom_a924bf61_preserves_global_state(env e) {
    address user;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_permissionedTransfers_before = currentContract.permissionedTransfers;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;

    // call function under test
    allowFrom(e, user);

    // assign all the 'after' variables
    bool currentContract_isPaused_after = currentContract.isPaused;
    bool currentContract_permissionedTransfers_after = currentContract.permissionedTransfers;
    uint112 currentContract_depositCap_after = currentContract.depositCap;
    uint64 currentContract_shareLockPeriod_after = currentContract.shareLockPeriod;
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;

    // verify integrity
    assert (((e.msg.sender == currentContract_owner_before) || (currentContract_authority_before != 0)) => (((((currentContract_isPaused_after == currentContract_isPaused_before) && (currentContract_permissionedTransfers_after == currentContract_permissionedTransfers_before)) && (currentContract_depositCap_after == currentContract_depositCap_before)) && (currentContract_shareLockPeriod_after == currentContract_shareLockPeriod_before)) && (currentContract_depositNonce_after == currentContract_depositNonce_before))), "msg.sender == owner@before || authority@before != address(0) => isPaused@after == isPaused@before && permissionedTransfers@after == permissionedTransfers@before && depositCap@after == depositCap@before && shareLockPeriod@after == shareLockPeriod@before && depositNonce@after == depositNonce@before";
}

/*
 * beforeTransferData[user].denyTo@after == true
 *
 * What it means: After a successful call to denyTo, the denyTo flag for the specified user must be set to true in their beforeTransferData
 *
 * Why it should hold: This is the core functionality of the denyTo function - it must actually deny the user from receiving shares by setting the flag. Without this, the function would be a no-op that doesn't achieve its intended purpose
 *
 * Possible consequences: Users who should be denied from receiving shares could still receive them, bypassing access controls and potentially allowing sanctioned or malicious actors to hold vault shares
 */
rule denyTo_3b575407_sets_deny_to_true(env e) {
    address user;

    // assign all the 'before' variables

    // call function under test
    denyTo(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyTo_after = currentContract.beforeTransferData[user].denyTo;

    // verify integrity
    assert (currentContract_beforeTransferData_user__denyTo_after == true), "beforeTransferData[user].denyTo@after == true";
}

/*
 * beforeTransferData[user].denyFrom@after == beforeTransferData[user].denyFrom@before
 *
 * What it means: The denyFrom flag for the user should remain unchanged when calling denyTo - only the denyTo flag should be modified
 *
 * Why it should hold: denyTo should only affect the user's ability to receive shares, not their ability to send shares. These are independent access controls that should be managed separately
 *
 * Possible consequences: Unintended modification of transfer permissions could either grant unexpected privileges or impose unintended restrictions on users
 */
rule denyTo_3b575407_preserves_deny_from(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__denyFrom_before = currentContract.beforeTransferData[user].denyFrom;

    // call function under test
    denyTo(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyFrom_after = currentContract.beforeTransferData[user].denyFrom;

    // verify integrity
    assert (currentContract_beforeTransferData_user__denyFrom_after == currentContract_beforeTransferData_user__denyFrom_before), "beforeTransferData[user].denyFrom@after == beforeTransferData[user].denyFrom@before";
}

/*
 * beforeTransferData[user].denyOperator@after == beforeTransferData[user].denyOperator@before
 *
 * What it means: The denyOperator flag for the user should remain unchanged when calling denyTo - only the denyTo flag should be modified
 *
 * Why it should hold: denyTo should only affect the user's ability to receive shares, not their ability to operate on behalf of others. These are independent access controls
 *
 * Possible consequences: Unintended modification of operator permissions could disrupt legitimate operator functionality or grant unexpected operator privileges
 */
rule denyTo_3b575407_preserves_deny_operator(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__denyOperator_before = currentContract.beforeTransferData[user].denyOperator;

    // call function under test
    denyTo(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyOperator_after = currentContract.beforeTransferData[user].denyOperator;

    // verify integrity
    assert (currentContract_beforeTransferData_user__denyOperator_after == currentContract_beforeTransferData_user__denyOperator_before), "beforeTransferData[user].denyOperator@after == beforeTransferData[user].denyOperator@before";
}

/*
 * beforeTransferData[user].permissionedOperator@after == beforeTransferData[user].permissionedOperator@before
 *
 * What it means: The permissionedOperator flag for the user should remain unchanged when calling denyTo - only the denyTo flag should be modified
 *
 * Why it should hold: denyTo should only affect receiving shares, not permissioned operator status. These are separate authorization mechanisms that should be managed independently
 *
 * Possible consequences: Unintended modification of permissioned operator status could break transfer functionality when permissionedTransfers is enabled
 */
rule denyTo_3b575407_preserves_permissioned_operator(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__permissionedOperator_before = currentContract.beforeTransferData[user].permissionedOperator;

    // call function under test
    denyTo(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__permissionedOperator_after = currentContract.beforeTransferData[user].permissionedOperator;

    // verify integrity
    assert (currentContract_beforeTransferData_user__permissionedOperator_after == currentContract_beforeTransferData_user__permissionedOperator_before), "beforeTransferData[user].permissionedOperator@after == beforeTransferData[user].permissionedOperator@before";
}

/*
 * beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before
 *
 * What it means: The shareUnlockTime for the user should remain unchanged when calling denyTo - only the denyTo flag should be modified
 *
 * Why it should hold: denyTo should only affect receiving permissions, not the timing of when existing shares become unlocked. Share lock timing is managed by deposit functions
 *
 * Possible consequences: Unintended modification of unlock times could either prematurely unlock shares or extend lock periods beyond what users agreed to
 */
rule denyTo_3b575407_preserves_share_unlock_time(env e) {
    address user;

    // assign all the 'before' variables
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_before = currentContract.beforeTransferData[user].shareUnlockTime;

    // call function under test
    denyTo(e, user);

    // assign all the 'after' variables
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_after = currentContract.beforeTransferData[user].shareUnlockTime;

    // verify integrity
    assert (currentContract_beforeTransferData_user__shareUnlockTime_after == currentContract_beforeTransferData_user__shareUnlockTime_before), "beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before";
}

/*
 * beforeTransferData[user].denyTo@before == true => revert
 *
 * What it means: If the user is already denied from receiving shares (denyTo=true), calling denyTo again should revert rather than succeed as a no-op
 *
 * Why it should hold: No-op operations should revert to prevent wasted gas and indicate to callers that the operation was meaningless. This follows the principle that operations should either change state or fail
 *
 * Possible consequences: Wasted gas costs and potential confusion about whether the operation succeeded in changing state
 */
// gereon: not sure if this simple function warrants a no-op check
rule __denyTo_3b575407_no_op_reverts(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__denyTo_before = currentContract.beforeTransferData[user].denyTo;

    // call function under test
    denyTo@withrevert(e, user);
    bool denyTo_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_beforeTransferData_user__denyTo_before == true) => denyTo_reverted), "beforeTransferData[user].denyTo@before == true => revert";
}

/*
 * other != user => beforeTransferData[other].denyTo@after == beforeTransferData[other].denyTo@before
 *
 * What it means: Calling denyTo for one user should not affect the denyTo status of any other users - the change should be isolated to the specified user
 *
 * Why it should hold: Access control changes should be precise and only affect the intended target. Modifying other users' permissions would be a serious bug
 *
 * Possible consequences: Unintended modification of other users' permissions could lead to widespread access control failures, affecting multiple users simultaneously
 */
rule denyTo_3b575407_preserves_other_users(env e) {
    address user;
    address other;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_other__denyTo_before = currentContract.beforeTransferData[other].denyTo;

    // call function under test
    denyTo(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_other__denyTo_after = currentContract.beforeTransferData[other].denyTo;

    // verify integrity
    assert ((other != user) => (currentContract_beforeTransferData_other__denyTo_after == currentContract_beforeTransferData_other__denyTo_before)), "other != user => beforeTransferData[other].denyTo@after == beforeTransferData[other].denyTo@before";
}

/*
 * owner@after == owner@before && authority@after == authority@before && depositNonce@after == depositNonce@before && shareLockPeriod@after == shareLockPeriod@before && isPaused@after == isPaused@before && permissionedTransfers@after == permissionedTransfers@before && depositCap@after == depositCap@before
 *
 * What it means: Core contract state variables (owner, authority, depositNonce, shareLockPeriod, isPaused, permissionedTransfers, depositCap) should remain unchanged when calling denyTo
 *
 * Why it should hold: denyTo should only modify user-specific access controls, not global contract configuration. These variables control fundamental contract behavior
 *
 * Possible consequences: Unintended modification of core state could break contract functionality, change security parameters, or disrupt operations
 */
rule denyTo_3b575407_preserves_all_storage(env e) {
    address user;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_permissionedTransfers_before = currentContract.permissionedTransfers;
    uint112 currentContract_depositCap_before = currentContract.depositCap;

    // call function under test
    denyTo(e, user);

    // assign all the 'after' variables
    address currentContract_owner_after = currentContract.owner;
    address currentContract_authority_after = currentContract.authority;
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;
    uint64 currentContract_shareLockPeriod_after = currentContract.shareLockPeriod;
    bool currentContract_isPaused_after = currentContract.isPaused;
    bool currentContract_permissionedTransfers_after = currentContract.permissionedTransfers;
    uint112 currentContract_depositCap_after = currentContract.depositCap;

    // verify integrity
    assert (((((((currentContract_owner_after == currentContract_owner_before) && (currentContract_authority_after == currentContract_authority_before)) && (currentContract_depositNonce_after == currentContract_depositNonce_before)) && (currentContract_shareLockPeriod_after == currentContract_shareLockPeriod_before)) && (currentContract_isPaused_after == currentContract_isPaused_before)) && (currentContract_permissionedTransfers_after == currentContract_permissionedTransfers_before)) && (currentContract_depositCap_after == currentContract_depositCap_before)), "owner@after == owner@before && authority@after == authority@before && depositNonce@after == depositNonce@before && shareLockPeriod@after == shareLockPeriod@before && isPaused@after == isPaused@before && permissionedTransfers@after == permissionedTransfers@before && depositCap@after == depositCap@before";
}

/*
 * publicDepositHistory[nonce]@after == publicDepositHistory[nonce]@before
 *
 * What it means: The publicDepositHistory mapping should remain unchanged when calling denyTo - historical deposit records should not be modified
 *
 * Why it should hold: denyTo is an access control function that should not affect historical records. Deposit history is used for refund functionality and audit trails
 *
 * Possible consequences: Corruption of deposit history could prevent legitimate refunds or create audit trail inconsistencies
 */
rule denyTo_3b575407_preserves_deposit_history(env e) {
    address user;
    uint256 nonce;

    // assign all the 'before' variables
    bytes32 currentContract_publicDepositHistory_nonce__before = currentContract.publicDepositHistory[nonce];

    // call function under test
    denyTo(e, user);

    // assign all the 'after' variables
    bytes32 currentContract_publicDepositHistory_nonce__after = currentContract.publicDepositHistory[nonce];

    // verify integrity
    assert (currentContract_publicDepositHistory_nonce__after == currentContract_publicDepositHistory_nonce__before), "publicDepositHistory[nonce]@after == publicDepositHistory[nonce]@before";
}

/*
 * locked@after == locked@before
 *
 * What it means: The reentrancy guard locked state should remain unchanged when calling denyTo
 *
 * Why it should hold: denyTo should not affect the reentrancy protection mechanism. The locked state is managed by the ReentrancyGuard modifier
 *
 * Possible consequences: Unintended modification of reentrancy state could break reentrancy protection or cause functions to become permanently locked
 */
rule denyTo_3b575407_preserves_locked_state(env e) {
    address user;

    // assign all the 'before' variables
    uint256 currentContract_locked_before = currentContract.locked;

    // call function under test
    denyTo(e, user);

    // assign all the 'after' variables
    uint256 currentContract_locked_after = currentContract.locked;

    // verify integrity
    assert (currentContract_locked_after == currentContract_locked_before), "locked@after == locked@before";
}

/*
 * assetData[asset].allowDeposits@after == assetData[asset].allowDeposits@before
 *
 * What it means: The allowDeposits flag for all assets should remain unchanged when calling denyTo
 *
 * Why it should hold: denyTo is a user access control function and should not affect asset configuration. Asset deposit permissions are managed separately
 *
 * Possible consequences: Unintended modification of asset permissions could block or enable deposits for assets inappropriately
 */
rule denyTo_3b575407_preserves_asset_deposits(env e) {
    address user;
    address asset;

    // assign all the 'before' variables
    bool currentContract_assetData_asset__allowDeposits_before = currentContract.assetData[asset].allowDeposits;

    // call function under test
    denyTo(e, user);

    // assign all the 'after' variables
    bool currentContract_assetData_asset__allowDeposits_after = currentContract.assetData[asset].allowDeposits;

    // verify integrity
    assert (currentContract_assetData_asset__allowDeposits_after == currentContract_assetData_asset__allowDeposits_before), "assetData[asset].allowDeposits@after == assetData[asset].allowDeposits@before";
}

/*
 * assetData[asset].allowWithdraws@after == assetData[asset].allowWithdraws@before
 *
 * What it means: The allowWithdraws flag for all assets should remain unchanged when calling denyTo
 *
 * Why it should hold: denyTo is a user access control function and should not affect asset configuration. Asset withdrawal permissions are managed separately
 *
 * Possible consequences: Unintended modification of withdrawal permissions could block or enable withdrawals inappropriately
 */
rule denyTo_3b575407_preserves_asset_withdraws(env e) {
    address user;
    address asset;

    // assign all the 'before' variables
    bool currentContract_assetData_asset__allowWithdraws_before = currentContract.assetData[asset].allowWithdraws;

    // call function under test
    denyTo(e, user);

    // assign all the 'after' variables
    bool currentContract_assetData_asset__allowWithdraws_after = currentContract.assetData[asset].allowWithdraws;

    // verify integrity
    assert (currentContract_assetData_asset__allowWithdraws_after == currentContract_assetData_asset__allowWithdraws_before), "assetData[asset].allowWithdraws@after == assetData[asset].allowWithdraws@before";
}

/*
 * assetData[asset].sharePremium@after == assetData[asset].sharePremium@before
 *
 * What it means: The sharePremium for all assets should remain unchanged when calling denyTo
 *
 * Why it should hold: denyTo is a user access control function and should not affect asset pricing configuration. Share premiums determine deposit economics
 *
 * Possible consequences: Unintended modification of share premiums could change deposit economics, affecting user returns and protocol revenue
 */
rule denyTo_3b575407_preserves_share_premium(env e) {
    address user;
    address asset;

    // assign all the 'before' variables
    uint16 currentContract_assetData_asset__sharePremium_before = currentContract.assetData[asset].sharePremium;

    // call function under test
    denyTo(e, user);

    // assign all the 'after' variables
    uint16 currentContract_assetData_asset__sharePremium_after = currentContract.assetData[asset].sharePremium;

    // verify integrity
    assert (currentContract_assetData_asset__sharePremium_after == currentContract_assetData_asset__sharePremium_before), "assetData[asset].sharePremium@after == assetData[asset].sharePremium@before";
}

/*
 * beforeTransferData[user].denyTo@before == false => revert
 *
 * What it means: If a user is already allowed to receive shares (denyTo is false), calling allowTo on that user must revert
 *
 * Why it should hold: The function should only perform meaningful state changes. If denyTo is already false, the function would do nothing meaningful and should revert to prevent wasted gas and indicate the operation is unnecessary
 *
 * Possible consequences: Gas waste, unclear contract state, potential for griefing attacks where users repeatedly call functions that do nothing, and violation of the principle that no-op operations should fail
 */
rule allowTo_5f45bac8_no_op_reverts(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__denyTo_before = currentContract.beforeTransferData[user].denyTo;

    // call function under test
    allowTo@withrevert(e, user);
    bool allowTo_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_beforeTransferData_user__denyTo_before == false) => allowTo_reverted), "beforeTransferData[user].denyTo@before == false => revert";
}

/*
 * beforeTransferData[user].denyTo@before == true => beforeTransferData[user].denyTo@after == false
 *
 * What it means: When called on a user who is currently denied from receiving shares (denyTo is true), the function must set their denyTo flag to false
 *
 * Why it should hold: This is the core functionality of allowTo - it should enable users to receive shares by clearing the denial flag. This is essential for the access control system to work properly
 *
 * Possible consequences: Complete failure of the access control system, users permanently unable to receive shares even when they should be allowed, breaking the fundamental permission management functionality
 */
rule allowTo_5f45bac8_sets_denyTo_false(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__denyTo_before = currentContract.beforeTransferData[user].denyTo;

    // call function under test
    allowTo(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyTo_after = currentContract.beforeTransferData[user].denyTo;

    // verify integrity
    assert ((currentContract_beforeTransferData_user__denyTo_before == true) => (currentContract_beforeTransferData_user__denyTo_after == false)), "beforeTransferData[user].denyTo@before == true => beforeTransferData[user].denyTo@after == false";
}

/*
 * beforeTransferData[user].denyFrom@after == beforeTransferData[user].denyFrom@before && beforeTransferData[user].denyOperator@after == beforeTransferData[user].denyOperator@before && beforeTransferData[user].permissionedOperator@after == beforeTransferData[user].permissionedOperator@before && beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before
 *
 * What it means: The allowTo function must only modify the denyTo field and leave all other fields in the user's BeforeTransferData struct unchanged (denyFrom, denyOperator, permissionedOperator, shareUnlockTime)
 *
 * Why it should hold: The function should have surgical precision - it should only change what it's supposed to change. Modifying other fields would be a serious bug that could corrupt the user's permission state
 *
 * Possible consequences: Corruption of user permission state, unintended privilege escalation or denial, breaking of share lock mechanisms, and complete compromise of the access control system
 */
rule allowTo_5f45bac8_preserves_other_fields(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__denyFrom_before = currentContract.beforeTransferData[user].denyFrom;
    bool currentContract_beforeTransferData_user__denyOperator_before = currentContract.beforeTransferData[user].denyOperator;
    bool currentContract_beforeTransferData_user__permissionedOperator_before = currentContract.beforeTransferData[user].permissionedOperator;
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_before = currentContract.beforeTransferData[user].shareUnlockTime;

    // call function under test
    allowTo(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyFrom_after = currentContract.beforeTransferData[user].denyFrom;
    bool currentContract_beforeTransferData_user__denyOperator_after = currentContract.beforeTransferData[user].denyOperator;
    bool currentContract_beforeTransferData_user__permissionedOperator_after = currentContract.beforeTransferData[user].permissionedOperator;
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_after = currentContract.beforeTransferData[user].shareUnlockTime;

    // verify integrity
    assert ((((currentContract_beforeTransferData_user__denyFrom_after == currentContract_beforeTransferData_user__denyFrom_before) && (currentContract_beforeTransferData_user__denyOperator_after == currentContract_beforeTransferData_user__denyOperator_before)) && (currentContract_beforeTransferData_user__permissionedOperator_after == currentContract_beforeTransferData_user__permissionedOperator_before)) && (currentContract_beforeTransferData_user__shareUnlockTime_after == currentContract_beforeTransferData_user__shareUnlockTime_before)), "beforeTransferData[user].denyFrom@after == beforeTransferData[user].denyFrom@before && beforeTransferData[user].denyOperator@after == beforeTransferData[user].denyOperator@before && beforeTransferData[user].permissionedOperator@after == beforeTransferData[user].permissionedOperator@before && beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before";
}

/*
 * otherUser != user => beforeTransferData[otherUser].denyTo@after == beforeTransferData[otherUser].denyTo@before
 *
 * What it means: The allowTo function must only affect the specified user and not modify the denyTo status of any other users in the system
 *
 * Why it should hold: The function takes a specific user parameter and should only affect that user. Affecting other users would be a critical bug that could cause widespread permission corruption
 *
 * Possible consequences: Mass permission corruption, unintended privilege changes for multiple users, potential for widespread access control bypass, and system-wide security compromise
 */
rule allowTo_5f45bac8_no_other_users_affected(env e) {
    address user;
    address otherUser;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_otherUser__denyTo_before = currentContract.beforeTransferData[otherUser].denyTo;

    // call function under test
    allowTo(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_otherUser__denyTo_after = currentContract.beforeTransferData[otherUser].denyTo;

    // verify integrity
    assert ((otherUser != user) => (currentContract_beforeTransferData_otherUser__denyTo_after == currentContract_beforeTransferData_otherUser__denyTo_before)), "otherUser != user => beforeTransferData[otherUser].denyTo@after == beforeTransferData[otherUser].denyTo@before";
}

/*
 * owner@after == owner@before && authority@after == authority@before && depositNonce@after == depositNonce@before && shareLockPeriod@after == shareLockPeriod@before && isPaused@after == isPaused@before && permissionedTransfers@after == permissionedTransfers@before && depositCap@after == depositCap@before
 *
 * What it means: The allowTo function must not modify any global contract state variables like owner, authority, depositNonce, shareLockPeriod, isPaused, permissionedTransfers, or depositCap
 *
 * Why it should hold: This function is specifically for managing individual user permissions and should not affect global contract configuration. Modifying global state would be a severe bug that could compromise the entire contract
 *
 * Possible consequences: Complete contract compromise, unauthorized changes to critical parameters, potential for contract takeover, disruption of deposit/withdrawal functionality, and system-wide security failures
 */
rule allowTo_5f45bac8_no_global_state_changes(env e) {
    address user;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_permissionedTransfers_before = currentContract.permissionedTransfers;
    uint112 currentContract_depositCap_before = currentContract.depositCap;

    // call function under test
    allowTo(e, user);

    // assign all the 'after' variables
    address currentContract_owner_after = currentContract.owner;
    address currentContract_authority_after = currentContract.authority;
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;
    uint64 currentContract_shareLockPeriod_after = currentContract.shareLockPeriod;
    bool currentContract_isPaused_after = currentContract.isPaused;
    bool currentContract_permissionedTransfers_after = currentContract.permissionedTransfers;
    uint112 currentContract_depositCap_after = currentContract.depositCap;

    // verify integrity
    assert (((((((currentContract_owner_after == currentContract_owner_before) && (currentContract_authority_after == currentContract_authority_before)) && (currentContract_depositNonce_after == currentContract_depositNonce_before)) && (currentContract_shareLockPeriod_after == currentContract_shareLockPeriod_before)) && (currentContract_isPaused_after == currentContract_isPaused_before)) && (currentContract_permissionedTransfers_after == currentContract_permissionedTransfers_before)) && (currentContract_depositCap_after == currentContract_depositCap_before)), "owner@after == owner@before && authority@after == authority@before && depositNonce@after == depositNonce@before && shareLockPeriod@after == shareLockPeriod@before && isPaused@after == isPaused@before && permissionedTransfers@after == permissionedTransfers@before && depositCap@after == depositCap@before";
}

/*
 * user == address(0) => beforeTransferData[address(0)].denyOperator@after == true
 *
 * What it means: When the user parameter is the zero address, the denyOperator flag for the zero address must be set to true after the function executes
 *
 * Why it should hold: The function should consistently deny operator privileges regardless of the input address, including edge cases like the zero address. This ensures complete coverage of the deny functionality
 *
 * Possible consequences: If the zero address is not properly denied, it could lead to unexpected transfer behaviors or bypass security checks when the zero address is involved in transfers
 */
rule denyOperator_1b62636c_zero_address_denied(env e) {
    address user;

    // assign all the 'before' variables

    // call function under test
    denyOperator(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_0__denyOperator_after = currentContract.beforeTransferData[0].denyOperator;

    // verify integrity
    assert ((user == 0) => (currentContract_beforeTransferData_0__denyOperator_after == true)), "user == address(0) => beforeTransferData[address(0)].denyOperator@after == true";
}

/*
 * user != address(0) => beforeTransferData[user].denyOperator@after == true
 *
 * What it means: For any non-zero address, the denyOperator flag in the beforeTransferData mapping must be set to true after the function executes
 *
 * Why it should hold: This is the core functionality of the denyOperator function - it must actually deny the specified operator from performing transfers by setting the appropriate flag
 *
 * Possible consequences: If this property fails, the function becomes a no-op and operators that should be denied would still be able to perform transfers, completely breaking the access control system
 */
rule denyOperator_1b62636c_deny_operator_set(env e) {
    address user;

    // assign all the 'before' variables

    // call function under test
    denyOperator(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyOperator_after = currentContract.beforeTransferData[user].denyOperator;

    // verify integrity
    assert ((user != 0) => (currentContract_beforeTransferData_user__denyOperator_after == true)), "user != address(0) => beforeTransferData[user].denyOperator@after == true";
}

/*
 * beforeTransferData[user].denyFrom@after == beforeTransferData[user].denyFrom@before && beforeTransferData[user].denyTo@after == beforeTransferData[user].denyTo@before
 *
 * What it means: The denyFrom and denyTo flags in the beforeTransferData struct for the user must remain unchanged after the function executes
 *
 * Why it should hold: The denyOperator function should only modify the denyOperator field and not interfere with other access control settings. This ensures surgical precision in access control modifications
 *
 * Possible consequences: If other fields are modified, it could lead to unintended access control changes, either granting unexpected permissions or imposing unintended restrictions
 */
rule denyOperator_1b62636c_other_fields_unchanged(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__denyFrom_before = currentContract.beforeTransferData[user].denyFrom;
    bool currentContract_beforeTransferData_user__denyTo_before = currentContract.beforeTransferData[user].denyTo;

    // call function under test
    denyOperator(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyFrom_after = currentContract.beforeTransferData[user].denyFrom;
    bool currentContract_beforeTransferData_user__denyTo_after = currentContract.beforeTransferData[user].denyTo;

    // verify integrity
    assert ((currentContract_beforeTransferData_user__denyFrom_after == currentContract_beforeTransferData_user__denyFrom_before) && (currentContract_beforeTransferData_user__denyTo_after == currentContract_beforeTransferData_user__denyTo_before)), "beforeTransferData[user].denyFrom@after == beforeTransferData[user].denyFrom@before && beforeTransferData[user].denyTo@after == beforeTransferData[user].denyTo@before";
}

/*
 * beforeTransferData[user].denyOperator@before == true => beforeTransferData[user].denyOperator@after == true
 *
 * What it means: If an operator is already denied (denyOperator flag is true), calling denyOperator again must keep the flag as true
 *
 * Why it should hold: This ensures idempotency of the deny operation and prevents any potential state corruption when the function is called multiple times on the same operator
 *
 * Possible consequences: If the flag could be toggled or reset, it could lead to inconsistent access control states and potential security vulnerabilities
 */
rule denyOperator_1b62636c_already_denied_stays_denied(env e) {
    address user;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_user__denyOperator_before = currentContract.beforeTransferData[user].denyOperator;

    // call function under test
    denyOperator(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyOperator_after = currentContract.beforeTransferData[user].denyOperator;

    // verify integrity
    assert ((currentContract_beforeTransferData_user__denyOperator_before == true) => (currentContract_beforeTransferData_user__denyOperator_after == true)), "beforeTransferData[user].denyOperator@before == true => beforeTransferData[user].denyOperator@after == true";
}

/*
 * beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before
 *
 * What it means: The shareUnlockTime field in the beforeTransferData struct must remain unchanged after the function executes
 *
 * Why it should hold: The denyOperator function should only affect operator permissions and not interfere with share lock timing mechanisms, which are separate security features
 *
 * Possible consequences: If share unlock times are modified, it could either prematurely unlock shares (allowing early transfers) or extend lock periods beyond intended durations, affecting user funds availability
 */
rule denyOperator_1b62636c_share_unlock_unchanged(env e) {
    address user;

    // assign all the 'before' variables
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_before = currentContract.beforeTransferData[user].shareUnlockTime;

    // call function under test
    denyOperator(e, user);

    // assign all the 'after' variables
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_after = currentContract.beforeTransferData[user].shareUnlockTime;

    // verify integrity
    assert (currentContract_beforeTransferData_user__shareUnlockTime_after == currentContract_beforeTransferData_user__shareUnlockTime_before), "beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before";
}

/*
 * msg.sender != owner@before && (authority@before == address(0) || !authority@before.canCall(msg.sender, address(this), msg.sig)) => revert
 *
 * What it means: The function must revert if called by someone who is not the owner and either has no authority contract set or the authority contract denies permission for this specific function call
 *
 * Why it should hold: This enforces the access control mechanism inherited from the Auth contract. The allowOperator function should only be callable by authorized roles (OWNER_ROLE and DENIER_ROLE according to the devdoc), so unauthorized users must be blocked
 *
 * Possible consequences: Unauthorized access control manipulation - attackers could allow themselves or others to bypass operator restrictions, potentially enabling unauthorized transfers of locked shares
 */
// gereon: the auth mechanism is more complex than the AI thinks
rule allowOperator_1ba9a458_unauthorized_reverts(env e) {
    address user;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    bool currentContract_authority_canCall_e__e_msg_sender__currentContract__to_bytes4_0x1ba9a458___before = currentContract.isAuthorizedHarness(e, e.msg.sender, to_bytes4(0x1ba9a458));

    // call function under test
    allowOperator@withrevert(e, user);
    bool allowOperator_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((e.msg.sender != currentContract_owner_before) && (!currentContract_authority_canCall_e__e_msg_sender__currentContract__to_bytes4_0x1ba9a458___before)) => allowOperator_reverted), "msg.sender != owner@before && (authority@before == address(0) || !authority@before.canCall(msg.sender, address(this), msg.sig)) => revert";
}

/*
 * user == address(0) => revert
 *
 * What it means: The function must revert when called with the zero address (0x0) as the user parameter
 *
 * Why it should hold: Setting permissions for the zero address is meaningless and likely indicates a programming error. The zero address is commonly used as a null value in Ethereum and should not have operator permissions
 *
 * Possible consequences: State corruption and potential DoS - allowing zero address operations could lead to unexpected behavior in transfer logic and waste gas on meaningless state changes
 */
rule allowOperator_1ba9a458_zero_address_reverts(env e) {
    address user;

    // assign all the 'before' variables

    // call function under test
    allowOperator@withrevert(e, user);
    bool allowOperator_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((user == 0) => allowOperator_reverted), "user == address(0) => revert";
}

/*
 * user != address(0) && (msg.sender == owner@before || (authority@before != address(0) && authority@before.canCall(msg.sender, address(this), msg.sig))) => beforeTransferData[user].denyOperator@after == false
 *
 * What it means: When called by an authorized user with a valid non-zero address, the function must set the denyOperator flag to false for that user in the beforeTransferData mapping
 *
 * Why it should hold: This is the core functionality of allowOperator - it should remove operator restrictions by setting denyOperator to false, allowing the user to act as an operator for share transfers
 *
 * Possible consequences: Broken access control - if the flag isn't properly set to false, users who should be allowed to operate will remain restricted, breaking the intended functionality
 */
rule allowOperator_1ba9a458_sets_denyOperator_false(env e) {
    address user;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    bool currentContract_authority_canCall_e__e_msg_sender__currentContract__to_bytes4_0x1ba9a458___before = currentContract.isAuthorizedHarness(e, e.msg.sender, to_bytes4(0x1ba9a458));

    // call function under test
    allowOperator(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyOperator_after = currentContract.beforeTransferData[user].denyOperator;

    // verify integrity
    assert (((user != 0) && ((e.msg.sender == currentContract_owner_before) || ((currentContract_authority_before != 0) && currentContract_authority_canCall_e__e_msg_sender__currentContract__to_bytes4_0x1ba9a458___before))) => (currentContract_beforeTransferData_user__denyOperator_after == false)), "user != address(0) && (msg.sender == owner@before || (authority@before != address(0) && authority@before.canCall(msg.sender, address(this), msg.sig))) => beforeTransferData[user].denyOperator@after == false";
}

/*
 * user != address(0) && (msg.sender == owner@before || (authority@before != address(0) && authority@before.canCall(msg.sender, address(this), msg.sig))) => beforeTransferData[user].denyFrom@after == beforeTransferData[user].denyFrom@before && beforeTransferData[user].denyTo@after == beforeTransferData[user].denyTo@before && beforeTransferData[user].permissionedOperator@after == beforeTransferData[user].permissionedOperator@before && beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before
 *
 * What it means: The function must only modify the denyOperator field and leave all other fields in the BeforeTransferData struct unchanged (denyFrom, denyTo, permissionedOperator, shareUnlockTime)
 *
 * Why it should hold: The function should have surgical precision - it should only change the specific permission it's designed to modify without affecting other unrelated permissions or user state
 *
 * Possible consequences: Unintended permission changes - modifying other fields could accidentally grant or revoke permissions the admin didn't intend to change, leading to security vulnerabilities
 */
rule allowOperator_1ba9a458_preserves_other_fields(env e) {
    address user;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    bool currentContract_authority_canCall_e__e_msg_sender__currentContract__to_bytes4_0x1ba9a458___before = currentContract.isAuthorizedHarness(e, e.msg.sender, to_bytes4(0x1ba9a458));
    bool currentContract_beforeTransferData_user__denyFrom_before = currentContract.beforeTransferData[user].denyFrom;
    bool currentContract_beforeTransferData_user__denyTo_before = currentContract.beforeTransferData[user].denyTo;
    bool currentContract_beforeTransferData_user__permissionedOperator_before = currentContract.beforeTransferData[user].permissionedOperator;
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_before = currentContract.beforeTransferData[user].shareUnlockTime;

    // call function under test
    allowOperator(e, user);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_user__denyFrom_after = currentContract.beforeTransferData[user].denyFrom;
    bool currentContract_beforeTransferData_user__denyTo_after = currentContract.beforeTransferData[user].denyTo;
    bool currentContract_beforeTransferData_user__permissionedOperator_after = currentContract.beforeTransferData[user].permissionedOperator;
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_after = currentContract.beforeTransferData[user].shareUnlockTime;

    // verify integrity
    assert (((user != 0) && ((e.msg.sender == currentContract_owner_before) || ((currentContract_authority_before != 0) && currentContract_authority_canCall_e__e_msg_sender__currentContract__to_bytes4_0x1ba9a458___before))) => ((((currentContract_beforeTransferData_user__denyFrom_after == currentContract_beforeTransferData_user__denyFrom_before) && (currentContract_beforeTransferData_user__denyTo_after == currentContract_beforeTransferData_user__denyTo_before)) && (currentContract_beforeTransferData_user__permissionedOperator_after == currentContract_beforeTransferData_user__permissionedOperator_before)) && (currentContract_beforeTransferData_user__shareUnlockTime_after == currentContract_beforeTransferData_user__shareUnlockTime_before))), "user != address(0) && (msg.sender == owner@before || (authority@before != address(0) && authority@before.canCall(msg.sender, address(this), msg.sig))) => beforeTransferData[user].denyFrom@after == beforeTransferData[user].denyFrom@before && beforeTransferData[user].denyTo@after == beforeTransferData[user].denyTo@before && beforeTransferData[user].permissionedOperator@after == beforeTransferData[user].permissionedOperator@before && beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before";
}

/*
 * user != address(0) && (msg.sender == owner@before || (authority@before != address(0) && authority@before.canCall(msg.sender, address(this), msg.sig))) && !beforeTransferData[user].denyOperator@before => revert
 *
 * What it means: If an authorized user calls the function on a user who already has denyOperator set to false, the function must revert rather than succeed with no changes
 *
 * Why it should hold: Following the NO-OPS MUST REVERT principle - operations that don't change state should fail to prevent wasted gas and indicate potential programming errors or misunderstanding of current state
 *
 * Possible consequences: Gas waste and unclear system state - allowing no-op operations makes it harder to detect bugs and wastes gas on meaningless transactions
 */
// gereon: not sure if this simple function warrants a no-op check
rule __allowOperator_1ba9a458_no_op_reverts(env e) {
    address user;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    bool currentContract_authority_canCall_e__e_msg_sender__currentContract__to_bytes4_0x1ba9a458___before = currentContract.isAuthorizedHarness(e, e.msg.sender, to_bytes4(0x1ba9a458));
    bool currentContract_beforeTransferData_user__denyOperator_before = currentContract.beforeTransferData[user].denyOperator;

    // call function under test
    allowOperator@withrevert(e, user);
    bool allowOperator_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((((user != 0) && ((e.msg.sender == currentContract_owner_before) || ((currentContract_authority_before != 0) && currentContract_authority_canCall_e__e_msg_sender__currentContract__to_bytes4_0x1ba9a458___before))) && !(currentContract_beforeTransferData_user__denyOperator_before)) => allowOperator_reverted), "user != address(0) && (msg.sender == owner@before || (authority@before != address(0) && authority@before.canCall(msg.sender, address(this), msg.sig))) && !beforeTransferData[user].denyOperator@before => revert";
}

/*
 * msg.sender != owner@before && authority@before == address(0) => revert
 *
 * What it means: The function must revert if called by someone who is not the owner and when no authority contract is set (authority is address(0))
 *
 * Why it should hold: This function has the requiresAuth modifier which enforces access control. Only authorized users (owner or those approved by authority contract) should be able to change the permissionedTransfers setting which controls transfer restrictions
 *
 * Possible consequences: Unauthorized access control bypass allowing attackers to modify critical transfer permissions, potentially enabling or disabling transfer restrictions without proper authorization
 */
rule setPermissionedTransfers_8a6733f9_unauthorized_reverts(env e) {
    bool _permissionedTransfers;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    setPermissionedTransfers@withrevert(e, _permissionedTransfers);
    bool setPermissionedTransfers_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((e.msg.sender != currentContract_owner_before) && (currentContract_authority_before == 0)) => setPermissionedTransfers_reverted), "msg.sender != owner@before && authority@before == address(0) => revert";
}

/*
 * msg.sender == owner@before || authority@before != address(0) => permissionedTransfers@after == _permissionedTransfers
 *
 * What it means: When called by an authorized user (owner or approved by authority), the function must update the permissionedTransfers state variable to match the input parameter _permissionedTransfers
 *
 * Why it should hold: This is the core functionality of the function - it should actually update the permissionedTransfers flag when called by authorized users. The function's purpose is to toggle this boolean state
 *
 * Possible consequences: Function becomes non-functional, unable to change transfer permission settings, leading to permanent lock-in of current transfer restrictions or inability to enforce new restrictions
 */
rule setPermissionedTransfers_8a6733f9_sets_permissioned_transfers(env e) {
    bool _permissionedTransfers;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    setPermissionedTransfers(e, _permissionedTransfers);

    // assign all the 'after' variables
    bool currentContract_permissionedTransfers_after = currentContract.permissionedTransfers;

    // verify integrity
    assert (((e.msg.sender == currentContract_owner_before) || (currentContract_authority_before != 0)) => (currentContract_permissionedTransfers_after == _permissionedTransfers)), "msg.sender == owner@before || authority@before != address(0) => permissionedTransfers@after == _permissionedTransfers";
}

/*
 * _permissionedTransfers == permissionedTransfers@before => revert
 *
 * What it means: The function must revert if the input parameter _permissionedTransfers is the same as the current value of permissionedTransfers, preventing no-operation calls
 *
 * Why it should hold: No-op operations waste gas and provide no meaningful state change. The function should reject calls that don't actually change anything, following the principle that meaningless operations should fail
 *
 * Possible consequences: Gas waste through meaningless transactions, potential griefing attacks where attackers spam no-op calls, and unclear system state where successful transactions don't indicate actual changes
 */
rule setPermissionedTransfers_8a6733f9_no_op_reverts(env e) {
    bool _permissionedTransfers;

    // assign all the 'before' variables
    bool currentContract_permissionedTransfers_before = currentContract.permissionedTransfers;

    // call function under test
    setPermissionedTransfers@withrevert(e, _permissionedTransfers);
    bool setPermissionedTransfers_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((_permissionedTransfers == currentContract_permissionedTransfers_before) => setPermissionedTransfers_reverted), "_permissionedTransfers == permissionedTransfers@before => revert";
}

/*
 * msg.sender == owner@before || authority@before != address(0) => owner@after == owner@before && authority@after == authority@before && locked@after == locked@before && depositNonce@after == depositNonce@before && shareLockPeriod@after == shareLockPeriod@before && isPaused@after == isPaused@before && depositCap@after == depositCap@before
 *
 * What it means: When called by authorized users, the function must only modify permissionedTransfers and leave all other state variables (owner, authority, locked, depositNonce, shareLockPeriod, isPaused, depositCap) unchanged
 *
 * Why it should hold: The function should have minimal side effects and only change what it's intended to change. Modifying unrelated state variables would indicate bugs or unexpected behavior that could corrupt the contract's state
 *
 * Possible consequences: State corruption where unrelated contract functionality is broken, potential security vulnerabilities if critical variables like owner or depositCap are modified, and unpredictable contract behavior
 */
rule setPermissionedTransfers_8a6733f9_other_state_unchanged(env e) {
    bool _permissionedTransfers;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    uint256 currentContract_locked_before = currentContract.locked;
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;
    bool currentContract_isPaused_before = currentContract.isPaused;
    uint112 currentContract_depositCap_before = currentContract.depositCap;

    // call function under test
    setPermissionedTransfers(e, _permissionedTransfers);

    // assign all the 'after' variables
    address currentContract_owner_after = currentContract.owner;
    address currentContract_authority_after = currentContract.authority;
    uint256 currentContract_locked_after = currentContract.locked;
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;
    uint64 currentContract_shareLockPeriod_after = currentContract.shareLockPeriod;
    bool currentContract_isPaused_after = currentContract.isPaused;
    uint112 currentContract_depositCap_after = currentContract.depositCap;

    // verify integrity
    assert (((e.msg.sender == currentContract_owner_before) || (currentContract_authority_before != 0)) => (((((((currentContract_owner_after == currentContract_owner_before) && (currentContract_authority_after == currentContract_authority_before)) && (currentContract_locked_after == currentContract_locked_before)) && (currentContract_depositNonce_after == currentContract_depositNonce_before)) && (currentContract_shareLockPeriod_after == currentContract_shareLockPeriod_before)) && (currentContract_isPaused_after == currentContract_isPaused_before)) && (currentContract_depositCap_after == currentContract_depositCap_before))), "msg.sender == owner@before || authority@before != address(0) => owner@after == owner@before && authority@after == authority@before && locked@after == locked@before && depositNonce@after == depositNonce@before && shareLockPeriod@after == shareLockPeriod@before && isPaused@after == isPaused@before && depositCap@after == depositCap@before";
}

/*
 * operator == address(0) => revert
 *
 * What it means: The function must revert when the operator parameter is the zero address (0x0)
 *
 * Why it should hold: Zero address is typically used as a null value in Ethereum and should not be granted operator permissions. The function should prevent meaningless operations by rejecting zero address inputs
 *
 * Possible consequences: State corruption where zero address gains operator privileges, potential bypass of access controls, and logical inconsistencies in permission checks
 */
rule allowPermissionedOperator_9ac4f42d_zero_address_reverts(env e) {
    address operator;

    // assign all the 'before' variables

    // call function under test
    allowPermissionedOperator@withrevert(e, operator);
    bool allowPermissionedOperator_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((operator == 0) => allowPermissionedOperator_reverted), "operator == address(0) => revert";
}

/*
 * operator != address(0) => beforeTransferData[operator].permissionedOperator@after == true
 *
 * What it means: When a valid non-zero operator address is provided, the function sets the permissionedOperator flag to true for that address in the beforeTransferData mapping
 *
 * Why it should hold: This is the core functionality of the function - to grant permission to an operator to transfer shares when permissionedTransfers is enabled. Based on the function name and similar functions like denyPermissionedOperator, this should be the primary state change
 *
 * Possible consequences: Complete failure of the permission system where operators cannot be granted privileges, breaking the permissioned transfer functionality
 */
rule allowPermissionedOperator_9ac4f42d_sets_permissioned_operator(env e) {
    address operator;

    // assign all the 'before' variables

    // call function under test
    allowPermissionedOperator(e, operator);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_operator__permissionedOperator_after = currentContract.beforeTransferData[operator].permissionedOperator;

    // verify integrity
    assert ((operator != 0) => (currentContract_beforeTransferData_operator__permissionedOperator_after == true)), "operator != address(0) => beforeTransferData[operator].permissionedOperator@after == true";
}

/*
 * operator != address(0) => beforeTransferData[operator].denyFrom@after == beforeTransferData[operator].denyFrom@before
 *
 * What it means: The function does not modify the denyFrom flag in the beforeTransferData struct for the operator address
 *
 * Why it should hold: The function should only modify the permissionedOperator field and not interfere with other access control flags. The denyFrom flag serves a different purpose (preventing transfers from an address) and should remain unchanged
 *
 * Possible consequences: Unintended privilege escalation or access control bypass where denied users suddenly gain transfer abilities
 */
rule allowPermissionedOperator_9ac4f42d_preserves_deny_from(env e) {
    address operator;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_operator__denyFrom_before = currentContract.beforeTransferData[operator].denyFrom;

    // call function under test
    allowPermissionedOperator(e, operator);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_operator__denyFrom_after = currentContract.beforeTransferData[operator].denyFrom;

    // verify integrity
    assert ((operator != 0) => (currentContract_beforeTransferData_operator__denyFrom_after == currentContract_beforeTransferData_operator__denyFrom_before)), "operator != address(0) => beforeTransferData[operator].denyFrom@after == beforeTransferData[operator].denyFrom@before";
}

/*
 * operator != address(0) => beforeTransferData[operator].denyTo@after == beforeTransferData[operator].denyTo@before
 *
 * What it means: The function does not modify the denyTo flag in the beforeTransferData struct for the operator address
 *
 * Why it should hold: Similar to denyFrom, the denyTo flag controls whether an address can receive shares and should not be affected by granting operator permissions. These are orthogonal access controls
 *
 * Possible consequences: Security bypass where addresses that should not receive shares can suddenly do so, violating compliance or security policies
 */
rule allowPermissionedOperator_9ac4f42d_preserves_deny_to(env e) {
    address operator;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_operator__denyTo_before = currentContract.beforeTransferData[operator].denyTo;

    // call function under test
    allowPermissionedOperator(e, operator);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_operator__denyTo_after = currentContract.beforeTransferData[operator].denyTo;

    // verify integrity
    assert ((operator != 0) => (currentContract_beforeTransferData_operator__denyTo_after == currentContract_beforeTransferData_operator__denyTo_before)), "operator != address(0) => beforeTransferData[operator].denyTo@after == beforeTransferData[operator].denyTo@before";
}

/*
 * operator != address(0) => beforeTransferData[operator].denyOperator@after == beforeTransferData[operator].denyOperator@before
 *
 * What it means: The function does not modify the denyOperator flag in the beforeTransferData struct for the operator address
 *
 * Why it should hold: The denyOperator flag prevents an address from acting as an operator in transfers. This is separate from permissionedOperator privileges and should not be modified when granting permissioned operator status
 *
 * Possible consequences: Conflicting access controls where an address is both denied and allowed as operator, leading to unpredictable behavior
 */
rule allowPermissionedOperator_9ac4f42d_preserves_deny_operator(env e) {
    address operator;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_operator__denyOperator_before = currentContract.beforeTransferData[operator].denyOperator;

    // call function under test
    allowPermissionedOperator(e, operator);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_operator__denyOperator_after = currentContract.beforeTransferData[operator].denyOperator;

    // verify integrity
    assert ((operator != 0) => (currentContract_beforeTransferData_operator__denyOperator_after == currentContract_beforeTransferData_operator__denyOperator_before)), "operator != address(0) => beforeTransferData[operator].denyOperator@after == beforeTransferData[operator].denyOperator@before";
}

/*
 * operator != address(0) => beforeTransferData[operator].shareUnlockTime@after == beforeTransferData[operator].shareUnlockTime@before
 *
 * What it means: The function does not modify the shareUnlockTime field in the beforeTransferData struct for the operator address
 *
 * Why it should hold: Share unlock time controls when shares become transferable after deposits and is unrelated to operator permissions. Modifying this could affect the share locking mechanism
 *
 * Possible consequences: Premature unlocking of shares, breaking the deposit refund mechanism and share lock period security
 */
rule allowPermissionedOperator_9ac4f42d_preserves_share_unlock_time(env e) {
    address operator;

    // assign all the 'before' variables
    uint256 currentContract_beforeTransferData_operator__shareUnlockTime_before = currentContract.beforeTransferData[operator].shareUnlockTime;

    // call function under test
    allowPermissionedOperator(e, operator);

    // assign all the 'after' variables
    uint256 currentContract_beforeTransferData_operator__shareUnlockTime_after = currentContract.beforeTransferData[operator].shareUnlockTime;

    // verify integrity
    assert ((operator != 0) => (currentContract_beforeTransferData_operator__shareUnlockTime_after == currentContract_beforeTransferData_operator__shareUnlockTime_before)), "operator != address(0) => beforeTransferData[operator].shareUnlockTime@after == beforeTransferData[operator].shareUnlockTime@before";
}

/*
 * operator != address(0) && other != operator => beforeTransferData[other].permissionedOperator@after == beforeTransferData[other].permissionedOperator@before
 *
 * What it means: The function only modifies the permissionedOperator flag for the specified operator address and does not affect the permissionedOperator status of any other addresses
 *
 * Why it should hold: The function should have surgical precision, only affecting the intended address. Modifying other addresses would be a serious bug indicating memory corruption or logic errors
 *
 * Possible consequences: Mass privilege escalation or revocation affecting multiple operators simultaneously, causing system-wide access control failures
 */
rule allowPermissionedOperator_9ac4f42d_other_operators_unchanged(env e) {
    address operator;
    address other;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_other__permissionedOperator_before = currentContract.beforeTransferData[other].permissionedOperator;

    // call function under test
    allowPermissionedOperator(e, operator);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_other__permissionedOperator_after = currentContract.beforeTransferData[other].permissionedOperator;

    // verify integrity
    assert (((operator != 0) && (other != operator)) => (currentContract_beforeTransferData_other__permissionedOperator_after == currentContract_beforeTransferData_other__permissionedOperator_before)), "operator != address(0) && other != operator => beforeTransferData[other].permissionedOperator@after == beforeTransferData[other].permissionedOperator@before";
}

/*
 * beforeTransferData[operator].permissionedOperator@after == false
 *
 * What it means: When the function executes successfully, it must set the permissionedOperator flag to false for the specified operator address
 *
 * Why it should hold: This is the core functionality of denyPermissionedOperator - it should revoke permission for an operator to transfer shares when permissionedTransfers is enabled. Based on the contract pattern and the corresponding allowPermissionedOperator function, this function must set the flag to false
 *
 * Possible consequences: If this property is violated, operators that should be denied permission could retain their ability to transfer shares, bypassing access controls and potentially allowing unauthorized transfers
 */
rule denyPermissionedOperator_bf671384_sets_permissioned_false(env e) {
    address operator;

    // assign all the 'before' variables

    // call function under test
    denyPermissionedOperator(e, operator);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_operator__permissionedOperator_after = currentContract.beforeTransferData[operator].permissionedOperator;

    // verify integrity
    assert (currentContract_beforeTransferData_operator__permissionedOperator_after == false), "beforeTransferData[operator].permissionedOperator@after == false";
}

/*
 * !beforeTransferData[operator].permissionedOperator@before => revert
 *
 * What it means: If the operator's permissionedOperator flag is already false before the function call, the function must revert instead of doing nothing
 *
 * Why it should hold: Following the NO-OPS MUST REVERT principle, attempting to deny permission for an operator that already lacks permission is a meaningless operation that should fail rather than succeed silently
 *
 * Possible consequences: If this property is violated, the function could succeed when it should fail, leading to confusion about the actual state and potentially masking bugs in calling code
 */
// gereon: not sure if this simple function warrants a no-op check
rule __denyPermissionedOperator_bf671384_no_op_reverts(env e) {
    address operator;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_operator__permissionedOperator_before = currentContract.beforeTransferData[operator].permissionedOperator;

    // call function under test
    denyPermissionedOperator@withrevert(e, operator);
    bool denyPermissionedOperator_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (!(currentContract_beforeTransferData_operator__permissionedOperator_before) => denyPermissionedOperator_reverted), "!beforeTransferData[operator].permissionedOperator@before => revert";
}

/*
 * beforeTransferData[operator].denyFrom@after == beforeTransferData[operator].denyFrom@before && beforeTransferData[operator].denyTo@after == beforeTransferData[operator].denyTo@before && beforeTransferData[operator].denyOperator@after == beforeTransferData[operator].denyOperator@before && beforeTransferData[operator].shareUnlockTime@after == beforeTransferData[operator].shareUnlockTime@before
 *
 * What it means: When the function executes, it must only modify the permissionedOperator field and leave all other fields in the BeforeTransferData struct unchanged (denyFrom, denyTo, denyOperator, shareUnlockTime)
 *
 * Why it should hold: The function should have surgical precision - it's specifically designed to modify only the permissionedOperator flag. Modifying other fields would be outside its intended scope and could cause unintended side effects
 *
 * Possible consequences: If this property is violated, the function could accidentally modify other access control flags or share lock times, leading to unintended permission changes or share unlock behavior
 */
rule denyPermissionedOperator_bf671384_other_fields_unchanged(env e) {
    address operator;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_operator__denyFrom_before = currentContract.beforeTransferData[operator].denyFrom;
    bool currentContract_beforeTransferData_operator__denyTo_before = currentContract.beforeTransferData[operator].denyTo;
    bool currentContract_beforeTransferData_operator__denyOperator_before = currentContract.beforeTransferData[operator].denyOperator;
    uint256 currentContract_beforeTransferData_operator__shareUnlockTime_before = currentContract.beforeTransferData[operator].shareUnlockTime;

    // call function under test
    denyPermissionedOperator(e, operator);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_operator__denyFrom_after = currentContract.beforeTransferData[operator].denyFrom;
    bool currentContract_beforeTransferData_operator__denyTo_after = currentContract.beforeTransferData[operator].denyTo;
    bool currentContract_beforeTransferData_operator__denyOperator_after = currentContract.beforeTransferData[operator].denyOperator;
    uint256 currentContract_beforeTransferData_operator__shareUnlockTime_after = currentContract.beforeTransferData[operator].shareUnlockTime;

    // verify integrity
    assert ((((currentContract_beforeTransferData_operator__denyFrom_after == currentContract_beforeTransferData_operator__denyFrom_before) && (currentContract_beforeTransferData_operator__denyTo_after == currentContract_beforeTransferData_operator__denyTo_before)) && (currentContract_beforeTransferData_operator__denyOperator_after == currentContract_beforeTransferData_operator__denyOperator_before)) && (currentContract_beforeTransferData_operator__shareUnlockTime_after == currentContract_beforeTransferData_operator__shareUnlockTime_before)), "beforeTransferData[operator].denyFrom@after == beforeTransferData[operator].denyFrom@before && beforeTransferData[operator].denyTo@after == beforeTransferData[operator].denyTo@before && beforeTransferData[operator].denyOperator@after == beforeTransferData[operator].denyOperator@before && beforeTransferData[operator].shareUnlockTime@after == beforeTransferData[operator].shareUnlockTime@before";
}

/*
 * msg.sender != owner@before && authority@before == address(0) => revert
 *
 * What it means: The function must revert if called by someone who is not the owner and when no authority contract is set
 *
 * Why it should hold: The setDepositCap function has the requiresAuth modifier, which enforces access control. Only authorized users should be able to modify the deposit cap as it's a critical security parameter
 *
 * Possible consequences: Unauthorized access control bypass, allowing attackers to manipulate deposit limits which could lead to economic attacks or protocol disruption
 */
rule setDepositCap_7bd876b6_unauthorized_reverts(env e) {
    uint112 cap;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    setDepositCap@withrevert(e, cap);
    bool setDepositCap_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((e.msg.sender != currentContract_owner_before) && (currentContract_authority_before == 0)) => setDepositCap_reverted), "msg.sender != owner@before && authority@before == address(0) => revert";
}

/*
 * msg.sender == owner@before || authority@before != address(0) => depositCap@after == cap
 *
 * What it means: When called by an authorized user, the function must update the depositCap storage variable to the provided cap parameter value
 *
 * Why it should hold: This is the core functionality of setDepositCap - it should actually store the new cap value when called by authorized users. The function's purpose is to update this critical parameter
 *
 * Possible consequences: Function malfunction where authorized calls don't update the cap, leading to inability to manage deposit limits and potential protocol misconfiguration
 */
rule setDepositCap_7bd876b6_cap_stored(env e) {
    uint112 cap;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    setDepositCap(e, cap);

    // assign all the 'after' variables
    uint112 currentContract_depositCap_after = currentContract.depositCap;

    // verify integrity
    assert (((e.msg.sender == currentContract_owner_before) || (currentContract_authority_before != 0)) => (currentContract_depositCap_after == cap)), "msg.sender == owner@before || authority@before != address(0) => depositCap@after == cap";
}

/*
 * (msg.sender == owner@before || authority@before != address(0)) && cap == 0 => depositCap@after == 0
 *
 * What it means: Authorized users must be able to set the deposit cap to zero, effectively disabling all new deposits
 *
 * Why it should hold: Setting cap to 0 is a valid emergency measure to halt deposits. The function should support this edge case as it's operationally important for risk management
 *
 * Possible consequences: Inability to emergency-stop deposits during critical situations, leaving the protocol vulnerable to continued inflows during attacks or market stress
 */
rule setDepositCap_7bd876b6_zero_cap_allowed(env e) {
    uint112 cap;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    setDepositCap(e, cap);

    // assign all the 'after' variables
    uint112 currentContract_depositCap_after = currentContract.depositCap;

    // verify integrity
    assert ((((e.msg.sender == currentContract_owner_before) || (currentContract_authority_before != 0)) && (cap == 0)) => (currentContract_depositCap_after == 0)), "(msg.sender == owner@before || authority@before != address(0)) && cap == 0 => depositCap@after == 0";
}

/*
 * (msg.sender == owner@before || authority@before != address(0)) && cap == type(uint112).max => depositCap@after == type(uint112).max
 *
 * What it means: Authorized users must be able to set the deposit cap to the maximum uint112 value, effectively removing deposit limits
 *
 * Why it should hold: Setting cap to maximum uint112 value removes deposit restrictions. This should be allowed as it represents unlimited deposits, which may be desired in normal operations
 *
 * Possible consequences: Inability to remove deposit restrictions when needed, limiting protocol scalability and user access during normal operations
 */
rule setDepositCap_7bd876b6_max_cap_allowed(env e) {
    uint112 cap;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    setDepositCap(e, cap);

    // assign all the 'after' variables
    uint112 currentContract_depositCap_after = currentContract.depositCap;

    // verify integrity
    assert ((((e.msg.sender == currentContract_owner_before) || (currentContract_authority_before != 0)) && (cap == ((2 ^ 112 - 1)))) => (currentContract_depositCap_after == ((2 ^ 112 - 1)))), "(msg.sender == owner@before || authority@before != address(0)) && cap == type(uint112).max => depositCap@after == type(uint112).max";
}

/*
 * (msg.sender == owner@before || authority@before != address(0)) && cap == depositCap@before => revert
 *
 * What it means: If an authorized user tries to set the deposit cap to the same value it already has, the function must revert
 *
 * Why it should hold: Following the NO-OPS MUST REVERT rule, meaningless operations should fail. Setting the cap to its current value accomplishes nothing and should be prevented
 *
 * Possible consequences: Wasted gas on meaningless transactions and potential confusion about whether the operation succeeded or had any effect
 */
rule setDepositCap_7bd876b6_no_op_reverts(env e) {
    uint112 cap;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    uint112 currentContract_depositCap_before = currentContract.depositCap;

    // call function under test
    setDepositCap@withrevert(e, cap);
    bool setDepositCap_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((((e.msg.sender == currentContract_owner_before) || (currentContract_authority_before != 0)) && (cap == currentContract_depositCap_before)) => setDepositCap_reverted), "(msg.sender == owner@before || authority@before != address(0)) && cap == depositCap@before => revert";
}

/*
 * owner@after == owner@before && authority@after == authority@before && locked@after == locked@before && depositNonce@after == depositNonce@before && shareLockPeriod@after == shareLockPeriod@before && isPaused@after == isPaused@before && permissionedTransfers@after == permissionedTransfers@before
 *
 * What it means: The setDepositCap function must only modify the depositCap variable and leave all other contract state variables unchanged
 *
 * Why it should hold: The function should have minimal side effects and only change what it's supposed to change. Modifying other state variables would indicate a bug or malicious behavior
 *
 * Possible consequences: Unintended state corruption, breaking other contract functionality, or creating attack vectors through unexpected state changes
 */
rule setDepositCap_7bd876b6_other_state_unchanged(env e) {
    uint112 cap;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;
    uint256 currentContract_locked_before = currentContract.locked;
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_permissionedTransfers_before = currentContract.permissionedTransfers;

    // call function under test
    setDepositCap(e, cap);

    // assign all the 'after' variables
    address currentContract_owner_after = currentContract.owner;
    address currentContract_authority_after = currentContract.authority;
    uint256 currentContract_locked_after = currentContract.locked;
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;
    uint64 currentContract_shareLockPeriod_after = currentContract.shareLockPeriod;
    bool currentContract_isPaused_after = currentContract.isPaused;
    bool currentContract_permissionedTransfers_after = currentContract.permissionedTransfers;

    // verify integrity
    assert (((((((currentContract_owner_after == currentContract_owner_before) && (currentContract_authority_after == currentContract_authority_before)) && (currentContract_locked_after == currentContract_locked_before)) && (currentContract_depositNonce_after == currentContract_depositNonce_before)) && (currentContract_shareLockPeriod_after == currentContract_shareLockPeriod_before)) && (currentContract_isPaused_after == currentContract_isPaused_before)) && (currentContract_permissionedTransfers_after == currentContract_permissionedTransfers_before)), "owner@after == owner@before && authority@after == authority@before && locked@after == locked@before && depositNonce@after == depositNonce@before && shareLockPeriod@after == shareLockPeriod@before && isPaused@after == isPaused@before && permissionedTransfers@after == permissionedTransfers@before";
}

/*
 * depositTimestamp + shareLockUpPeriodAtTimeOfDeposit <= block.timestamp => revert
 *
 * What it means: The function must revert if the deposit's lock period has already expired (current time >= deposit timestamp + lock period)
 *
 * Why it should hold: According to the contract documentation, deposits can only be refunded during the share lock period. Once this period expires, the deposit becomes permanent and non-refundable
 *
 * Possible consequences: Unauthorized refunds of expired deposits, allowing users to withdraw funds they should no longer be able to access, leading to fund loss for the vault
 */
rule refundDeposit_46b563f4_expired_lock_period(env e) {
    uint256 nonce;
    address receiver;
    address depositAsset;
    uint256 depositAmount;
    uint256 shareAmount;
    uint256 depositTimestamp;
    uint256 shareLockUpPeriodAtTimeOfDeposit;

    // assign all the 'before' variables

    // call function under test
    refundDeposit@withrevert(e, nonce, receiver, depositAsset, depositAmount, shareAmount, depositTimestamp, shareLockUpPeriodAtTimeOfDeposit);
    bool refundDeposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((depositTimestamp + shareLockUpPeriodAtTimeOfDeposit <= e.block.timestamp) => refundDeposit_reverted), "depositTimestamp + shareLockUpPeriodAtTimeOfDeposit <= block.timestamp => revert";
}

/*
 * shareLockUpPeriodAtTimeOfDeposit == 0 => revert
 *
 * What it means: The function must revert if the share lock period at time of deposit was zero
 *
 * Why it should hold: Deposits with zero lock period cannot be refunded because they were never meant to be locked or refundable in the first place
 *
 * Possible consequences: Allowing refunds of deposits that were never supposed to be refundable, breaking the contract's deposit mechanics and enabling fund theft
 */
rule refundDeposit_46b563f4_zero_share_lock(env e) {
    uint256 nonce;
    address receiver;
    address depositAsset;
    uint256 depositAmount;
    uint256 shareAmount;
    uint256 depositTimestamp;
    uint256 shareLockUpPeriodAtTimeOfDeposit;

    // assign all the 'before' variables

    // call function under test
    refundDeposit@withrevert(e, nonce, receiver, depositAsset, depositAmount, shareAmount, depositTimestamp, shareLockUpPeriodAtTimeOfDeposit);
    bool refundDeposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((shareLockUpPeriodAtTimeOfDeposit == 0) => refundDeposit_reverted), "shareLockUpPeriodAtTimeOfDeposit == 0 => revert";
}

/*
 * shareAmount == 0 => revert
 *
 * What it means: The function must revert if the share amount parameter is zero
 *
 * Why it should hold: Refunding zero shares is a meaningless operation that should not be allowed, following the no-op prevention pattern
 *
 * Possible consequences: Wasted gas, potential state corruption, and bypassing of other validation checks through meaningless operations
 */
rule refundDeposit_46b563f4_no_shares_to_refund(env e) {
    uint256 nonce;
    address receiver;
    address depositAsset;
    uint256 depositAmount;
    uint256 shareAmount;
    uint256 depositTimestamp;
    uint256 shareLockUpPeriodAtTimeOfDeposit;

    // assign all the 'before' variables

    // call function under test
    refundDeposit@withrevert(e, nonce, receiver, depositAsset, depositAmount, shareAmount, depositTimestamp, shareLockUpPeriodAtTimeOfDeposit);
    bool refundDeposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((shareAmount == 0) => refundDeposit_reverted), "shareAmount == 0 => revert";
}

/*
 * beforeTransferData[receiver].shareUnlockTime@before <= block.timestamp => revert
 *
 * What it means: The function must revert if the receiver's shares are already unlocked (shareUnlockTime <= current time)
 *
 * Why it should hold: If shares are unlocked, the user can transfer them freely, making refunds inappropriate since they may have already moved the shares
 *
 * Possible consequences: Double-spending attacks where users can both transfer their shares and get refunds, leading to fund loss and accounting errors
 */
rule refundDeposit_46b563f4_receiver_shares_unlocked(env e) {
    uint256 nonce;
    address receiver;
    address depositAsset;
    uint256 depositAmount;
    uint256 shareAmount;
    uint256 depositTimestamp;
    uint256 shareLockUpPeriodAtTimeOfDeposit;

    // assign all the 'before' variables
    uint256 currentContract_beforeTransferData_receiver__shareUnlockTime_before = currentContract.beforeTransferData[receiver].shareUnlockTime;

    // call function under test
    refundDeposit@withrevert(e, nonce, receiver, depositAsset, depositAmount, shareAmount, depositTimestamp, shareLockUpPeriodAtTimeOfDeposit);
    bool refundDeposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_beforeTransferData_receiver__shareUnlockTime_before <= e.block.timestamp) => refundDeposit_reverted), "beforeTransferData[receiver].shareUnlockTime@before <= block.timestamp => revert";
}

/*
 * publicDepositHistory[nonce]@before == bytes32(0) => revert
 *
 * What it means: The function must revert if the deposit nonce has no corresponding entry in publicDepositHistory (empty bytes32)
 *
 * Why it should hold: Only valid, existing deposits should be refundable. Empty history entries indicate non-existent or already processed deposits
 *
 * Possible consequences: Refunding non-existent deposits, creating funds out of thin air, and severe accounting corruption
 */
rule refundDeposit_46b563f4_invalid_nonce(env e) {
    uint256 nonce;
    address receiver;
    address depositAsset;
    uint256 depositAmount;
    uint256 shareAmount;
    uint256 depositTimestamp;
    uint256 shareLockUpPeriodAtTimeOfDeposit;

    // assign all the 'before' variables
    bytes32 currentContract_publicDepositHistory_nonce__before = currentContract.publicDepositHistory[nonce];

    // call function under test
    refundDeposit@withrevert(e, nonce, receiver, depositAsset, depositAmount, shareAmount, depositTimestamp, shareLockUpPeriodAtTimeOfDeposit);
    bool refundDeposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_publicDepositHistory_nonce__before == to_bytes32(0)) => refundDeposit_reverted), "publicDepositHistory[nonce]@before == bytes32(0) => revert";
}

/*
 * depositAmount == 0 => revert
 *
 * What it means: The function must revert if the deposit amount parameter is zero
 *
 * Why it should hold: Refunding zero deposit amount is meaningless and should be prevented as a no-op operation
 *
 * Possible consequences: Wasted gas, potential bypass of validation logic, and state corruption through meaningless operations
 */
rule refundDeposit_46b563f4_zero_deposit_amount(env e) {
    uint256 nonce;
    address receiver;
    address depositAsset;
    uint256 depositAmount;
    uint256 shareAmount;
    uint256 depositTimestamp;
    uint256 shareLockUpPeriodAtTimeOfDeposit;

    // assign all the 'before' variables

    // call function under test
    refundDeposit@withrevert(e, nonce, receiver, depositAsset, depositAmount, shareAmount, depositTimestamp, shareLockUpPeriodAtTimeOfDeposit);
    bool refundDeposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((depositAmount == 0) => refundDeposit_reverted), "depositAmount == 0 => revert";
}

/*
 * publicDepositHistory[nonce]@before != bytes32(0) && depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > block.timestamp && shareLockUpPeriodAtTimeOfDeposit > 0 && shareAmount > 0 => publicDepositHistory[nonce]@after == bytes32(0)
 *
 * What it means: For valid refunds (non-empty history, unexpired lock, positive amounts), the deposit history entry must be cleared (set to bytes32(0))
 *
 * Why it should hold: Prevents double-refunding by ensuring each deposit can only be refunded once, maintaining proper accounting
 *
 * Possible consequences: Double-refund attacks where the same deposit can be refunded multiple times, leading to fund drainage
 */
rule refundDeposit_46b563f4_valid_refund_clears_history(env e) {
    uint256 nonce;
    address receiver;
    address depositAsset;
    uint256 depositAmount;
    uint256 shareAmount;
    uint256 depositTimestamp;
    uint256 shareLockUpPeriodAtTimeOfDeposit;

    // assign all the 'before' variables
    bytes32 currentContract_publicDepositHistory_nonce__before = currentContract.publicDepositHistory[nonce];

    // call function under test
    refundDeposit(e, nonce, receiver, depositAsset, depositAmount, shareAmount, depositTimestamp, shareLockUpPeriodAtTimeOfDeposit);

    // assign all the 'after' variables
    bytes32 currentContract_publicDepositHistory_nonce__after = currentContract.publicDepositHistory[nonce];

    // verify integrity
    assert (((((currentContract_publicDepositHistory_nonce__before != to_bytes32(0)) && (depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > e.block.timestamp)) && (shareLockUpPeriodAtTimeOfDeposit > 0)) && (shareAmount > 0)) => (currentContract_publicDepositHistory_nonce__after == to_bytes32(0))), "publicDepositHistory[nonce]@before != bytes32(0) && depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > block.timestamp && shareLockUpPeriodAtTimeOfDeposit > 0 && shareAmount > 0 => publicDepositHistory[nonce]@after == bytes32(0)";
}

/*
 * publicDepositHistory[nonce]@before != bytes32(0) && depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > block.timestamp && shareLockUpPeriodAtTimeOfDeposit > 0 && shareAmount > 0 && otherNonce != nonce => publicDepositHistory[otherNonce]@after == publicDepositHistory[otherNonce]@before
 *
 * What it means: Valid refunds must not affect deposit history entries of other nonces
 *
 * Why it should hold: Refunding one deposit should not corrupt or clear other users' deposit records, maintaining data integrity
 *
 * Possible consequences: Corruption of other users' deposit records, preventing legitimate refunds or enabling unauthorized ones
 */
rule refundDeposit_46b563f4_preserves_other_deposits(env e) {
    uint256 nonce;
    address receiver;
    address depositAsset;
    uint256 depositAmount;
    uint256 shareAmount;
    uint256 depositTimestamp;
    uint256 shareLockUpPeriodAtTimeOfDeposit;
    uint256 otherNonce;

    // assign all the 'before' variables
    bytes32 currentContract_publicDepositHistory_nonce__before = currentContract.publicDepositHistory[nonce];
    bytes32 currentContract_publicDepositHistory_otherNonce__before = currentContract.publicDepositHistory[otherNonce];

    // call function under test
    refundDeposit(e, nonce, receiver, depositAsset, depositAmount, shareAmount, depositTimestamp, shareLockUpPeriodAtTimeOfDeposit);

    // assign all the 'after' variables
    bytes32 currentContract_publicDepositHistory_otherNonce__after = currentContract.publicDepositHistory[otherNonce];

    // verify integrity
    assert ((((((currentContract_publicDepositHistory_nonce__before != to_bytes32(0)) && (depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > e.block.timestamp)) && (shareLockUpPeriodAtTimeOfDeposit > 0)) && (shareAmount > 0)) && (otherNonce != nonce)) => (currentContract_publicDepositHistory_otherNonce__after == currentContract_publicDepositHistory_otherNonce__before)), "publicDepositHistory[nonce]@before != bytes32(0) && depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > block.timestamp && shareLockUpPeriodAtTimeOfDeposit > 0 && shareAmount > 0 && otherNonce != nonce => publicDepositHistory[otherNonce]@after == publicDepositHistory[otherNonce]@before";
}

/*
 * publicDepositHistory[nonce]@before != bytes32(0) && depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > block.timestamp && shareLockUpPeriodAtTimeOfDeposit > 0 && shareAmount > 0 => beforeTransferData[receiver].shareUnlockTime@after == beforeTransferData[receiver].shareUnlockTime@before
 *
 * What it means: Valid refunds must not change the receiver's share unlock time
 *
 * Why it should hold: Refunding should not affect the user's existing share lock status, as the lock was set during deposit and should remain until natural expiry
 *
 * Possible consequences: Manipulation of share lock times, potentially allowing premature transfers or extending locks inappropriately
 */
rule refundDeposit_46b563f4_preserves_share_lock(env e) {
    uint256 nonce;
    address receiver;
    address depositAsset;
    uint256 depositAmount;
    uint256 shareAmount;
    uint256 depositTimestamp;
    uint256 shareLockUpPeriodAtTimeOfDeposit;

    // assign all the 'before' variables
    bytes32 currentContract_publicDepositHistory_nonce__before = currentContract.publicDepositHistory[nonce];
    uint256 currentContract_beforeTransferData_receiver__shareUnlockTime_before = currentContract.beforeTransferData[receiver].shareUnlockTime;

    // call function under test
    refundDeposit(e, nonce, receiver, depositAsset, depositAmount, shareAmount, depositTimestamp, shareLockUpPeriodAtTimeOfDeposit);

    // assign all the 'after' variables
    uint256 currentContract_beforeTransferData_receiver__shareUnlockTime_after = currentContract.beforeTransferData[receiver].shareUnlockTime;

    // verify integrity
    assert (((((currentContract_publicDepositHistory_nonce__before != to_bytes32(0)) && (depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > e.block.timestamp)) && (shareLockUpPeriodAtTimeOfDeposit > 0)) && (shareAmount > 0)) => (currentContract_beforeTransferData_receiver__shareUnlockTime_after == currentContract_beforeTransferData_receiver__shareUnlockTime_before)), "publicDepositHistory[nonce]@before != bytes32(0) && depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > block.timestamp && shareLockUpPeriodAtTimeOfDeposit > 0 && shareAmount > 0 => beforeTransferData[receiver].shareUnlockTime@after == beforeTransferData[receiver].shareUnlockTime@before";
}

/*
 * publicDepositHistory[nonce]@before != bytes32(0) && depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > block.timestamp && shareLockUpPeriodAtTimeOfDeposit > 0 && shareAmount > 0 => isPaused@after == isPaused@before
 *
 * What it means: Valid refunds must not change the contract's pause state
 *
 * Why it should hold: Refund operations should not have side effects on contract-wide settings like pause state, which should only be controlled by authorized admin functions
 *
 * Possible consequences: Unauthorized pausing or unpausing of the contract, disrupting normal operations
 */
rule refundDeposit_46b563f4_preserves_pause_state(env e) {
    uint256 nonce;
    address receiver;
    address depositAsset;
    uint256 depositAmount;
    uint256 shareAmount;
    uint256 depositTimestamp;
    uint256 shareLockUpPeriodAtTimeOfDeposit;

    // assign all the 'before' variables
    bytes32 currentContract_publicDepositHistory_nonce__before = currentContract.publicDepositHistory[nonce];
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    refundDeposit(e, nonce, receiver, depositAsset, depositAmount, shareAmount, depositTimestamp, shareLockUpPeriodAtTimeOfDeposit);

    // assign all the 'after' variables
    bool currentContract_isPaused_after = currentContract.isPaused;

    // verify integrity
    assert (((((currentContract_publicDepositHistory_nonce__before != to_bytes32(0)) && (depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > e.block.timestamp)) && (shareLockUpPeriodAtTimeOfDeposit > 0)) && (shareAmount > 0)) => (currentContract_isPaused_after == currentContract_isPaused_before)), "publicDepositHistory[nonce]@before != bytes32(0) && depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > block.timestamp && shareLockUpPeriodAtTimeOfDeposit > 0 && shareAmount > 0 => isPaused@after == isPaused@before";
}

/*
 * publicDepositHistory[nonce]@before != bytes32(0) && depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > block.timestamp && shareLockUpPeriodAtTimeOfDeposit > 0 && shareAmount > 0 => depositNonce@after == depositNonce@before
 *
 * What it means: Valid refunds must not change the global deposit nonce counter
 *
 * Why it should hold: The deposit nonce is a global counter that should only increment with new deposits, not be affected by refund operations
 *
 * Possible consequences: Nonce collision attacks, deposit tracking corruption, and potential replay attacks
 */
rule refundDeposit_46b563f4_preserves_deposit_nonce(env e) {
    uint256 nonce;
    address receiver;
    address depositAsset;
    uint256 depositAmount;
    uint256 shareAmount;
    uint256 depositTimestamp;
    uint256 shareLockUpPeriodAtTimeOfDeposit;

    // assign all the 'before' variables
    bytes32 currentContract_publicDepositHistory_nonce__before = currentContract.publicDepositHistory[nonce];
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;

    // call function under test
    refundDeposit(e, nonce, receiver, depositAsset, depositAmount, shareAmount, depositTimestamp, shareLockUpPeriodAtTimeOfDeposit);

    // assign all the 'after' variables
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;

    // verify integrity
    assert (((((currentContract_publicDepositHistory_nonce__before != to_bytes32(0)) && (depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > e.block.timestamp)) && (shareLockUpPeriodAtTimeOfDeposit > 0)) && (shareAmount > 0)) => (currentContract_depositNonce_after == currentContract_depositNonce_before)), "publicDepositHistory[nonce]@before != bytes32(0) && depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > block.timestamp && shareLockUpPeriodAtTimeOfDeposit > 0 && shareAmount > 0 => depositNonce@after == depositNonce@before";
}

/*
 * publicDepositHistory[nonce]@before != bytes32(0) && depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > block.timestamp && shareLockUpPeriodAtTimeOfDeposit > 0 && shareAmount > 0 && otherUser != receiver => beforeTransferData[otherUser].shareUnlockTime@after == beforeTransferData[otherUser].shareUnlockTime@before
 *
 * What it means: Valid refunds must not affect the share unlock times of other users
 *
 * Why it should hold: Refunding one user's deposit should not impact other users' share lock status, maintaining isolation between user accounts
 *
 * Possible consequences: Cross-user lock manipulation, allowing attackers to unlock other users' shares prematurely or extend their locks
 */
rule refundDeposit_46b563f4_preserves_other_user_lock(env e) {
    uint256 nonce;
    address receiver;
    address depositAsset;
    uint256 depositAmount;
    uint256 shareAmount;
    uint256 depositTimestamp;
    uint256 shareLockUpPeriodAtTimeOfDeposit;
    address otherUser;

    // assign all the 'before' variables
    bytes32 currentContract_publicDepositHistory_nonce__before = currentContract.publicDepositHistory[nonce];
    uint256 currentContract_beforeTransferData_otherUser__shareUnlockTime_before = currentContract.beforeTransferData[otherUser].shareUnlockTime;

    // call function under test
    refundDeposit(e, nonce, receiver, depositAsset, depositAmount, shareAmount, depositTimestamp, shareLockUpPeriodAtTimeOfDeposit);

    // assign all the 'after' variables
    uint256 currentContract_beforeTransferData_otherUser__shareUnlockTime_after = currentContract.beforeTransferData[otherUser].shareUnlockTime;

    // verify integrity
    assert ((((((currentContract_publicDepositHistory_nonce__before != to_bytes32(0)) && (depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > e.block.timestamp)) && (shareLockUpPeriodAtTimeOfDeposit > 0)) && (shareAmount > 0)) && (otherUser != receiver)) => (currentContract_beforeTransferData_otherUser__shareUnlockTime_after == currentContract_beforeTransferData_otherUser__shareUnlockTime_before)), "publicDepositHistory[nonce]@before != bytes32(0) && depositTimestamp + shareLockUpPeriodAtTimeOfDeposit > block.timestamp && shareLockUpPeriodAtTimeOfDeposit > 0 && shareAmount > 0 && otherUser != receiver => beforeTransferData[otherUser].shareUnlockTime@after == beforeTransferData[otherUser].shareUnlockTime@before";
}

/*
 * isPaused@before => revert
 *
 * What it means: When the contract is paused (isPaused is true), all deposit calls must revert
 *
 * Why it should hold: The pause mechanism is a critical safety feature that allows admins to halt deposits during emergencies, security incidents, or maintenance periods
 *
 * Possible consequences: If deposits continue when paused, users could lose funds during known security incidents, or deposits could occur during contract upgrades leading to inconsistent state
 */
rule deposit_0efe6a8b_paused_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    deposit@withrevert(e, depositAsset, depositAmount, minimumMint);
    bool deposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (currentContract_isPaused_before => deposit_reverted), "isPaused@before => revert";
}

/*
 * depositAmount == 0 => revert
 *
 * What it means: Deposit calls with zero depositAmount must revert instead of succeeding as no-ops
 *
 * Why it should hold: Zero-amount operations are meaningless and should be prevented to avoid wasting gas and cluttering state with empty transactions
 *
 * Possible consequences: Gas waste, state pollution with meaningless transactions, potential griefing attacks through spam deposits
 */
rule deposit_0efe6a8b_zero_amount_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables

    // call function under test
    deposit@withrevert(e, depositAsset, depositAmount, minimumMint);
    bool deposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((depositAmount == 0) => deposit_reverted), "depositAmount == 0 => revert";
}

/*
 * !assetData[depositAsset].allowDeposits@before => revert
 *
 * What it means: Deposits must revert if the asset's allowDeposits flag is false
 *
 * Why it should hold: Asset support is controlled by admins through the allowDeposits flag to manage which tokens can be deposited
 *
 * Possible consequences: Unauthorized deposits of unsupported or malicious tokens, potential fund loss if pricing is unavailable
 */
rule deposit_0efe6a8b_unsupported_asset_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;

    // call function under test
    deposit@withrevert(e, depositAsset, depositAmount, minimumMint);
    bool deposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (!(currentContract_assetData_depositAsset__allowDeposits_before) => deposit_reverted), "!assetData[depositAsset].allowDeposits@before => revert";
}

/*
 * shares < minimumMint => revert
 *
 * What it means: Deposits must revert if the calculated shares are less than the user's minimumMint requirement
 *
 * Why it should hold: Users specify minimumMint to protect against slippage and ensure they receive adequate shares for their deposit
 *
 * Possible consequences: Users could receive fewer shares than expected due to price changes or calculation errors, leading to financial loss
 */
rule deposit_0efe6a8b_minimum_mint_not_met(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables

    // call function under test
    deposit@withrevert(e, depositAsset, depositAmount, minimumMint);
    bool deposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((shares < minimumMint) => deposit_reverted), "shares < minimumMint => revert";
}

/*
 * depositCap@before != type(uint112).max && shares + vault.totalSupply()@before > depositCap@before => revert
 *
 * What it means: Deposits must revert if adding the new shares would exceed the deposit cap
 *
 * Why it should hold: The deposit cap limits total vault size to manage risk and prevent the vault from growing beyond manageable limits
 *
 * Possible consequences: Vault could grow beyond intended size, increasing systemic risk and making the vault harder to manage
 */
rule deposit_0efe6a8b_deposit_exceeds_cap(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);

    // call function under test
    deposit@withrevert(e, depositAsset, depositAmount, minimumMint);
    bool deposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((currentContract_depositCap_before != ((2 ^ 112 - 1))) && (shares + currentContract_vault_totalSupply_e__before > currentContract_depositCap_before)) => deposit_reverted), "depositCap@before != type(uint112).max && shares + vault.totalSupply()@before > depositCap@before => revert";
}

/*
 * depositAsset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE => revert
 *
 * What it means: Deposits using the native asset address (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) must revert
 *
 * Why it should hold: The deposit function doesn't handle native ETH deposits - only ERC20 tokens are supported in this function
 *
 * Possible consequences: Native ETH could be lost or stuck in the contract if not properly handled
 */
rule deposit_0efe6a8b_native_deposit_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables

    // call function under test
    deposit@withrevert(e, depositAsset, depositAmount, minimumMint);
    bool deposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((depositAsset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) => deposit_reverted), "depositAsset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE => revert";
}

/*
 * shareLockPeriod@before > 0 && !isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => beforeTransferData[msg.sender].shareUnlockTime@after == block.timestamp + shareLockPeriod@before
 *
 * What it means: When shareLockPeriod > 0 and deposit succeeds, the user's shareUnlockTime is set to current timestamp plus the lock period
 *
 * Why it should hold: Share locking prevents immediate transfers after deposit, allowing time for deposit refunds and preventing certain attack vectors
 *
 * Possible consequences: Users could transfer shares immediately after deposit, preventing refunds and enabling flash loan attacks
 */
rule deposit_0efe6a8b_share_lock_updates(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);

    // call function under test
    shares = deposit(e, depositAsset, depositAmount, minimumMint);

    // assign all the 'after' variables
    uint256 currentContract_beforeTransferData_e_msg_sender__shareUnlockTime_after = currentContract.beforeTransferData[e.msg.sender].shareUnlockTime;

    // verify integrity
    assert (((((((currentContract_shareLockPeriod_before > 0) && !(currentContract_isPaused_before)) && currentContract_assetData_depositAsset__allowDeposits_before) && (depositAmount > 0)) && (shares >= minimumMint)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) => (currentContract_beforeTransferData_e_msg_sender__shareUnlockTime_after == e.block.timestamp + currentContract_shareLockPeriod_before)), "shareLockPeriod@before > 0 && !isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => beforeTransferData[msg.sender].shareUnlockTime@after == block.timestamp + shareLockPeriod@before";
}

/*
 * !isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => depositNonce@after == depositNonce@before + 1
 *
 * What it means: Every successful deposit increments the depositNonce by exactly 1
 *
 * Why it should hold: The nonce provides unique identifiers for deposits and is used for tracking deposit history and refunds
 *
 * Possible consequences: Duplicate nonces could overwrite deposit history, preventing proper refunds or causing confusion
 */
rule deposit_0efe6a8b_nonce_increments(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;

    // call function under test
    shares = deposit(e, depositAsset, depositAmount, minimumMint);

    // assign all the 'after' variables
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;

    // verify integrity
    assert (((((!(currentContract_isPaused_before) && currentContract_assetData_depositAsset__allowDeposits_before) && (depositAmount > 0)) && (shares >= minimumMint)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) => (currentContract_depositNonce_after == currentContract_depositNonce_before + 1)), "!isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => depositNonce@after == depositNonce@before + 1";
}

/*
 * shareLockPeriod@before > 0 && !isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => publicDepositHistory@after[uint256(depositNonce@after)] != bytes32(0)
 *
 * What it means: When shareLockPeriod > 0 and deposit succeeds, a non-zero hash is saved in publicDepositHistory for the new nonce
 *
 * Why it should hold: Deposit history is required for the refund mechanism - without it, deposits cannot be refunded during the lock period
 *
 * Possible consequences: Deposits could not be refunded even during the lock period, trapping user funds
 */
rule deposit_0efe6a8b_deposit_history_saved(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);

    // call function under test
    shares = deposit(e, depositAsset, depositAmount, minimumMint);

    // assign all the 'after' variables
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;
    bytes32 currentContract_publicDepositHistory_assert_uint256_currentContract_depositNonce_after____0____currentContract_depositNonce_after___2___256____2___256______currentContract_depositNonce_after____2___256____after = currentContract.publicDepositHistory[assert_uint256(currentContract_depositNonce_after >= 0 ? (currentContract_depositNonce_after % 2 ^ 256) : 2 ^ 256 - (-(currentContract_depositNonce_after) % 2 ^ 256))];

    // verify integrity
    assert (((((((currentContract_shareLockPeriod_before > 0) && !(currentContract_isPaused_before)) && currentContract_assetData_depositAsset__allowDeposits_before) && (depositAmount > 0)) && (shares >= minimumMint)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) => (currentContract_publicDepositHistory_assert_uint256_currentContract_depositNonce_after____0____currentContract_depositNonce_after___2___256____2___256______currentContract_depositNonce_after____2___256____after != to_bytes32(0))), "shareLockPeriod@before > 0 && !isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => publicDepositHistory@after[uint256(depositNonce@after)] != bytes32(0)";
}

/*
 * shareLockPeriod@before == 0 && !isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => publicDepositHistory@after[uint256(depositNonce@after)] == publicDepositHistory@before[uint256(depositNonce@after)]
 *
 * What it means: When shareLockPeriod is 0, no deposit history should be saved since refunds are not possible
 *
 * Why it should hold: When there's no lock period, deposits are immediately final and don't need refund capability, so history storage is unnecessary
 *
 * Possible consequences: Unnecessary gas costs and state bloat from storing unused deposit history
 */
// gereon: used nonce_after before the call...
rule deposit_0efe6a8b_no_history_zero_lock(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;
    bytes32 currentContract_publicDepositHistory_assert_uint256_currentContract_depositNonce_after____0____currentContract_depositNonce_after___2___256____2___256______currentContract_depositNonce_after____2___256____before = currentContract.publicDepositHistory[assert_uint256(currentContract_depositNonce_before >= 0 ? (currentContract_depositNonce_before % 2 ^ 256) : 2 ^ 256 - (-(currentContract_depositNonce_before) % 2 ^ 256))];

    // call function under test
    shares = deposit(e, depositAsset, depositAmount, minimumMint);

    // assign all the 'after' variables
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;
    bytes32 currentContract_publicDepositHistory_assert_uint256_currentContract_depositNonce_after____0____currentContract_depositNonce_after___2___256____2___256______currentContract_depositNonce_after____2___256____after = currentContract.publicDepositHistory[assert_uint256(currentContract_depositNonce_after >= 0 ? (currentContract_depositNonce_after % 2 ^ 256) : 2 ^ 256 - (-(currentContract_depositNonce_after) % 2 ^ 256))];

    // verify integrity
    assert (((((((currentContract_shareLockPeriod_before == 0) && !(currentContract_isPaused_before)) && currentContract_assetData_depositAsset__allowDeposits_before) && (depositAmount > 0)) && (shares >= minimumMint)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) => (currentContract_publicDepositHistory_assert_uint256_currentContract_depositNonce_after____0____currentContract_depositNonce_after___2___256____2___256______currentContract_depositNonce_after____2___256____after == currentContract_publicDepositHistory_assert_uint256_currentContract_depositNonce_after____0____currentContract_depositNonce_after___2___256____2___256______currentContract_depositNonce_after____2___256____before)), "shareLockPeriod@before == 0 && !isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => publicDepositHistory@after[uint256(depositNonce@after)] == publicDepositHistory@before[uint256(depositNonce@after)]";
}

/*
 * shareLockPeriod@before == 0 && !isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => beforeTransferData[msg.sender].shareUnlockTime@after == beforeTransferData[msg.sender].shareUnlockTime@before
 *
 * What it means: When shareLockPeriod is 0, the user's shareUnlockTime should not change
 *
 * Why it should hold: With zero lock period, shares should be immediately transferable, so unlock time shouldn't be modified
 *
 * Possible consequences: Shares could be unnecessarily locked even when lock period is disabled
 */
rule deposit_0efe6a8b_no_unlock_time_zero_lock(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);
    uint256 currentContract_beforeTransferData_e_msg_sender__shareUnlockTime_before = currentContract.beforeTransferData[e.msg.sender].shareUnlockTime;

    // call function under test
    shares = deposit(e, depositAsset, depositAmount, minimumMint);

    // assign all the 'after' variables
    uint256 currentContract_beforeTransferData_e_msg_sender__shareUnlockTime_after = currentContract.beforeTransferData[e.msg.sender].shareUnlockTime;

    // verify integrity
    assert (((((((currentContract_shareLockPeriod_before == 0) && !(currentContract_isPaused_before)) && currentContract_assetData_depositAsset__allowDeposits_before) && (depositAmount > 0)) && (shares >= minimumMint)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) => (currentContract_beforeTransferData_e_msg_sender__shareUnlockTime_after == currentContract_beforeTransferData_e_msg_sender__shareUnlockTime_before)), "shareLockPeriod@before == 0 && !isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => beforeTransferData[msg.sender].shareUnlockTime@after == beforeTransferData[msg.sender].shareUnlockTime@before";
}

/*
 * locked@before != 1 => revert
 *
 * What it means: The deposit function must revert if called when the reentrancy lock is already held
 *
 * Why it should hold: Reentrancy protection prevents recursive calls that could lead to double-spending or state corruption
 *
 * Possible consequences: Reentrancy attacks could drain the vault or corrupt accounting state
 */
rule deposit_0efe6a8b_reentrancy_protected(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables
    uint256 currentContract_locked_before = currentContract.locked;

    // call function under test
    deposit@withrevert(e, depositAsset, depositAmount, minimumMint);
    bool deposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_locked_before != 1) => deposit_reverted), "locked@before != 1 => revert";
}

/*
 * !isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => isPaused@after == isPaused@before
 *
 * What it means: Successful deposits should not modify the isPaused state
 *
 * Why it should hold: Deposit operations should only affect deposit-related state, not global contract settings
 *
 * Possible consequences: Deposits could accidentally unpause the contract or modify critical settings
 */
rule deposit_0efe6a8b_other_storage_unchanged(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);

    // call function under test
    shares = deposit(e, depositAsset, depositAmount, minimumMint);

    // assign all the 'after' variables
    bool currentContract_isPaused_after = currentContract.isPaused;

    // verify integrity
    assert (((((!(currentContract_isPaused_before) && currentContract_assetData_depositAsset__allowDeposits_before) && (depositAmount > 0)) && (shares >= minimumMint)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) => (currentContract_isPaused_after == currentContract_isPaused_before)), "!isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => isPaused@after == isPaused@before";
}

/*
 * !isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => assetData[depositAsset].allowDeposits@after == assetData[depositAsset].allowDeposits@before
 *
 * What it means: Successful deposits should not modify the asset's allowDeposits flag
 *
 * Why it should hold: Asset configuration should only be changed by authorized admin functions, not by user deposits
 *
 * Possible consequences: Users could enable deposits for disabled assets or disable deposits for others
 */
rule deposit_0efe6a8b_asset_data_unchanged(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);

    // call function under test
    shares = deposit(e, depositAsset, depositAmount, minimumMint);

    // assign all the 'after' variables
    bool currentContract_assetData_depositAsset__allowDeposits_after = currentContract.assetData[depositAsset].allowDeposits;

    // verify integrity
    assert (((((!(currentContract_isPaused_before) && currentContract_assetData_depositAsset__allowDeposits_before) && (depositAmount > 0)) && (shares >= minimumMint)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) => (currentContract_assetData_depositAsset__allowDeposits_after == currentContract_assetData_depositAsset__allowDeposits_before)), "!isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => assetData[depositAsset].allowDeposits@after == assetData[depositAsset].allowDeposits@before";
}

/*
 * !isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => shareLockPeriod@after == shareLockPeriod@before
 *
 * What it means: Successful deposits should not modify the global shareLockPeriod setting
 *
 * Why it should hold: Lock period is a global security parameter that should only be changed by admin functions
 *
 * Possible consequences: Users could manipulate lock periods to avoid intended security restrictions
 */
rule deposit_0efe6a8b_share_lock_period_unchanged(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;

    // call function under test
    shares = deposit(e, depositAsset, depositAmount, minimumMint);

    // assign all the 'after' variables
    uint64 currentContract_shareLockPeriod_after = currentContract.shareLockPeriod;

    // verify integrity
    assert (((((!(currentContract_isPaused_before) && currentContract_assetData_depositAsset__allowDeposits_before) && (depositAmount > 0)) && (shares >= minimumMint)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) => (currentContract_shareLockPeriod_after == currentContract_shareLockPeriod_before)), "!isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => shareLockPeriod@after == shareLockPeriod@before";
}

/*
 * !isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => depositCap@after == depositCap@before
 *
 * What it means: Successful deposits should not modify the depositCap setting
 *
 * Why it should hold: Deposit cap is a risk management parameter that should only be changed by authorized admins
 *
 * Possible consequences: Users could bypass deposit caps or maliciously reduce caps to prevent others from depositing
 */
rule deposit_0efe6a8b_deposit_cap_unchanged(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);

    // call function under test
    shares = deposit(e, depositAsset, depositAmount, minimumMint);

    // assign all the 'after' variables
    uint112 currentContract_depositCap_after = currentContract.depositCap;

    // verify integrity
    assert (((((!(currentContract_isPaused_before) && currentContract_assetData_depositAsset__allowDeposits_before) && (depositAmount > 0)) && (shares >= minimumMint)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) => (currentContract_depositCap_after == currentContract_depositCap_before)), "!isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) => depositCap@after == depositCap@before";
}

/*
 * !isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) && user != msg.sender => beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before
 *
 * What it means: A user's deposit should not affect other users' shareUnlockTime
 *
 * Why it should hold: Each user's share lock should be independent - one user's actions shouldn't affect others' lock status
 *
 * Possible consequences: Users could unlock others' shares prematurely or extend others' lock periods maliciously
 */
rule deposit_0efe6a8b_other_users_unchanged(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;
    address user;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_before = currentContract.beforeTransferData[user].shareUnlockTime;

    // call function under test
    shares = deposit(e, depositAsset, depositAmount, minimumMint);

    // assign all the 'after' variables
    uint256 currentContract_beforeTransferData_user__shareUnlockTime_after = currentContract.beforeTransferData[user].shareUnlockTime;

    // verify integrity
    assert ((((((!(currentContract_isPaused_before) && currentContract_assetData_depositAsset__allowDeposits_before) && (depositAmount > 0)) && (shares >= minimumMint)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) && (user != e.msg.sender)) => (currentContract_beforeTransferData_user__shareUnlockTime_after == currentContract_beforeTransferData_user__shareUnlockTime_before)), "!isPaused@before && assetData[depositAsset].allowDeposits@before && depositAmount > 0 && shares >= minimumMint && (depositCap@before == type(uint112).max || shares + vault.totalSupply()@before <= depositCap@before) && user != msg.sender => beforeTransferData[user].shareUnlockTime@after == beforeTransferData[user].shareUnlockTime@before";
}

/*
 * nonce1 != nonce2 => publicDepositHistory@before[nonce1] != publicDepositHistory@before[nonce2]
 *
 * What it means: Different nonces should never have the same deposit history hash
 *
 * Why it should hold: Each deposit should have a unique history record to prevent confusion and ensure proper refund tracking
 *
 * Possible consequences: Duplicate hashes could cause refund confusion or allow unauthorized refunds
 */
rule deposit_0efe6a8b_history_uniqueness(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 shares;
    uint256 nonce1;
    uint256 nonce2;

    // assign all the 'before' variables
    bytes32 currentContract_publicDepositHistory_nonce1__before = currentContract.publicDepositHistory[nonce1];
    bytes32 currentContract_publicDepositHistory_nonce2__before = currentContract.publicDepositHistory[nonce2];

    // call function under test
    shares = deposit(e, depositAsset, depositAmount, minimumMint);

    // assign all the 'after' variables

    // verify integrity
    assert ((nonce1 != nonce2) => (currentContract_publicDepositHistory_nonce1__before != currentContract_publicDepositHistory_nonce2__before)), "nonce1 != nonce2 => publicDepositHistory@before[nonce1] != publicDepositHistory@before[nonce2]";
}

/*
 * isPaused@before => revert
 *
 * What it means: When the contract is paused, any call to depositWithPermit must revert
 *
 * Why it should hold: The pause mechanism is a critical safety feature that allows admins to halt deposits during emergencies or maintenance. The contract explicitly checks isPaused in _beforeDeposit() and reverts with TellerWithMultiAssetSupport__Paused()
 *
 * Possible consequences: Emergency response failure - deposits could continue during security incidents, maintenance, or when the system needs to be halted
 */
rule depositWithPermit_3d935d9e_paused_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    depositWithPermit@withrevert(e, depositAsset, depositAmount, minimumMint, deadline, v, r, s);
    bool depositWithPermit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (currentContract_isPaused_before => depositWithPermit_reverted), "isPaused@before => revert";
}

/*
 * depositAmount == 0 => revert
 *
 * What it means: Attempting to deposit zero tokens must always revert
 *
 * Why it should hold: Zero-amount deposits are meaningless operations that waste gas and could be used for griefing. The _erc20Deposit function explicitly checks for depositAmount == 0 and reverts with TellerWithMultiAssetSupport__ZeroAssets()
 *
 * Possible consequences: Gas griefing attacks, state pollution with meaningless transactions, and potential bypass of deposit tracking mechanisms
 */
rule depositWithPermit_3d935d9e_zero_amount_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 shares;

    // assign all the 'before' variables

    // call function under test
    depositWithPermit@withrevert(e, depositAsset, depositAmount, minimumMint, deadline, v, r, s);
    bool depositWithPermit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((depositAmount == 0) => depositWithPermit_reverted), "depositAmount == 0 => revert";
}

/*
 * depositAsset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE => revert
 *
 * What it means: Using the native asset address (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) as depositAsset must revert
 *
 * Why it should hold: The depositWithPermit function has the revertOnNativeDeposit modifier that explicitly prevents native asset deposits, as permit functionality doesn't work with native ETH
 *
 * Possible consequences: Function call with incompatible asset type that could lead to undefined behavior or bypass intended restrictions
 */
rule depositWithPermit_3d935d9e_native_asset_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 shares;

    // assign all the 'before' variables

    // call function under test
    depositWithPermit@withrevert(e, depositAsset, depositAmount, minimumMint, deadline, v, r, s);
    bool depositWithPermit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((depositAsset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) => depositWithPermit_reverted), "depositAsset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE => revert";
}

/*
 * !assetData[depositAsset].allowDeposits@before => revert
 *
 * What it means: If an asset's allowDeposits flag is false, depositWithPermit must revert
 *
 * Why it should hold: Asset support is controlled by admin through updateAssetData(). The _beforeDeposit() function checks assetData[depositAsset].allowDeposits and reverts with TellerWithMultiAssetSupport__AssetNotSupported() if false
 *
 * Possible consequences: Unauthorized deposits of restricted or malicious tokens, bypassing admin controls over which assets can be deposited
 */
rule depositWithPermit_3d935d9e_unsupported_asset_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;

    // call function under test
    depositWithPermit@withrevert(e, depositAsset, depositAmount, minimumMint, deadline, v, r, s);
    bool depositWithPermit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (!(currentContract_assetData_depositAsset__allowDeposits_before) => depositWithPermit_reverted), "!assetData[depositAsset].allowDeposits@before => revert";
}

/*
 * depositAmount > 0 && assetData[depositAsset].allowDeposits@before && !isPaused@before => result < minimumMint => revert
 *
 * What it means: When deposit conditions are met but calculated shares are below minimumMint, the function must revert
 *
 * Why it should hold: Users specify minimumMint as slippage protection. The _erc20Deposit function calculates shares and checks if shares < minimumMint, reverting with TellerWithMultiAssetSupport__MinimumMintNotMet()
 *
 * Possible consequences: Slippage protection bypass allowing users to receive fewer shares than expected, leading to economic loss
 */
rule depositWithPermit_3d935d9e_below_minimum_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    depositWithPermit@withrevert(e, depositAsset, depositAmount, minimumMint, deadline, v, r, s);
    bool depositWithPermit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((((depositAmount > 0) && currentContract_assetData_depositAsset__allowDeposits_before) && !(currentContract_isPaused_before)) => ((shares < minimumMint) => depositWithPermit_reverted)), "depositAmount > 0 && assetData[depositAsset].allowDeposits@before && !isPaused@before => result < minimumMint => revert";
}

/*
 * depositCap@before != type(uint112).max && result + vault.totalSupply()@before > depositCap@before => revert
 *
 * What it means: When deposit would cause total supply to exceed the deposit cap, the function must revert
 *
 * Why it should hold: The contract has a depositCap to limit total vault size. The _erc20Deposit function checks if shares + vault.totalSupply() > cap and reverts with TellerWithMultiAssetSupport__DepositExceedsCap()
 *
 * Possible consequences: Vault size limits bypass, potentially leading to over-exposure, liquidity issues, or regulatory compliance violations
 */
rule depositWithPermit_3d935d9e_exceeds_cap_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 shares;

    // assign all the 'before' variables
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);

    // call function under test
    depositWithPermit@withrevert(e, depositAsset, depositAmount, minimumMint, deadline, v, r, s);
    bool depositWithPermit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((currentContract_depositCap_before != ((2 ^ 112 - 1))) && (shares + currentContract_vault_totalSupply_e__before > currentContract_depositCap_before)) => depositWithPermit_reverted), "depositCap@before != type(uint112).max && result + vault.totalSupply()@before > depositCap@before => revert";
}

/*
 * depositAmount > 0 && assetData[depositAsset].allowDeposits@before && !isPaused@before && result >= minimumMint && (depositCap@before == type(uint112).max || result + vault.totalSupply()@before <= depositCap@before) => vault.balanceOf(msg.sender)@after == vault.balanceOf(msg.sender)@before + result
 *
 * What it means: When all deposit conditions are satisfied, the user's vault balance must increase by exactly the calculated share amount
 *
 * Why it should hold: This is the core functionality - successful deposits must mint the correct number of shares to the user. The vault.enter() call should increase the user's balance by the calculated shares
 *
 * Possible consequences: Incorrect share minting leading to user fund loss or system accounting errors
 */
rule depositWithPermit_3d935d9e_valid_deposit_mints_shares(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    bool currentContract_isPaused_before = currentContract.isPaused;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);
    uint256 currentContract_vault_balanceOf_e__e_msg_sender__before = currentContract.vault.balanceOf(e, e.msg.sender);

    // call function under test
    shares = depositWithPermit(e, depositAsset, depositAmount, minimumMint, deadline, v, r, s);

    // assign all the 'after' variables
    uint256 currentContract_vault_balanceOf_e__e_msg_sender__after = currentContract.vault.balanceOf(e, e.msg.sender);

    // verify integrity
    assert ((((((depositAmount > 0) && currentContract_assetData_depositAsset__allowDeposits_before) && !(currentContract_isPaused_before)) && (shares >= minimumMint)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) => (currentContract_vault_balanceOf_e__e_msg_sender__after == currentContract_vault_balanceOf_e__e_msg_sender__before + shares)), "depositAmount > 0 && assetData[depositAsset].allowDeposits@before && !isPaused@before && result >= minimumMint && (depositCap@before == type(uint112).max || result + vault.totalSupply()@before <= depositCap@before) => vault.balanceOf(msg.sender)@after == vault.balanceOf(msg.sender)@before + result";
}

/*
 * depositAmount > 0 && assetData[depositAsset].allowDeposits@before && !isPaused@before && result >= minimumMint && (depositCap@before == type(uint112).max || result + vault.totalSupply()@before <= depositCap@before) => depositNonce@after == depositNonce@before + 1
 *
 * What it means: Every successful deposit must increment the depositNonce by exactly 1
 *
 * Why it should hold: The depositNonce is used for tracking deposits and generating unique deposit hashes. The _afterPublicDeposit function increments depositNonce for each deposit
 *
 * Possible consequences: Deposit tracking corruption, hash collisions in publicDepositHistory, and potential refund mechanism failures
 */
rule depositWithPermit_3d935d9e_increments_nonce(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    bool currentContract_isPaused_before = currentContract.isPaused;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;

    // call function under test
    shares = depositWithPermit(e, depositAsset, depositAmount, minimumMint, deadline, v, r, s);

    // assign all the 'after' variables
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;

    // verify integrity
    assert ((((((depositAmount > 0) && currentContract_assetData_depositAsset__allowDeposits_before) && !(currentContract_isPaused_before)) && (shares >= minimumMint)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) => (currentContract_depositNonce_after == currentContract_depositNonce_before + 1)), "depositAmount > 0 && assetData[depositAsset].allowDeposits@before && !isPaused@before && result >= minimumMint && (depositCap@before == type(uint112).max || result + vault.totalSupply()@before <= depositCap@before) => depositNonce@after == depositNonce@before + 1";
}

/*
 * shareLockPeriod@before > 0 && depositAmount > 0 && assetData[depositAsset].allowDeposits@before && !isPaused@before && result >= minimumMint && (depositCap@before == type(uint112).max || result + vault.totalSupply()@before <= depositCap@before) => beforeTransferData[msg.sender].shareUnlockTime@after == block.timestamp + shareLockPeriod@before
 *
 * What it means: When shareLockPeriod > 0 and deposit succeeds, the user's shareUnlockTime must be set to current timestamp plus the lock period
 *
 * Why it should hold: Share locking prevents immediate transfers and enables the refund mechanism. The _afterPublicDeposit function sets beforeTransferData[user].shareUnlockTime when shareLockPeriod > 0
 *
 * Possible consequences: Share lock mechanism failure allowing immediate transfers and preventing refunds during the intended lock period
 */
rule depositWithPermit_3d935d9e_sets_share_unlock(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 shares;

    // assign all the 'before' variables
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    bool currentContract_isPaused_before = currentContract.isPaused;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);

    // call function under test
    shares = depositWithPermit(e, depositAsset, depositAmount, minimumMint, deadline, v, r, s);

    // assign all the 'after' variables
    uint256 currentContract_beforeTransferData_e_msg_sender__shareUnlockTime_after = currentContract.beforeTransferData[e.msg.sender].shareUnlockTime;

    // verify integrity
    assert (((((((currentContract_shareLockPeriod_before > 0) && (depositAmount > 0)) && currentContract_assetData_depositAsset__allowDeposits_before) && !(currentContract_isPaused_before)) && (shares >= minimumMint)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) => (currentContract_beforeTransferData_e_msg_sender__shareUnlockTime_after == e.block.timestamp + currentContract_shareLockPeriod_before)), "shareLockPeriod@before > 0 && depositAmount > 0 && assetData[depositAsset].allowDeposits@before && !isPaused@before && result >= minimumMint && (depositCap@before == type(uint112).max || result + vault.totalSupply()@before <= depositCap@before) => beforeTransferData[msg.sender].shareUnlockTime@after == block.timestamp + shareLockPeriod@before";
}

/*
 * shareLockPeriod@before == 0 && depositAmount > 0 && assetData[depositAsset].allowDeposits@before && !isPaused@before && result >= minimumMint && (depositCap@before == type(uint112).max || result + vault.totalSupply()@before <= depositCap@before) => beforeTransferData[msg.sender].shareUnlockTime@after == beforeTransferData[msg.sender].shareUnlockTime@before
 *
 * What it means: When shareLockPeriod is 0 and deposit succeeds, the user's shareUnlockTime must remain unchanged
 *
 * Why it should hold: When there's no lock period, the unlock time shouldn't be modified. The _afterPublicDeposit function only sets shareUnlockTime when currentShareLockPeriod > 0
 *
 * Possible consequences: Unintended share locking when no lock period is configured, preventing legitimate transfers
 */
rule depositWithPermit_3d935d9e_no_unlock_when_zero_period(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 shares;

    // assign all the 'before' variables
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    bool currentContract_isPaused_before = currentContract.isPaused;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);
    uint256 currentContract_beforeTransferData_e_msg_sender__shareUnlockTime_before = currentContract.beforeTransferData[e.msg.sender].shareUnlockTime;

    // call function under test
    shares = depositWithPermit(e, depositAsset, depositAmount, minimumMint, deadline, v, r, s);

    // assign all the 'after' variables
    uint256 currentContract_beforeTransferData_e_msg_sender__shareUnlockTime_after = currentContract.beforeTransferData[e.msg.sender].shareUnlockTime;

    // verify integrity
    assert (((((((currentContract_shareLockPeriod_before == 0) && (depositAmount > 0)) && currentContract_assetData_depositAsset__allowDeposits_before) && !(currentContract_isPaused_before)) && (shares >= minimumMint)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) => (currentContract_beforeTransferData_e_msg_sender__shareUnlockTime_after == currentContract_beforeTransferData_e_msg_sender__shareUnlockTime_before)), "shareLockPeriod@before == 0 && depositAmount > 0 && assetData[depositAsset].allowDeposits@before && !isPaused@before && result >= minimumMint && (depositCap@before == type(uint112).max || result + vault.totalSupply()@before <= depositCap@before) => beforeTransferData[msg.sender].shareUnlockTime@after == beforeTransferData[msg.sender].shareUnlockTime@before";
}

/*
 * assetData[depositAsset].sharePremium@before > 0 && depositAmount > 0 && assetData[depositAsset].allowDeposits@before && !isPaused@before && (depositCap@before == type(uint112).max || result + vault.totalSupply()@before <= depositCap@before) => result < depositAmount * ONE_SHARE / accountant.getRateInQuoteSafe(depositAsset)@before
 *
 * What it means: When an asset has a share premium > 0, the minted shares must be less than the base calculation (depositAmount * ONE_SHARE / rate)
 *
 * Why it should hold: Share premiums reduce the shares minted as a fee mechanism. The _erc20Deposit function applies the premium: shares = shares.mulDivDown(1e4 - asset.sharePremium, 1e4)
 *
 * Possible consequences: Fee mechanism bypass allowing users to receive more shares than intended, reducing protocol revenue
 */
rule depositWithPermit_3d935d9e_share_premium_reduces(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 shares;

    // assign all the 'before' variables
    uint16 currentContract_assetData_depositAsset__sharePremium_before = currentContract.assetData[depositAsset].sharePremium;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    bool currentContract_isPaused_before = currentContract.isPaused;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);
    uint256 currentContract_accountant_getRateInQuoteSafe_e__depositAsset__before = currentContract.getRateInQuoteSafe(e, depositAsset);

    // call function under test
    shares = depositWithPermit(e, depositAsset, depositAmount, minimumMint, deadline, v, r, s);

    // assign all the 'after' variables

    // verify integrity
    assert ((((((currentContract_assetData_depositAsset__sharePremium_before > 0) && (depositAmount > 0)) && currentContract_assetData_depositAsset__allowDeposits_before) && !(currentContract_isPaused_before)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) => (shares < depositAmount * currentContract.ONE_SHARE / currentContract_accountant_getRateInQuoteSafe_e__depositAsset__before)), "assetData[depositAsset].sharePremium@before > 0 && depositAmount > 0 && assetData[depositAsset].allowDeposits@before && !isPaused@before && (depositCap@before == type(uint112).max || result + vault.totalSupply()@before <= depositCap@before) => result < depositAmount * ONE_SHARE / accountant.getRateInQuoteSafe(depositAsset)@before";
}

/*
 * assetData[depositAsset].sharePremium@before == 0 && depositAmount > 0 && assetData[depositAsset].allowDeposits@before && !isPaused@before && (depositCap@before == type(uint112).max || result + vault.totalSupply()@before <= depositCap@before) => result == depositAmount * ONE_SHARE / accountant.getRateInQuoteSafe(depositAsset)@before
 *
 * What it means: When an asset has no share premium (sharePremium = 0), minted shares must equal the base calculation exactly
 *
 * Why it should hold: Assets without premiums should mint shares at the exact rate without any reduction. The _erc20Deposit function only applies premium when asset.sharePremium > 0
 *
 * Possible consequences: Incorrect share calculation leading to user receiving fewer shares than deserved when no fee should apply
 */
rule depositWithPermit_3d935d9e_no_premium_exact_shares(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 shares;

    // assign all the 'before' variables
    uint16 currentContract_assetData_depositAsset__sharePremium_before = currentContract.assetData[depositAsset].sharePremium;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    bool currentContract_isPaused_before = currentContract.isPaused;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);
    uint256 currentContract_accountant_getRateInQuoteSafe_e__depositAsset__before = currentContract.getRateInQuoteSafe(e, depositAsset);

    // call function under test
    shares = depositWithPermit(e, depositAsset, depositAmount, minimumMint, deadline, v, r, s);

    // assign all the 'after' variables

    // verify integrity
    assert ((((((currentContract_assetData_depositAsset__sharePremium_before == 0) && (depositAmount > 0)) && currentContract_assetData_depositAsset__allowDeposits_before) && !(currentContract_isPaused_before)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (shares + currentContract_vault_totalSupply_e__before <= currentContract_depositCap_before))) => (shares == depositAmount * currentContract.ONE_SHARE / currentContract_accountant_getRateInQuoteSafe_e__depositAsset__before)), "assetData[depositAsset].sharePremium@before == 0 && depositAmount > 0 && assetData[depositAsset].allowDeposits@before && !isPaused@before && (depositCap@before == type(uint112).max || result + vault.totalSupply()@before <= depositCap@before) => result == depositAmount * ONE_SHARE / accountant.getRateInQuoteSafe(depositAsset)@before";
}

/*
 * locked@before == 1 => revert
 *
 * What it means: If the contract is already in a locked state (locked = 1), any call to depositWithPermit must revert
 *
 * Why it should hold: The nonReentrant modifier protects against reentrancy attacks by setting locked = 1 during execution and reverting if already locked
 *
 * Possible consequences: Reentrancy attacks allowing manipulation of contract state during execution, potentially leading to fund theft or double-spending
 */
rule depositWithPermit_3d935d9e_reentrancy_protected(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 shares;

    // assign all the 'before' variables
    uint256 currentContract_locked_before = currentContract.locked;

    // call function under test
    depositWithPermit@withrevert(e, depositAsset, depositAmount, minimumMint, deadline, v, r, s);
    bool depositWithPermit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_locked_before == 1) => depositWithPermit_reverted), "locked@before == 1 => revert";
}

/*
 * depositAsset.allowance(msg.sender, vault)@before < depositAmount => revert
 *
 * What it means: If the permit call fails and the user's allowance is insufficient for the deposit, the function must revert
 *
 * Why it should hold: The _handlePermit function tries permit and falls back to checking allowance. If both fail, the deposit cannot proceed as the vault cannot transfer the user's tokens
 *
 * Possible consequences: Deposits proceeding without proper token approval, leading to failed transfers and inconsistent state
 */
rule depositWithPermit_3d935d9e_permit_failure_low_allowance(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 shares;

    // assign all the 'before' variables
    uint256 depositAsset_allowance_e__e_msg_sender__currentContract_vault__before = depositAsset.allowance(e, e.msg.sender, currentContract.vault);

    // call function under test
    depositWithPermit@withrevert(e, depositAsset, depositAmount, minimumMint, deadline, v, r, s);
    bool depositWithPermit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((depositAsset_allowance_e__e_msg_sender__currentContract_vault__before < depositAmount) => depositWithPermit_reverted), "depositAsset.allowance(msg.sender, vault)@before < depositAmount => revert";
}

/*
 * isPaused@before => revert
 *
 * What it means: The function must revert when the contract is in a paused state
 *
 * Why it should hold: The contract has a pause mechanism controlled by admin roles to halt deposits during emergencies or maintenance. The bulkDeposit function should respect this pause state like other deposit functions
 *
 * Possible consequences: Bypassing pause controls could allow deposits during emergency situations, potentially exposing funds to known vulnerabilities or preventing proper maintenance
 */
rule bulkDeposit_9d574420_paused_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    bulkDeposit@withrevert(e, depositAsset, depositAmount, minimumMint, to);
    bool bulkDeposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (currentContract_isPaused_before => bulkDeposit_reverted), "isPaused@before => revert";
}

/*
 * depositAmount == 0 => revert
 *
 * What it means: The function must revert when depositAmount parameter is zero
 *
 * Why it should hold: Zero-amount deposits are meaningless operations that waste gas and could be used to spam the system or trigger unintended state changes
 *
 * Possible consequences: DoS attacks through gas-wasting spam transactions, potential state corruption if zero amounts cause division by zero or other edge cases
 */
rule bulkDeposit_9d574420_zero_amount_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables

    // call function under test
    bulkDeposit@withrevert(e, depositAsset, depositAmount, minimumMint, to);
    bool bulkDeposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((depositAmount == 0) => bulkDeposit_reverted), "depositAmount == 0 => revert";
}

/*
 * !assetData[depositAsset].allowDeposits@before => revert
 *
 * What it means: The function must revert when trying to deposit an asset that is not configured to allow deposits
 *
 * Why it should hold: The contract maintains an allowlist of assets through assetData mapping. Only assets explicitly configured with allowDeposits=true should be accepted
 *
 * Possible consequences: Accepting unauthorized assets could lead to pricing errors, liquidity issues, or deposits of worthless/malicious tokens
 */
rule bulkDeposit_9d574420_asset_not_allowed_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;

    // call function under test
    bulkDeposit@withrevert(e, depositAsset, depositAmount, minimumMint, to);
    bool bulkDeposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (!(currentContract_assetData_depositAsset__allowDeposits_before) => bulkDeposit_reverted), "!assetData[depositAsset].allowDeposits@before => revert";
}

/*
 * depositAsset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE => revert
 *
 * What it means: The function must revert when depositAsset is the native ETH placeholder address (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
 *
 * Why it should hold: The contract documentation explicitly states bulkDeposit does NOT support native deposits, unlike the regular deposit function
 *
 * Possible consequences: Native ETH handling requires special logic for wrapping/unwrapping. Accepting native deposits without proper handling could lock ETH permanently
 */
rule bulkDeposit_9d574420_native_deposit_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables

    // call function under test
    bulkDeposit@withrevert(e, depositAsset, depositAmount, minimumMint, to);
    bool bulkDeposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((depositAsset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) => bulkDeposit_reverted), "depositAsset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE => revert";
}

/*
 * depositCap@before != type(uint112).max && vault.totalSupply()@before + shares > depositCap@before => revert
 *
 * What it means: The function must revert when the deposit would cause total vault shares to exceed the configured deposit cap
 *
 * Why it should hold: The contract has a depositCap mechanism to limit total vault size for risk management. All deposits must respect this limit
 *
 * Possible consequences: Bypassing deposit caps could lead to excessive vault growth beyond risk tolerance, potential liquidity issues, or regulatory compliance violations
 */
rule bulkDeposit_9d574420_exceeds_cap_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);

    // call function under test
    bulkDeposit@withrevert(e, depositAsset, depositAmount, minimumMint, to);
    bool bulkDeposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((currentContract_depositCap_before != ((2 ^ 112 - 1))) && (currentContract_vault_totalSupply_e__before + shares > currentContract_depositCap_before)) => bulkDeposit_reverted), "depositCap@before != type(uint112).max && vault.totalSupply()@before + shares > depositCap@before => revert";
}

/*
 * shares < minimumMint => revert
 *
 * What it means: The function must revert when the calculated shares amount is less than the minimumMint parameter
 *
 * Why it should hold: Users specify minimumMint to protect against slippage and ensure they receive adequate shares for their deposit
 *
 * Possible consequences: Users could receive fewer shares than expected due to price movements or calculation errors, leading to financial losses
 */
rule bulkDeposit_9d574420_below_minimum_reverts(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables

    // call function under test
    bulkDeposit@withrevert(e, depositAsset, depositAmount, minimumMint, to);
    bool bulkDeposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((shares < minimumMint) => bulkDeposit_reverted), "shares < minimumMint => revert";
}

/*
 * !isPaused@before && depositAmount > 0 && assetData[depositAsset].allowDeposits@before && shares >= minimumMint => beforeTransferData[to].shareUnlockTime@after == beforeTransferData[to].shareUnlockTime@before
 *
 * What it means: The function must not set share unlock times for the recipient address, keeping their existing unlock time unchanged
 *
 * Why it should hold: bulkDeposit is for institutional/solver use and should not impose share locks like regular user deposits do
 *
 * Possible consequences: Incorrectly locking shares could prevent legitimate transfers or withdrawals by institutional users
 */
rule bulkDeposit_9d574420_no_share_lock(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    uint256 currentContract_beforeTransferData_to__shareUnlockTime_before = currentContract.beforeTransferData[to].shareUnlockTime;

    // call function under test
    shares = bulkDeposit(e, depositAsset, depositAmount, minimumMint, to);

    // assign all the 'after' variables
    uint256 currentContract_beforeTransferData_to__shareUnlockTime_after = currentContract.beforeTransferData[to].shareUnlockTime;

    // verify integrity
    assert ((((!(currentContract_isPaused_before) && (depositAmount > 0)) && currentContract_assetData_depositAsset__allowDeposits_before) && (shares >= minimumMint)) => (currentContract_beforeTransferData_to__shareUnlockTime_after == currentContract_beforeTransferData_to__shareUnlockTime_before)), "!isPaused@before && depositAmount > 0 && assetData[depositAsset].allowDeposits@before && shares >= minimumMint => beforeTransferData[to].shareUnlockTime@after == beforeTransferData[to].shareUnlockTime@before";
}

/*
 * depositNonce@after == depositNonce@before
 *
 * What it means: The function must not increment the deposit nonce counter
 *
 * Why it should hold: Deposit nonce is used for tracking refundable public deposits. bulkDeposit is not refundable so should not consume nonce values
 *
 * Possible consequences: Incorrectly incrementing nonce could interfere with refund mechanisms for regular deposits
 */
rule bulkDeposit_9d574420_deposit_nonce_unchanged(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables
    uint64 currentContract_depositNonce_before = currentContract.depositNonce;

    // call function under test
    shares = bulkDeposit(e, depositAsset, depositAmount, minimumMint, to);

    // assign all the 'after' variables
    uint64 currentContract_depositNonce_after = currentContract.depositNonce;

    // verify integrity
    assert (currentContract_depositNonce_after == currentContract_depositNonce_before), "depositNonce@after == depositNonce@before";
}

/*
 * !isPaused@before && depositAmount > 0 && assetData[depositAsset].allowDeposits@before && shares >= minimumMint && (depositCap@before == type(uint112).max || vault.totalSupply()@before + shares <= depositCap@before) => result == shares
 *
 * What it means: The function must return the calculated shares amount when the deposit is successful
 *
 * Why it should hold: Callers need to know how many shares were minted to properly account for the transaction and update their records
 *
 * Possible consequences: Incorrect return values could lead to accounting errors in calling contracts or systems
 */
rule bulkDeposit_9d574420_returns_share_amount(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    uint112 currentContract_depositCap_before = currentContract.depositCap;
    uint256 currentContract_vault_totalSupply_e__before = currentContract.vault.totalSupply(e);

    // call function under test
    shares = bulkDeposit(e, depositAsset, depositAmount, minimumMint, to);

    // assign all the 'after' variables

    // verify integrity
    assert (((((!(currentContract_isPaused_before) && (depositAmount > 0)) && currentContract_assetData_depositAsset__allowDeposits_before) && (shares >= minimumMint)) && ((currentContract_depositCap_before == ((2 ^ 112 - 1))) || (currentContract_vault_totalSupply_e__before + shares <= currentContract_depositCap_before))) => (shares == shares)), "!isPaused@before && depositAmount > 0 && assetData[depositAsset].allowDeposits@before && shares >= minimumMint && (depositCap@before == type(uint112).max || vault.totalSupply()@before + shares <= depositCap@before) => result == shares";
}

/*
 * locked@before != 1 => revert
 *
 * What it means: The function must revert if called during an ongoing execution (reentrancy attack)
 *
 * Why it should hold: The function has nonReentrant modifier to prevent reentrancy attacks during external calls
 *
 * Possible consequences: Reentrancy attacks could allow multiple deposits in a single transaction, potentially draining the vault or manipulating prices
 */
rule bulkDeposit_9d574420_reentrancy_protected(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables
    uint256 currentContract_locked_before = currentContract.locked;

    // call function under test
    bulkDeposit@withrevert(e, depositAsset, depositAmount, minimumMint, to);
    bool bulkDeposit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_locked_before != 1) => bulkDeposit_reverted), "locked@before != 1 => revert";
}

/*
 * isPaused@after == isPaused@before
 *
 * What it means: The function must not modify the isPaused state variable
 *
 * Why it should hold: Only authorized admin functions should be able to change pause state. bulkDeposit is a deposit function, not an admin function
 *
 * Possible consequences: Unauthorized pause state changes could disrupt contract operations or bypass security controls
 */
rule bulkDeposit_9d574420_storage_unchanged_paused(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_isPaused_before = currentContract.isPaused;

    // call function under test
    shares = bulkDeposit(e, depositAsset, depositAmount, minimumMint, to);

    // assign all the 'after' variables
    bool currentContract_isPaused_after = currentContract.isPaused;

    // verify integrity
    assert (currentContract_isPaused_after == currentContract_isPaused_before), "isPaused@after == isPaused@before";
}

/*
 * depositCap@after == depositCap@before
 *
 * What it means: The function must not modify the depositCap state variable
 *
 * Why it should hold: Only authorized admin functions should modify deposit caps. bulkDeposit should respect existing caps, not change them
 *
 * Possible consequences: Unauthorized cap changes could bypass risk management controls or enable excessive deposits
 */
rule bulkDeposit_9d574420_storage_unchanged_cap(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables
    uint112 currentContract_depositCap_before = currentContract.depositCap;

    // call function under test
    shares = bulkDeposit(e, depositAsset, depositAmount, minimumMint, to);

    // assign all the 'after' variables
    uint112 currentContract_depositCap_after = currentContract.depositCap;

    // verify integrity
    assert (currentContract_depositCap_after == currentContract_depositCap_before), "depositCap@after == depositCap@before";
}

/*
 * assetData[depositAsset].allowDeposits@after == assetData[depositAsset].allowDeposits@before && assetData[depositAsset].allowWithdraws@after == assetData[depositAsset].allowWithdraws@before && assetData[depositAsset].sharePremium@after == assetData[depositAsset].sharePremium@before
 *
 * What it means: The function must not modify any fields of the assetData mapping for the deposit asset
 *
 * Why it should hold: Only authorized admin functions should modify asset configurations. bulkDeposit should use existing settings, not change them
 *
 * Possible consequences: Unauthorized asset configuration changes could enable deposits of restricted assets or bypass premium calculations
 */
rule bulkDeposit_9d574420_storage_unchanged_asset(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_assetData_depositAsset__allowDeposits_before = currentContract.assetData[depositAsset].allowDeposits;
    bool currentContract_assetData_depositAsset__allowWithdraws_before = currentContract.assetData[depositAsset].allowWithdraws;
    uint16 currentContract_assetData_depositAsset__sharePremium_before = currentContract.assetData[depositAsset].sharePremium;

    // call function under test
    shares = bulkDeposit(e, depositAsset, depositAmount, minimumMint, to);

    // assign all the 'after' variables
    bool currentContract_assetData_depositAsset__allowDeposits_after = currentContract.assetData[depositAsset].allowDeposits;
    bool currentContract_assetData_depositAsset__allowWithdraws_after = currentContract.assetData[depositAsset].allowWithdraws;
    uint16 currentContract_assetData_depositAsset__sharePremium_after = currentContract.assetData[depositAsset].sharePremium;

    // verify integrity
    assert (((currentContract_assetData_depositAsset__allowDeposits_after == currentContract_assetData_depositAsset__allowDeposits_before) && (currentContract_assetData_depositAsset__allowWithdraws_after == currentContract_assetData_depositAsset__allowWithdraws_before)) && (currentContract_assetData_depositAsset__sharePremium_after == currentContract_assetData_depositAsset__sharePremium_before)), "assetData[depositAsset].allowDeposits@after == assetData[depositAsset].allowDeposits@before && assetData[depositAsset].allowWithdraws@after == assetData[depositAsset].allowWithdraws@before && assetData[depositAsset].sharePremium@after == assetData[depositAsset].sharePremium@before";
}

/*
 * publicDepositHistory[0]@after == publicDepositHistory[0]@before
 *
 * What it means: The function must not modify the publicDepositHistory mapping
 *
 * Why it should hold: Public deposit history is only for refundable user deposits. bulkDeposit is not refundable so should not create history entries
 *
 * Possible consequences: Incorrect history entries could interfere with refund mechanisms or create confusion about refundable deposits
 */
rule bulkDeposit_9d574420_no_public_history_update(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables
    bytes32 currentContract_publicDepositHistory_0__before = currentContract.publicDepositHistory[0];

    // call function under test
    shares = bulkDeposit(e, depositAsset, depositAmount, minimumMint, to);

    // assign all the 'after' variables
    bytes32 currentContract_publicDepositHistory_0__after = currentContract.publicDepositHistory[0];

    // verify integrity
    assert (currentContract_publicDepositHistory_0__after == currentContract_publicDepositHistory_0__before), "publicDepositHistory[0]@after == publicDepositHistory[0]@before";
}

/*
 * permissionedTransfers@after == permissionedTransfers@before
 *
 * What it means: The function must not modify the permissionedTransfers boolean flag
 *
 * Why it should hold: Only admin functions should control transfer permission settings. bulkDeposit is a deposit function with no authority over transfer controls
 *
 * Possible consequences: Unauthorized changes to transfer permissions could bypass access controls or restrict legitimate transfers
 */
rule bulkDeposit_9d574420_permissioned_transfers_unchanged(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_permissionedTransfers_before = currentContract.permissionedTransfers;

    // call function under test
    shares = bulkDeposit(e, depositAsset, depositAmount, minimumMint, to);

    // assign all the 'after' variables
    bool currentContract_permissionedTransfers_after = currentContract.permissionedTransfers;

    // verify integrity
    assert (currentContract_permissionedTransfers_after == currentContract_permissionedTransfers_before), "permissionedTransfers@after == permissionedTransfers@before";
}

/*
 * shareLockPeriod@after == shareLockPeriod@before
 *
 * What it means: The function must not modify the global shareLockPeriod setting
 *
 * Why it should hold: Only admin functions should modify global lock period settings. bulkDeposit should not have authority over these security parameters
 *
 * Possible consequences: Unauthorized lock period changes could affect security of future deposits or bypass intended lock mechanisms
 */
rule bulkDeposit_9d574420_share_lock_period_unchanged(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables
    uint64 currentContract_shareLockPeriod_before = currentContract.shareLockPeriod;

    // call function under test
    shares = bulkDeposit(e, depositAsset, depositAmount, minimumMint, to);

    // assign all the 'after' variables
    uint64 currentContract_shareLockPeriod_after = currentContract.shareLockPeriod;

    // verify integrity
    assert (currentContract_shareLockPeriod_after == currentContract_shareLockPeriod_before), "shareLockPeriod@after == shareLockPeriod@before";
}

/*
 * beforeTransferData[msg.sender].denyFrom@after == beforeTransferData[msg.sender].denyFrom@before && beforeTransferData[msg.sender].denyTo@after == beforeTransferData[msg.sender].denyTo@before && beforeTransferData[msg.sender].denyOperator@after == beforeTransferData[msg.sender].denyOperator@before && beforeTransferData[msg.sender].permissionedOperator@after == beforeTransferData[msg.sender].permissionedOperator@before
 *
 * What it means: The function must not modify any deny/allow flags or permissions for the caller in beforeTransferData mapping
 *
 * Why it should hold: Only admin functions should modify user permissions and deny lists. bulkDeposit should not have authority over access controls
 *
 * Possible consequences: Unauthorized permission changes could bypass security controls or grant/revoke access inappropriately
 */
rule bulkDeposit_9d574420_before_transfer_data_unchanged(env e) {
    address depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
    uint256 shares;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_e_msg_sender__denyFrom_before = currentContract.beforeTransferData[e.msg.sender].denyFrom;
    bool currentContract_beforeTransferData_e_msg_sender__denyTo_before = currentContract.beforeTransferData[e.msg.sender].denyTo;
    bool currentContract_beforeTransferData_e_msg_sender__denyOperator_before = currentContract.beforeTransferData[e.msg.sender].denyOperator;
    bool currentContract_beforeTransferData_e_msg_sender__permissionedOperator_before = currentContract.beforeTransferData[e.msg.sender].permissionedOperator;

    // call function under test
    shares = bulkDeposit(e, depositAsset, depositAmount, minimumMint, to);

    // assign all the 'after' variables
    bool currentContract_beforeTransferData_e_msg_sender__denyFrom_after = currentContract.beforeTransferData[e.msg.sender].denyFrom;
    bool currentContract_beforeTransferData_e_msg_sender__denyTo_after = currentContract.beforeTransferData[e.msg.sender].denyTo;
    bool currentContract_beforeTransferData_e_msg_sender__denyOperator_after = currentContract.beforeTransferData[e.msg.sender].denyOperator;
    bool currentContract_beforeTransferData_e_msg_sender__permissionedOperator_after = currentContract.beforeTransferData[e.msg.sender].permissionedOperator;

    // verify integrity
    assert ((((currentContract_beforeTransferData_e_msg_sender__denyFrom_after == currentContract_beforeTransferData_e_msg_sender__denyFrom_before) && (currentContract_beforeTransferData_e_msg_sender__denyTo_after == currentContract_beforeTransferData_e_msg_sender__denyTo_before)) && (currentContract_beforeTransferData_e_msg_sender__denyOperator_after == currentContract_beforeTransferData_e_msg_sender__denyOperator_before)) && (currentContract_beforeTransferData_e_msg_sender__permissionedOperator_after == currentContract_beforeTransferData_e_msg_sender__permissionedOperator_before)), "beforeTransferData[msg.sender].denyFrom@after == beforeTransferData[msg.sender].denyFrom@before && beforeTransferData[msg.sender].denyTo@after == beforeTransferData[msg.sender].denyTo@before && beforeTransferData[msg.sender].denyOperator@after == beforeTransferData[msg.sender].denyOperator@before && beforeTransferData[msg.sender].permissionedOperator@after == beforeTransferData[msg.sender].permissionedOperator@before";
}

/*
 * shareAmount == 0 => revert
 *
 * What it means: The function must revert when shareAmount is zero, preventing meaningless withdrawal operations
 *
 * Why it should hold: Zero-share withdrawals serve no purpose and waste gas. The contract should enforce that all operations have meaningful impact, following the NO-OP MUST REVERT principle
 *
 * Possible consequences: Gas waste, potential griefing attacks, and violation of expected contract behavior where operations should be meaningful
 */
rule bulkWithdraw_3e64ce99_zero_shares_revert(env e) {
    address withdrawAsset;
    uint256 shareAmount;
    uint256 minimumAssets;
    address to;
    uint256 assetsOut;

    // assign all the 'before' variables

    // call function under test
    bulkWithdraw@withrevert(e, withdrawAsset, shareAmount, minimumAssets, to);
    bool bulkWithdraw_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((shareAmount == 0) => bulkWithdraw_reverted), "shareAmount == 0 => revert";
}

/*
 * !assetData[withdrawAsset].allowWithdraws@before => revert
 *
 * What it means: The function must revert when attempting to withdraw an asset that is not configured to allow withdrawals in the assetData mapping
 *
 * Why it should hold: The contract has explicit asset configuration through assetData.allowWithdraws flag. This is a core access control mechanism that prevents withdrawals of assets that should not be withdrawable
 *
 * Possible consequences: Unauthorized asset withdrawals, bypassing of asset-specific restrictions, and violation of the vault's asset management policies
 */
rule bulkWithdraw_3e64ce99_asset_not_allowed_revert(env e) {
    address withdrawAsset;
    uint256 shareAmount;
    uint256 minimumAssets;
    address to;
    uint256 assetsOut;

    // assign all the 'before' variables
    bool currentContract_assetData_withdrawAsset__allowWithdraws_before = currentContract.assetData[withdrawAsset].allowWithdraws;

    // call function under test
    bulkWithdraw@withrevert(e, withdrawAsset, shareAmount, minimumAssets, to);
    bool bulkWithdraw_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (!(currentContract_assetData_withdrawAsset__allowWithdraws_before) => bulkWithdraw_reverted), "!assetData[withdrawAsset].allowWithdraws@before => revert";
}

/*
 * shareAmount > vault.balanceOf(msg.sender)@before => revert
 *
 * What it means: The function must revert when the caller attempts to withdraw more shares than they currently own
 *
 * Why it should hold: This is a fundamental balance check that prevents users from withdrawing more than they own, which would be impossible and could lead to accounting errors
 *
 * Possible consequences: Accounting corruption, potential for negative balances, and violation of basic token economics
 */
rule bulkWithdraw_3e64ce99_shares_exceed_balance_revert(env e) {
    address withdrawAsset;
    uint256 shareAmount;
    uint256 minimumAssets;
    address to;
    uint256 assetsOut;

    // assign all the 'before' variables
    uint256 currentContract_vault_balanceOf_e__e_msg_sender__before = currentContract.vault.balanceOf(e, e.msg.sender);

    // call function under test
    bulkWithdraw@withrevert(e, withdrawAsset, shareAmount, minimumAssets, to);
    bool bulkWithdraw_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((shareAmount > currentContract_vault_balanceOf_e__e_msg_sender__before) => bulkWithdraw_reverted), "shareAmount > vault.balanceOf(msg.sender)@before => revert";
}

/*
 * result < minimumAssets => revert
 *
 * What it means: The function must revert when the calculated assets to be withdrawn (result) is less than the minimum required by the caller
 *
 * Why it should hold: This protects users from receiving less assets than expected due to slippage, price changes, or calculation errors. It's a critical user protection mechanism
 *
 * Possible consequences: Users receiving insufficient assets due to unfavorable price movements or calculation errors, leading to financial losses
 */
rule bulkWithdraw_3e64ce99_below_minimum_assets_revert(env e) {
    address withdrawAsset;
    uint256 shareAmount;
    uint256 minimumAssets;
    address to;
    uint256 assetsOut;

    // assign all the 'before' variables

    // call function under test
    bulkWithdraw@withrevert(e, withdrawAsset, shareAmount, minimumAssets, to);
    bool bulkWithdraw_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((assetsOut < minimumAssets) => bulkWithdraw_reverted), "result < minimumAssets => revert";
}

/*
 * to == address(0) => revert
 *
 * What it means: The function must revert when the recipient address (to) is the zero address (0x0)
 *
 * Why it should hold: Sending assets to the zero address effectively burns them permanently. This is almost always unintentional and should be prevented to protect users from losing their funds
 *
 * Possible consequences: Permanent loss of withdrawn assets, as they would be sent to an unrecoverable address
 */
rule bulkWithdraw_3e64ce99_to_zero_address_revert(env e) {
    address withdrawAsset;
    uint256 shareAmount;
    uint256 minimumAssets;
    address to;
    uint256 assetsOut;

    // assign all the 'before' variables

    // call function under test
    bulkWithdraw@withrevert(e, withdrawAsset, shareAmount, minimumAssets, to);
    bool bulkWithdraw_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((to == 0) => bulkWithdraw_reverted), "to == address(0) => revert";
}

/*
 * shareAmount > 0 && assetData[withdrawAsset].allowWithdraws@before && result >= minimumAssets => result == shareAmount * accountant.getRateInQuoteSafe(withdrawAsset)@before / ONE_SHARE
 *
 * What it means: For valid withdrawals, the returned asset amount should equal the share amount multiplied by the asset's rate divided by ONE_SHARE
 *
 * Why it should hold: This ensures correct calculation of asset amounts based on share value and exchange rates. It's the core mathematical relationship that maintains the vault's economic model
 *
 * Possible consequences: Incorrect asset payouts leading to either user losses or vault losses, disrupting the economic balance of the system
 */
rule bulkWithdraw_3e64ce99_valid_withdrawal_returns(env e) {
    address withdrawAsset;
    uint256 shareAmount;
    uint256 minimumAssets;
    address to;
    uint256 assetsOut;

    // assign all the 'before' variables
    bool currentContract_assetData_withdrawAsset__allowWithdraws_before = currentContract.assetData[withdrawAsset].allowWithdraws;
    uint256 currentContract_accountant_getRateInQuoteSafe_e__withdrawAsset__before = currentContract.getRateInQuoteSafe(e, withdrawAsset);

    // call function under test
    assetsOut = bulkWithdraw(e, withdrawAsset, shareAmount, minimumAssets, to);

    // assign all the 'after' variables

    // verify integrity
    assert ((((shareAmount > 0) && currentContract_assetData_withdrawAsset__allowWithdraws_before) && (assetsOut >= minimumAssets)) => (assetsOut == shareAmount * currentContract_accountant_getRateInQuoteSafe_e__withdrawAsset__before / currentContract.ONE_SHARE)), "shareAmount > 0 && assetData[withdrawAsset].allowWithdraws@before && result >= minimumAssets => result == shareAmount * accountant.getRateInQuoteSafe(withdrawAsset)@before / ONE_SHARE";
}

/*
 * beforeTransferData[msg.sender].denyFrom@before => revert
 *
 * What it means: The function must revert when the caller is on the deny-from list, preventing them from transferring or withdrawing their shares
 *
 * Why it should hold: This implements access control restrictions where certain addresses are blocked from moving their shares, likely for compliance or security reasons
 *
 * Possible consequences: Bypassing of compliance restrictions, allowing blocked users to move funds when they shouldn't be able to
 */
rule bulkWithdraw_3e64ce99_denied_from_revert(env e) {
    address withdrawAsset;
    uint256 shareAmount;
    uint256 minimumAssets;
    address to;
    uint256 assetsOut;

    // assign all the 'before' variables
    bool currentContract_beforeTransferData_e_msg_sender__denyFrom_before = currentContract.beforeTransferData[e.msg.sender].denyFrom;

    // call function under test
    bulkWithdraw@withrevert(e, withdrawAsset, shareAmount, minimumAssets, to);
    bool bulkWithdraw_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (currentContract_beforeTransferData_e_msg_sender__denyFrom_before => bulkWithdraw_reverted), "beforeTransferData[msg.sender].denyFrom@before => revert";
}

/*
 * beforeTransferData[msg.sender].shareUnlockTime@before > block.timestamp => revert
 *
 * What it means: The function must revert when the caller's shares are still locked (shareUnlockTime is in the future)
 *
 * Why it should hold: The contract implements a share locking mechanism where shares cannot be transferred or withdrawn until a certain time. This is part of the deposit refund system and security model
 *
 * Possible consequences: Bypassing of the share lock mechanism, allowing premature withdrawals and potentially interfering with the deposit refund system
 */
rule bulkWithdraw_3e64ce99_shares_locked_revert(env e) {
    address withdrawAsset;
    uint256 shareAmount;
    uint256 minimumAssets;
    address to;
    uint256 assetsOut;

    // assign all the 'before' variables
    uint256 currentContract_beforeTransferData_e_msg_sender__shareUnlockTime_before = currentContract.beforeTransferData[e.msg.sender].shareUnlockTime;

    // call function under test
    bulkWithdraw@withrevert(e, withdrawAsset, shareAmount, minimumAssets, to);
    bool bulkWithdraw_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_beforeTransferData_e_msg_sender__shareUnlockTime_before > e.block.timestamp) => bulkWithdraw_reverted), "beforeTransferData[msg.sender].shareUnlockTime@before > block.timestamp => revert";
}

/*
 * locked@before == 2 => revert
 *
 * What it means: The function must revert if it's called while already executing (locked state equals 2, indicating reentrancy)
 *
 * Why it should hold: The contract uses ReentrancyGuard to prevent reentrancy attacks. The locked variable tracks execution state, and value 2 indicates the function is already executing
 *
 * Possible consequences: Reentrancy attacks that could allow multiple withdrawals in a single transaction, potentially draining the vault
 */
rule bulkWithdraw_3e64ce99_reentrancy_protection(env e) {
    address withdrawAsset;
    uint256 shareAmount;
    uint256 minimumAssets;
    address to;
    uint256 assetsOut;

    // assign all the 'before' variables
    uint256 currentContract_locked_before = currentContract.locked;

    // call function under test
    bulkWithdraw@withrevert(e, withdrawAsset, shareAmount, minimumAssets, to);
    bool bulkWithdraw_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_locked_before == 2) => bulkWithdraw_reverted), "locked@before == 2 => revert";
}

/*
 * shareAmount == 0 || !assetData[withdrawAsset].allowWithdraws@before || to == address(0) => locked@after == locked@before
 *
 * What it means: When the function reverts due to invalid parameters, the locked state should remain unchanged from before to after the call
 *
 * Why it should hold: Failed operations should not modify contract state. This ensures that reverted transactions don't leave the contract in an inconsistent state
 *
 * Possible consequences: State corruption where failed transactions still modify contract state, leading to inconsistent or unpredictable behavior
 */
rule bulkWithdraw_3e64ce99_no_state_change_on_revert(env e) {
    address withdrawAsset;
    uint256 shareAmount;
    uint256 minimumAssets;
    address to;
    uint256 assetsOut;

    // assign all the 'before' variables
    bool currentContract_assetData_withdrawAsset__allowWithdraws_before = currentContract.assetData[withdrawAsset].allowWithdraws;
    uint256 currentContract_locked_before = currentContract.locked;

    // call function under test
    assetsOut = bulkWithdraw(e, withdrawAsset, shareAmount, minimumAssets, to);

    // assign all the 'after' variables
    uint256 currentContract_locked_after = currentContract.locked;

    // verify integrity
    assert ((((shareAmount == 0) || !(currentContract_assetData_withdrawAsset__allowWithdraws_before)) || (to == 0)) => (currentContract_locked_after == currentContract_locked_before)), "shareAmount == 0 || !assetData[withdrawAsset].allowWithdraws@before || to == address(0) => locked@after == locked@before";
}