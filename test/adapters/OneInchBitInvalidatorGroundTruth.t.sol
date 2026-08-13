// SPDX-License-Identifier: SEL-1.0
pragma solidity 0.8.21;

import {Test, console} from "@forge-std/Test.sol";

interface IOneInchRouterGT {
    // MakerTraits is `type MakerTraits is uint256` in 1inch v6, so the ABI type is uint256.
    function cancelOrder(uint256 makerTraits, bytes32 orderHash) external;
    function bitInvalidatorForOrder(address maker, uint256 slot) external view returns (uint256);
}

/// @notice GROUND TRUTH. Exercises the DEPLOYED 1inch AggregationRouterV6 (not source/snippets):
///         invalidates a nonce >= 256 as a maker, then reads bitInvalidatorForOrder back with the raw nonce
///         vs. the shifted slot. This decides whether the adapter must pass the raw nonce (checkSlot shifts
///         internally) or the slot, independent of any documentation, param naming, or third-party claim.
contract OneInchBitInvalidatorGroundTruthTest is Test {
    address constant ONEINCH_ROUTER = 0x111111125421cA6dc452d289314280a0f8842A65;

    uint256 constant NO_PARTIAL_FILLS_FLAG = 1 << 255; // FOK => bit-invalidator path
    uint256 constant NONCE_OFFSET = 120; // nonceOrEpoch lives at bits [120,160)

    function setUp() public {
        vm.createSelectFork("mainnet", 24592183);
    }

    function testBitInvalidatorShiftSemantics_DeployedRouter() external {
        address maker = makeAddr("gtMaker");
        uint256 nonce = 300; // >= 256, so slot = nonce>>8 = 1 and bit = 1<<(300 & 0xff) = 1<<44
        uint256 makerTraits = NO_PARTIAL_FILLS_FLAG | (nonce << NONCE_OFFSET);
        uint256 expectedBit = uint256(1) << (nonce & 0xff); // 1<<44

        // Invalidate nonce 300 on the REAL router as `maker` (FOK => the BitInvalidator path).
        vm.prank(maker);
        IOneInchRouterGT(ONEINCH_ROUTER).cancelOrder(makerTraits, bytes32(0));

        uint256 atRawNonce = IOneInchRouterGT(ONEINCH_ROUTER).bitInvalidatorForOrder(maker, nonce); // 300 (what the adapter passes)
        uint256 atSlot = IOneInchRouterGT(ONEINCH_ROUTER).bitInvalidatorForOrder(maker, nonce >> 8); // 1 (the shifted slot, not the raw nonce)
        uint256 atSibling = IOneInchRouterGT(ONEINCH_ROUTER).bitInvalidatorForOrder(maker, 256); // same slot as 300
        uint256 atZero = IOneInchRouterGT(ONEINCH_ROUTER).bitInvalidatorForOrder(maker, 0);

        console.log("bitInvalidatorForOrder(maker, rawNonce=300):", atRawNonce);
        console.log("bitInvalidatorForOrder(maker, slot=1)      :", atSlot);
        console.log("bitInvalidatorForOrder(maker, 256 sibling) :", atSibling);
        console.log("bitInvalidatorForOrder(maker, 0)           :", atZero);
        console.log("expectedBit (1<<44)                        :", expectedBit);

        // If checkSlot shifts internally (>>8): querying with the RAW NONCE surfaces the invalidated word;
        // 256 (same slot 1) surfaces the same word; slot=1 and 0 (both land in slot 0) are empty.
        assertEq(atRawNonce, expectedBit, "raw nonce surfaces the bit => checkSlot shifts >>8 internally");
        assertEq(atSibling, expectedBit, "nonce 256 shares slot 1 with 300 => arg is a nonce, not a slot");
        assertEq(atSlot, 0, "nonce>>8 (=1) reads slot 0 => WRONG word for nonce>=256");
        assertEq(atZero, 0, "control: untouched slot reads 0");

        // The adapter passes the RAW nonce, so it reads `atRawNonce` (the word carrying the invalidation);
        // querying the shifted slot (nonce >> 8) instead reads `atSlot`, a different word.
        assertTrue((atRawNonce & expectedBit) != 0, "raw nonce detects the invalidation");
        assertTrue((atSlot & expectedBit) == 0, "the shifted-slot query does not");
    }
}
