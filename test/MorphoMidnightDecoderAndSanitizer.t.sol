// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MorphoMidnightDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MorphoMidnightDecoderAndSanitizer.sol";
import {MorphoMidnightDecoderAndSanitizerSingleton} from "src/base/DecodersAndSanitizers/MorphoMidnightDecoderAndSanitizerSingleton.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {Test} from "@forge-std/Test.sol";

contract MockUSDC {
    function symbol() external pure returns (string memory) {
        return "USDC";
    }
}

contract MockWETH {
    function symbol() external pure returns (string memory) {
        return "WETH";
    }
}

contract MidnightMarketIdHarness is MorphoMidnightDecoderAndSanitizer {
    function marketId(DecoderCustomTypes.MidnightMarket calldata market) external pure returns (address) {
        return _getMidnightMarketId(market);
    }
}

contract MorphoMidnightDecoderAndSanitizerTest is Test, MerkleTreeHelper {
    address internal constant MIDNIGHT = 0x1111111111111111111111111111111111111111;
    address internal constant LOAN_TOKEN = 0x2222222222222222222222222222222222222222;
    address internal constant COLLATERAL_TOKEN = 0x3333333333333333333333333333333333333333;
    address internal constant ORACLE = 0x4444444444444444444444444444444444444444;

    // Golden values for the fixture market below, derived two independent ways:
    // 1. morpho-org/midnight IdLib.toId (forge test in their repo @ commit f47568c, solc 0.8.34/osaka)
    // 2. cast abi-encode + cast keccak over SSTORE2_PREFIX ++ abi.encode(market), CREATE2 formula
    bytes32 internal constant MARKET_FULL_ID = 0xd8ab888035e6589a6f54f9ef0e4054a4480981697dc318e07eb54a6f4b0f19ce;
    address internal constant MARKET_ID_ADDRESS = 0x0e4054a4480981697DC318e07EB54A6F4B0F19Ce;

    // Selectors from `forge inspect Midnight methodIdentifiers` in morpho-org/midnight @ f47568c.
    bytes4 internal constant TAKE_SELECTOR = 0x6a14c9ef;
    bytes4 internal constant WITHDRAW_SELECTOR = 0xa6db1750;
    bytes4 internal constant REPAY_SELECTOR = 0x6b210f9e;
    bytes4 internal constant SUPPLY_COLLATERAL_SELECTOR = 0x32292d96;
    bytes4 internal constant WITHDRAW_COLLATERAL_SELECTOR = 0xa121e2a9;
    bytes4 internal constant UPDATE_POSITION_SELECTOR = 0x545e513a;

    address internal boringVaultAddress = vm.addr(0xB0B);
    address internal maker = vm.addr(0xAAAA);
    address internal makerCallback = vm.addr(0xBBBB);
    address internal makerReceiver = vm.addr(0xCCCC);
    address internal ratifier = vm.addr(0xDDDD);

    MorphoMidnightDecoderAndSanitizerSingleton internal decoder;
    MidnightMarketIdHarness internal harness;

    string internal takeSignature;
    string internal withdrawSignature;
    string internal repaySignature;
    string internal supplyCollateralSignature;
    string internal withdrawCollateralSignature;
    string internal updatePositionSignature;

    function setUp() external {
        decoder = new MorphoMidnightDecoderAndSanitizerSingleton();
        harness = new MidnightMarketIdHarness();

        vm.etch(LOAN_TOKEN, type(MockUSDC).runtimeCode);
        vm.etch(COLLATERAL_TOKEN, type(MockWETH).runtimeCode);

        setSourceChainName("mainnet");
        setAddress(false, sourceChain, "morphoMidnight", MIDNIGHT);
        setAddress(false, sourceChain, "boringVault", boringVaultAddress);
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", address(decoder));

        takeSignature = _midnightTakeSignature();
        withdrawSignature = string.concat("withdraw(", MIDNIGHT_MARKET_TUPLE, ",uint256,address,address)");
        repaySignature = string.concat("repay(", MIDNIGHT_MARKET_TUPLE, ",uint256,address,address,bytes)");
        supplyCollateralSignature = string.concat("supplyCollateral(", MIDNIGHT_MARKET_TUPLE, ",uint256,uint256,address)");
        withdrawCollateralSignature = string.concat("withdrawCollateral(", MIDNIGHT_MARKET_TUPLE, ",uint256,uint256,address,address)");
        updatePositionSignature = string.concat("updatePosition(", MIDNIGHT_MARKET_TUPLE, ",address)");
    }

    function _fixtureMarket() internal pure returns (DecoderCustomTypes.MidnightMarket memory market) {
        DecoderCustomTypes.MidnightCollateralParams[] memory collateralParams = new DecoderCustomTypes.MidnightCollateralParams[](1);
        collateralParams[0] = DecoderCustomTypes.MidnightCollateralParams({token: COLLATERAL_TOKEN, lltv: 0.86e18, liquidationCursor: 0.3e18, oracle: ORACLE});
        market = DecoderCustomTypes.MidnightMarket({
            chainId: 1,
            midnight: MIDNIGHT,
            loanToken: LOAN_TOKEN,
            collateralParams: collateralParams,
            maturity: 1798761600,
            rcfThreshold: 1000000000,
            enterGate: address(0),
            liquidatorGate: address(0)
        });
    }

    function _fixtureMarketTwoCollateral() internal pure returns (DecoderCustomTypes.MidnightMarket memory market) {
        DecoderCustomTypes.MidnightCollateralParams[] memory collateralParams = new DecoderCustomTypes.MidnightCollateralParams[](2);
        collateralParams[0] = DecoderCustomTypes.MidnightCollateralParams({token: COLLATERAL_TOKEN, lltv: 0.86e18, liquidationCursor: 0.3e18, oracle: ORACLE});
        collateralParams[1] = DecoderCustomTypes.MidnightCollateralParams({token: LOAN_TOKEN, lltv: 0.5e18, liquidationCursor: 0.2e18, oracle: ORACLE});
        market = DecoderCustomTypes.MidnightMarket({
            chainId: 1,
            midnight: MIDNIGHT,
            loanToken: LOAN_TOKEN,
            collateralParams: collateralParams,
            maturity: 1798761600,
            rcfThreshold: 1000000000,
            enterGate: address(0),
            liquidatorGate: address(0)
        });
    }

    function _fixtureOffer(bool buy, address receiverIfMakerIsSeller) internal view returns (DecoderCustomTypes.MidnightOffer memory offer) {
        offer = DecoderCustomTypes.MidnightOffer({
            market: _fixtureMarket(),
            buy: buy,
            maker: maker,
            start: 1751932800,
            expiry: 1752537600,
            tick: 3000,
            group: bytes32(uint256(1)),
            callback: address(0),
            callbackData: hex"",
            receiverIfMakerIsSeller: receiverIfMakerIsSeller,
            ratifier: ratifier,
            reduceOnly: false,
            maxUnits: 1e18,
            maxAssets: 0,
            continuousFeeCap: 1e15
        });
    }

    function _decode(bytes memory callData) internal view returns (bool success, bytes memory result) {
        (success, result) = address(decoder).staticcall(callData);
        if (success) result = abi.decode(result, (bytes));
    }

    function _packLeafArguments(ManageLeaf memory leaf) internal pure returns (bytes memory packed) {
        for (uint256 i; i < leaf.argumentAddresses.length; ++i) {
            packed = abi.encodePacked(packed, leaf.argumentAddresses[i]);
        }
    }

    // ========================================= MARKET ID =========================================

    function testMarketIdMatchesMidnightIdLib() external view {
        assertEq(harness.marketId(_fixtureMarket()), MARKET_ID_ADDRESS, "decoder market id != IdLib golden");

        (bytes32 fullId, address idAddress) = _getMidnightMarketId(_fixtureMarket());
        assertEq(fullId, MARKET_FULL_ID, "helper full id != IdLib golden");
        assertEq(idAddress, MARKET_ID_ADDRESS, "helper id address != IdLib golden");
    }

    /// @dev The id computation is intentionally duplicated (calldata version in the decoder, memory
    /// version in MerkleTreeHelper); this guards the two copies against diverging edits.
    function testFuzzMarketIdParityBetweenDecoderAndHelper(
        uint256 chainId,
        address midnight,
        address loanToken,
        uint8 collateralCount,
        uint256 fieldSeed,
        uint256 maturity,
        uint256 rcfThreshold,
        address enterGate,
        address liquidatorGate
    ) external view {
        uint256 count = bound(collateralCount, 1, 16);
        DecoderCustomTypes.MidnightCollateralParams[] memory collateralParams = new DecoderCustomTypes.MidnightCollateralParams[](count);
        for (uint256 i; i < count; ++i) {
            collateralParams[i] = DecoderCustomTypes.MidnightCollateralParams({
                token: address(uint160(uint256(keccak256(abi.encode(fieldSeed, i, "token"))))),
                lltv: uint256(keccak256(abi.encode(fieldSeed, i, "lltv"))),
                liquidationCursor: uint256(keccak256(abi.encode(fieldSeed, i, "cursor"))),
                oracle: address(uint160(uint256(keccak256(abi.encode(fieldSeed, i, "oracle")))))
            });
        }
        DecoderCustomTypes.MidnightMarket memory market = DecoderCustomTypes.MidnightMarket({
            chainId: chainId,
            midnight: midnight,
            loanToken: loanToken,
            collateralParams: collateralParams,
            maturity: maturity,
            rcfThreshold: rcfThreshold,
            enterGate: enterGate,
            liquidatorGate: liquidatorGate
        });

        (, address helperIdAddress) = _getMidnightMarketId(market);
        assertEq(harness.marketId(market), helperIdAddress, "decoder and helper market ids diverge");
    }

    // ========================================= SELECTORS =========================================

    function testSignatureStringsMatchMidnightSelectors() external view {
        assertEq(bytes4(keccak256(bytes(takeSignature))), TAKE_SELECTOR, "take");
        assertEq(bytes4(keccak256(bytes(withdrawSignature))), WITHDRAW_SELECTOR, "withdraw");
        assertEq(bytes4(keccak256(bytes(repaySignature))), REPAY_SELECTOR, "repay");
        assertEq(bytes4(keccak256(bytes(supplyCollateralSignature))), SUPPLY_COLLATERAL_SELECTOR, "supplyCollateral");
        assertEq(bytes4(keccak256(bytes(withdrawCollateralSignature))), WITHDRAW_COLLATERAL_SELECTOR, "withdrawCollateral");
        assertEq(bytes4(keccak256(bytes(updatePositionSignature))), UPDATE_POSITION_SELECTOR, "updatePosition");
    }

    // ========================================= DECODING =========================================

    function testTakeDecodingLendDirection() external view {
        DecoderCustomTypes.MidnightOffer memory offer = _fixtureOffer(false, makerReceiver);
        offer.maker = maker;
        offer.callback = makerCallback;
        offer.ratifier = ratifier;

        (bool success, bytes memory result) =
            _decode(abi.encodeWithSignature(takeSignature, offer, hex"", 1e18, boringVaultAddress, address(0), address(0), hex""));
        assertTrue(success, "take decode failed");
        assertEq(
            result,
            abi.encodePacked(
                MARKET_ID_ADDRESS,
                address(0), // offer.buy = false
                maker,
                makerCallback,
                makerReceiver,
                ratifier,
                boringVaultAddress,
                address(0)
            ),
            "take packed addresses mismatch"
        );
    }

    function testTakeRevertsOnTakerCallback() external view {
        DecoderCustomTypes.MidnightOffer memory offer = _fixtureOffer(true, address(0));

        (bool success, bytes memory result) = address(decoder)
            .staticcall(abi.encodeWithSignature(takeSignature, offer, hex"", 1e18, boringVaultAddress, boringVaultAddress, vm.addr(0xEEEE), hex""));
        assertFalse(success, "should revert on taker callback");
        assertEq(result, abi.encodePacked(MorphoMidnightDecoderAndSanitizer.MorphoMidnightDecoderAndSanitizer__CallbackNotSupported.selector));
    }

    function testTakeRevertsOnTakerCallbackData() external view {
        DecoderCustomTypes.MidnightOffer memory offer = _fixtureOffer(true, address(0));

        (bool success, bytes memory result) = address(decoder)
            .staticcall(abi.encodeWithSignature(takeSignature, offer, hex"", 1e18, boringVaultAddress, boringVaultAddress, address(0), hex"dead"));
        assertFalse(success, "should revert on taker callback data");
        assertEq(result, abi.encodePacked(MorphoMidnightDecoderAndSanitizer.MorphoMidnightDecoderAndSanitizer__CallbackNotSupported.selector));
    }

    function testWithdrawDecoding() external view {
        (bool success, bytes memory result) =
            _decode(abi.encodeWithSignature(withdrawSignature, _fixtureMarket(), 1e18, boringVaultAddress, boringVaultAddress));
        assertTrue(success, "withdraw decode failed");
        assertEq(result, abi.encodePacked(MARKET_ID_ADDRESS, boringVaultAddress, boringVaultAddress));
    }

    function testRepayDecodingAndCallbackRejection() external view {
        (bool success, bytes memory result) = _decode(abi.encodeWithSignature(repaySignature, _fixtureMarket(), 1e18, boringVaultAddress, address(0), hex""));
        assertTrue(success, "repay decode failed");
        assertEq(result, abi.encodePacked(MARKET_ID_ADDRESS, boringVaultAddress));

        (success, result) =
            address(decoder).staticcall(abi.encodeWithSignature(repaySignature, _fixtureMarket(), 1e18, boringVaultAddress, vm.addr(0xEEEE), hex""));
        assertFalse(success, "should revert on repay callback");

        (success, result) =
            address(decoder).staticcall(abi.encodeWithSignature(repaySignature, _fixtureMarket(), 1e18, boringVaultAddress, address(0), hex"dead"));
        assertFalse(success, "should revert on repay callback data");
    }

    function testCollateralDecodingAndOvercastGuard() external view {
        (bool success, bytes memory result) = _decode(abi.encodeWithSignature(supplyCollateralSignature, _fixtureMarket(), 0, 100e18, boringVaultAddress));
        assertTrue(success, "supplyCollateral decode failed");
        assertEq(result, abi.encodePacked(MARKET_ID_ADDRESS, address(0), boringVaultAddress));

        (success, result) = _decode(abi.encodeWithSignature(withdrawCollateralSignature, _fixtureMarket(), 0, 100e18, boringVaultAddress, boringVaultAddress));
        assertTrue(success, "withdrawCollateral decode failed");
        assertEq(result, abi.encodePacked(MARKET_ID_ADDRESS, address(0), boringVaultAddress, boringVaultAddress));

        (success, result) = address(decoder)
            .staticcall(abi.encodeWithSignature(supplyCollateralSignature, _fixtureMarket(), uint256(type(uint160).max) + 1, 100e18, boringVaultAddress));
        assertFalse(success, "should revert on overcast collateral index");
        assertEq(result, abi.encodePacked(MorphoMidnightDecoderAndSanitizer.MorphoMidnightDecoderAndSanitizer__OvercastUint160.selector));

        (success, result) = address(decoder)
            .staticcall(
                abi.encodeWithSignature(
                    withdrawCollateralSignature, _fixtureMarket(), uint256(type(uint160).max) + 1, 100e18, boringVaultAddress, boringVaultAddress
                )
            );
        assertFalse(success, "should revert on overcast collateral index (withdraw)");
        assertEq(result, abi.encodePacked(MorphoMidnightDecoderAndSanitizer.MorphoMidnightDecoderAndSanitizer__OvercastUint160.selector));
    }

    function testCollateralIndexIsActuallyPinned() external view {
        // The other collateral checks use index 0, where address(uint160(0)) == address(0): a dropped
        // index pin would pass vacuously. Index 1 forces a non-zero pin a regression cannot fake.
        DecoderCustomTypes.MidnightMarket memory market = _fixtureMarketTwoCollateral();
        (, address idAddr) = _getMidnightMarketId(market);

        (bool success, bytes memory result) = _decode(abi.encodeWithSignature(supplyCollateralSignature, market, uint256(1), 100e18, boringVaultAddress));
        assertTrue(success, "supplyCollateral index 1 decode failed");
        assertEq(result, abi.encodePacked(idAddr, address(uint160(1)), boringVaultAddress), "supplyCollateral did not pin collateralIndex 1");

        (success, result) = _decode(abi.encodeWithSignature(withdrawCollateralSignature, market, uint256(1), 100e18, boringVaultAddress, boringVaultAddress));
        assertTrue(success, "withdrawCollateral index 1 decode failed");
        assertEq(
            result, abi.encodePacked(idAddr, address(uint160(1)), boringVaultAddress, boringVaultAddress), "withdrawCollateral did not pin collateralIndex 1"
        );
    }

    function testUpdatePositionDecoding() external view {
        (bool success, bytes memory result) = _decode(abi.encodeWithSignature(updatePositionSignature, _fixtureMarket(), boringVaultAddress));
        assertTrue(success, "updatePosition decode failed");
        assertEq(result, abi.encodePacked(MARKET_ID_ADDRESS, boringVaultAddress));
    }

    // ========================================= LEAF HELPERS =========================================

    function testLeafHelpersMatchDecoderOutput() external {
        DecoderCustomTypes.MidnightMarket memory market = _fixtureMarket();
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addMorphoMidnightSupplyLeafs(leafs, market, maker, makerCallback, makerReceiver, ratifier, true);
        _addMorphoMidnightSellCreditLeafs(leafs, market, maker, makerCallback, ratifier);
        _addMorphoMidnightCollateralLeafs(leafs, market, 0);
        _addMorphoMidnightRepayLeafs(leafs, market);
        assertEq(leafIndex, 8, "expected 9 leaves (loan token approval deduped for repay)");

        // Every leaf signature must resolve to a decoder function.
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        // The tree must build.
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        assertTrue(manageTree[manageTree.length - 1][0] != bytes32(0), "empty root");

        // Leaf 1: take (lend direction) — decoder output must equal the leaf's packed argumentAddresses.
        DecoderCustomTypes.MidnightOffer memory lendOffer = _fixtureOffer(false, makerReceiver);
        lendOffer.maker = maker;
        lendOffer.callback = makerCallback;
        lendOffer.ratifier = ratifier;
        (bool success, bytes memory result) =
            _decode(abi.encodeWithSignature(takeSignature, lendOffer, hex"", 1e18, boringVaultAddress, address(0), address(0), hex""));
        assertTrue(success);
        assertEq(result, _packLeafArguments(leafs[1]), "take lend leaf mismatch");

        // Leaf 2: withdraw.
        (success, result) = _decode(abi.encodeWithSignature(withdrawSignature, market, 1e18, boringVaultAddress, boringVaultAddress));
        assertTrue(success);
        assertEq(result, _packLeafArguments(leafs[2]), "withdraw leaf mismatch");

        // Leaf 3: updatePosition.
        (success, result) = _decode(abi.encodeWithSignature(updatePositionSignature, market, boringVaultAddress));
        assertTrue(success);
        assertEq(result, _packLeafArguments(leafs[3]), "updatePosition leaf mismatch");

        // Leaf 4: take (sell credit direction).
        DecoderCustomTypes.MidnightOffer memory sellOffer = _fixtureOffer(true, address(0));
        sellOffer.maker = maker;
        sellOffer.callback = makerCallback;
        sellOffer.ratifier = ratifier;
        (success, result) = _decode(abi.encodeWithSignature(takeSignature, sellOffer, hex"", 1e18, boringVaultAddress, boringVaultAddress, address(0), hex""));
        assertTrue(success);
        assertEq(result, _packLeafArguments(leafs[4]), "take sell leaf mismatch");

        // Leaf 6: supplyCollateral.
        (success, result) = _decode(abi.encodeWithSignature(supplyCollateralSignature, market, 0, 100e18, boringVaultAddress));
        assertTrue(success);
        assertEq(result, _packLeafArguments(leafs[6]), "supplyCollateral leaf mismatch");

        // Leaf 7: withdrawCollateral.
        (success, result) = _decode(abi.encodeWithSignature(withdrawCollateralSignature, market, 0, 100e18, boringVaultAddress, boringVaultAddress));
        assertTrue(success);
        assertEq(result, _packLeafArguments(leafs[7]), "withdrawCollateral leaf mismatch");

        // Leaf 8: repay.
        (success, result) = _decode(abi.encodeWithSignature(repaySignature, market, 1e18, boringVaultAddress, address(0), hex""));
        assertTrue(success);
        assertEq(result, _packLeafArguments(leafs[8]), "repay leaf mismatch");

        // Leaves 0 and 5: ERC20 approvals. The decoder pins spender = morphoMidnight for both; a wrong
        // spender in either approval leaf would slip past the index 1-8 checks above.
        (success, result) = _decode(abi.encodeWithSignature("approve(address,uint256)", MIDNIGHT, uint256(0)));
        assertTrue(success);
        assertEq(result, _packLeafArguments(leafs[0]), "loan approval leaf mismatch");
        assertEq(result, _packLeafArguments(leafs[5]), "collateral approval leaf mismatch");
    }

    /// @dev External wrapper so vm.expectRevert can observe the internal builder's require.
    function exposed_addMorphoMidnightSupplyLeafs(
        DecoderCustomTypes.MidnightMarket memory market,
        address maker_,
        address makerCallback_,
        address makerReceiver_,
        address ratifier_,
        bool addTake_
    ) external {
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addMorphoMidnightSupplyLeafs(leafs, market, maker_, makerCallback_, makerReceiver_, ratifier_, addTake_);
    }

    function testSupplyLeafRejectsZeroMakerReceiver() external {
        vm.expectRevert("Midnight lend leaf: makerReceiver == address(0)");
        this.exposed_addMorphoMidnightSupplyLeafs(_fixtureMarket(), maker, makerCallback, address(0), ratifier, true);
    }

    function testSupplyLeafCanOmitTake() external {
        ManageLeaf[] memory leafs = new ManageLeaf[](3);
        _addMorphoMidnightSupplyLeafs(leafs, _fixtureMarket(), maker, makerCallback, address(0), ratifier, false);

        assertEq(leafIndex, 2, "expected approval, withdraw, and updatePosition leaves");
        assertEq(leafs[0].signature, "approve(address,uint256)");
        assertEq(leafs[1].signature, withdrawSignature);
        assertEq(leafs[2].signature, updatePositionSignature);
    }

    function testLoanEqualsCollateralApprovalDedup() external {
        // A market whose collateral token IS its loan token must not emit two separate approvals.
        DecoderCustomTypes.MidnightCollateralParams[] memory collateralParams = new DecoderCustomTypes.MidnightCollateralParams[](1);
        collateralParams[0] = DecoderCustomTypes.MidnightCollateralParams({token: LOAN_TOKEN, lltv: 0.86e18, liquidationCursor: 0.3e18, oracle: ORACLE});
        DecoderCustomTypes.MidnightMarket memory market = DecoderCustomTypes.MidnightMarket({
            chainId: 1,
            midnight: MIDNIGHT,
            loanToken: LOAN_TOKEN,
            collateralParams: collateralParams,
            maturity: 1798761600,
            rcfThreshold: 1000000000,
            enterGate: address(0),
            liquidatorGate: address(0)
        });

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addMorphoMidnightSupplyLeafs(leafs, market, maker, makerCallback, makerReceiver, ratifier, true);
        _addMorphoMidnightCollateralLeafs(leafs, market, 0);

        // supply: approve(0) take-lend(1) withdraw(2) updatePosition(3); collateral: [approve deduped]
        // supplyCollateral(4) withdrawCollateral(5). A missing dedup would push leafIndex to 6.
        assertEq(leafIndex, 5, "collateral approval must dedupe against the loan-token approval");
    }
}
