// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract MockEndpoint {
    address public delegate;

    struct MessagingFee { uint256 nativeFee; uint256 lzTokenFee; }
    struct MessagingParams { uint32 dstEid; bytes32 receiver; bytes payload; bytes options; bool payInLzToken; }
    struct MessagingReceipt { bytes32 guid; uint64 nonce; MessagingFee fee; }

    uint256 public nativeQuote;
    uint256 public lzTokenQuote;

    function setDelegate(address _delegate) external {
        delegate = _delegate;
    }

    function setQuote(uint256 nativeFee, uint256 lzFee) external {
        nativeQuote = nativeFee;
        lzTokenQuote = lzFee;
    }

    function quote(MessagingParams calldata, address) external view returns (MessagingFee memory fee) {
        fee = MessagingFee(nativeQuote, lzTokenQuote);
    }

    function send(MessagingParams calldata params, address) external payable returns (MessagingReceipt memory r) {
        // Ensure callers pay the quoted native fee when not paying in LZ token to avoid silent false-positives in tests.
        if (!params.payInLzToken) {
            require(msg.value >= nativeQuote, "MockEndpoint: fee not covered");
        }
        r = MessagingReceipt({guid: bytes32("mock"), nonce: 1, fee: MessagingFee(nativeQuote, lzTokenQuote)});
    }

    function lzToken() external pure returns (address) { return address(0xdead); }
} 