import "dispatching_BoringVault.spec";

/*
 * msg.sender != owner@before => revert
 *
 * What it means: The manage function must revert if the caller is not the contract owner
 *
 * Why it should hold: The function has the requiresAuth modifier and is designed for privileged operations. Only the owner should be able to make arbitrary calls from the contract
 *
 * Possible consequences: Complete contract takeover, unauthorized fund transfers, malicious contract interactions, privilege escalation
 */
rule manage_f6e715d0_requires_auth(env e) {
    address target;
    bytes data;
    uint256 value;
    bytes result;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;

    // call function under test
    manage@withrevert(e, target, data, value);
    bool manage_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((e.msg.sender != currentContract_owner_before) => manage_reverted), "msg.sender != owner@before => revert";
}

/*
 * data.length == 0 => revert
 *
 * What it means: The manage function must revert when the data parameter is empty (zero length)
 *
 * Why it should hold: Empty calldata represents a no-op operation that provides no meaningful functionality. Following the NO-OPS MUST REVERT rule, meaningless operations should fail
 *
 * Possible consequences: Gas waste, potential state inconsistencies, unclear contract behavior
 */
rule manage_f6e715d0_empty_data_reverts(env e) {
    address target;
    bytes data;
    uint256 value;
    bytes result;

    // assign all the 'before' variables

    // call function under test
    manage@withrevert(e, target, data, value);
    bool manage_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((data.length == 0) => manage_reverted), "data.length == 0 => revert";
}

/*
 * target == address(0) => revert
 *
 * What it means: The manage function must revert when the target address is the zero address (0x0)
 *
 * Why it should hold: Calling the zero address is a meaningless operation that cannot execute any useful functionality and represents invalid input
 *
 * Possible consequences: Gas waste, failed transactions, potential state corruption
 */
rule manage_f6e715d0_zero_address_target_reverts(env e) {
    address target;
    bytes data;
    uint256 value;
    bytes result;

    // assign all the 'before' variables

    // call function under test
    manage@withrevert(e, target, data, value);
    bool manage_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((target == 0) => manage_reverted), "target == address(0) => revert";
}

/*
 * value > address(this).balance@before => revert
 *
 * What it means: The manage function must revert when the value parameter exceeds the contract's current ETH balance
 *
 * Why it should hold: The contract cannot send more ETH than it holds. This prevents impossible operations and ensures the call will not fail due to insufficient funds
 *
 * Possible consequences: Failed transactions, gas waste, potential reentrancy issues if not handled properly
 */
rule manage_f6e715d0_value_exceeds_balance_reverts(env e) {
    address target;
    bytes data;
    uint256 value;
    bytes result;

    // assign all the 'before' variables
    uint256 nativeBalances_currentContract__before = nativeBalances[currentContract];

    // call function under test
    manage@withrevert(e, target, data, value);
    bool manage_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((value > nativeBalances_currentContract__before) => manage_reverted), "value > address(this).balance@before => revert";
}

/*
 * msg.sender == owner@before && target != address(0) && data.length > 0 && value <= address(this).balance@before => result.length >= 0
 *
 * What it means: When all preconditions are met (authorized caller, valid target, non-empty data, sufficient balance), the function should return some result data
 *
 * Why it should hold: The function is designed to make arbitrary calls and return their results. If preconditions are satisfied, it should execute successfully and return the call result
 *
 * Possible consequences: Broken functionality, inability to interact with external contracts, failed integrations
 */
rule manage_f6e715d0_successful_call_returns_data(env e) {
    address target;
    bytes data;
    uint256 value;
    bytes result;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    uint256 nativeBalances_currentContract__before = nativeBalances[currentContract];

    // call function under test
    result = manage(e, target, data, value);

    // assign all the 'after' variables

    // verify integrity
    assert (((((e.msg.sender == currentContract_owner_before) && (target != 0)) && (data.length > 0)) && (value <= nativeBalances_currentContract__before)) => (result.length >= 0)), "msg.sender == owner@before && target != address(0) && data.length > 0 && value <= address(this).balance@before => result.length >= 0";
}

/*
 * targets.length != data.length || targets.length != values.length => revert
 *
 * What it means: The function must revert if the three input arrays (targets, data, values) have different lengths
 *
 * Why it should hold: The function is designed to execute multiple calls where each target corresponds to specific data and value. Mismatched array lengths would cause out-of-bounds access or incorrect parameter pairing
 *
 * Possible consequences: Out-of-bounds array access leading to undefined behavior, incorrect function calls with wrong parameters, or partial execution of intended operations
 */
rule manage_224d8703_array_length_mismatch(env e) {
    address[] targets;
    bytes[] data;
    uint256[] values;
    bytes[] results;

    // assign all the 'before' variables

    // call function under test
    manage@withrevert(e, targets, data, values);
    bool manage_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((targets.length != data.length) || (targets.length != values.length)) => manage_reverted), "targets.length != data.length || targets.length != values.length => revert";
}

/*
 * targets.length == 0 => revert
 *
 * What it means: The function must revert when called with empty arrays, preventing no-op operations
 *
 * Why it should hold: Following the NO-OPS MUST REVERT rule, calling manage with empty arrays performs no meaningful work and should be rejected rather than succeeding silently
 *
 * Possible consequences: Wasted gas costs, misleading success status for operations that accomplish nothing, potential confusion in automated systems expecting actual work to be performed
 */
rule manage_224d8703_empty_arrays(env e) {
    address[] targets;
    bytes[] data;
    uint256[] values;
    bytes[] results;

    // assign all the 'before' variables

    // call function under test
    manage@withrevert(e, targets, data, values);
    bool manage_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((targets.length == 0) => manage_reverted), "targets.length == 0 => revert";
}

/*
 * owner@after == owner@before && authority@after == authority@before
 *
 * What it means: The manage function cannot modify the contract's authorization state (owner and authority addresses)
 *
 * Why it should hold: The manage function is for external contract interactions, not for changing the vault's core authorization structure. Allowing auth changes through manage would bypass proper governance
 *
 * Possible consequences: Unauthorized privilege escalation, loss of contract control, bypassing of intended governance mechanisms
 */
rule manage_224d8703_auth_state_unchanged(env e) {
    address[] targets;
    bytes[] data;
    uint256[] values;
    bytes[] results;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    results = manage(e, targets, data, values);

    // assign all the 'after' variables
    address currentContract_owner_after = currentContract.owner;
    address currentContract_authority_after = currentContract.authority;

    // verify integrity
    assert ((currentContract_owner_after == currentContract_owner_before) && (currentContract_authority_after == currentContract_authority_before)), "owner@after == owner@before && authority@after == authority@before";
}

/*
 * hook@after == hook@before
 *
 * What it means: The manage function cannot modify the beforeTransferHook address
 *
 * Why it should hold: The hook is a critical security component that should only be changed through the dedicated setBeforeTransferHook function with proper authorization checks
 *
 * Possible consequences: Bypassing transfer restrictions, unauthorized modification of transfer behavior, potential fund theft through hook manipulation
 */
rule manage_224d8703_hook_unchanged(env e) {
    address[] targets;
    bytes[] data;
    uint256[] values;
    bytes[] results;

    // assign all the 'before' variables
    address currentContract_hook_before = currentContract.hook;

    // call function under test
    results = manage(e, targets, data, values);

    // assign all the 'after' variables
    address currentContract_hook_after = currentContract.hook;

    // verify integrity
    assert (currentContract_hook_after == currentContract_hook_before), "hook@after == hook@before";
}

/*
 * totalSupply@after == totalSupply@before
 *
 * What it means: The manage function cannot change the total supply of vault shares
 *
 * Why it should hold: Share minting and burning should only occur through the dedicated enter and exit functions with proper authorization and accounting
 *
 * Possible consequences: Unauthorized share creation or destruction, breaking the vault's economic model, potential fund theft through supply manipulation
 */
rule manage_224d8703_total_supply_unchanged(env e) {
    address[] targets;
    bytes[] data;
    uint256[] values;
    bytes[] results;

    // assign all the 'before' variables
    uint256 currentContract_totalSupply_before = currentContract.totalSupply;

    // call function under test
    results = manage(e, targets, data, values);

    // assign all the 'after' variables
    uint256 currentContract_totalSupply_after = currentContract.totalSupply;

    // verify integrity
    assert (currentContract_totalSupply_after == currentContract_totalSupply_before), "totalSupply@after == totalSupply@before";
}

/*
 * balanceOf[msg.sender]@after == balanceOf[msg.sender]@before
 *
 * What it means: The manage function cannot change the share balance of the caller
 *
 * Why it should hold: Managers should not be able to modify their own share balances through the manage function, as this would bypass proper enter/exit procedures
 *
 * Possible consequences: Self-dealing by managers, unauthorized share allocation, breaking vault accounting integrity
 */
rule manage_224d8703_balances_unchanged(env e) {
    address[] targets;
    bytes[] data;
    uint256[] values;
    bytes[] results;

    // assign all the 'before' variables
    uint256 currentContract_balanceOf_e_msg_sender__before = currentContract.balanceOf[e.msg.sender];

    // call function under test
    results = manage(e, targets, data, values);

    // assign all the 'after' variables
    uint256 currentContract_balanceOf_e_msg_sender__after = currentContract.balanceOf[e.msg.sender];

    // verify integrity
    assert (currentContract_balanceOf_e_msg_sender__after == currentContract_balanceOf_e_msg_sender__before), "balanceOf[msg.sender]@after == balanceOf[msg.sender]@before";
}

/*
 * allowance[msg.sender][owner@before]@after == allowance[msg.sender][owner@before]@before
 *
 * What it means: The manage function cannot modify the allowance between the caller and the owner
 *
 * Why it should hold: Allowances should only be modified through standard ERC20 approve mechanisms, not through the manage function which is for external operations
 *
 * Possible consequences: Unauthorized spending permissions, bypassing approval mechanisms, potential unauthorized transfers
 */
rule manage_224d8703_allowances_unchanged(env e) {
    address[] targets;
    bytes[] data;
    uint256[] values;
    bytes[] results;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    uint256 currentContract_allowance_e_msg_sender__currentContract_owner_before__before = currentContract.allowance[e.msg.sender][currentContract_owner_before];

    // call function under test
    results = manage(e, targets, data, values);

    // assign all the 'after' variables
    uint256 currentContract_allowance_e_msg_sender__currentContract_owner_before__after = currentContract.allowance[e.msg.sender][currentContract_owner_before];

    // verify integrity
    assert (currentContract_allowance_e_msg_sender__currentContract_owner_before__after == currentContract_allowance_e_msg_sender__currentContract_owner_before__before), "allowance[msg.sender][owner@before]@after == allowance[msg.sender][owner@before]@before";
}

/*
 * msg.sender != owner@before && authority@before == address(0) => revert
 *
 * What it means: The function must revert if called by someone who is not the owner when no authority contract is set
 *
 * Why it should hold: The manage function has requiresAuth modifier, so it should only be callable by authorized parties. When authority is zero address, only the owner should be able to call it
 *
 * Possible consequences: Unauthorized access to management functions, potential fund theft, unauthorized contract interactions
 */
rule manage_224d8703_unauthorized_caller(env e) {
    address[] targets;
    bytes[] data;
    uint256[] values;
    bytes[] results;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    manage@withrevert(e, targets, data, values);
    bool manage_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((e.msg.sender != currentContract_owner_before) && (currentContract_authority_before == 0)) => manage_reverted), "msg.sender != owner@before && authority@before == address(0) => revert";
}

/*
 * shareAmount == 0 => revert
 *
 * What it means: If shareAmount is zero, the function must revert and not execute
 *
 * Why it should hold: Minting zero shares is a meaningless operation that wastes gas and could indicate an error in the calling logic. The contract should prevent no-op operations to maintain clarity and prevent accidental calls
 *
 * Possible consequences: Gas waste, potential for griefing attacks through repeated meaningless calls, and masking of logic errors in calling contracts
 */
rule enter_39d6ba32_zero_shares_must_revert(env e) {
    address from;
    address asset;
    uint256 assetAmount;
    address to;
    uint256 shareAmount;

    // assign all the 'before' variables

    // call function under test
    enter@withrevert(e, from, asset, assetAmount, to, shareAmount);
    bool enter_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((shareAmount == 0) => enter_reverted), "shareAmount == 0 => revert";
}

/*
 * from == address(0) || to == address(0) => revert
 *
 * What it means: If either the from address or to address is the zero address, the function must revert
 *
 * Why it should hold: Zero addresses are invalid for token operations - you cannot transfer from or mint to the zero address as it represents a null/invalid state in Ethereum
 *
 * Possible consequences: Tokens could be permanently lost if minted to zero address, or accounting errors if attempting to transfer from zero address
 */
rule enter_39d6ba32_invalid_addresses_revert(env e) {
    address from;
    address asset;
    uint256 assetAmount;
    address to;
    uint256 shareAmount;

    // assign all the 'before' variables

    // call function under test
    enter@withrevert(e, from, asset, assetAmount, to, shareAmount);
    bool enter_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((from == 0) || (to == 0)) => enter_reverted), "from == address(0) || to == address(0) => revert";
}

/*
 * shareAmount > 0 => totalSupply@after == totalSupply@before + shareAmount
 *
 * What it means: When shareAmount is greater than zero, the total supply must increase by exactly shareAmount
 *
 * Why it should hold: This is the core invariant of minting - new shares must be added to the total supply to maintain accounting consistency
 *
 * Possible consequences: Supply accounting corruption, potential for infinite minting or supply underflow/overflow
 */
rule enter_39d6ba32_valid_mint_increases_supply(env e) {
    address from;
    address asset;
    uint256 assetAmount;
    address to;
    uint256 shareAmount;

    // assign all the 'before' variables
    uint256 currentContract_totalSupply_before = currentContract.totalSupply;

    // call function under test
    enter(e, from, asset, assetAmount, to, shareAmount);

    // assign all the 'after' variables
    uint256 currentContract_totalSupply_after = currentContract.totalSupply;

    // verify integrity
    assert ((shareAmount > 0) => (currentContract_totalSupply_after == currentContract_totalSupply_before + shareAmount)), "shareAmount > 0 => totalSupply@after == totalSupply@before + shareAmount";
}

/*
 * shareAmount > 0 => balanceOf(to)@after == balanceOf(to)@before + shareAmount
 *
 * What it means: When shareAmount is greater than zero, the recipient's balance must increase by exactly shareAmount
 *
 * Why it should hold: The minted shares must be credited to the specified recipient address to complete the minting operation correctly
 *
 * Possible consequences: Shares could be lost or credited to wrong addresses, breaking user accounting
 */
rule enter_39d6ba32_valid_mint_increases_balance(env e) {
    address from;
    address asset;
    uint256 assetAmount;
    address to;
    uint256 shareAmount;

    // assign all the 'before' variables
    uint256 balanceOf_e__to__before = balanceOf(e, to);

    // call function under test
    enter(e, from, asset, assetAmount, to, shareAmount);

    // assign all the 'after' variables
    uint256 balanceOf_e__to__after = balanceOf(e, to);

    // verify integrity
    assert ((shareAmount > 0) => (balanceOf_e__to__after == balanceOf_e__to__before + shareAmount)), "shareAmount > 0 => balanceOf(to)@after == balanceOf(to)@before + shareAmount";
}

/*
 * assetAmount > 0 && shareAmount > 0 => asset.balanceOf(address(this))@after == asset.balanceOf(address(this))@before + assetAmount
 *
 * What it means: When both assetAmount and shareAmount are greater than zero, the vault's asset balance must increase by assetAmount
 *
 * Why it should hold: When users provide assets in exchange for shares, those assets must be transferred into the vault to back the newly minted shares
 *
 * Possible consequences: Unbacked shares could be minted without receiving corresponding assets, leading to insolvency
 */
// gereon: from should not be currentContract
rule enter_39d6ba32_asset_transfer_when_nonzero(env e) {
    address from;
    address asset;
    uint256 assetAmount;
    address to;
    uint256 shareAmount;

    require(from != currentContract);

    // assign all the 'before' variables
    uint256 asset_balanceOf_e__currentContract__before = asset.balanceOf(e, currentContract);

    // call function under test
    enter(e, from, asset, assetAmount, to, shareAmount);

    // assign all the 'after' variables
    uint256 asset_balanceOf_e__currentContract__after = asset.balanceOf(e, currentContract);

    // verify integrity
    assert (((assetAmount > 0) && (shareAmount > 0)) => (asset_balanceOf_e__currentContract__after == asset_balanceOf_e__currentContract__before + assetAmount)), "assetAmount > 0 && shareAmount > 0 => asset.balanceOf(address(this))@after == asset.balanceOf(address(this))@before + assetAmount";
}

/*
 * assetAmount == 0 && shareAmount > 0 => asset.balanceOf(address(this))@after == asset.balanceOf(address(this))@before
 *
 * What it means: When assetAmount is zero but shareAmount is positive, the vault's asset balance must remain unchanged
 *
 * Why it should hold: The contract documentation states that if assetAmount is zero, no assets are transferred in, so the vault's asset balance should not change
 *
 * Possible consequences: Unexpected asset transfers could occur even when assetAmount is zero, breaking the documented behavior
 */
rule enter_39d6ba32_no_asset_transfer_when_zero(env e) {
    address from;
    address asset;
    uint256 assetAmount;
    address to;
    uint256 shareAmount;

    // assign all the 'before' variables
    uint256 asset_balanceOf_e__currentContract__before = asset.balanceOf(e, currentContract);

    // call function under test
    enter(e, from, asset, assetAmount, to, shareAmount);

    // assign all the 'after' variables
    uint256 asset_balanceOf_e__currentContract__after = asset.balanceOf(e, currentContract);

    // verify integrity
    assert (((assetAmount == 0) && (shareAmount > 0)) => (asset_balanceOf_e__currentContract__after == asset_balanceOf_e__currentContract__before)), "assetAmount == 0 && shareAmount > 0 => asset.balanceOf(address(this))@after == asset.balanceOf(address(this))@before";
}

/*
 * shareAmount > 0 && other != to => balanceOf(other)@after == balanceOf(other)@before
 *
 * What it means: When minting shares to a recipient, all other users' balances must remain unchanged
 *
 * Why it should hold: Minting should only affect the recipient's balance, not other users' balances, to maintain proper isolation between accounts
 *
 * Possible consequences: Other users could lose shares or have their balances corrupted during minting operations
 */
rule enter_39d6ba32_other_balances_unchanged(env e) {
    address from;
    address asset;
    uint256 assetAmount;
    address to;
    uint256 shareAmount;
    address other;

    // assign all the 'before' variables
    uint256 balanceOf_e__other__before = balanceOf(e, other);

    // call function under test
    enter(e, from, asset, assetAmount, to, shareAmount);

    // assign all the 'after' variables
    uint256 balanceOf_e__other__after = balanceOf(e, other);

    // verify integrity
    assert (((shareAmount > 0) && (other != to)) => (balanceOf_e__other__after == balanceOf_e__other__before)), "shareAmount > 0 && other != to => balanceOf(other)@after == balanceOf(other)@before";
}

/*
 * allowance(user1, user2)@after == allowance(user1, user2)@before
 *
 * What it means: The enter function must not modify any approval allowances between addresses
 *
 * Why it should hold: Minting shares should not affect existing approval relationships between users, as these are separate concerns
 *
 * Possible consequences: User approvals could be corrupted, leading to unauthorized transfers or blocked legitimate transfers
 */
rule enter_39d6ba32_allowances_unchanged(env e) {
    address from;
    address asset;
    uint256 assetAmount;
    address to;
    uint256 shareAmount;
    address user1;
    address user2;

    // assign all the 'before' variables
    uint256 allowance_e__user1__user2__before = allowance(e, user1, user2);

    // call function under test
    enter(e, from, asset, assetAmount, to, shareAmount);

    // assign all the 'after' variables
    uint256 allowance_e__user1__user2__after = allowance(e, user1, user2);

    // verify integrity
    assert (allowance_e__user1__user2__after == allowance_e__user1__user2__before), "allowance(user1, user2)@after == allowance(user1, user2)@before";
}

/*
 * nonces(user)@after == nonces(user)@before
 *
 * What it means: The enter function must not modify any user's nonce values used for permit functionality
 *
 * Why it should hold: Minting shares should not affect permit nonces, which are used for gasless approvals and should only change during permit operations
 *
 * Possible consequences: Permit functionality could be broken, preventing gasless transactions
 */
rule enter_39d6ba32_nonces_unchanged(env e) {
    address from;
    address asset;
    uint256 assetAmount;
    address to;
    uint256 shareAmount;
    address user;

    // assign all the 'before' variables
    uint256 nonces_e__user__before = nonces(e, user);

    // call function under test
    enter(e, from, asset, assetAmount, to, shareAmount);

    // assign all the 'after' variables
    uint256 nonces_e__user__after = nonces(e, user);

    // verify integrity
    assert (nonces_e__user__after == nonces_e__user__before), "nonces(user)@after == nonces(user)@before";
}

/*
 * hook@after == hook@before
 *
 * What it means: The enter function must not modify the beforeTransferHook address
 *
 * Why it should hold: The hook configuration should only be changed through the dedicated setBeforeTransferHook function by authorized users, not during minting operations
 *
 * Possible consequences: Transfer restrictions could be bypassed or maliciously modified
 */
rule enter_39d6ba32_hook_unchanged(env e) {
    address from;
    address asset;
    uint256 assetAmount;
    address to;
    uint256 shareAmount;

    // assign all the 'before' variables
    address currentContract_hook_before = currentContract.hook;

    // call function under test
    enter(e, from, asset, assetAmount, to, shareAmount);

    // assign all the 'after' variables
    address currentContract_hook_after = currentContract.hook;

    // verify integrity
    assert (currentContract_hook_after == currentContract_hook_before), "hook@after == hook@before";
}

/*
 * owner@after == owner@before
 *
 * What it means: The enter function must not modify the contract owner address
 *
 * Why it should hold: Ownership should only change through dedicated ownership transfer functions, not during regular minting operations
 *
 * Possible consequences: Unauthorized ownership changes could lead to complete contract takeover
 */
rule enter_39d6ba32_owner_unchanged(env e) {
    address from;
    address asset;
    uint256 assetAmount;
    address to;
    uint256 shareAmount;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;

    // call function under test
    enter(e, from, asset, assetAmount, to, shareAmount);

    // assign all the 'after' variables
    address currentContract_owner_after = currentContract.owner;

    // verify integrity
    assert (currentContract_owner_after == currentContract_owner_before), "owner@after == owner@before";
}

/*
 * authority@after == authority@before
 *
 * What it means: The enter function must not modify the authority contract address used for access control
 *
 * Why it should hold: The authority configuration should only be changed through dedicated functions, not during minting operations
 *
 * Possible consequences: Access control could be completely bypassed or redirected to malicious contracts
 */
rule enter_39d6ba32_authority_unchanged(env e) {
    address from;
    address asset;
    uint256 assetAmount;
    address to;
    uint256 shareAmount;

    // assign all the 'before' variables
    address currentContract_authority_before = currentContract.authority;

    // call function under test
    enter(e, from, asset, assetAmount, to, shareAmount);

    // assign all the 'after' variables
    address currentContract_authority_after = currentContract.authority;

    // verify integrity
    assert (currentContract_authority_after == currentContract_authority_before), "authority@after == authority@before";
}

/*
 * shareAmount == 0 => revert
 *
 * What it means: The function must revert when shareAmount is zero, preventing meaningless operations
 *
 * Why it should hold: Based on the NO-OP prevention pattern, operations that don't perform meaningful work should revert rather than succeed with no effect. The exit function is meant to burn shares in exchange for assets, so zero shares is meaningless
 *
 * Possible consequences: Gas waste, event spam, potential confusion in off-chain systems tracking vault operations, and violation of the principle that operations should either succeed meaningfully or fail
 */
rule exit_18457e61_zero_shares_reverts(env e) {
    address to;
    address asset;
    uint256 assetAmount;
    address from;
    uint256 shareAmount;

    // assign all the 'before' variables

    // call function under test
    exit@withrevert(e, to, asset, assetAmount, from, shareAmount);
    bool exit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((shareAmount == 0) => exit_reverted), "shareAmount == 0 => revert";
}

/*
 * to == address(0) || from == address(0) => revert
 *
 * What it means: The function must revert when either the recipient address (to) or the share holder address (from) is the zero address
 *
 * Why it should hold: Zero addresses are invalid for token operations - you cannot transfer assets to address(0) or burn shares from address(0). This is a fundamental validation requirement for any token-related operation
 *
 * Possible consequences: Permanent loss of assets if transferred to zero address, impossible share burning operations, and potential contract state corruption
 */
rule exit_18457e61_invalid_addresses_revert(env e) {
    address to;
    address asset;
    uint256 assetAmount;
    address from;
    uint256 shareAmount;

    // assign all the 'before' variables

    // call function under test
    exit@withrevert(e, to, asset, assetAmount, from, shareAmount);
    bool exit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((to == 0) || (from == 0)) => exit_reverted), "to == address(0) || from == address(0) => revert";
}

/*
 * balanceOf[from]@before < shareAmount => revert
 *
 * What it means: The function must revert when the from address doesn't have enough shares to burn the requested shareAmount
 *
 * Why it should hold: This is a fundamental requirement for any token burning operation - you cannot burn more tokens than an address owns. Without this check, the function would attempt invalid state changes
 *
 * Possible consequences: Underflow errors, contract state corruption, or successful burns of non-existent shares leading to accounting inconsistencies
 */
rule exit_18457e61_insufficient_balance_reverts(env e) {
    address to;
    address asset;
    uint256 assetAmount;
    address from;
    uint256 shareAmount;

    // assign all the 'before' variables
    uint256 currentContract_balanceOf_from__before = currentContract.balanceOf[from];

    // call function under test
    exit@withrevert(e, to, asset, assetAmount, from, shareAmount);
    bool exit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((currentContract_balanceOf_from__before < shareAmount) => exit_reverted), "balanceOf[from]@before < shareAmount => revert";
}

/*
 * msg.sender != owner@before => revert
 *
 * What it means: The function must revert when called by anyone other than the contract owner, enforcing access control
 *
 * Why it should hold: The function has the requiresAuth modifier and is documented as callable by BURNER_ROLE. Only authorized addresses should be able to burn shares and transfer assets out of the vault
 *
 * Possible consequences: Unauthorized draining of vault assets, unauthorized share burning, complete loss of access control leading to vault compromise
 */
rule exit_18457e61_requires_auth(env e) {
    address to;
    address asset;
    uint256 assetAmount;
    address from;
    uint256 shareAmount;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;

    // call function under test
    exit@withrevert(e, to, asset, assetAmount, from, shareAmount);
    bool exit_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((e.msg.sender != currentContract_owner_before) => exit_reverted), "msg.sender != owner@before => revert";
}

/*
 * shareAmount > 0 && balanceOf[from]@before >= shareAmount => balanceOf[from]@after == balanceOf[from]@before - shareAmount
 *
 * What it means: When shareAmount is positive and the from address has sufficient balance, the from address's share balance must decrease by exactly shareAmount
 *
 * Why it should hold: This is the core functionality of the exit function - burning shares. The balance must be reduced by the exact amount specified to maintain proper accounting
 *
 * Possible consequences: Incorrect share accounting, potential for infinite shares, or shares not being properly burned leading to supply inflation
 */
rule exit_18457e61_burns_shares(env e) {
    address to;
    address asset;
    uint256 assetAmount;
    address from;
    uint256 shareAmount;

    // assign all the 'before' variables
    uint256 currentContract_balanceOf_from__before = currentContract.balanceOf[from];

    // call function under test
    exit(e, to, asset, assetAmount, from, shareAmount);

    // assign all the 'after' variables
    uint256 currentContract_balanceOf_from__after = currentContract.balanceOf[from];

    // verify integrity
    assert (((shareAmount > 0) && (currentContract_balanceOf_from__before >= shareAmount)) => (currentContract_balanceOf_from__after == currentContract_balanceOf_from__before - shareAmount)), "shareAmount > 0 && balanceOf[from]@before >= shareAmount => balanceOf[from]@after == balanceOf[from]@before - shareAmount";
}

/*
 * shareAmount > 0 && balanceOf[from]@before >= shareAmount => totalSupply@after == totalSupply@before - shareAmount
 *
 * What it means: When shares are successfully burned, the total supply of shares must decrease by exactly the shareAmount
 *
 * Why it should hold: Burning shares must reduce the total supply to maintain the invariant that totalSupply equals the sum of all individual balances. This is fundamental to token accounting
 *
 * Possible consequences: Total supply inflation, accounting inconsistencies between individual balances and total supply, potential for economic attacks exploiting supply discrepancies
 */
rule exit_18457e61_reduces_total_supply(env e) {
    address to;
    address asset;
    uint256 assetAmount;
    address from;
    uint256 shareAmount;

    // assign all the 'before' variables
    uint256 currentContract_balanceOf_from__before = currentContract.balanceOf[from];
    uint256 currentContract_totalSupply_before = currentContract.totalSupply;

    // call function under test
    exit(e, to, asset, assetAmount, from, shareAmount);

    // assign all the 'after' variables
    uint256 currentContract_totalSupply_after = currentContract.totalSupply;

    // verify integrity
    assert (((shareAmount > 0) && (currentContract_balanceOf_from__before >= shareAmount)) => (currentContract_totalSupply_after == currentContract_totalSupply_before - shareAmount)), "shareAmount > 0 && balanceOf[from]@before >= shareAmount => totalSupply@after == totalSupply@before - shareAmount";
}

/*
 * shareAmount > 0 && balanceOf[from]@before >= shareAmount && other != from => balanceOf[other]@after == balanceOf[other]@before
 *
 * What it means: When shares are burned from one address, all other addresses' share balances must remain exactly the same
 *
 * Why it should hold: Share burning should only affect the specific address losing shares. Other users' balances must be protected from any side effects of the operation
 *
 * Possible consequences: Unauthorized balance modifications, theft of shares from innocent users, complete breakdown of user balance isolation
 */
rule exit_18457e61_other_balances_unchanged(env e) {
    address to;
    address asset;
    uint256 assetAmount;
    address from;
    uint256 shareAmount;
    address other;

    // assign all the 'before' variables
    uint256 currentContract_balanceOf_from__before = currentContract.balanceOf[from];
    uint256 currentContract_balanceOf_other__before = currentContract.balanceOf[other];

    // call function under test
    exit(e, to, asset, assetAmount, from, shareAmount);

    // assign all the 'after' variables
    uint256 currentContract_balanceOf_other__after = currentContract.balanceOf[other];

    // verify integrity
    assert ((((shareAmount > 0) && (currentContract_balanceOf_from__before >= shareAmount)) && (other != from)) => (currentContract_balanceOf_other__after == currentContract_balanceOf_other__before)), "shareAmount > 0 && balanceOf[from]@before >= shareAmount && other != from => balanceOf[other]@after == balanceOf[other]@before";
}

/*
 * msg.sender != owner@before => revert
 *
 * What it means: Only the contract owner can call setBeforeTransferHook - any other caller must cause the function to revert
 *
 * Why it should hold: The function has requiresAuth modifier and devdoc states 'Callable by OWNER_ROLE', indicating strict access control is required
 *
 * Possible consequences: Unauthorized hook modification leading to complete bypass of transfer restrictions, potential fund theft, or malicious hook installation
 */
rule setBeforeTransferHook_8929565f_only_owner_can_call(env e) {
    address _hook;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;

    // call function under test
    setBeforeTransferHook@withrevert(e, _hook);
    bool setBeforeTransferHook_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((e.msg.sender != currentContract_owner_before) => setBeforeTransferHook_reverted), "msg.sender != owner@before => revert";
}

/*
 * msg.sender == owner@before => hook@after == _hook
 *
 * What it means: When the owner successfully calls the function, the hook storage variable must be updated to the new _hook parameter value
 *
 * Why it should hold: This is the core functionality - the function's purpose is to update the hook address when called by authorized user
 *
 * Possible consequences: Hook address not updating despite successful call, breaking transfer hook functionality and leaving old restrictions in place
 */
rule setBeforeTransferHook_8929565f_hook_address_changes(env e) {
    address _hook;

    // assign all the 'before' variables
    address currentContract_owner_before = currentContract.owner;

    // call function under test
    setBeforeTransferHook(e, _hook);

    // assign all the 'after' variables
    address currentContract_hook_after = currentContract.hook;

    // verify integrity
    assert ((e.msg.sender == currentContract_owner_before) => (currentContract_hook_after == _hook)), "msg.sender == owner@before => hook@after == _hook";
}

/*
 * _hook == hook@before => revert
 *
 * What it means: Setting the hook to the same address it already has must revert - no-op operations are not allowed
 *
 * Why it should hold: Following the NO-OPS MUST REVERT rule - meaningless operations that don't change state should fail rather than succeed silently
 *
 * Possible consequences: Wasted gas on meaningless transactions, potential confusion about whether hook was actually updated, masking of implementation bugs
 */
rule setBeforeTransferHook_8929565f_same_hook_reverts(env e) {
    address _hook;

    // assign all the 'before' variables
    address currentContract_hook_before = currentContract.hook;

    // call function under test
    setBeforeTransferHook@withrevert(e, _hook);
    bool setBeforeTransferHook_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((_hook == currentContract_hook_before) => setBeforeTransferHook_reverted), "_hook == hook@before => revert";
}

/*
 * _hook == address(0) => hook@after == address(0)
 *
 * What it means: Setting the hook to zero address (address(0)) is valid and should update the hook storage to zero address
 *
 * Why it should hold: Contract documentation states 'If set to zero address, the share locker logic is disabled' - this is an intended feature to disable hooks
 *
 * Possible consequences: Inability to disable hook functionality when needed, permanent lock-in to hook-based restrictions
 */
rule setBeforeTransferHook_8929565f_zero_address_allowed(env e) {
    address _hook;

    // assign all the 'before' variables

    // call function under test
    setBeforeTransferHook(e, _hook);

    // assign all the 'after' variables
    address currentContract_hook_after = currentContract.hook;

    // verify integrity
    assert ((_hook == 0) => (currentContract_hook_after == 0)), "_hook == address(0) => hook@after == address(0)";
}

/*
 * _hook != address(0) => hook@after == _hook
 *
 * What it means: Setting the hook to any non-zero address should successfully update the hook storage to that address
 *
 * Why it should hold: This covers the normal use case of setting a valid hook contract address to enable transfer restrictions
 *
 * Possible consequences: Inability to set valid hook contracts, breaking the core hook functionality of the system
 */
rule setBeforeTransferHook_8929565f_non_zero_address_allowed(env e) {
    address _hook;

    // assign all the 'before' variables

    // call function under test
    setBeforeTransferHook(e, _hook);

    // assign all the 'after' variables
    address currentContract_hook_after = currentContract.hook;

    // verify integrity
    assert ((_hook != 0) => (currentContract_hook_after == _hook)), "_hook != address(0) => hook@after == _hook";
}

/*
 * amount == 0 => revert
 *
 * What it means: The transfer function must revert when the amount parameter is zero
 *
 * Why it should hold: Zero-amount transfers are meaningless operations that waste gas and can be used to spam the network or trigger unnecessary hook calls. The contract should prevent no-op operations by reverting.
 *
 * Possible consequences: Gas griefing attacks, unnecessary hook executions, event spam, and potential DoS through repeated meaningless transactions
 */
rule transfer_a9059cbb_zero_amount_reverts(env e) {
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables

    // call function under test
    transfer@withrevert(e, to, amount);
    bool transfer_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((amount == 0) => transfer_reverted), "amount == 0 => revert";
}

/*
 * to == msg.sender => revert
 *
 * What it means: The transfer function must revert when a user tries to transfer tokens to themselves
 *
 * Why it should hold: Self-transfers are meaningless operations that don't change any balances but still consume gas and trigger hooks. They should be prevented as no-ops.
 *
 * Possible consequences: Gas griefing, unnecessary hook executions, and potential manipulation of systems that track transfer activity
 */
rule transfer_a9059cbb_self_transfer_reverts(env e) {
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables

    // call function under test
    transfer@withrevert(e, to, amount);
    bool transfer_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((to == e.msg.sender) => transfer_reverted), "to == msg.sender => revert";
}

/*
 * to == address(0) => revert
 *
 * What it means: The transfer function must revert when attempting to transfer tokens to the zero address (0x0)
 *
 * Why it should hold: Transferring to the zero address effectively burns tokens without proper accounting, which can break total supply invariants and cause permanent token loss
 *
 * Possible consequences: Permanent token loss, total supply accounting errors, and potential breaking of vault economics
 */
rule transfer_a9059cbb_zero_address_reverts(env e) {
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables

    // call function under test
    transfer@withrevert(e, to, amount);
    bool transfer_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((to == 0) => transfer_reverted), "to == address(0) => revert";
}

/*
 * amount > balanceOf[msg.sender]@before => revert
 *
 * What it means: The transfer function must revert when a user tries to transfer more tokens than they currently own
 *
 * Why it should hold: This is a fundamental ERC20 requirement - users cannot transfer tokens they don't have, as it would create negative balances or allow unauthorized token creation
 *
 * Possible consequences: Unauthorized token creation, negative balances, total supply inflation, and complete breakdown of token accounting
 */
rule transfer_a9059cbb_insufficient_balance_reverts(env e) {
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables
    uint256 currentContract_balanceOf_e_msg_sender__before = currentContract.balanceOf[e.msg.sender];

    // call function under test
    transfer@withrevert(e, to, amount);
    bool transfer_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((amount > currentContract_balanceOf_e_msg_sender__before) => transfer_reverted), "amount > balanceOf[msg.sender]@before => revert";
}

/*
 * amount > 0 && amount <= balanceOf[msg.sender]@before && to != msg.sender && to != address(0) => balanceOf[msg.sender]@after == balanceOf[msg.sender]@before - amount
 *
 * What it means: For valid transfers, the sender's balance must decrease by exactly the transfer amount
 *
 * Why it should hold: This ensures proper token accounting - when tokens are transferred out, they must be deducted from the sender's balance to maintain conservation of tokens
 *
 * Possible consequences: Token duplication, infinite token creation, and complete breakdown of scarcity mechanisms
 */
rule transfer_a9059cbb_sender_balance_decreases(env e) {
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables
    uint256 currentContract_balanceOf_e_msg_sender__before = currentContract.balanceOf[e.msg.sender];

    // call function under test
    result = transfer(e, to, amount);

    // assign all the 'after' variables
    uint256 currentContract_balanceOf_e_msg_sender__after = currentContract.balanceOf[e.msg.sender];

    // verify integrity
    assert (((((amount > 0) && (amount <= currentContract_balanceOf_e_msg_sender__before)) && (to != e.msg.sender)) && (to != 0)) => (currentContract_balanceOf_e_msg_sender__after == currentContract_balanceOf_e_msg_sender__before - amount)), "amount > 0 && amount <= balanceOf[msg.sender]@before && to != msg.sender && to != address(0) => balanceOf[msg.sender]@after == balanceOf[msg.sender]@before - amount";
}

/*
 * amount > 0 && amount <= balanceOf[msg.sender]@before && to != msg.sender && to != address(0) => balanceOf[to]@after == balanceOf[to]@before + amount
 *
 * What it means: For valid transfers, the recipient's balance must increase by exactly the transfer amount
 *
 * Why it should hold: This ensures the recipient actually receives the tokens being transferred, maintaining the conservation of tokens in the system
 *
 * Possible consequences: Token loss, failed transfers appearing successful, and users losing funds without recourse
 */
rule transfer_a9059cbb_recipient_balance_increases(env e) {
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables
    uint256 currentContract_balanceOf_e_msg_sender__before = currentContract.balanceOf[e.msg.sender];
    uint256 currentContract_balanceOf_to__before = currentContract.balanceOf[to];

    // call function under test
    result = transfer(e, to, amount);

    // assign all the 'after' variables
    uint256 currentContract_balanceOf_to__after = currentContract.balanceOf[to];

    // verify integrity
    assert (((((amount > 0) && (amount <= currentContract_balanceOf_e_msg_sender__before)) && (to != e.msg.sender)) && (to != 0)) => (currentContract_balanceOf_to__after == currentContract_balanceOf_to__before + amount)), "amount > 0 && amount <= balanceOf[msg.sender]@before && to != msg.sender && to != address(0) => balanceOf[to]@after == balanceOf[to]@before + amount";
}

/*
 * totalSupply@after == totalSupply@before
 *
 * What it means: The total supply of tokens must remain exactly the same before and after any transfer operation
 *
 * Why it should hold: Transfers only move tokens between accounts without creating or destroying them, so the total supply should be invariant during transfers
 *
 * Possible consequences: Inflation or deflation of token supply, breaking vault economics, and incorrect asset-to-share ratios
 */
rule transfer_a9059cbb_total_supply_unchanged(env e) {
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables
    uint256 currentContract_totalSupply_before = currentContract.totalSupply;

    // call function under test
    result = transfer(e, to, amount);

    // assign all the 'after' variables
    uint256 currentContract_totalSupply_after = currentContract.totalSupply;

    // verify integrity
    assert (currentContract_totalSupply_after == currentContract_totalSupply_before), "totalSupply@after == totalSupply@before";
}

/*
 * amount > 0 && amount <= balanceOf[msg.sender]@before && to != msg.sender && to != address(0) && other != msg.sender && other != to => balanceOf[other]@after == balanceOf[other]@before
 *
 * What it means: The balances of all accounts other than the sender and recipient must remain unchanged during a transfer
 *
 * Why it should hold: A transfer should only affect the two parties involved - any changes to other accounts would indicate unauthorized token movements or accounting errors
 *
 * Possible consequences: Unauthorized token theft, random balance changes, and complete loss of user trust in the system
 */
rule transfer_a9059cbb_other_balances_unchanged(env e) {
    address to;
    uint256 amount;
    bool result;
    address other;

    // assign all the 'before' variables
    uint256 currentContract_balanceOf_e_msg_sender__before = currentContract.balanceOf[e.msg.sender];
    uint256 currentContract_balanceOf_other__before = currentContract.balanceOf[other];

    // call function under test
    result = transfer(e, to, amount);

    // assign all the 'after' variables
    uint256 currentContract_balanceOf_other__after = currentContract.balanceOf[other];

    // verify integrity
    assert (((((((amount > 0) && (amount <= currentContract_balanceOf_e_msg_sender__before)) && (to != e.msg.sender)) && (to != 0)) && (other != e.msg.sender)) && (other != to)) => (currentContract_balanceOf_other__after == currentContract_balanceOf_other__before)), "amount > 0 && amount <= balanceOf[msg.sender]@before && to != msg.sender && to != address(0) && other != msg.sender && other != to => balanceOf[other]@after == balanceOf[other]@before";
}

/*
 * amount == 0 => revert
 *
 * What it means: Any transfer with amount equal to zero must revert and fail
 *
 * Why it should hold: Zero-amount transfers are meaningless operations that waste gas and can be used to spam the network or trigger unnecessary hook calls without actual value transfer
 *
 * Possible consequences: DoS attacks through gas waste, unnecessary event emissions, and potential hook exploitation
 */
rule transferFrom_23b872dd_zero_amount_reverts(env e) {
    address from;
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables

    // call function under test
    transferFrom@withrevert(e, from, to, amount);
    bool transferFrom_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((amount == 0) => transferFrom_reverted), "amount == 0 => revert";
}

/*
 * from == address(0) || to == address(0) => revert
 *
 * What it means: Transfers involving zero address as either sender or recipient must revert
 *
 * Why it should hold: Zero address represents an invalid/null address in Ethereum and transfers to/from it are meaningless operations that could lead to token burns or undefined behavior
 *
 * Possible consequences: Accidental token burns, state corruption, and loss of funds
 */
rule transferFrom_23b872dd_invalid_addresses_revert(env e) {
    address from;
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables

    // call function under test
    transferFrom@withrevert(e, from, to, amount);
    bool transferFrom_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((from == 0) || (to == 0)) => transferFrom_reverted), "from == address(0) || to == address(0) => revert";
}

/*
 * from == to => revert
 *
 * What it means: Transfers where the sender and recipient are the same address must revert
 *
 * Why it should hold: Self-transfers are no-op operations that don't change any meaningful state but still consume gas and can trigger hooks unnecessarily
 *
 * Possible consequences: Gas waste, unnecessary hook executions, and potential exploitation of hook logic
 */
rule transferFrom_23b872dd_self_transfer_reverts(env e) {
    address from;
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables

    // call function under test
    transferFrom@withrevert(e, from, to, amount);
    bool transferFrom_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((from == to) => transferFrom_reverted), "from == to => revert";
}

/*
 * amount > balanceOf[from]@before => revert
 *
 * What it means: Transfers that exceed the sender's current balance must revert
 *
 * Why it should hold: This is a fundamental ERC20 requirement - users cannot transfer more tokens than they own, as this would create tokens out of thin air
 *
 * Possible consequences: Token inflation, accounting errors, and violation of token economics
 */
rule transferFrom_23b872dd_insufficient_balance_reverts(env e) {
    address from;
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables
    uint256 currentContract_balanceOf_from__before = currentContract.balanceOf[from];

    // call function under test
    transferFrom@withrevert(e, from, to, amount);
    bool transferFrom_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert ((amount > currentContract_balanceOf_from__before) => transferFrom_reverted), "amount > balanceOf[from]@before => revert";
}

/*
 * msg.sender != from && amount > allowance[from][msg.sender]@before => revert
 *
 * What it means: Third-party transfers that exceed the approved allowance must revert, except when the sender is transferring their own tokens
 *
 * Why it should hold: The allowance mechanism is core to ERC20 security - third parties can only transfer up to the amount explicitly approved by the token owner
 *
 * Possible consequences: Unauthorized token transfers and theft of funds
 */
rule transferFrom_23b872dd_insufficient_allowance_reverts(env e) {
    address from;
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables
    uint256 currentContract_allowance_from__e_msg_sender__before = currentContract.allowance[from][e.msg.sender];

    // call function under test
    transferFrom@withrevert(e, from, to, amount);
    bool transferFrom_reverted = lastReverted;

    // assign all the 'after' variables

    // verify integrity
    assert (((e.msg.sender != from) && (amount > currentContract_allowance_from__e_msg_sender__before)) => transferFrom_reverted), "msg.sender != from && amount > allowance[from][msg.sender]@before => revert";
}

/*
 * amount > 0 && from != to && amount <= balanceOf[from]@before && (msg.sender == from || amount <= allowance[from][msg.sender]@before) => balanceOf[from]@after == balanceOf[from]@before - amount
 *
 * What it means: For valid transfers, the sender's balance must decrease by exactly the transfer amount
 *
 * Why it should hold: Conservation of tokens requires that when tokens are transferred out, the sender's balance decreases by the exact amount being transferred
 *
 * Possible consequences: Token duplication, accounting errors, and violation of token conservation
 */
rule transferFrom_23b872dd_balance_decreases_correctly(env e) {
    address from;
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables
    uint256 currentContract_balanceOf_from__before = currentContract.balanceOf[from];
    uint256 currentContract_allowance_from__e_msg_sender__before = currentContract.allowance[from][e.msg.sender];

    // call function under test
    result = transferFrom(e, from, to, amount);

    // assign all the 'after' variables
    uint256 currentContract_balanceOf_from__after = currentContract.balanceOf[from];

    // verify integrity
    assert (((((amount > 0) && (from != to)) && (amount <= currentContract_balanceOf_from__before)) && ((e.msg.sender == from) || (amount <= currentContract_allowance_from__e_msg_sender__before))) => (currentContract_balanceOf_from__after == currentContract_balanceOf_from__before - amount)), "amount > 0 && from != to && amount <= balanceOf[from]@before && (msg.sender == from || amount <= allowance[from][msg.sender]@before) => balanceOf[from]@after == balanceOf[from]@before - amount";
}

/*
 * amount > 0 && from != to && amount <= balanceOf[from]@before && (msg.sender == from || amount <= allowance[from][msg.sender]@before) => balanceOf[to]@after == balanceOf[to]@before + amount
 *
 * What it means: For valid transfers, the recipient's balance must increase by exactly the transfer amount
 *
 * Why it should hold: Conservation of tokens requires that when tokens are transferred, the recipient receives the exact amount being transferred
 *
 * Possible consequences: Token loss, incomplete transfers, and violation of token conservation
 */
rule transferFrom_23b872dd_balance_increases_correctly(env e) {
    address from;
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables
    uint256 currentContract_balanceOf_from__before = currentContract.balanceOf[from];
    uint256 currentContract_allowance_from__e_msg_sender__before = currentContract.allowance[from][e.msg.sender];
    uint256 currentContract_balanceOf_to__before = currentContract.balanceOf[to];

    // call function under test
    result = transferFrom(e, from, to, amount);

    // assign all the 'after' variables
    uint256 currentContract_balanceOf_to__after = currentContract.balanceOf[to];

    // verify integrity
    assert (((((amount > 0) && (from != to)) && (amount <= currentContract_balanceOf_from__before)) && ((e.msg.sender == from) || (amount <= currentContract_allowance_from__e_msg_sender__before))) => (currentContract_balanceOf_to__after == currentContract_balanceOf_to__before + amount)), "amount > 0 && from != to && amount <= balanceOf[from]@before && (msg.sender == from || amount <= allowance[from][msg.sender]@before) => balanceOf[to]@after == balanceOf[to]@before + amount";
}

/*
 * amount > 0 && msg.sender != from && amount <= allowance[from][msg.sender]@before => allowance[from][msg.sender]@after == allowance[from][msg.sender]@before - amount
 *
 * What it means: When a third party executes a transfer, the allowance must decrease by exactly the transfer amount
 *
 * Why it should hold: The allowance system requires that each use of approval reduces the remaining allowance to prevent over-spending
 *
 * Possible consequences: Unlimited spending beyond approved amounts and theft of funds
 */
rule transferFrom_23b872dd_allowance_decreases_correctly(env e) {
    address from;
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables
    uint256 currentContract_allowance_from__e_msg_sender__before = currentContract.allowance[from][e.msg.sender];

    // call function under test
    result = transferFrom(e, from, to, amount);

    // assign all the 'after' variables
    uint256 currentContract_allowance_from__e_msg_sender__after = currentContract.allowance[from][e.msg.sender];

    // verify integrity
    assert ((((amount > 0) && (e.msg.sender != from)) && (amount <= currentContract_allowance_from__e_msg_sender__before)) => (currentContract_allowance_from__e_msg_sender__after == currentContract_allowance_from__e_msg_sender__before - amount)), "amount > 0 && msg.sender != from && amount <= allowance[from][msg.sender]@before => allowance[from][msg.sender]@after == allowance[from][msg.sender]@before - amount";
}

/*
 * msg.sender == from => allowance[from][msg.sender]@after == allowance[from][msg.sender]@before
 *
 * What it means: When users transfer their own tokens, their self-allowance should not change
 *
 * Why it should hold: Self-transfers don't consume allowance since users have unlimited permission to transfer their own tokens
 *
 * Possible consequences: Incorrect allowance accounting and potential blocking of legitimate self-transfers
 */
rule transferFrom_23b872dd_allowance_unchanged_when_sender_is_from(env e) {
    address from;
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables
    uint256 currentContract_allowance_from__e_msg_sender__before = currentContract.allowance[from][e.msg.sender];

    // call function under test
    result = transferFrom(e, from, to, amount);

    // assign all the 'after' variables
    uint256 currentContract_allowance_from__e_msg_sender__after = currentContract.allowance[from][e.msg.sender];

    // verify integrity
    assert ((e.msg.sender == from) => (currentContract_allowance_from__e_msg_sender__after == currentContract_allowance_from__e_msg_sender__before)), "msg.sender == from => allowance[from][msg.sender]@after == allowance[from][msg.sender]@before";
}

/*
 * totalSupply@after == totalSupply@before
 *
 * What it means: Transfers must not change the total token supply
 *
 * Why it should hold: Transfers only move tokens between accounts and should never create or destroy tokens
 *
 * Possible consequences: Token inflation or deflation, violation of tokenomics, and economic manipulation
 */
rule transferFrom_23b872dd_total_supply_unchanged(env e) {
    address from;
    address to;
    uint256 amount;
    bool result;

    // assign all the 'before' variables
    uint256 currentContract_totalSupply_before = currentContract.totalSupply;

    // call function under test
    result = transferFrom(e, from, to, amount);

    // assign all the 'after' variables
    uint256 currentContract_totalSupply_after = currentContract.totalSupply;

    // verify integrity
    assert (currentContract_totalSupply_after == currentContract_totalSupply_before), "totalSupply@after == totalSupply@before";
}

/*
 * account != from && account != to => balanceOf[account]@after == balanceOf[account]@before
 *
 * What it means: Transfers must only affect the sender and recipient balances, leaving all other account balances unchanged
 *
 * Why it should hold: Transfers should have isolated effects and not modify balances of uninvolved parties
 *
 * Possible consequences: Unauthorized balance modifications, theft from uninvolved parties, and system-wide corruption
 */
rule transferFrom_23b872dd_other_balances_unchanged(env e) {
    address from;
    address to;
    uint256 amount;
    bool result;
    address account;

    // assign all the 'before' variables
    uint256 currentContract_balanceOf_account__before = currentContract.balanceOf[account];

    // call function under test
    result = transferFrom(e, from, to, amount);

    // assign all the 'after' variables
    uint256 currentContract_balanceOf_account__after = currentContract.balanceOf[account];

    // verify integrity
    assert (((account != from) && (account != to)) => (currentContract_balanceOf_account__after == currentContract_balanceOf_account__before)), "account != from && account != to => balanceOf[account]@after == balanceOf[account]@before";
}

/*
 * allowance[owner_addr][spender]@after == allowance[owner_addr][spender]@before || (owner_addr == from && spender == msg.sender)
 *
 * What it means: Transfers must only affect the specific allowance being used (if any), leaving all other allowances unchanged
 *
 * Why it should hold: Transfers should have isolated effects on allowances and not modify unrelated approval relationships
 *
 * Possible consequences: Corruption of approval system, unauthorized allowance modifications, and disruption of third-party integrations
 */
rule transferFrom_23b872dd_other_allowances_unchanged(env e) {
    address from;
    address to;
    uint256 amount;
    bool result;
    address owner_addr;
    address spender;

    // assign all the 'before' variables
    uint256 currentContract_allowance_owner_addr__spender__before = currentContract.allowance[owner_addr][spender];

    // call function under test
    result = transferFrom(e, from, to, amount);

    // assign all the 'after' variables
    uint256 currentContract_allowance_owner_addr__spender__after = currentContract.allowance[owner_addr][spender];

    // verify integrity
    assert ((currentContract_allowance_owner_addr__spender__after == currentContract_allowance_owner_addr__spender__before) || ((owner_addr == from) && (spender == e.msg.sender))), "allowance[owner_addr][spender]@after == allowance[owner_addr][spender]@before || (owner_addr == from && spender == msg.sender)";
}