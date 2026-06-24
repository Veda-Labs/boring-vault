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
import {ERC4626BufferLens} from "src/helper/ERC4626BufferLens.sol";

contract MockERC20Mintable is ERC20 {
    constructor() ERC20("Mock Asset", "MOCK", 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockERC4626 is ERC4626 {
    uint256 internal totalAssets_;
    uint256 internal maxWithdrawCap = type(uint256).max; // uncapped by default

    constructor(ERC20 asset_) ERC4626(asset_, "Mock Vault", "mVLT") {}

    function setTotalAssets(uint256 assets) external {
        totalAssets_ = assets;
    }

    function mintShares(address to, uint256 shares) external {
        _mint(to, shares);
    }

    /// @notice Simulate a liquidity shortfall / withdrawal pause that caps maxWithdraw below the share claim.
    function setMaxWithdrawCap(uint256 cap) external {
        maxWithdrawCap = cap;
    }

    function totalAssets() public view override returns (uint256) {
        return totalAssets_;
    }

    function maxWithdraw(address owner) public view override returns (uint256) {
        uint256 byShares = convertToAssets(balanceOf[owner]);
        return byShares < maxWithdrawCap ? byShares : maxWithdrawCap;
    }
}

/// @notice Minimal stand-in exposing only the surface the lens reads off the helper.
contract MockERC4626BufferHelper {
    ERC4626 public immutable ERC_4626_VAULT;

    constructor(ERC4626 vault_) {
        ERC_4626_VAULT = vault_;
    }
}

/// @notice Minimal stand-in exposing only the teller surface the lens reads.
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

contract ERC4626BufferLensTest is Test {
    address internal boringVault = address(0xB0B);

    MockERC20Mintable internal asset;
    MockERC4626 internal erc4626Vault;
    MockERC4626BufferHelper internal bufferHelper;
    MockTellerWithBufferShape internal teller;
    ERC4626BufferLens internal lens;

    function setUp() external {
        asset = new MockERC20Mintable();
        erc4626Vault = new MockERC4626(asset);
        bufferHelper = new MockERC4626BufferHelper(ERC4626(address(erc4626Vault)));
        teller = new MockTellerWithBufferShape(boringVault);
        teller.setWithdrawBufferHelper(address(bufferHelper));
        lens = new ERC4626BufferLens();
    }

    function _withdrawable() internal view returns (uint256) {
        return lens.getInstantlyWithdrawableAmount(TellerWithBuffer(address(teller)), asset);
    }

    function testNoHelperReturnsIdleVaultBalance() external {
        teller.setWithdrawBufferHelper(address(0));
        asset.mint(boringVault, 777e18);

        assertEq(_withdrawable(), 777e18);
    }

    function testReturnsVaultMaxWithdraw() external {
        // Non-1:1 price per share so the result reflects maxWithdraw, not the raw share count:
        // vault owns 100 shares of a 200-share / 500-asset vault => 100 * 500 / 200 = 250 assets.
        erc4626Vault.mintShares(boringVault, 100e18);
        erc4626Vault.mintShares(address(0xCAFE), 100e18); // totalSupply = 200
        erc4626Vault.setTotalAssets(500e18);
        asset.mint(address(erc4626Vault), 500e18);

        // Independent oracle: maxWithdraw = balanceOf(vault) * totalAssets / totalSupply.
        uint256 expected = 100e18 * 500e18 / 200e18; // 250e18
        assertEq(erc4626Vault.maxWithdraw(boringVault), expected); // confirm the mock matches the formula
        assertEq(_withdrawable(), expected);
    }

    function testReturnsConstrainedMaxWithdraw() external {
        // Solvent on paper: 100 shares of a 200-share / 500-asset vault => 250 assets claimable.
        erc4626Vault.mintShares(boringVault, 100e18);
        erc4626Vault.mintShares(address(0xCAFE), 100e18);
        erc4626Vault.setTotalAssets(500e18);
        asset.mint(address(erc4626Vault), 500e18);
        assertEq(erc4626Vault.convertToAssets(100e18), 250e18, "paper claim is 250");

        // ...but a liquidity shortfall / withdrawal pause caps maxWithdraw at 100. The lens is documented
        // to trust maxWithdraw, so it MUST report the constraint (100), not the 250 paper claim.
        erc4626Vault.setMaxWithdrawCap(100e18);
        assertEq(_withdrawable(), 100e18, "lens must propagate the constrained maxWithdraw, not the share claim");
    }

    function testReturnsZeroWhenVaultEmpty() external {
        // No shares held by the vault -> maxWithdraw is 0.
        erc4626Vault.setTotalAssets(0);
        assertEq(_withdrawable(), 0);
    }

    function testRevertsOnAssetMismatch() external {
        // The configured ERC4626 vault's underlying is `asset`, but we query a different token.
        MockERC20Mintable otherAsset = new MockERC20Mintable();
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC4626BufferLens.ERC4626BufferLens__AssetMismatch.selector, address(otherAsset), address(asset)
            )
        );
        lens.getInstantlyWithdrawableAmount(TellerWithBuffer(address(teller)), otherAsset);
    }
}
