// SPDX-License-Identifier: UNLICENSED
// forge test --match-contract PrvlAaveBorrow -vvvv
pragma solidity 0.8.21;

import {PrvlAaveBorrow, TokenConfig} from "src/adaptors/PrvlAaveBorrow.sol";
import {DeployPrvlBorrow} from "script/DeployPrvlBorrow.s.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {PrvlAgentVaultDecoderAndSanitizerV2} from "src/base/DecodersAndSanitizers/Protocols/Paravel/PrvlAgentVaultDecoderAndSanitizerV2.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Test, console} from "@forge-std/Test.sol";

interface IDebtToken {
    function approveDelegation(address delegatee, uint256 amount) external;
}

interface IWstETH {
    function stEthPerToken() external view returns (uint256);
}

interface IAavePool {
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
}

contract PrvlAaveBorrowTest is Test {
    address constant TEAM_MULTISIG = 0xE42C03CB1999E345fdE8465CAAf4B4379143375F;
    address constant TEST_CALLER = 0x0000000000000000000000000000000000000111;

    address constant UNISWAP_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant AAVE_POOL = 0x4e033931ad43597d96D6bcc25c280717730B58B1;

    address constant VAULT = 0x951f36b2F8Fd8B213AE999E53dF1c77749A6cDed;
    address constant MANAGER = 0x618c13371DB671AdbCbA93e76f758E307E6A0871;
    address constant AUTHORITY = 0x0951A4fa55DD8F20B1eab2021cD8693D32f410B5;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant A_WSTETH = 0xC035a7cf15375cE2706766804551791aD035E0C2;
    address constant DEBT_WETH = 0x91b7d78BF92db564221f6B5AeE744D1727d1Dd1e;

    PrvlAaveBorrow public adaptor;
    BoringVault public boringVault;
    ManagerWithMerkleVerification public manager;
    RolesAuthority public rolesAuthority;
    PrvlAgentVaultDecoderAndSanitizerV2 public decoder;

    uint256 public configId;
    bytes32 public merkleRoot;

    uint8 constant STRATEGIST_ROLE = 7;

    struct ManageLeaf {
        address target;
        bool canSendValue;
        bytes4 selector;
        address[] argumentAddresses;
    }

    function setUp() public {
        string memory rpcKey = "MAINNET_RPC_URL";
        vm.createSelectFork(vm.envString(rpcKey));

        boringVault = BoringVault(payable(VAULT));
        manager = ManagerWithMerkleVerification(MANAGER);
        rolesAuthority = RolesAuthority(AUTHORITY);

        vm.startPrank(TEAM_MULTISIG);
        decoder = new PrvlAgentVaultDecoderAndSanitizerV2();
        adaptor = new PrvlAaveBorrow(TEAM_MULTISIG, AUTHORITY, UNISWAP_ROUTER, AAVE_POOL, VAULT);

        TokenConfig memory config = TokenConfig({
            baseToken: WETH,
            depositToken: WSTETH,
            aToken: A_WSTETH,
            debtToken: DEBT_WETH,
            aaveVariableRate: 2,
            path0: hex"c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000647f39c581f595b53c5cb19bd0b3f8da6c935e2ca0",
            path1: hex"7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0000064c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
        });
        configId = adaptor.setTokenConfig(config);

        // Allow VAULT to call adaptor vault functions
        rolesAuthority.setRoleCapability(STRATEGIST_ROLE, address(adaptor), PrvlAaveBorrow.supply.selector, true);
        rolesAuthority.setRoleCapability(STRATEGIST_ROLE, address(adaptor), PrvlAaveBorrow.reducePosition.selector, true);
        rolesAuthority.setRoleCapability(STRATEGIST_ROLE, address(adaptor), PrvlAaveBorrow.settle.selector, true);
        rolesAuthority.setUserRole(VAULT, STRATEGIST_ROLE, true);
        vm.stopPrank();

        _setupMerkleTree();
        _setupRoles();
    }

    function _setupMerkleTree() internal {
        ManageLeaf[] memory leafs = _buildMerkleLeafs();
        merkleRoot = _generateMerkleRoot(leafs);
        _setMerkleRoot();
    }

    function _buildMerkleLeafs() internal view returns (ManageLeaf[] memory leafs) {
        leafs = new ManageLeaf[](9);

        // supply(uint256,uint256,uint256,uint256)
        leafs[0] = ManageLeaf({
            target: address(adaptor),
            canSendValue: false,
            selector: PrvlAaveBorrow.supply.selector,
            argumentAddresses: new address[](0)
        });

        // reducePosition(uint256,uint256,uint256,uint256)
        leafs[1] = ManageLeaf({
            target: address(adaptor),
            canSendValue: false,
            selector: PrvlAaveBorrow.reducePosition.selector,
            argumentAddresses: new address[](0)
        });

        // settle(uint256,uint256)
        leafs[2] = ManageLeaf({
            target: address(adaptor),
            canSendValue: false,
            selector: PrvlAaveBorrow.settle.selector,
            argumentAddresses: new address[](0)
        });

        // Approval for WETH to adaptor
        leafs[3] = ManageLeaf({
            target: WETH,
            canSendValue: false,
            selector: ERC20.approve.selector,
            argumentAddresses: new address[](1)
        });
        leafs[3].argumentAddresses[0] = address(adaptor);

        // Approval for WSTETH to adaptor
        leafs[4] = ManageLeaf({
            target: WSTETH,
            canSendValue: false,
            selector: ERC20.approve.selector,
            argumentAddresses: new address[](1)
        });
        leafs[4].argumentAddresses[0] = address(adaptor);

        // Approval for aWSTETH to adaptor
        leafs[5] = ManageLeaf({
            target: A_WSTETH,
            canSendValue: false,
            selector: ERC20.approve.selector,
            argumentAddresses: new address[](1)
        });
        leafs[5].argumentAddresses[0] = address(adaptor);

        // Approval for WETH to Aave pool (for repayment)
        leafs[6] = ManageLeaf({
            target: WETH,
            canSendValue: false,
            selector: ERC20.approve.selector,
            argumentAddresses: new address[](1)
        });
        leafs[6].argumentAddresses[0] = AAVE_POOL;

        // Approval for WSTETH to Aave pool
        leafs[7] = ManageLeaf({
            target: WSTETH,
            canSendValue: false,
            selector: ERC20.approve.selector,
            argumentAddresses: new address[](1)
        });
        leafs[7].argumentAddresses[0] = AAVE_POOL;

        // approveDelegation for debt token to adaptor
        leafs[8] = ManageLeaf({
            target: DEBT_WETH,
            canSendValue: false,
            selector: IDebtToken.approveDelegation.selector,
            argumentAddresses: new address[](1)
        });
        leafs[8].argumentAddresses[0] = address(adaptor);
    }

    function _setMerkleRoot() internal {
        vm.prank(TEAM_MULTISIG);
        manager.setManageRoot(TEST_CALLER, merkleRoot);
    }

    function _setupRoles() internal {
        vm.startPrank(TEAM_MULTISIG);
        rolesAuthority.setUserRole(TEST_CALLER, STRATEGIST_ROLE, true);
        vm.stopPrank();
    }

    function _generateMerkleRoot(ManageLeaf[] memory leafs) internal view returns (bytes32) {
        uint256 leafsLength = leafs.length;
        bytes32[] memory hashes = new bytes32[](leafsLength);

        for (uint256 i; i < leafsLength; ++i) {
            bytes memory rawDigest = abi.encodePacked(
                address(decoder),
                leafs[i].target,
                leafs[i].canSendValue,
                leafs[i].selector
            );
            for (uint256 j; j < leafs[i].argumentAddresses.length; ++j) {
                rawDigest = abi.encodePacked(rawDigest, leafs[i].argumentAddresses[j]);
            }
            hashes[i] = keccak256(rawDigest);
        }

        return _buildMerkleRoot(hashes);
    }

    function _buildMerkleRoot(bytes32[] memory hashes) internal pure returns (bytes32) {
        if (hashes.length == 1) return hashes[0];

        uint256 nextLen = (hashes.length + 1) / 2;
        bytes32[] memory nextLevel = new bytes32[](nextLen);

        for (uint256 i = 0; i < hashes.length; i += 2) {
            if (i + 1 < hashes.length) {
                nextLevel[i / 2] = _hashPair(hashes[i], hashes[i + 1]);
            } else {
                nextLevel[i / 2] = hashes[i];
            }
        }

        return _buildMerkleRoot(nextLevel);
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _getProof(ManageLeaf memory leaf, ManageLeaf[] memory allLeafs) internal view returns (bytes32[] memory) {
        bytes32[] memory hashes = new bytes32[](allLeafs.length);
        uint256 targetIndex;

        bytes memory targetDigest = abi.encodePacked(address(decoder), leaf.target, leaf.canSendValue, leaf.selector);
        for (uint256 j; j < leaf.argumentAddresses.length; ++j) {
            targetDigest = abi.encodePacked(targetDigest, leaf.argumentAddresses[j]);
        }
        bytes32 targetHash = keccak256(targetDigest);

        for (uint256 i; i < allLeafs.length; ++i) {
            bytes memory rawDigest = abi.encodePacked(
                address(decoder),
                allLeafs[i].target,
                allLeafs[i].canSendValue,
                allLeafs[i].selector
            );
            for (uint256 j; j < allLeafs[i].argumentAddresses.length; ++j) {
                rawDigest = abi.encodePacked(rawDigest, allLeafs[i].argumentAddresses[j]);
            }
            hashes[i] = keccak256(rawDigest);
            if (hashes[i] == targetHash) targetIndex = i;
        }

        return _buildProof(hashes, targetIndex);
    }

    function _buildProof(bytes32[] memory hashes, uint256 targetIndex) internal pure returns (bytes32[] memory) {
        if (hashes.length == 1) return new bytes32[](0);

        uint256 proofLen = 0;
        uint256 tempLen = hashes.length;
        while (tempLen > 1) {
            proofLen++;
            tempLen = (tempLen + 1) / 2;
        }

        bytes32[] memory proof = new bytes32[](proofLen);
        uint256 proofIndex = 0;
        uint256 index = targetIndex;

        bytes32[] memory currentLevel = hashes;

        while (currentLevel.length > 1) {
            uint256 nextLen = (currentLevel.length + 1) / 2;
            bytes32[] memory nextLevel = new bytes32[](nextLen);

            for (uint256 i = 0; i < currentLevel.length; i += 2) {
                if (i + 1 < currentLevel.length) {
                    nextLevel[i / 2] = _hashPair(currentLevel[i], currentLevel[i + 1]);

                    if (i == index || i + 1 == index) {
                        proof[proofIndex] = (i == index) ? currentLevel[i + 1] : currentLevel[i];
                        proofIndex++;
                        index = i / 2;
                    }
                } else {
                    nextLevel[i / 2] = currentLevel[i];
                    if (i == index) {
                        index = i / 2;
                    }
                }
            }
            currentLevel = nextLevel;
        }

        // Trim proof array to actual size
        bytes32[] memory trimmedProof = new bytes32[](proofIndex);
        for (uint256 i = 0; i < proofIndex; i++) {
            trimmedProof[i] = proof[i];
        }
        return trimmedProof;
    }

    // ========================================= UNIT TESTS =========================================

    function test_Constructor() public view {
        assertEq(address(adaptor.uniswapV3Router()), UNISWAP_ROUTER);
        assertEq(address(adaptor.aave()), AAVE_POOL);
        assertEq(adaptor.vault(), VAULT);
    }

    function test_Constructor_RevertZeroAddress() public {
        vm.expectRevert(PrvlAaveBorrow.PrvlAaveBorrow__invalidZeroAddress.selector);
        new PrvlAaveBorrow(address(0), AUTHORITY, UNISWAP_ROUTER, AAVE_POOL, VAULT);

        vm.expectRevert(PrvlAaveBorrow.PrvlAaveBorrow__invalidZeroAddress.selector);
        new PrvlAaveBorrow(TEAM_MULTISIG, AUTHORITY, address(0), AAVE_POOL, VAULT);

        vm.expectRevert(PrvlAaveBorrow.PrvlAaveBorrow__invalidZeroAddress.selector);
        new PrvlAaveBorrow(TEAM_MULTISIG, AUTHORITY, UNISWAP_ROUTER, address(0), VAULT);

        vm.expectRevert(PrvlAaveBorrow.PrvlAaveBorrow__invalidZeroAddress.selector);
        new PrvlAaveBorrow(TEAM_MULTISIG, AUTHORITY, UNISWAP_ROUTER, AAVE_POOL, address(0));
    }

    function test_SetTokenConfig() public {
        vm.startPrank(TEAM_MULTISIG);
        PrvlAaveBorrow newAdaptor = new PrvlAaveBorrow(TEAM_MULTISIG, AUTHORITY, UNISWAP_ROUTER, AAVE_POOL, VAULT);

        TokenConfig memory config = TokenConfig({
            baseToken: WETH,
            depositToken: WSTETH,
            aToken: A_WSTETH,
            debtToken: DEBT_WETH,
            aaveVariableRate: 2,
            path0: hex"c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000647f39c581f595b53c5cb19bd0b3f8da6c935e2ca0",
            path1: hex"7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0000064c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
        });

        uint256 id = newAdaptor.setTokenConfig(config);

        (address baseToken,,,,,,) = newAdaptor.tokenConfigs(id);
        assertEq(baseToken, WETH);
        vm.stopPrank();
    }

    function test_SetTokenConfig_RevertConfigExists() public {
        TokenConfig memory config = TokenConfig({
            baseToken: WETH,
            depositToken: WSTETH,
            aToken: A_WSTETH,
            debtToken: DEBT_WETH,
            aaveVariableRate: 2,
            path0: hex"c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000647f39c581f595b53c5cb19bd0b3f8da6c935e2ca0",
            path1: hex"7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0000064c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
        });

        vm.prank(TEAM_MULTISIG);
        vm.expectRevert(PrvlAaveBorrow.PrvlAaveBorrow__configAlreadyExists.selector);
        adaptor.setTokenConfig(config);
    }

    function test_SetTokenConfig_RevertZeroAddress() public {
        vm.startPrank(TEAM_MULTISIG);
        PrvlAaveBorrow newAdaptor = new PrvlAaveBorrow(TEAM_MULTISIG, AUTHORITY, UNISWAP_ROUTER, AAVE_POOL, VAULT);

        TokenConfig memory config = TokenConfig({
            baseToken: address(0),
            depositToken: WSTETH,
            aToken: A_WSTETH,
            debtToken: DEBT_WETH,
            aaveVariableRate: 2,
            path0: "",
            path1: ""
        });

        vm.expectRevert(PrvlAaveBorrow.PrvlAaveBorrow__invalidZeroAddress.selector);
        newAdaptor.setTokenConfig(config);
        vm.stopPrank();
    }

    function test_RemoveTokenConfig() public {
        vm.prank(TEAM_MULTISIG);
        adaptor.removeTokenConfig(configId);

        (address baseToken,,,,,,) = adaptor.tokenConfigs(configId);
        assertEq(baseToken, address(0));
    }

    function test_RemoveTokenConfig_RevertInvalidConfigId() public {
        vm.prank(TEAM_MULTISIG);
        vm.expectRevert(PrvlAaveBorrow.PrvlAaveBorrow__invalidConfigId.selector);
        adaptor.removeTokenConfig(999);
    }

    function test_SweepERC20() public {
        uint256 amount = 1 ether;
        deal(WETH, address(adaptor), amount);

        uint256 vaultBalBefore = ERC20(WETH).balanceOf(VAULT);

        vm.prank(TEAM_MULTISIG);
        adaptor.sweepERC20(WETH, amount);

        assertEq(ERC20(WETH).balanceOf(VAULT), vaultBalBefore + amount);
        assertEq(ERC20(WETH).balanceOf(address(adaptor)), 0);
    }

    function test_Supply_RevertMinOutZero() public {
        vm.prank(VAULT);
        vm.expectRevert(PrvlAaveBorrow.PrvlAaveBorrow__minOutCannotBeZero.selector);
        adaptor.supply(configId, 1 ether, 0, 0.5 ether);
    }

    function test_Supply_RevertInvalidConfigId() public {
        vm.prank(VAULT);
        vm.expectRevert(PrvlAaveBorrow.PrvlAaveBorrow__invalidConfigId.selector);
        adaptor.supply(999, 1 ether, 0.9 ether, 0.5 ether);
    }

    function test_ReducePosition_RevertMinOutZero() public {
        vm.prank(VAULT);
        vm.expectRevert(PrvlAaveBorrow.PrvlAaveBorrow__minOutCannotBeZero.selector);
        adaptor.reducePosition(configId, 0, 0.5 ether, 1 ether);
    }

    function test_ReducePosition_RevertInvalidConfigId() public {
        vm.prank(VAULT);
        vm.expectRevert(PrvlAaveBorrow.PrvlAaveBorrow__invalidConfigId.selector);
        adaptor.reducePosition(999, 0.9 ether, 0.5 ether, 1 ether);
    }

    function test_Settle_RevertMinOutZero() public {
        vm.prank(VAULT);
        vm.expectRevert(PrvlAaveBorrow.PrvlAaveBorrow__minOutCannotBeZero.selector);
        adaptor.settle(configId, 0);
    }

    function test_Settle_RevertInvalidConfigId() public {
        vm.prank(VAULT);
        vm.expectRevert(PrvlAaveBorrow.PrvlAaveBorrow__invalidConfigId.selector);
        adaptor.settle(999, 0.9 ether);
    }

    function test_AccessControl_Supply() public {
        address unauthorized = address(0xBAD);
        vm.prank(unauthorized);
        vm.expectRevert("UNAUTHORIZED");
        adaptor.supply(configId, 1 ether, 0.9 ether, 0.5 ether);
    }

    function test_AccessControl_ReducePosition() public {
        address unauthorized = address(0xBAD);
        vm.prank(unauthorized);
        vm.expectRevert("UNAUTHORIZED");
        adaptor.reducePosition(configId, 0.9 ether, 0.5 ether, 1 ether);
    }

    function test_AccessControl_Settle() public {
        address unauthorized = address(0xBAD);
        vm.prank(unauthorized);
        vm.expectRevert("UNAUTHORIZED");
        adaptor.settle(configId, 0.9 ether);
    }

    function test_AccessControl_SetTokenConfig() public {
        address unauthorized = address(0xBAD);
        TokenConfig memory config = TokenConfig({
            baseToken: address(1),
            depositToken: address(2),
            aToken: address(3),
            debtToken: address(4),
            aaveVariableRate: 2,
            path0: "",
            path1: ""
        });

        vm.prank(unauthorized);
        vm.expectRevert("UNAUTHORIZED");
        adaptor.setTokenConfig(config);
    }

    function test_AccessControl_RemoveTokenConfig() public {
        address unauthorized = address(0xBAD);
        vm.prank(unauthorized);
        vm.expectRevert("UNAUTHORIZED");
        adaptor.removeTokenConfig(configId);
    }

    function test_AccessControl_SweepERC20() public {
        address unauthorized = address(0xBAD);
        vm.prank(unauthorized);
        vm.expectRevert("UNAUTHORIZED");
        adaptor.sweepERC20(WETH, 1 ether);
    }

    // ========================================= INTEGRATION TESTS =========================================

    function test_Supply_Integration() public {
        uint256 amount = 10 ether;
        uint256 borrowAmount = 1 ether;
        uint256 minOut = (amount * 80) / 100;

        deal(WETH, VAULT, amount);

        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);
        vm.stopPrank();

        assertGt(ERC20(A_WSTETH).balanceOf(VAULT), 0, "Should have aTokens");
        assertGt(ERC20(DEBT_WETH).balanceOf(VAULT), 0, "Should have debt");
    }

    function test_Reduce_Integration() public {
        uint256 amount = 10 ether;
        uint256 borrowAmount = 1 ether;
        uint256 minOut = (amount * 80) / 100;

        deal(WETH, VAULT, amount * 2);

        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);

        uint256 aTokenBal = ERC20(A_WSTETH).balanceOf(VAULT);
        uint256 debtBal = ERC20(DEBT_WETH).balanceOf(VAULT);

        uint256 repayAmount = debtBal / 2;
        uint256 withdrawAmount = aTokenBal / 2;

        ERC20(WETH).approve(address(adaptor), repayAmount);
        ERC20(A_WSTETH).approve(address(adaptor), withdrawAmount);

        uint256 reduceMinOut = 1;
        adaptor.reducePosition(configId, reduceMinOut, repayAmount, withdrawAmount);
        vm.stopPrank();

        assertLt(ERC20(DEBT_WETH).balanceOf(VAULT), debtBal, "Debt should decrease");
    }

    function test_Settle_Integration() public {
        uint256 amount = 10 ether;
        uint256 borrowAmount = 2 ether;
        uint256 minOut = (amount * 80) / 100;

        deal(WETH, VAULT, amount * 5);

        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);

        uint256 debtBal = ERC20(DEBT_WETH).balanceOf(VAULT);
        assertGt(debtBal, 0, "Should have debt");

        ERC20(A_WSTETH).approve(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), type(uint256).max);

        adaptor.settle(configId, 1);
        vm.stopPrank();

        assertEq(ERC20(DEBT_WETH).balanceOf(VAULT), 0, "Debt should be zero after settle");
        assertEq(ERC20(A_WSTETH).balanceOf(VAULT), 0, "aToken balance should be zero after settle");
    }


    // ========================================= EDGE CASE TESTS =========================================

    function test_Supply_MaxAmount() public {
        uint256 amount = 100 ether;
        uint256 borrowAmount = 10 ether;
        uint256 minOut = (amount * 80) / 100;

        deal(WETH, VAULT, amount);

        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);
        vm.stopPrank();

        assertGt(ERC20(A_WSTETH).balanceOf(VAULT), 0);
    }

    function test_MultipleSupplyOperations() public {
        uint256 amount = 10 ether;
        uint256 borrowAmount = 1 ether;
        uint256 minOut = (amount * 80) / 100;

        deal(WETH, VAULT, amount * 3);

        vm.startPrank(VAULT);

        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount * 3);

        adaptor.supply(configId, amount, minOut, borrowAmount);
        uint256 aTokensAfterFirst = ERC20(A_WSTETH).balanceOf(VAULT);

        adaptor.supply(configId, amount, minOut, borrowAmount);
        uint256 aTokensAfterSecond = ERC20(A_WSTETH).balanceOf(VAULT);

        adaptor.supply(configId, amount, minOut, borrowAmount);
        uint256 aTokensAfterThird = ERC20(A_WSTETH).balanceOf(VAULT);

        vm.stopPrank();

        assertGt(aTokensAfterSecond, aTokensAfterFirst);
        assertGt(aTokensAfterThird, aTokensAfterSecond);
    }

    // ========================================= FUZZ TESTS =========================================

    function testFuzz_Supply(uint256 amount, uint256 borrowRatio) public {
        amount = bound(amount, 1 ether, 100 ether);
        borrowRatio = bound(borrowRatio, 1, 50);

        uint256 minOut = (amount * 80) / 100;
        uint256 borrowAmount = (minOut * borrowRatio) / 100;

        deal(WETH, VAULT, amount);

        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);
        vm.stopPrank();

        assertGt(ERC20(A_WSTETH).balanceOf(VAULT), 0, "Should have aTokens");
        assertGt(ERC20(DEBT_WETH).balanceOf(VAULT), 0, "Should have debt");
    }

    function testFuzz_SupplyAndSettle(uint256 amount, uint256 borrowRatio) public {
        amount = bound(amount, 1 ether, 100 ether);
        borrowRatio = bound(borrowRatio, 1, 50);

        uint256 minOut = (amount * 80) / 100;
        uint256 borrowAmount = (minOut * borrowRatio) / 100;

        deal(WETH, VAULT, amount * 5);

        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);

        uint256 aTokenBal = ERC20(A_WSTETH).balanceOf(VAULT);
        uint256 debtBal = ERC20(DEBT_WETH).balanceOf(VAULT);
        assertGt(aTokenBal, 0, "Should have aTokens after supply");
        assertGt(debtBal, 0, "Should have debt after supply");

        ERC20(A_WSTETH).approve(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), type(uint256).max);
        adaptor.settle(configId, 1);
        vm.stopPrank();

        assertEq(ERC20(DEBT_WETH).balanceOf(VAULT), 0, "Debt should be zero after settle");
        assertEq(ERC20(A_WSTETH).balanceOf(VAULT), 0, "aTokens should be zero after settle");
    }

    function testFuzz_ReducePosition(uint256 amount, uint256 borrowRatio, uint256 reduceRatio) public {
        amount = bound(amount, 10 ether, 100 ether);
        borrowRatio = bound(borrowRatio, 10, 40);
        reduceRatio = bound(reduceRatio, 10, 90);

        uint256 minOut = (amount * 80) / 100;
        uint256 borrowAmount = (minOut * borrowRatio) / 100;

        deal(WETH, VAULT, amount * 5);

        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);

        uint256 aTokenBal = ERC20(A_WSTETH).balanceOf(VAULT);
        uint256 debtBal = ERC20(DEBT_WETH).balanceOf(VAULT);

        uint256 repayAmount = (debtBal * reduceRatio) / 100;
        uint256 withdrawAmount = (aTokenBal * reduceRatio) / 100;

        ERC20(WETH).approve(address(adaptor), repayAmount);
        ERC20(A_WSTETH).approve(address(adaptor), withdrawAmount);
        adaptor.reducePosition(configId, 1, repayAmount, withdrawAmount);
        vm.stopPrank();

        assertLt(ERC20(DEBT_WETH).balanceOf(VAULT), debtBal, "Debt should decrease");
        assertLt(ERC20(A_WSTETH).balanceOf(VAULT), aTokenBal, "aTokens should decrease");
    }

    // ========================================= INVARIANT TESTS =========================================

    function _getWstEthPriceInEth() internal view returns (uint256) {
        return IWstETH(WSTETH).stEthPerToken();
    }

    function _getHealthFactor() internal view returns (uint256) {
        (,,,,, uint256 healthFactor) = IAavePool(AAVE_POOL).getUserAccountData(VAULT);
        return healthFactor;
    }

    function _getLTV() internal view returns (uint256 collateralInEth, uint256 debtInEth, uint256 ltvBps) {
        uint256 aTokenBal = ERC20(A_WSTETH).balanceOf(VAULT);
        uint256 debtBal = ERC20(DEBT_WETH).balanceOf(VAULT);
        uint256 wstEthPrice = _getWstEthPriceInEth();

        collateralInEth = (aTokenBal * wstEthPrice) / 1e18;
        debtInEth = debtBal;

        if (collateralInEth > 0) {
            ltvBps = (debtInEth * 10000) / collateralInEth;
        }
    }

    function testFuzz_Invariant_HealthFactorAboveLiquidation(uint256 amount, uint256 borrowRatio) public {
        amount = bound(amount, 1 ether, 100 ether);
        borrowRatio = bound(borrowRatio, 1, 70);

        uint256 minOut = (amount * 80) / 100;
        uint256 borrowAmount = (minOut * borrowRatio) / 100;

        deal(WETH, VAULT, amount);

        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);
        vm.stopPrank();

        uint256 healthFactor = _getHealthFactor();
        assertGt(healthFactor, 1e18, "Health factor must be above 1.0");
    }

    function testFuzz_Invariant_RepayReducesDebtExactly(uint256 amount, uint256 borrowRatio, uint256 repayRatio) public {
        amount = bound(amount, 10 ether, 100 ether);
        borrowRatio = bound(borrowRatio, 20, 50);
        repayRatio = bound(repayRatio, 10, 90);

        uint256 minOut = (amount * 80) / 100;
        uint256 borrowAmount = (minOut * borrowRatio) / 100;

        deal(WETH, VAULT, amount * 5);

        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);

        uint256 debtBefore = ERC20(DEBT_WETH).balanceOf(VAULT);
        uint256 repayAmount = (debtBefore * repayRatio) / 100;
        uint256 withdrawAmount = ERC20(A_WSTETH).balanceOf(VAULT) / 4;

        ERC20(WETH).approve(address(adaptor), repayAmount);
        ERC20(A_WSTETH).approve(address(adaptor), withdrawAmount);
        adaptor.reducePosition(configId, 1, repayAmount, withdrawAmount);
        vm.stopPrank();

        uint256 debtAfter = ERC20(DEBT_WETH).balanceOf(VAULT);

        // Debt should decrease by repay amount (allow small rounding from Aave)
        assertApproxEqAbs(debtBefore - debtAfter, repayAmount, 5, "Debt reduction must equal repay amount");
    }

    function testFuzz_Invariant_SettleClosesPosition(uint256 amount, uint256 borrowRatio) public {
        amount = bound(amount, 1 ether, 50 ether);
        borrowRatio = bound(borrowRatio, 5, 50);

        uint256 minOut = (amount * 80) / 100;
        uint256 borrowAmount = (minOut * borrowRatio) / 100;

        deal(WETH, VAULT, amount * 5);

        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);

        uint256 healthFactorBefore = _getHealthFactor();
        assertGt(healthFactorBefore, 1e18, "Health factor should be above 1.0 before settle");

        ERC20(A_WSTETH).approve(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), type(uint256).max);
        adaptor.settle(configId, 1);
        vm.stopPrank();

        assertEq(ERC20(DEBT_WETH).balanceOf(VAULT), 0, "Debt must be zero after settle");
        assertEq(ERC20(A_WSTETH).balanceOf(VAULT), 0, "aTokens must be zero after settle");

        (, uint256 totalDebt,,,,) = IAavePool(AAVE_POOL).getUserAccountData(VAULT);
        assertEq(totalDebt, 0, "Aave debt must be zero");
    }

    function testFuzz_Invariant_ReduceMaintainsHealthFactor(uint256 amount, uint256 borrowRatio, uint256 reduceRatio) public {
        amount = bound(amount, 10 ether, 100 ether);
        borrowRatio = bound(borrowRatio, 20, 50);
        reduceRatio = bound(reduceRatio, 10, 50);

        uint256 minOut = (amount * 80) / 100;
        uint256 borrowAmount = (minOut * borrowRatio) / 100;

        deal(WETH, VAULT, amount * 5);

        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);

        uint256 healthFactorBefore = _getHealthFactor();

        uint256 aTokenBal = ERC20(A_WSTETH).balanceOf(VAULT);
        uint256 debtBal = ERC20(DEBT_WETH).balanceOf(VAULT);

        uint256 repayAmount = (debtBal * reduceRatio) / 100;
        uint256 withdrawAmount = (aTokenBal * reduceRatio) / 100;

        ERC20(WETH).approve(address(adaptor), repayAmount);
        ERC20(A_WSTETH).approve(address(adaptor), withdrawAmount);
        adaptor.reducePosition(configId, 1, repayAmount, withdrawAmount);
        vm.stopPrank();

        uint256 healthFactorAfter = _getHealthFactor();

        assertGt(healthFactorAfter, 1e18, "Health factor must stay above 1.0 after reduce");
        assertGe(healthFactorAfter, healthFactorBefore - 1e17, "Health factor should not drop significantly");
    }

    function test_WstEthExchangeRate() public view {
        uint256 wstEthPrice = _getWstEthPriceInEth();

        // wstETH wraps stETH with accumulated yield, should be ~1.22+ ETH
        assertGt(wstEthPrice, 1.1e18, "wstETH exchange rate too low");
        assertLt(wstEthPrice, 1.5e18, "wstETH exchange rate too high");
    }

    function _assertAdaptorHasNoFunds() internal view {
        assertEq(ERC20(WETH).balanceOf(address(adaptor)), 0, "Adaptor should not hold WETH");
        assertEq(ERC20(WSTETH).balanceOf(address(adaptor)), 0, "Adaptor should not hold WSTETH");
        assertEq(ERC20(A_WSTETH).balanceOf(address(adaptor)), 0, "Adaptor should not hold aWSTETH");
        assertEq(address(adaptor).balance, 0, "Adaptor should not hold ETH");
    }

    function testFuzz_Invariant_AdaptorNeverHoldsFunds(uint256 amount, uint256 borrowRatio) public {
        amount = bound(amount, 1 ether, 100 ether);
        borrowRatio = bound(borrowRatio, 5, 50);

        uint256 minOut = (amount * 80) / 100;
        uint256 borrowAmount = (minOut * borrowRatio) / 100;

        deal(WETH, VAULT, amount * 5);

        _assertAdaptorHasNoFunds();

        // Supply
        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);
        vm.stopPrank();

        _assertAdaptorHasNoFunds();

        // Reduce
        uint256 aTokenBal = ERC20(A_WSTETH).balanceOf(VAULT);
        uint256 debtBal = ERC20(DEBT_WETH).balanceOf(VAULT);
        uint256 repayAmount = debtBal / 4;
        uint256 withdrawAmount = aTokenBal / 4;

        vm.startPrank(VAULT);
        ERC20(WETH).approve(address(adaptor), repayAmount);
        ERC20(A_WSTETH).approve(address(adaptor), withdrawAmount);
        adaptor.reducePosition(configId, 1, repayAmount, withdrawAmount);
        vm.stopPrank();

        _assertAdaptorHasNoFunds();

        // Settle
        vm.startPrank(VAULT);
        ERC20(A_WSTETH).approve(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), type(uint256).max);
        adaptor.settle(configId, 1);
        vm.stopPrank();

        _assertAdaptorHasNoFunds();
    }

    function testFuzz_Invariant_BorrowedAmountGoesToVault(uint256 amount, uint256 borrowRatio) public {
        amount = bound(amount, 1 ether, 100 ether);
        borrowRatio = bound(borrowRatio, 5, 50);

        uint256 minOut = (amount * 80) / 100;
        uint256 borrowAmount = (minOut * borrowRatio) / 100;

        deal(WETH, VAULT, amount);

        uint256 vaultWethBefore = ERC20(WETH).balanceOf(VAULT);

        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);
        vm.stopPrank();

        uint256 vaultWethAfter = ERC20(WETH).balanceOf(VAULT);
        uint256 debtBal = ERC20(DEBT_WETH).balanceOf(VAULT);

        // Vault sent `amount` and received `borrowAmount` back
        // So net change should be: borrowAmount - amount
        int256 expectedChange = int256(borrowAmount) - int256(amount);
        int256 actualChange = int256(vaultWethAfter) - int256(vaultWethBefore);

        assertEq(actualChange, expectedChange, "Vault WETH change must equal borrowAmount - swapIn");
        // Allow small rounding from Aave interest accrual
        assertApproxEqAbs(debtBal, borrowAmount, 5, "Debt must equal borrowed amount");
    }

    function testFuzz_Invariant_SupplyIncreasesPosition(uint256 amount, uint256 borrowRatio) public {
        amount = bound(amount, 1 ether, 50 ether);
        borrowRatio = bound(borrowRatio, 5, 50);

        uint256 minOut = (amount * 80) / 100;
        uint256 borrowAmount = (minOut * borrowRatio) / 100;

        deal(WETH, VAULT, amount * 3);

        uint256 aTokensBefore = ERC20(A_WSTETH).balanceOf(VAULT);
        uint256 debtBefore = ERC20(DEBT_WETH).balanceOf(VAULT);

        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);
        vm.stopPrank();

        uint256 aTokensAfter = ERC20(A_WSTETH).balanceOf(VAULT);
        uint256 debtAfter = ERC20(DEBT_WETH).balanceOf(VAULT);

        assertGt(aTokensAfter, aTokensBefore, "Supply must increase aTokens");
        assertGt(debtAfter, debtBefore, "Supply must increase debt");
    }

    function testFuzz_Invariant_ReduceDecreasesPosition(uint256 amount, uint256 borrowRatio, uint256 reduceRatio) public {
        amount = bound(amount, 10 ether, 100 ether);
        borrowRatio = bound(borrowRatio, 20, 50);
        reduceRatio = bound(reduceRatio, 10, 50);

        uint256 minOut = (amount * 80) / 100;
        uint256 borrowAmount = (minOut * borrowRatio) / 100;

        deal(WETH, VAULT, amount * 5);

        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);

        uint256 aTokensBefore = ERC20(A_WSTETH).balanceOf(VAULT);
        uint256 debtBefore = ERC20(DEBT_WETH).balanceOf(VAULT);

        uint256 repayAmount = (debtBefore * reduceRatio) / 100;
        uint256 withdrawAmount = (aTokensBefore * reduceRatio) / 100;

        ERC20(WETH).approve(address(adaptor), repayAmount);
        ERC20(A_WSTETH).approve(address(adaptor), withdrawAmount);
        adaptor.reducePosition(configId, 1, repayAmount, withdrawAmount);
        vm.stopPrank();

        uint256 aTokensAfter = ERC20(A_WSTETH).balanceOf(VAULT);
        uint256 debtAfter = ERC20(DEBT_WETH).balanceOf(VAULT);

        assertLt(aTokensAfter, aTokensBefore, "Reduce must decrease aTokens");
        assertLt(debtAfter, debtBefore, "Reduce must decrease debt");
    }

    function test_Invariant_WstEthPriceSanityCheck() public view {
        uint256 wstEthPrice = _getWstEthPriceInEth();

        // wstETH wraps stETH with accumulated yield, should be ~1.2+ ETH
        assertGt(wstEthPrice, 1.1e18, "wstETH price too low");
        assertLt(wstEthPrice, 1.5e18, "wstETH price too high");
    }

    function testFuzz_Invariant_ValueConservation(uint256 amount, uint256 borrowRatio) public {
        amount = bound(amount, 5 ether, 50 ether);
        borrowRatio = bound(borrowRatio, 10, 40);

        uint256 minOut = (amount * 80) / 100;
        uint256 borrowAmount = (minOut * borrowRatio) / 100;

        deal(WETH, VAULT, amount * 5);

        uint256 vaultWethBefore = ERC20(WETH).balanceOf(VAULT);

        vm.startPrank(VAULT);
        IDebtToken(DEBT_WETH).approveDelegation(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), amount);
        adaptor.supply(configId, amount, minOut, borrowAmount);

        ERC20(A_WSTETH).approve(address(adaptor), type(uint256).max);
        ERC20(WETH).approve(address(adaptor), type(uint256).max);
        adaptor.settle(configId, 1);
        vm.stopPrank();

        uint256 vaultWethAfter = ERC20(WETH).balanceOf(VAULT);

        // After full cycle, vault should have lost at most 5% to slippage/fees
        uint256 maxLoss = (amount * 5) / 100;
        assertGe(vaultWethAfter, vaultWethBefore - maxLoss, "Value loss exceeds 5% threshold");
    }

    function test_Invariant_AdaptorApprovalsIntact() public view {
        (address baseToken, address depositToken,,,,,) = adaptor.tokenConfigs(configId);

        // Check Uniswap approvals
        uint256 baseToRouter = ERC20(baseToken).allowance(address(adaptor), address(adaptor.uniswapV3Router()));
        uint256 depositToRouter = ERC20(depositToken).allowance(address(adaptor), address(adaptor.uniswapV3Router()));

        assertEq(baseToRouter, type(uint256).max, "baseToken should have max approval to router");
        assertEq(depositToRouter, type(uint256).max, "depositToken should have max approval to router");

        // Check Aave approvals
        uint256 baseToAave = ERC20(baseToken).allowance(address(adaptor), address(adaptor.aave()));
        uint256 depositToAave = ERC20(depositToken).allowance(address(adaptor), address(adaptor.aave()));

        assertEq(baseToAave, type(uint256).max, "baseToken should have max approval to Aave");
        assertEq(depositToAave, type(uint256).max, "depositToken should have max approval to Aave");
    }

    // ========================================= FULL INTEGRATION TESTS (via Manager) =========================================

    function test_FullIntegration_Supply() public {
        uint256 amount = 10 ether;
        uint256 borrowAmount = 1 ether;
        uint256 minOut = (amount * 80) / 100;

        deal(WETH, VAULT, amount);

        ManageLeaf[] memory leafs = _buildMerkleLeafs();

        // Build targets and data for manager call
        address[] memory targets = new address[](3);
        bytes[] memory targetData = new bytes[](3);
        uint256[] memory values = new uint256[](3);
        bytes32[][] memory proofs = new bytes32[][](3);

        // 1. Approve WETH to adaptor
        targets[0] = WETH;
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(adaptor), amount);
        proofs[0] = _getProof(leafs[3], leafs);

        // 2. Approve delegation for debt token
        targets[1] = DEBT_WETH;
        targetData[1] = abi.encodeWithSelector(IDebtToken.approveDelegation.selector, address(adaptor), type(uint256).max);
        proofs[1] = _getProof(leafs[8], leafs);

        // 3. Call supply on adaptor
        targets[2] = address(adaptor);
        targetData[2] = abi.encodeWithSelector(PrvlAaveBorrow.supply.selector, configId, amount, minOut, borrowAmount);
        proofs[2] = _getProof(leafs[0], leafs);

        address[] memory decoders = new address[](3);
        decoders[0] = address(decoder);
        decoders[1] = address(decoder);
        decoders[2] = address(decoder);

        vm.prank(TEST_CALLER);
        manager.manageVaultWithMerkleVerification(proofs, decoders, targets, targetData, values);

        assertGt(ERC20(A_WSTETH).balanceOf(VAULT), 0, "Vault should have aTokens");
        assertGt(ERC20(DEBT_WETH).balanceOf(VAULT), 0, "Vault should have debt");
    }

    function test_FullIntegration_SupplyAndSettle() public {
        uint256 amount = 10 ether;
        uint256 borrowAmount = 2 ether;
        uint256 minOut = (amount * 80) / 100;

        deal(WETH, VAULT, amount * 5);

        ManageLeaf[] memory leafs = _buildMerkleLeafs();

        // === SUPPLY ===
        {
            address[] memory targets = new address[](3);
            bytes[] memory targetData = new bytes[](3);
            uint256[] memory values = new uint256[](3);
            bytes32[][] memory proofs = new bytes32[][](3);

            targets[0] = WETH;
            targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(adaptor), amount);
            proofs[0] = _getProof(leafs[3], leafs);

            targets[1] = DEBT_WETH;
            targetData[1] = abi.encodeWithSelector(IDebtToken.approveDelegation.selector, address(adaptor), type(uint256).max);
            proofs[1] = _getProof(leafs[8], leafs);

            targets[2] = address(adaptor);
            targetData[2] = abi.encodeWithSelector(PrvlAaveBorrow.supply.selector, configId, amount, minOut, borrowAmount);
            proofs[2] = _getProof(leafs[0], leafs);

            address[] memory decoders = new address[](3);
            decoders[0] = address(decoder);
            decoders[1] = address(decoder);
            decoders[2] = address(decoder);

            vm.prank(TEST_CALLER);
            manager.manageVaultWithMerkleVerification(proofs, decoders, targets, targetData, values);
        }

        uint256 debtBal = ERC20(DEBT_WETH).balanceOf(VAULT);
        assertGt(debtBal, 0, "Should have debt after supply");

        // === SETTLE ===
        {
            address[] memory targets = new address[](3);
            bytes[] memory targetData = new bytes[](3);
            uint256[] memory values = new uint256[](3);
            bytes32[][] memory proofs = new bytes32[][](3);

            targets[0] = WETH;
            targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(adaptor), type(uint256).max);
            proofs[0] = _getProof(leafs[3], leafs);

            targets[1] = A_WSTETH;
            targetData[1] = abi.encodeWithSelector(ERC20.approve.selector, address(adaptor), type(uint256).max);
            proofs[1] = _getProof(leafs[5], leafs);

            targets[2] = address(adaptor);
            targetData[2] = abi.encodeWithSelector(PrvlAaveBorrow.settle.selector, configId, 1);
            proofs[2] = _getProof(leafs[2], leafs);

            address[] memory decoders = new address[](3);
            decoders[0] = address(decoder);
            decoders[1] = address(decoder);
            decoders[2] = address(decoder);

            vm.prank(TEST_CALLER);
            manager.manageVaultWithMerkleVerification(proofs, decoders, targets, targetData, values);
        }

        assertEq(ERC20(DEBT_WETH).balanceOf(VAULT), 0, "Debt should be zero after settle");
        assertEq(ERC20(A_WSTETH).balanceOf(VAULT), 0, "aToken balance should be zero after settle");
    }
}
