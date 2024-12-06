// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {DecoderGuard, IMultiSend} from "src/base/Gnosis/DecoderGuard.sol";
import {ITransactionGuard} from "src/interfaces/ITransactionGuard.sol";
import {
    AaveGuardDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    BaseDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/AaveGuardDecoderAndSanitizer.sol";

import {Test, stdStorage, StdStorage, stdError, console, Vm} from "@forge-std/Test.sol";

contract DecoderGuardTest is Test {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    DecoderGuard public decoderGuard;
    address public baseDecoderAndSanitizer;

    ERC20 constant usdc = ERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831); // USDC on arbitrum
    ERC20 constant weth = ERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1); // WETH on arbitrum
    address constant spender = address(0xBEEF);
    uint256 constant amount = 1000e6; // 1000 USDC
    address constant multiSend = 0x9641d764fc13c8B624c04430C7356C1C7C8102e2;
    address constant multiSendAddress = 0x9641d764fc13c8B624c04430C7356C1C7C8102e2;
    address constant gnosisSafe = 0x5061F6517591804391b38937c99057014B1EDb78;
    address constant aaveV3Pool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "ARBITRUM_RPC_URL";
        uint256 blockNumber = 20842935;
        _startFork(rpcKey, blockNumber);

        baseDecoderAndSanitizer = address(new AaveGuardDecoderAndSanitizer());
        decoderGuard = new DecoderGuard(address(this), Authority(address(0)), baseDecoderAndSanitizer, multiSend);
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

    function testMultiSend() public {
        bytes memory data =
            hex"8d80ff0a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001b200794a61358d6845594f94dc1db02a252b5b4814ad00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000084617ba03700000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000000000000000000000000000000009184e72a0000000000000000000000000005061f6517591804391b38937c99057014b1edb78000000000000000000000000000000000000000000000000000000000000000000794a61358d6845594f94dc1db02a252b5b4814ad00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000084617ba03700000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000000000000000000000000000000009184e72a0000000000000000000000000005061f6517591804391b38937c99057014b1edb7800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        // Make the aave supply call a valid digest.
        bytes memory aaveSupplyCalldata =
            abi.encodeWithSelector(AaveV3DecoderAndSanitizer.supply.selector, address(weth), 0, gnosisSafe, 0);
        bytes32 digest = decoderGuard.makeDigestValid(aaveV3Pool, 0, aaveSupplyCalldata);

        decoderGuard.checkTransaction(
            address(multiSend),
            0,
            data,
            ITransactionGuard.Operation.DelegateCall,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            "",
            address(this)
        );

        // Make the digest invalid
        decoderGuard.makeDigestInvalid(digest);

        // Should revert after invalidating the digest
        vm.expectRevert(abi.encodeWithSelector(DecoderGuard.DecoderGuard__DigestNotValid.selector, digest));
        decoderGuard.checkTransaction(
            address(multiSend),
            0,
            data,
            ITransactionGuard.Operation.DelegateCall,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            "",
            address(this)
        );
    }

    function testRevertUnsupportedMode() public {
        // Test direct call with unsupported operation mode (DelegateCall)
        bytes memory callData = abi.encodeWithSelector(ERC20.approve.selector, spender, amount);

        vm.expectRevert(DecoderGuard.DecoderGuard__UnsupportedMode.selector);
        decoderGuard.checkTransaction(
            address(usdc),
            0,
            callData,
            ITransactionGuard.Operation.DelegateCall, // Using DelegateCall instead of Call
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            "",
            address(this)
        );
    }

    function testRevertMalformedHeader() public {
        // Create malformed multiSend data with incorrect selector
        bytes memory badSelector = hex"deadbeef"; // Wrong selector
        bytes memory malformedData = abi.encodePacked(badSelector, bytes32(uint256(0x20)), bytes32(uint256(100)));

        vm.expectRevert(DecoderGuard.DecoderGuard__MalformedHeader.selector);
        decoderGuard.checkTransaction(
            multiSendAddress,
            0,
            malformedData,
            ITransactionGuard.Operation.DelegateCall,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            "",
            address(this)
        );
    }

    function testRevertMalformedBody() public {
        // Set operation to Delegate Call for one of the entries.
        bytes memory malformedData =
            hex"8d80ff0a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001b200794a61358d6845594f94dc1db02a252b5b4814ad00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000084617ba03700000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000000000000000000000000000000009184e72a0000000000000000000000000005061f6517591804391b38937c99057014b1edb78000000000000000000000000000000000000000000000000000000000000000001794a61358d6845594f94dc1db02a252b5b4814ad00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000084617ba03700000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000000000000000000000000000000009184e72a0000000000000000000000000005061f6517591804391b38937c99057014b1edb7800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        vm.expectRevert(DecoderGuard.DecoderGuard__MalformedBody.selector);
        decoderGuard.checkTransaction(
            multiSendAddress,
            0,
            malformedData,
            ITransactionGuard.Operation.DelegateCall,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            "",
            address(this)
        );
    }

    function testRevertMalformedBodyEmptyTransactions() public {
        // Create multiSend data with no transactions
        bytes memory validHeader = abi.encodePacked(
            IMultiSend.multiSend.selector,
            bytes32(uint256(0x20)),
            bytes32(uint256(0)) // Length 0 for transaction data
        );

        vm.expectRevert(DecoderGuard.DecoderGuard__MalformedBody.selector);
        decoderGuard.checkTransaction(
            multiSendAddress,
            0,
            validHeader,
            ITransactionGuard.Operation.DelegateCall,
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
