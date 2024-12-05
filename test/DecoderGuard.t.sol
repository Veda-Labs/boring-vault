// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {DecoderGuard} from "src/base/Gnosis/DecoderGuard.sol";
import {ITransactionGuard} from "src/interfaces/ITransactionGuard.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

import {Test, stdStorage, StdStorage, stdError, console, Vm} from "@forge-std/Test.sol";

contract DecoderGuardTest is Test {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    DecoderGuard public decoderGuard;
    address public baseDecoderAndSanitizer;

    ERC20 constant usdc = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC on mainnet
    address constant spender = address(0xBEEF);
    uint256 constant amount = 1000e6; // 1000 USDC

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20842935;
        _startFork(rpcKey, blockNumber);

        baseDecoderAndSanitizer = address(new BaseDecoderAndSanitizer(address(0)));
        decoderGuard = new DecoderGuard(address(this), Authority(address(0)), baseDecoderAndSanitizer);
    }

    function testRevertWhenDigestNotValid() public {
        // Create approve calldata
        bytes memory approveCalldata = abi.encodeWithSelector(ERC20.approve.selector, spender, amount);

        // Try to check transaction with invalid digest
        (bytes32 digest,) = decoderGuard.digestTransaction(address(usdc), 0, approveCalldata);
        vm.expectRevert(abi.encodeWithSelector(DecoderGuard.DecoderGuard__DigestNotValid.selector, digest));
        decoderGuard.checkTransaction(
            address(usdc), // to
            0, // value
            approveCalldata,
            ITransactionGuard.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            "",
            address(this)
        );
    }

    function testSkipDigestCheck() public {
        bytes memory approveCalldata = abi.encodeWithSelector(ERC20.approve.selector, spender, amount);

        // Toggle skip check
        decoderGuard.toggleSkipDigestCheck();

        // Should pass without reverting
        decoderGuard.checkTransaction(
            address(usdc),
            0,
            approveCalldata,
            ITransactionGuard.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            "",
            address(this)
        );
    }

    function testValidateAndCheckDigests() public {
        // Create approve calldata
        bytes memory approveCalldata = abi.encodeWithSelector(ERC20.approve.selector, spender, amount);

        // Make approve digest valid
        decoderGuard.makeDigestValid(address(usdc), 0, approveCalldata);

        // Should pass without reverting for approve
        decoderGuard.checkTransaction(
            address(usdc),
            0,
            approveCalldata,
            ITransactionGuard.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            "",
            address(this)
        );

        // Create transfer calldata (different function)
        bytes memory transferCalldata = abi.encodeWithSelector(ERC20.transfer.selector, spender, amount);

        (bytes32 transferDigest,) = decoderGuard.digestTransaction(address(usdc), 0, transferCalldata);
        // Should revert for transfer (different digest)
        vm.expectRevert(abi.encodeWithSelector(DecoderGuard.DecoderGuard__DigestNotValid.selector, transferDigest));
        decoderGuard.checkTransaction(
            address(usdc),
            0,
            transferCalldata,
            ITransactionGuard.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            "",
            address(this)
        );
    }

    function testMakeDigestInvalid() public {
        // Create approve calldata
        bytes memory approveCalldata = abi.encodeWithSelector(ERC20.approve.selector, spender, amount);

        // Make approve digest valid
        decoderGuard.makeDigestValid(address(usdc), 0, approveCalldata);

        // Should pass without reverting for approve
        decoderGuard.checkTransaction(
            address(usdc),
            0,
            approveCalldata,
            ITransactionGuard.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            "",
            address(this)
        );

        // Invalidate the digest
        (bytes32 digest,) = decoderGuard.digestTransaction(address(usdc), 0, approveCalldata);
        decoderGuard.makeDigestInvalid(digest);

        // Should revert after invalidating the digest
        vm.expectRevert(abi.encodeWithSelector(DecoderGuard.DecoderGuard__DigestNotValid.selector, digest));
        decoderGuard.checkTransaction(
            address(usdc),
            0,
            approveCalldata,
            ITransactionGuard.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            "",
            address(this)
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
