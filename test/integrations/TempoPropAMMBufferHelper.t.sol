// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {IDirectPropAMM} from "src/interfaces/IDirectPropAMM.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

interface IDirectPropAMMAdmin {
    function fund(address token, uint256 amount, bytes32 memo) external;
    function unpause() external;
    function setTakerAllowed(address taker, bool allowed) external;
    function setRecipientAllowed(address recipient, bool allowed) external;
    function resetPriceAnchor(bool baseToQuote) external;
}

interface IPushPriceOracle {
    function pushPrice(uint256 price, uint256 updatedAt) external;
    function price() external view returns (uint256);
    function updatedAt() external view returns (uint256);
}

/// @notice ABI of the upstream `DirectPropAMMBufferHelper`, matching the vendored artifact exactly.
/// @dev Getter names and types are upstream's, not this repository's conventions: `slippageBps` is a
///      `uint16` and the immutables are lowerCamelCase. Restating them here is the point of driving
///      the artifact rather than a local rewrite, since a rename upstream breaks this interface.
interface IDirectPropAMMBufferHelper {
    function pool() external view returns (address);
    function vault() external view returns (address);
    function baseToken() external view returns (address);
    function quoteToken() external view returns (address);
    function customerId() external view returns (bytes32);
    function slippageBps() external view returns (uint16);
    function BPS() external view returns (uint256);
    function MAX_SLIPPAGE_BPS() external view returns (uint256);

    function getDepositManageCall(address asset, uint256 amount) external view returns (address[] memory targets, bytes[] memory data, uint256[] memory values);

    function getWithdrawManageCall(address asset, uint256 amount) external view returns (address[] memory targets, bytes[] memory data, uint256[] memory values);
}

/**
 * @notice Tests `DirectPropAMMBufferHelper` against the real DirectPropAMM, with no pool mock.
 * @dev The pool and oracle are deployed on a Tempo fork from bytecode compiled out of the propAMM
 *      repository, and the tokens are the live TIP-20 predeploys. The helper only builds calldata, so
 *      each test asserts the batch it returns AND executes that batch through `BoringVault.manage`,
 *      which is exactly what `TellerWithBuffer` does with it.
 */
contract TempoPropAMMBufferHelperTest is Test {
    ERC20 internal constant PRIME = ERC20(0x20C00000000000000000000058d0B8b2CFDb358c);
    ERC20 internal constant PATH_USD = ERC20(0x20C0000000000000000000000000000000000000);
    address internal constant ADDRESS_REGISTRY = 0xfDC0000000000000000000000000000000000000;
    address internal constant PRIME_WHALE = 0xcC4957A13A225eA1BfC85346D48B7de2Cb2cE374;
    address internal constant PATH_USD_WHALE = 0xDEc0000000000000000000000000000000000000;

    uint256 internal constant FORK_BLOCK = 36_425_642;
    uint8 internal constant ORACLE_DECIMALS = 8;
    uint256 internal constant INITIAL_PRICE = 105_151_100;
    uint256 internal constant MAX_ORACLE_AGE = 90_000;
    uint256 internal constant MAX_PRICE_DEVIATION_BPS = 50;
    uint256 internal constant BPS = 10_000;

    uint8 internal constant MANAGER_ROLE = 20;
    bytes32 internal constant CUSTOMER_ID = keccak256("DIRECT_PROP_VEDA_BUFFER");
    uint16 internal constant SLIPPAGE_BPS = 10;

    /// @dev Sized against the live PRIME holder's actual balance (27.520864 at the fork block).
    uint256 internal constant POOL_INVENTORY = 15e6;
    uint256 internal constant VAULT_BASE_FUNDING = 8e6;

    BoringVault internal boringVault;
    RolesAuthority internal rolesAuthority;
    IDirectPropAMMBufferHelper internal helper;
    IDirectPropAMM internal pool;
    IPushPriceOracle internal oracle;

    function setUp() public {
        vm.createSelectFork("tempo", FORK_BLOCK);

        boringVault = new BoringVault(address(this), "Buffer Vault", "BV", 18);
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        rolesAuthority.setUserRole(address(this), MANAGER_ROLE, true);
        rolesAuthority.setRoleCapability(MANAGER_ROLE, address(boringVault), bytes4(keccak256("manage(address[],bytes[],uint256[])")), true);

        oracle = IPushPriceOracle(
            _deploy("test/artifacts/propAMM/PushPriceOracle.json", abi.encode(ORACLE_DECIMALS, address(this), address(this), INITIAL_PRICE, block.timestamp))
        );
        pool = IDirectPropAMM(
            _deploy(
                "test/artifacts/propAMM/DirectPropAMM.json",
                abi.encode(
                    address(PRIME), address(PATH_USD), address(oracle), ADDRESS_REGISTRY, address(this), address(this), MAX_ORACLE_AGE, MAX_PRICE_DEVIATION_BPS
                )
            )
        );

        vm.prank(PRIME_WHALE);
        PRIME.transfer(address(this), POOL_INVENTORY + VAULT_BASE_FUNDING);
        vm.prank(PATH_USD_WHALE);
        PATH_USD.transfer(address(this), POOL_INVENTORY + VAULT_BASE_FUNDING);
        PRIME.transfer(address(boringVault), VAULT_BASE_FUNDING);

        PRIME.approve(address(pool), POOL_INVENTORY);
        PATH_USD.approve(address(pool), POOL_INVENTORY);
        IDirectPropAMMAdmin(address(pool)).fund(address(PRIME), POOL_INVENTORY, bytes32("SEED_BASE"));
        IDirectPropAMMAdmin(address(pool)).fund(address(PATH_USD), POOL_INVENTORY, bytes32("SEED_QUOTE"));
        IDirectPropAMMAdmin(address(pool)).setTakerAllowed(address(boringVault), true);
        IDirectPropAMMAdmin(address(pool)).setRecipientAllowed(address(boringVault), true);
        IDirectPropAMMAdmin(address(pool)).resetPriceAnchor(true);
        IDirectPropAMMAdmin(address(pool)).resetPriceAnchor(false);
        IDirectPropAMMAdmin(address(pool)).unpause();

        helper = IDirectPropAMMBufferHelper(_deployHelper(address(pool), address(boringVault), CUSTOMER_ID, SLIPPAGE_BPS));
    }

    // ===================== construction =====================

    function testConstructorReadsThePairFromThePool() external view {
        assertEq(helper.baseToken(), address(PRIME));
        assertEq(helper.quoteToken(), address(PATH_USD));
        assertEq(helper.pool(), address(pool));
        assertEq(helper.vault(), address(boringVault));
        assertEq(helper.customerId(), CUSTOMER_ID);
        assertEq(helper.slippageBps(), SLIPPAGE_BPS);
    }

    function testConstructorRejectsZeroAddresses() external {
        _expectDeployRevert(address(0), address(boringVault), CUSTOMER_ID, SLIPPAGE_BPS, "InvalidAddress()");
        _expectDeployRevert(address(pool), address(0), CUSTOMER_ID, SLIPPAGE_BPS, "InvalidAddress()");
    }

    function testConstructorRejectsZeroCustomerId() external {
        _expectDeployRevert(address(pool), address(boringVault), bytes32(0), SLIPPAGE_BPS, "CustomerIdIsZero()");
    }

    /// @dev The ceiling is enforced at construction, so a configured helper's slippage can never be
    ///      raised afterwards. This is the one numeric bound the buffer path does have.
    function testConstructorRejectsSlippageAboveCeiling() external {
        uint16 ceiling = uint16(helper.MAX_SLIPPAGE_BPS());
        _expectDeployRevert(address(pool), address(boringVault), CUSTOMER_ID, ceiling + 1, "SlippageTooHigh(uint256,uint256)");
    }

    // ===================== deposit path =====================

    function testDepositBatchConvertsQuoteIntoBaseThroughTheRealPool() external {
        uint256 depositAmount = 1e6;
        PATH_USD.transfer(address(boringVault), depositAmount);

        (uint256 quotedBaseOut,,) = pool.quoteExactInput(false, depositAmount);
        uint256 minimumBaseOut = quotedBaseOut * (BPS - SLIPPAGE_BPS) / BPS;

        uint256 primeBefore = PRIME.balanceOf(address(boringVault));
        uint256 pathBefore = PATH_USD.balanceOf(address(boringVault));

        (address[] memory targets, bytes[] memory data, uint256[] memory values) = helper.getDepositManageCall(address(PATH_USD), depositAmount);
        boringVault.manage(targets, data, values);

        assertEq(PATH_USD.balanceOf(address(boringVault)), pathBefore - depositAmount, "quote not spent");
        uint256 received = PRIME.balanceOf(address(boringVault)) - primeBefore;
        assertGe(received, minimumBaseOut, "settled below the helper's own slippage floor");
        assertEq(PATH_USD.allowance(address(boringVault), address(pool)), 0, "residual allowance");
    }

    function testDepositBatchIsApproveZeroSwapApproveZero() external view {
        (address[] memory targets, bytes[] memory data,) = helper.getDepositManageCall(address(PATH_USD), 1e6);

        assertEq(targets.length, 4, "unexpected batch length");
        assertEq(targets[0], address(PATH_USD));
        assertEq(targets[1], address(PATH_USD));
        assertEq(targets[2], address(pool));
        assertEq(targets[3], address(PATH_USD));

        assertEq(bytes4(data[0]), ERC20.approve.selector);
        assertEq(bytes4(data[1]), ERC20.approve.selector);
        assertEq(bytes4(data[2]), IDirectPropAMM.swapExactInput.selector);
        assertEq(bytes4(data[3]), ERC20.approve.selector);

        (, uint256 firstAmount) = _decodeApprove(data[0]);
        (address spender, uint256 secondAmount) = _decodeApprove(data[1]);
        (, uint256 lastAmount) = _decodeApprove(data[3]);
        assertEq(firstAmount, 0, "batch did not clear allowance first");
        assertEq(spender, address(pool), "approval spender is not the pool");
        assertEq(secondAmount, 1e6, "approval is not the exact deposit amount");
        assertEq(lastAmount, 0, "batch did not clear allowance last");
    }

    /// @dev The recipient is pinned to the vault and the customer ID to the helper's immutable, so a
    ///      teller batch cannot be steered to another address or another rounding-credit route.
    function testDepositSwapPinsRecipientAndCustomerId() external view {
        (, bytes[] memory data,) = helper.getDepositManageCall(address(PATH_USD), 1e6);
        (,,, address recipient, bytes32 customerId,,,, uint256 toleranceBps,) = _decodeSwap(data[2]);

        assertEq(recipient, address(boringVault), "recipient is not the vault");
        assertEq(customerId, CUSTOMER_ID, "customer ID is not the helper's");
        assertEq(toleranceBps, 0, "atomic teller batch should bind the exact quoted price");
    }

    // ===================== withdraw path =====================

    /// @dev No swap when the vault already holds the redemption amount: the helper returns an empty
    ///      batch rather than trading unnecessarily.
    function testWithdrawBatchIsEmptyWhenVaultAlreadyHoldsEnoughQuote() external {
        PATH_USD.transfer(address(boringVault), 5e6);

        (address[] memory targets, bytes[] memory data, uint256[] memory values) = helper.getWithdrawManageCall(address(PATH_USD), 1e6);

        assertEq(targets.length, 0);
        assertEq(data.length, 0);
        assertEq(values.length, 0);
    }

    /// @dev Only the shortfall is sold, not the whole redemption.
    function testWithdrawBatchSellsOnlyTheShortfall() external {
        uint256 held = 400_000;
        uint256 redemption = 1e6;
        PATH_USD.transfer(address(boringVault), held);
        uint256 shortfall = redemption - held;

        (uint256 quotedBaseIn,,) = pool.quoteExactOutput(true, shortfall);
        uint256 primeBefore = PRIME.balanceOf(address(boringVault));

        (address[] memory targets, bytes[] memory data, uint256[] memory values) = helper.getWithdrawManageCall(address(PATH_USD), redemption);
        boringVault.manage(targets, data, values);

        assertEq(PATH_USD.balanceOf(address(boringVault)), redemption, "vault does not hold exactly the redemption");
        uint256 spent = primeBefore - PRIME.balanceOf(address(boringVault));
        assertLe(spent, quotedBaseIn * (BPS + SLIPPAGE_BPS) / BPS + 1, "spent more base than the slippage cap allows");
        assertEq(PRIME.allowance(address(boringVault), address(pool)), 0, "residual allowance");
    }

    function testWithdrawBatchApprovesBaseTokenNotQuote() external view {
        (address[] memory targets, bytes[] memory data,) = helper.getWithdrawManageCall(address(PATH_USD), 1e6);

        assertEq(targets.length, 4);
        assertEq(targets[0], address(PRIME), "withdraw path must approve the base token");
        assertEq(bytes4(data[2]), IDirectPropAMM.swapExactOutput.selector);

        (address spender,) = _decodeApprove(data[1]);
        assertEq(spender, address(pool));
    }

    // ===================== input validation =====================

    function testRejectsBaseTokenAsAsset() external {
        vm.expectPartialRevert(bytes4(keccak256("UnsupportedAsset(address)")));
        helper.getDepositManageCall(address(PRIME), 1e6);

        vm.expectPartialRevert(bytes4(keccak256("UnsupportedAsset(address)")));
        helper.getWithdrawManageCall(address(PRIME), 1e6);
    }

    function testRejectsZeroAmount() external {
        vm.expectRevert(bytes4(keccak256("AmountIsZero()")));
        helper.getDepositManageCall(address(PATH_USD), 0);

        vm.expectRevert(bytes4(keccak256("AmountIsZero()")));
        helper.getWithdrawManageCall(address(PATH_USD), 0);
    }

    // ===================== pool guards still apply =====================

    /// @dev The helper is not a bypass. A stale pool oracle makes the helper refuse to produce a
    ///      batch at all, so deposits and withdrawals through the teller fail closed with the pool.
    function testStaleOracleMakesTheHelperRefuseToQuote() external {
        vm.warp(block.timestamp + MAX_ORACLE_AGE + 1);

        vm.expectPartialRevert(bytes4(keccak256("StaleOraclePrice(uint256,uint256)")));
        helper.getDepositManageCall(address(PATH_USD), 1e6);
    }

    /// @dev Every batch pins `deadline = block.timestamp`, so it is valid only in the block that
    ///      produced it and cannot be held and replayed. That is also why the zero price tolerance
    ///      below is safe here but would be wrong on the strategist path, where quote and execution
    ///      are separate transactions.
    function testBatchDeadlineIsTheCurrentBlockSoItCannotBeReplayedLater() external {
        PATH_USD.transfer(address(boringVault), 1e6);
        (address[] memory targets, bytes[] memory data, uint256[] memory values) = helper.getDepositManageCall(address(PATH_USD), 1e6);

        (,,,,,, uint256 deadline,,,) = _decodeSwap(data[2]);
        assertEq(deadline, block.timestamp, "batch deadline is not the current block");

        vm.warp(block.timestamp + 1);
        vm.expectPartialRevert(bytes4(keccak256("DeadlineExpired(uint256,uint256)")));
        boringVault.manage(targets, data, values);
    }

    /// @dev The helper quotes with `quoteExactInput` / `quoteExactOutput`, which ignore the
    ///      rounding-credit route, while settlement runs `swapExactInput` / `swapExactOutput`, which
    ///      use it. Checked here rather than assumed: the route-aware quote pays at least as much on
    ///      the way in and asks at most as much on the way out, so the plain quote is a conservative
    ///      bound in both directions and even a zero-slippage helper settles.
    function testPlainQuoteIsConservativeVersusTheRouteAwareQuote() external {
        IDirectPropAMMBufferHelper strict = IDirectPropAMMBufferHelper(_deployHelper(address(pool), address(boringVault), CUSTOMER_ID, 0));
        PATH_USD.transfer(address(boringVault), 1e6);

        // Accrue rounding credit on the vault route with an amount that does not divide evenly.
        (address[] memory targets, bytes[] memory data, uint256[] memory values) = strict.getDepositManageCall(address(PATH_USD), 333_333);
        boringVault.manage(targets, data, values);

        bytes32 routeKey = pool.roundingRouteKey(address(boringVault), address(boringVault), CUSTOMER_ID);
        assertGt(pool.roundingCredit(routeKey), 0, "no rounding credit accrued");

        (uint256 plainOut,,) = pool.quoteExactInput(false, 333_333);
        (uint256 routeOut,,,) = pool.quoteExactInputFor(address(boringVault), address(boringVault), CUSTOMER_ID, false, 333_333);
        assertGe(routeOut, plainOut, "route pays less than the plain quote used as the floor");

        (uint256 plainIn,,) = pool.quoteExactOutput(true, 333_333);
        (uint256 routeIn,,,) = pool.quoteExactOutputFor(address(boringVault), address(boringVault), CUSTOMER_ID, true, 333_333);
        assertLe(routeIn, plainIn, "route asks more than the plain quote used as the cap");

        // A zero-slippage batch still settles once credit exists.
        (targets, data, values) = strict.getDepositManageCall(address(PATH_USD), 333_333);
        boringVault.manage(targets, data, values);
    }

    // ===================== helpers =====================

    string internal constant HELPER_ARTIFACT = "test/artifacts/propAMM/DirectPropAMMBufferHelper.json";

    function _deployHelper(address pool_, address vault_, bytes32 customerId_, uint16 slippageBps_) internal returns (address deployed) {
        deployed = _deploy(HELPER_ARTIFACT, abi.encode(pool_, vault_, customerId_, slippageBps_));
    }

    /// @dev A reverting constructor makes `create` return zero, so `vm.expectRevert` cannot see it.
    ///      Capture the constructor's returndata instead and match the error selector on it.
    function _expectDeployRevert(address pool_, address vault_, bytes32 customerId_, uint256 slippageBps_, string memory signature) internal {
        bytes memory creationCode = abi.encodePacked(vm.getCode(HELPER_ARTIFACT), abi.encode(pool_, vault_, customerId_, slippageBps_));
        address deployed;
        bytes memory err;
        assembly {
            deployed := create(0, add(creationCode, 0x20), mload(creationCode))
            let size := returndatasize()
            err := mload(0x40)
            mstore(0x40, add(err, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(err, size)
            returndatacopy(add(err, 0x20), 0, size)
        }
        assertEq(deployed, address(0), "constructor did not revert");
        assertEq(bytes4(err), bytes4(keccak256(bytes(signature))), "unexpected constructor revert reason");
    }

    function _deploy(string memory artifact, bytes memory args) internal returns (address deployed) {
        bytes memory creationCode = abi.encodePacked(vm.getCode(artifact), args);
        assembly {
            deployed := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        require(deployed != address(0), "deploy failed");
    }

    function _decodeApprove(bytes memory data) internal pure returns (address spender, uint256 amount) {
        bytes memory args = _stripSelector(data);
        (spender, amount) = abi.decode(args, (address, uint256));
    }

    function _decodeSwap(bytes memory data)
        internal
        pure
        returns (
            bool baseToQuote,
            uint256 amount,
            uint256 limit,
            address recipient,
            bytes32 customerId,
            bytes32 tradeId,
            uint256 deadline,
            uint256 expectedOraclePrice,
            uint256 oraclePriceToleranceBps,
            uint256 minimumOracleUpdatedAt
        )
    {
        return abi.decode(_stripSelector(data), (bool, uint256, uint256, address, bytes32, bytes32, uint256, uint256, uint256, uint256));
    }

    function _stripSelector(bytes memory data) internal pure returns (bytes memory args) {
        args = new bytes(data.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = data[i + 4];
        }
    }
}
