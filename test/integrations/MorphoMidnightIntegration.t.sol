// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {MorphoMidnightDecoderAndSanitizerSingleton} from "src/base/DecodersAndSanitizers/MorphoMidnightDecoderAndSanitizerSingleton.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test} from "@forge-std/Test.sol";

/// @notice Fork test that round-trips supplyCollateral -> withdrawCollateral through the BoringVault
///         manager against the REAL deployed Morpho Midnight singleton on Base. This is the closure for
///         the ABI-drift risk: the decoder/leaf-helper assumptions (struct layout, selectors, IdLib
///         market-id derivation) were pinned at commit f47568c; this proves they still match the live
///         contract. The collateral path needs no ratified offer/counterparty, so it exercises the full
///         leaf -> manager -> decoder -> real singleton stack without constructing maker offers.
contract MorphoMidnightIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;

    ManagerWithMerkleVerification internal manager;
    BoringVault internal boringVault;
    address internal rawDataDecoderAndSanitizer;
    RolesAuthority internal rolesAuthority;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    // Deployed Morpho Midnight singleton on Base (docs.morpho.org, src/Midnight.sol).
    address internal constant MIDNIGHT = 0xAdedD8ab6dE832766Fedf0FaC4992E5C4D3EA18A;
    // Base tokens.
    ERC20 internal constant cbBTC = ERC20(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf); // 8 decimals
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // 6 decimals
    address internal constant CBBTC_USDC_ORACLE = 0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9;

    // Golden values for the live cbBTC/USDC market below (MarketCreated tx
    // 0xcefc70e7a0098b85eca425fd9fb25d282d409d6c57b0ebfcc9976aaa01ad6120), independently confirmed by
    // reproducing IdLib.toId and by cast-checking that the SSTORE2 market-data contract has code onchain.
    bytes32 internal constant MARKET_FULL_ID = 0xea5d813ec70a84ef94e15143a41427d7bd597fc74ca0685688724c56d40aa1b2;
    address internal constant MARKET_DATA_ADDRESS = 0xA41427d7bD597fC74Ca0685688724C56d40Aa1B2;

    uint256 internal constant SUPPLY_AMOUNT = 1e8; // 1 cbBTC

    function setUp() external {
        setSourceChainName("base");
        // Base fork after the market's creation block (48417793) and well before its maturity
        // (1785510000 = 2026-07-31), so supplyCollateral/withdrawCollateral are live.
        _startFork("BASE_RPC_URL", 48995000);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);
        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));
        rawDataDecoderAndSanitizer = address(new MorphoMidnightDecoderAndSanitizerSingleton());

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(manager));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MANAGER_ROLE, address(boringVault), bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))), true);
        rolesAuthority.setRoleCapability(MANAGER_ROLE, address(boringVault), bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))), true);
        rolesAuthority.setRoleCapability(STRATEGIST_ROLE, address(manager), ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector, true);
        rolesAuthority.setRoleCapability(MANGER_INTERNAL_ROLE, address(manager), ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true);

        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);

        // Fund the vault with cbBTC to post as collateral.
        deal(address(cbBTC), address(boringVault), SUPPLY_AMOUNT);
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function _fixtureMarket() internal pure returns (DecoderCustomTypes.MidnightMarket memory market) {
        DecoderCustomTypes.MidnightCollateralParams[] memory collateralParams = new DecoderCustomTypes.MidnightCollateralParams[](1);
        collateralParams[0] =
            DecoderCustomTypes.MidnightCollateralParams({token: address(cbBTC), lltv: 0.98e18, liquidationCursor: 0.3e18, oracle: CBBTC_USDC_ORACLE});
        market = DecoderCustomTypes.MidnightMarket({
            chainId: 8453,
            midnight: MIDNIGHT,
            loanToken: USDC,
            collateralParams: collateralParams,
            maturity: 1785510000,
            rcfThreshold: 0,
            enterGate: address(0),
            liquidatorGate: address(0)
        });
    }

    /// @dev Proves the decoder/helper IdLib derivation matches the LIVE protocol: the id computed from
    ///      our hardcoded struct must equal the onchain market id, and the SSTORE2 data contract at that
    ///      address must actually exist on Base. A struct/field-order/prefix drift would break this.
    function testForkMarketIdMatchesLiveDeployment() external view {
        (bytes32 fullId, address idAddress) = _getMidnightMarketId(_fixtureMarket());
        assertEq(fullId, MARKET_FULL_ID, "computed id != live market id");
        assertEq(idAddress, MARKET_DATA_ADDRESS, "computed data address != live data address");
        assertGt(idAddress.code.length, 0, "SSTORE2 market-data contract has no code onchain");
    }

    /// @dev Full round-trip through the real singleton: approve + supplyCollateral, then withdrawCollateral.
    function testForkSupplyThenWithdrawCollateral() external {
        DecoderCustomTypes.MidnightMarket memory market = _fixtureMarket();

        // Collateral builder emits [approve(cbBTC), supplyCollateral, withdrawCollateral] at 0,1,2.
        // Pad to an even length so the merkle tree builder pairs cleanly.
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addMorphoMidnightCollateralLeafs(leafs, market, 0);
        // Empty pad leaf: give it the configured decoder so _generateMerkleTree and _getProofsUsingTree
        // hash it identically (the latter always uses rawDataDecoderAndSanitizer for the digest).
        leafs[3].decoderAndSanitizer = rawDataDecoderAndSanitizer;
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        bytes32[][] memory proofs = _getProofsUsingTree(leafs, manageTree);

        string memory supplySig = string.concat("supplyCollateral(", MIDNIGHT_MARKET_TUPLE, ",uint256,uint256,address)");
        string memory withdrawSig = string.concat("withdrawCollateral(", MIDNIGHT_MARKET_TUPLE, ",uint256,uint256,address,address)");

        uint256 vaultBefore = cbBTC.balanceOf(address(boringVault));
        uint256 singletonBefore = cbBTC.balanceOf(MIDNIGHT);

        // Call 1: approve cbBTC to the singleton, then supply it as collateral for the vault's position.
        {
            bytes32[][] memory p = new bytes32[][](2);
            p[0] = proofs[0];
            p[1] = proofs[1];
            address[] memory targets = new address[](2);
            targets[0] = address(cbBTC);
            targets[1] = MIDNIGHT;
            bytes[] memory data = new bytes[](2);
            data[0] = abi.encodeWithSignature("approve(address,uint256)", MIDNIGHT, SUPPLY_AMOUNT);
            data[1] = abi.encodeWithSignature(supplySig, market, uint256(0), SUPPLY_AMOUNT, address(boringVault));
            address[] memory dec = new address[](2);
            dec[0] = rawDataDecoderAndSanitizer;
            dec[1] = rawDataDecoderAndSanitizer;
            uint256[] memory values = new uint256[](2);
            manager.manageVaultWithMerkleVerification(p, dec, targets, data, values);
        }

        assertEq(cbBTC.balanceOf(address(boringVault)), vaultBefore - SUPPLY_AMOUNT, "vault should have posted cbBTC");
        assertEq(cbBTC.balanceOf(MIDNIGHT), singletonBefore + SUPPLY_AMOUNT, "singleton should custody the cbBTC");

        // Call 2: withdraw the collateral back to the vault (no debt => position stays healthy).
        {
            bytes32[][] memory p = new bytes32[][](1);
            p[0] = proofs[2];
            address[] memory targets = new address[](1);
            targets[0] = MIDNIGHT;
            bytes[] memory data = new bytes[](1);
            data[0] = abi.encodeWithSignature(withdrawSig, market, uint256(0), SUPPLY_AMOUNT, address(boringVault), address(boringVault));
            address[] memory dec = new address[](1);
            dec[0] = rawDataDecoderAndSanitizer;
            uint256[] memory values = new uint256[](1);
            manager.manageVaultWithMerkleVerification(p, dec, targets, data, values);
        }

        assertEq(cbBTC.balanceOf(address(boringVault)), vaultBefore, "vault should have its cbBTC back");
        assertEq(cbBTC.balanceOf(MIDNIGHT), singletonBefore, "singleton collateral should be released");
    }
}

/// @notice Replays a REAL historical Morpho Midnight sell offer on a Base fork, with the BoringVault as
///         the taker (buyer/lender). This is the take() closure the collateral round-trip could not give:
///         it drives an actual ratified offer through the manager -> decoder -> live singleton. The offer,
///         its EcrecoverRatifier signature, and the merkle proof are lifted verbatim from the calldata of
///         historical take tx 0xa5ac5d25e2e64f5e3bacc94be9ed414c69ed15b4d3a7d2a39adfc855b4073683 (block
///         48420789); we fork the block before it so the offer is still un-consumed. The ratifier signature
///         commits only to the offer-tree root + chainid + ratifier address, never the taker, so the vault
///         can settle it in place of the original taker.
contract MorphoMidnightTakeForkTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;

    ManagerWithMerkleVerification internal manager;
    BoringVault internal boringVault;
    address internal rawDataDecoderAndSanitizer;
    RolesAuthority internal rolesAuthority;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;

    address internal constant MIDNIGHT = 0xAdedD8ab6dE832766Fedf0FaC4992E5C4D3EA18A;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant WETH_USDC_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address internal constant ECRECOVER_RATIFIER = 0xd6e70365C8E8DDa9a4ca662C07bbE663b017755E;
    address internal constant MAKER = 0x6bA008e3F6eC55Dc6412e459Ac67949c6D1620c5;

    // Live market id for the WETH/USDC market the offer trades in (independently confirmed below).
    bytes32 internal constant MARKET_ID = 0x10a033a31e0143f28ea28af165b8c931764f5679843754dea86a0c6320655eb2;

    uint256 internal constant UNITS = 100570; // fills for buyerAssets = 100000 (0.1 USDC), fee 0
    uint256 internal constant EXPECTED_USDC_PAID = 100000;

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function setUp() external {
        setSourceChainName("base");
        // One block before historical take tx 0xa5ac...3683 (block 48420789), so the offer is un-consumed.
        // block.timestamp here = 1783630923, within [offer.start 1783616275, offer.expiry 1787929199].
        _startFork("BASE_RPC_URL", 48420788);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);
        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));
        rawDataDecoderAndSanitizer = address(new MorphoMidnightDecoderAndSanitizerSingleton());

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(manager));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MANAGER_ROLE, address(boringVault), bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))), true);
        rolesAuthority.setRoleCapability(MANAGER_ROLE, address(boringVault), bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))), true);
        rolesAuthority.setRoleCapability(STRATEGIST_ROLE, address(manager), ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector, true);
        rolesAuthority.setRoleCapability(MANGER_INTERNAL_ROLE, address(manager), ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true);

        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);

        // Fund the vault with USDC to pay for the credit it buys.
        deal(USDC, address(boringVault), 1e6);
    }

    function _offer() internal pure returns (DecoderCustomTypes.MidnightOffer memory offer) {
        DecoderCustomTypes.MidnightCollateralParams[] memory cp = new DecoderCustomTypes.MidnightCollateralParams[](1);
        cp[0] = DecoderCustomTypes.MidnightCollateralParams({token: WETH, lltv: 0.86e18, liquidationCursor: 0.3e18, oracle: WETH_USDC_ORACLE});
        offer = DecoderCustomTypes.MidnightOffer({
            market: DecoderCustomTypes.MidnightMarket({
                chainId: 8453,
                midnight: MIDNIGHT,
                loanToken: USDC,
                collateralParams: cp,
                maturity: 1787929200,
                rcfThreshold: 0,
                enterGate: address(0),
                liquidatorGate: address(0)
            }),
            buy: false, // sell offer: taker (vault) is the buyer/lender, pays USDC
            maker: MAKER,
            start: 1783616275,
            expiry: 1787929199,
            tick: 4408,
            group: 0x32289529196acf633b8cc6b170789af5193d410e160f29c44436626d3f7414b9,
            callback: address(0),
            callbackData: hex"",
            receiverIfMakerIsSeller: MAKER,
            ratifier: ECRECOVER_RATIFIER,
            reduceOnly: false,
            maxUnits: 3333333,
            maxAssets: 0,
            continuousFeeCap: 317097919
        });
    }

    // EcrecoverRatifier ratifierData = abi.encode(Signature{v,r,s}, root, leafIndex, proof[]), lifted from
    // the historical take calldata. Taker-agnostic: the signed digest commits to (offer-tree root, chainid,
    // ratifier), so the vault can reuse it.
    function _ratifierData() internal pure returns (bytes memory) {
        return hex"000000000000000000000000000000000000000000000000000000000000001c20bce965fcdedc509a1cb3d8f3ad7e24774b4692410fdf30fb31662a4584a9df7778d521691fcc778e70d606934ef67d2b63059d24c51bafb155d82824e29367bf491e843850cfe7587c551ba2e86ea50b1e51c1d1b11c532f4dfd4366a736d6000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000259931827d7e4bea2472434c9cefa6baeb450425181a8e4bc73ebe59f9bcf248e129777181b8d14e184bc1aa1600c773efe598335755b63c7e666fb86fc83845f";
    }

    /// @dev Midnight's take() price/tick math uses the Osaka CLZ opcode (Midnight.sol NatSpec), which revm
    ///      only executes under an Osaka+ spec. Probe for it so the suite's default `cancun` run skips this
    ///      test instead of failing with NotActivated. To actually run it: `forge test --evm-version osaka`.
    function _osakaEvmActive() internal returns (bool active) {
        address probe = address(uint160(uint256(keccak256("midnight.clz.probe"))));
        vm.etch(probe, hex"5f1e00"); // PUSH0; CLZ; STOP — reverts (NotActivated) on pre-Osaka specs
        (active,) = probe.staticcall("");
        vm.etch(probe, hex"");
    }

    function testForkTakeReplaysHistoricalSellOffer() external {
        if (!_osakaEvmActive()) {
            emit log("skipping take() replay: requires --evm-version osaka (Midnight uses the CLZ opcode)");
            vm.skip(true);
            return;
        }

        DecoderCustomTypes.MidnightOffer memory offer = _offer();

        // Sanity: our IdLib derivation lands on the live market this offer trades in.
        (bytes32 fullId,) = _getMidnightMarketId(offer.market);
        assertEq(fullId, MARKET_ID, "offer market id != live market id");

        // Lend-side leaves: approve(USDC)=0, take (buy=false)=1, withdraw=2, updatePosition=3 (even, no pad).
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addMorphoMidnightSupplyLeafs(leafs, offer.market, offer.maker, offer.callback, offer.receiverIfMakerIsSeller, offer.ratifier, true);
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        bytes32[][] memory proofs = _getProofsUsingTree(leafs, manageTree);

        bytes32[][] memory p = new bytes32[][](2);
        p[0] = proofs[0]; // approve(USDC)
        p[1] = proofs[1]; // take

        address[] memory targets = new address[](2);
        targets[0] = USDC;
        targets[1] = MIDNIGHT;

        bytes memory takeData = abi.encodeWithSignature(
            _midnightTakeSignature(),
            offer,
            _ratifierData(),
            UNITS,
            address(boringVault), // taker
            address(0), // receiverIfTakerIsSeller (must be 0 for buy==false)
            address(0), // takerCallback (decoder rejects nonzero)
            hex"" // takerCallbackData
        );
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSignature("approve(address,uint256)", MIDNIGHT, type(uint256).max);
        data[1] = takeData;

        address[] memory dec = new address[](2);
        dec[0] = rawDataDecoderAndSanitizer;
        dec[1] = rawDataDecoderAndSanitizer;
        uint256[] memory values = new uint256[](2);

        uint256 vaultUsdcBefore = ERC20(USDC).balanceOf(address(boringVault));
        uint256 makerUsdcBefore = ERC20(USDC).balanceOf(MAKER);
        uint256 singletonUsdcBefore = ERC20(USDC).balanceOf(MIDNIGHT);

        manager.manageVaultWithMerkleVerification(p, dec, targets, data, values);

        // The vault paid USDC for the credit; the maker (offer.receiverIfMakerIsSeller) received it; no fee.
        assertEq(vaultUsdcBefore - ERC20(USDC).balanceOf(address(boringVault)), EXPECTED_USDC_PAID, "vault should have paid 100000 USDC");
        assertEq(ERC20(USDC).balanceOf(MAKER) - makerUsdcBefore, EXPECTED_USDC_PAID, "maker should have received the USDC");
        assertEq(ERC20(USDC).balanceOf(MIDNIGHT), singletonUsdcBefore, "singleton should keep no settlement fee");
    }
}
