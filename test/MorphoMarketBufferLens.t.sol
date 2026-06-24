// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY - NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {TellerWithBuffer} from "src/base/Roles/TellerWithBuffer.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {MorphoMarketBufferLens} from "src/helper/MorphoMarketBufferLens.sol";
import {IMorpho, Id, Market, Position} from "src/interfaces/IMorpho.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract MockERC20Mintable is ERC20 {
    constructor() ERC20("Mock Asset", "MOCK", 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Minimal Morpho Blue singleton stand-in: only the views the lens reads.
contract MockMorpho {
    mapping(bytes32 => Market) internal _markets;
    mapping(bytes32 => mapping(address => Position)) internal _positions;

    function setMarket(bytes32 id, uint128 totalSupplyAssets, uint128 totalSupplyShares, uint128 totalBorrowAssets)
        external
    {
        _markets[id] = Market({
            totalSupplyAssets: totalSupplyAssets,
            totalSupplyShares: totalSupplyShares,
            totalBorrowAssets: totalBorrowAssets,
            // The lens never reads totalBorrowShares; set it nonzero alongside nonzero borrow assets so the
            // mocked market state is not self-contradictory (a real market can't have borrow assets w/ 0 shares).
            totalBorrowShares: totalBorrowAssets,
            lastUpdate: 0,
            fee: 0
        });
    }

    function setSupplyShares(bytes32 id, address user, uint256 supplyShares) external {
        _positions[id][user] = Position({supplyShares: supplyShares, borrowShares: 0, collateral: 0});
    }

    function market(Id id) external view returns (Market memory) {
        return _markets[Id.unwrap(id)];
    }

    function position(Id id, address user) external view returns (Position memory) {
        return _positions[Id.unwrap(id)][user];
    }
}

/// @notice Minimal MorphoMarketBufferHelper stand-in: only the surface the lens reads.
contract MockMorphoMarketBufferHelper {
    address public immutable LOAN_TOKEN;
    address public immutable MORPHO_BLUE;
    DecoderCustomTypes.MarketParams internal _marketParams;

    constructor(address loanToken, address morphoBlue, DecoderCustomTypes.MarketParams memory marketParams_) {
        LOAN_TOKEN = loanToken;
        MORPHO_BLUE = morphoBlue;
        _marketParams = marketParams_;
    }

    function marketParams() external view returns (DecoderCustomTypes.MarketParams memory) {
        return _marketParams;
    }
}

contract MockTellerWithBufferShape {
    address public vault;
    IBufferHelper public withdrawBufferHelper;

    constructor(address vault_) {
        vault = vault_;
    }

    function setWithdrawBufferHelper(address helper) external {
        withdrawBufferHelper = IBufferHelper(helper);
    }

    function currentBufferHelpers(ERC20) external view returns (IBufferHelper, IBufferHelper) {
        return (IBufferHelper(address(0)), withdrawBufferHelper);
    }
}

contract MorphoMarketBufferLensTest is Test {
    address internal boringVault = address(0xB0B);

    MockERC20Mintable internal asset;
    MockMorpho internal morpho;
    MockMorphoMarketBufferHelper internal bufferHelper;
    MockTellerWithBufferShape internal teller;
    MorphoMarketBufferLens internal lens;

    bytes32 internal marketIdBytes;

    function setUp() external {
        asset = new MockERC20Mintable();
        morpho = new MockMorpho();

        DecoderCustomTypes.MarketParams memory marketParams = DecoderCustomTypes.MarketParams({
            loanToken: address(asset),
            collateralToken: address(0xC011),
            oracle: address(0x0A11),
            irm: address(0x1A11),
            lltv: 0.86e18
        });
        marketIdBytes = keccak256(abi.encode(marketParams));

        bufferHelper = new MockMorphoMarketBufferHelper(address(asset), address(morpho), marketParams);
        teller = new MockTellerWithBufferShape(boringVault);
        teller.setWithdrawBufferHelper(address(bufferHelper));
        lens = new MorphoMarketBufferLens();
    }

    function _withdrawable() internal view returns (uint256) {
        return lens.getInstantlyWithdrawableAmount(TellerWithBuffer(address(teller)), asset);
    }

    function testNoHelperReturnsIdleVaultBalance() external {
        teller.setWithdrawBufferHelper(address(0));
        asset.mint(boringVault, 321e18);

        assertEq(_withdrawable(), 321e18);
    }

    function testPositionBindsWhenLiquidityAmple() external {
        // pps = 2.0 (2,000,000 assets / 1,000,000 shares); vault holds 100,000 shares -> ~200,000 assets.
        morpho.setMarket(marketIdBytes, 2_000_000e18, 1_000_000e18, 0);
        morpho.setSupplyShares(marketIdBytes, boringVault, 100_000e18);
        asset.mint(address(morpho), 2_000_000e18); // ample singleton liquidity

        // Independent (naive) oracle: shares * pps = 100,000 * 2 = 200,000; the lens's Morpho share math
        // (virtual shares/assets, round down) differs by only a few hundred wei at this scale.
        assertApproxEqAbs(_withdrawable(), 200_000e18, 1e12, "position should bind when liquidity is ample");
    }

    function testCappedByMarketLiquidity() external {
        // Position far exceeds the market's free liquidity (supply - borrow = 150,000).
        morpho.setMarket(marketIdBytes, 2_000_000e18, 1_000_000e18, 1_850_000e18);
        morpho.setSupplyShares(marketIdBytes, boringVault, 1_000_000e18); // ~2,000,000 assets
        asset.mint(address(morpho), 2_000_000e18);

        assertEq(_withdrawable(), 150_000e18, "should cap at market free liquidity (supply - borrow)");
    }

    function testCappedByMorphoTokenBalance() external {
        // Free liquidity is large, but the singleton only physically holds 75,000 loan tokens.
        morpho.setMarket(marketIdBytes, 2_000_000e18, 1_000_000e18, 0);
        morpho.setSupplyShares(marketIdBytes, boringVault, 1_000_000e18); // ~2,000,000 assets
        asset.mint(address(morpho), 75_000e18);

        assertEq(_withdrawable(), 75_000e18, "should cap at the loan tokens Morpho actually holds");
    }

    function testReturnsZeroWithoutPosition() external {
        morpho.setMarket(marketIdBytes, 2_000_000e18, 1_000_000e18, 0);
        asset.mint(address(morpho), 2_000_000e18);
        // No supply shares set for the vault.
        assertEq(_withdrawable(), 0, "no position should quote zero");
    }

    function testRevertsOnLoanTokenMismatch() external {
        MockERC20Mintable otherAsset = new MockERC20Mintable();
        vm.expectRevert(
            abi.encodeWithSelector(
                MorphoMarketBufferLens.MorphoMarketBufferLens__LoanTokenMismatch.selector,
                address(otherAsset),
                address(asset)
            )
        );
        lens.getInstantlyWithdrawableAmount(TellerWithBuffer(address(teller)), otherAsset);
    }
}
