// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY - NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {TellerWithBuffer} from "src/base/Roles/TellerWithBuffer.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {IMorpho, Id, Market, MarketParams} from "src/interfaces/IMorpho.sol";
import {MorphoV2ERC4626BufferLens} from "src/helper/MorphoV2ERC4626BufferLens.sol";

contract MockERC20Mintable is ERC20 {
    constructor() ERC20("Mock Asset", "MOCK", 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockMorphoV2Vault is ERC4626 {
    uint256 internal totalAssets_;
    address public liquidityAdapter;
    bytes public liquidityData;

    constructor(ERC20 asset_) ERC4626(asset_, "Mock MorphoV2 Vault", "mstk") {}

    function setTotalAssets(uint256 assets) external {
        totalAssets_ = assets;
    }

    function setLiquidityAdapter(address adapter) external {
        liquidityAdapter = adapter;
    }

    function setLiquidityData(bytes memory data) external {
        liquidityData = data;
    }

    function mintShares(address to, uint256 shares) external {
        _mint(to, shares);
    }

    function totalAssets() public view override returns (uint256) {
        return totalAssets_;
    }
}

contract MockERC4626BufferHelper {
    ERC4626 public immutable ERC_4626_VAULT;

    constructor(ERC4626 vault_) {
        ERC_4626_VAULT = vault_;
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

contract MockMorpho {
    mapping(bytes32 => Market) internal markets;

    function setMarket(bytes32 marketId, uint128 totalSupplyAssets, uint128 totalBorrowAssets) external {
        markets[marketId] = Market({
            totalSupplyAssets: totalSupplyAssets,
            totalSupplyShares: 0,
            totalBorrowAssets: totalBorrowAssets,
            totalBorrowShares: 0,
            lastUpdate: 0,
            fee: 0
        });
    }

    function market(Id id) external view returns (Market memory) {
        return markets[Id.unwrap(id)];
    }
}

contract MockLiquidityAdapter {
    IMorpho public morpho;
    address public adaptiveCurveIrm;
    mapping(bytes32 => uint256) public expectedSupplyAssets;
    mapping(bytes32 => uint256) internal allocations;

    constructor(IMorpho morpho_, address adaptiveCurveIrm_) {
        morpho = morpho_;
        adaptiveCurveIrm = adaptiveCurveIrm_;
    }

    function setAdaptiveCurveIrm(address adaptiveCurveIrm_) external {
        adaptiveCurveIrm = adaptiveCurveIrm_;
    }

    function setExpectedSupplyAssets(bytes32 marketId, uint256 adapterSupplyAssets) external {
        expectedSupplyAssets[marketId] = adapterSupplyAssets;
    }

    function setAllocation(MarketParams memory marketParams, uint256 allocationAssets) external {
        allocations[keccak256(abi.encode(marketParams))] = allocationAssets;
    }

    function allocation(MarketParams memory marketParams) external view returns (uint256) {
        return allocations[keccak256(abi.encode(marketParams))];
    }
}

contract MockMorphoVaultV1 is ERC4626 {
    uint256 internal maxWithdraw_;

    constructor(ERC20 asset_) ERC4626(asset_, "Mock MorphoV1 Vault", "mmv1") {}

    function setMaxWithdraw(uint256 assets) external {
        maxWithdraw_ = assets;
    }

    function maxWithdraw(address) public view override returns (uint256) {
        return maxWithdraw_;
    }

    function totalAssets() public pure override returns (uint256) {
        return 0;
    }
}

contract MockMorphoVaultV1LiquidityAdapter {
    address public morphoVaultV1;
    uint256 public allocation;

    constructor(address morphoVaultV1_) {
        morphoVaultV1 = morphoVaultV1_;
    }

    function setAllocation(uint256 assets) external {
        allocation = assets;
    }
}

contract MorphoV2ERC4626BufferLensTest is Test {
    address internal boringVault = address(0xB0B);

    MockERC20Mintable internal asset;
    address internal adaptiveCurveIrm = address(0x1A11);
    MockMorphoV2Vault internal morphoV2Vault;
    MockERC4626BufferHelper internal bufferHelper;
    MockTellerWithBufferShape internal teller;
    MockMorpho internal morpho;
    MockLiquidityAdapter internal liquidityAdapter;
    MorphoV2ERC4626BufferLens internal lens;

    function setUp() external {
        asset = new MockERC20Mintable();
        morpho = new MockMorpho();
        liquidityAdapter = new MockLiquidityAdapter(IMorpho(address(morpho)), adaptiveCurveIrm);
        morphoV2Vault = new MockMorphoV2Vault(asset);
        morphoV2Vault.setLiquidityAdapter(address(liquidityAdapter));
        bufferHelper = new MockERC4626BufferHelper(ERC4626(address(morphoV2Vault)));
        teller = new MockTellerWithBufferShape(boringVault);
        teller.setWithdrawBufferHelper(address(bufferHelper));
        lens = new MorphoV2ERC4626BufferLens();
    }

    function testNoHelperReturnsIdleAssetInBoringVault() external {
        teller.setWithdrawBufferHelper(address(0));
        asset.mint(boringVault, 123e18);

        assertEq(_withdrawable(), 123e18);
    }

    function testCapsIdleAssetsByBoringVaultShareClaimWithoutAdapter() external {
        _setBoringVaultShareClaim(60e18);
        morphoV2Vault.setLiquidityAdapter(address(0));
        asset.mint(address(morphoV2Vault), 100e18);

        assertEq(_withdrawable(), 60e18);
    }

    function testUsesOnlyConfiguredLiquidityDataMarket() external {
        _setBoringVaultShareClaim(1_000e18);
        asset.mint(address(morphoV2Vault), 100e18);
        asset.mint(address(morpho), 1_000e18);

        MarketParams memory selectedMarket =
            MarketParams(address(asset), address(0xC011), address(0x0A11), address(0x1A11), 0.86e18);
        bytes32 selectedMarketId = _setLiquidityData(selectedMarket);
        liquidityAdapter.setExpectedSupplyAssets(selectedMarketId, 250e18);
        morpho.setMarket(selectedMarketId, 1_000e18, 200e18);

        MarketParams memory otherMarket =
            MarketParams(address(asset), address(0xC022), address(0x0A22), address(0x1A22), 0.86e18);
        bytes32 otherMarketId = _marketId(otherMarket);
        liquidityAdapter.setExpectedSupplyAssets(otherMarketId, 500e18);
        morpho.setMarket(otherMarketId, 1_000e18, 0);

        assertEq(_withdrawable(), 350e18);
    }

    function testCapsConfiguredMarketByAccountingLiquidity() external {
        _setBoringVaultShareClaim(1_000e18);
        asset.mint(address(morphoV2Vault), 100e18);
        asset.mint(address(morpho), 1_000e18);

        bytes32 marketId =
            _setLiquidityData(MarketParams(address(asset), address(0xC011), address(0x0A11), address(0x1A11), 0.86e18));
        liquidityAdapter.setExpectedSupplyAssets(marketId, 250e18);
        morpho.setMarket(marketId, 500e18, 450e18);

        assertEq(_withdrawable(), 150e18);
    }

    function testCapsConfiguredMarketByMorphoTokenLiquidity() external {
        _setBoringVaultShareClaim(1_000e18);
        asset.mint(address(morphoV2Vault), 100e18);
        asset.mint(address(morpho), 75e18);

        bytes32 marketId =
            _setLiquidityData(MarketParams(address(asset), address(0xC011), address(0x0A11), address(0x1A11), 0.86e18));
        liquidityAdapter.setExpectedSupplyAssets(marketId, 250e18);
        morpho.setMarket(marketId, 500e18, 100e18);

        assertEq(_withdrawable(), 175e18);
    }

    function testCapsTotalWithdrawableByBoringVaultShareClaim() external {
        _setBoringVaultShareClaim(300e18);
        asset.mint(address(morphoV2Vault), 100e18);
        asset.mint(address(morpho), 1_000e18);

        bytes32 marketId =
            _setLiquidityData(MarketParams(address(asset), address(0xC011), address(0x0A11), address(0x1A11), 0.86e18));
        liquidityAdapter.setExpectedSupplyAssets(marketId, 500e18);
        morpho.setMarket(marketId, 1_000e18, 0);

        assertEq(_withdrawable(), 300e18);
    }

    function testReturnsIdleOnlyForConfiguredMarketWithWrongLoanToken() external {
        MockERC20Mintable otherAsset = new MockERC20Mintable();

        _setBoringVaultShareClaim(1_000e18);
        asset.mint(address(morphoV2Vault), 100e18);
        asset.mint(address(morpho), 1_000e18);

        bytes32 marketId = _setLiquidityData(
            MarketParams(address(otherAsset), address(0xC011), address(0x0A11), adaptiveCurveIrm, 0.86e18)
        );
        liquidityAdapter.setExpectedSupplyAssets(marketId, 500e18);
        morpho.setMarket(marketId, 1_000e18, 0);

        assertEq(_withdrawable(), 100e18);
    }

    function testReturnsIdleOnlyForConfiguredMarketWithWrongIrm() external {
        _setBoringVaultShareClaim(1_000e18);
        asset.mint(address(morphoV2Vault), 100e18);
        asset.mint(address(morpho), 1_000e18);

        bytes32 marketId =
            _setLiquidityData(MarketParams(address(asset), address(0xC011), address(0x0A11), address(0xBAD), 0.86e18));
        liquidityAdapter.setExpectedSupplyAssets(marketId, 500e18);
        morpho.setMarket(marketId, 1_000e18, 0);

        assertEq(_withdrawable(), 100e18);
    }

    function testReturnsIdleOnlyForConfiguredMarketWithZeroAllocation() external {
        _setBoringVaultShareClaim(1_000e18);
        asset.mint(address(morphoV2Vault), 100e18);
        asset.mint(address(morpho), 1_000e18);

        MarketParams memory marketParams =
            MarketParams(address(asset), address(0xC011), address(0x0A11), adaptiveCurveIrm, 0.86e18);
        bytes32 marketId = _setLiquidityData(marketParams);
        liquidityAdapter.setAllocation(marketParams, 0);
        liquidityAdapter.setExpectedSupplyAssets(marketId, 500e18);
        morpho.setMarket(marketId, 1_000e18, 0);

        assertEq(_withdrawable(), 100e18);
    }

    function testUsesConfiguredMorphoVaultV1AdapterMaxWithdraw() external {
        _setBoringVaultShareClaim(1_000e18);
        asset.mint(address(morphoV2Vault), 100e18);
        _setMorphoVaultV1LiquidityAdapter(asset, 300e18, 240e18);

        assertEq(_withdrawable(), 340e18);
    }

    function testCapsConfiguredMorphoVaultV1AdapterByBoringVaultShareClaim() external {
        _setBoringVaultShareClaim(300e18);
        asset.mint(address(morphoV2Vault), 100e18);
        _setMorphoVaultV1LiquidityAdapter(asset, 500e18, 500e18);

        assertEq(_withdrawable(), 300e18);
    }

    function testReturnsIdleOnlyForMorphoVaultV1AdapterWithZeroAllocation() external {
        _setBoringVaultShareClaim(1_000e18);
        asset.mint(address(morphoV2Vault), 100e18);
        _setMorphoVaultV1LiquidityAdapter(asset, 0, 240e18);

        assertEq(_withdrawable(), 100e18);
    }

    function testReturnsIdleOnlyForMorphoVaultV1AdapterWithNonEmptyLiquidityData() external {
        _setBoringVaultShareClaim(1_000e18);
        asset.mint(address(morphoV2Vault), 100e18);
        _setMorphoVaultV1LiquidityAdapter(asset, 300e18, 240e18);
        morphoV2Vault.setLiquidityData(hex"1234");

        assertEq(_withdrawable(), 100e18);
    }

    function testReturnsIdleOnlyForMorphoVaultV1AdapterAssetMismatch() external {
        MockERC20Mintable otherAsset = new MockERC20Mintable();

        _setBoringVaultShareClaim(1_000e18);
        asset.mint(address(morphoV2Vault), 100e18);
        _setMorphoVaultV1LiquidityAdapter(otherAsset, 300e18, 240e18);

        assertEq(_withdrawable(), 100e18);
    }

    function _setBoringVaultShareClaim(uint256 assets) internal {
        morphoV2Vault.mintShares(boringVault, assets);
        morphoV2Vault.setTotalAssets(assets);
    }

    function _withdrawable() internal view returns (uint256) {
        return lens.getInstantlyWithdrawableAmount(TellerWithBuffer(address(teller)), asset);
    }

    function _setLiquidityData(MarketParams memory marketParams) internal returns (bytes32 marketId) {
        marketId = _marketId(marketParams);
        liquidityAdapter.setAllocation(marketParams, 1);
        morphoV2Vault.setLiquidityData(abi.encode(marketParams));
    }

    function _setMorphoVaultV1LiquidityAdapter(ERC20 vaultAsset, uint256 allocation, uint256 maxWithdrawAmount)
        internal
    {
        MockMorphoVaultV1 morphoVaultV1 = new MockMorphoVaultV1(vaultAsset);
        morphoVaultV1.setMaxWithdraw(maxWithdrawAmount);

        MockMorphoVaultV1LiquidityAdapter morphoVaultV1Adapter =
            new MockMorphoVaultV1LiquidityAdapter(address(morphoVaultV1));
        morphoVaultV1Adapter.setAllocation(allocation);

        morphoV2Vault.setLiquidityAdapter(address(morphoVaultV1Adapter));
        morphoV2Vault.setLiquidityData(hex"");
    }

    function _marketId(MarketParams memory marketParams) internal pure returns (bytes32) {
        return keccak256(abi.encode(marketParams));
    }
}
