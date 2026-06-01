import "snippet_Authority.spec";
import "snippet_ERC20.spec";
import "snippet_RateProvider.spec";

methods {

    function OAppAuthSender._quote(uint32 _dstEid, bytes memory _message, bytes memory _options, bool _payInLzToken) internal returns (LayerZeroTellerWithRateLimiting.MessagingFee memory)
        => CVL_quote();

    function OAppAuthSender._lzSend(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        LayerZeroTellerWithRateLimiting.MessagingFee memory _fee,
        address _refundAddress
    ) internal returns (LayerZeroTellerWithRateLimiting.MessagingReceipt memory)
        => CVL_lzSend();

    function _.setDelegate(address) external => NONDET;

    function _.addExecutorLzReceiveOption(bytes memory, uint128, uint128) internal
        => CVL_nondetbytes() expect (bytes memory);
}

function CVL_quote() returns LayerZeroTellerWithRateLimiting.MessagingFee {
    LayerZeroTellerWithRateLimiting.MessagingFee res;
    return res;
}

function CVL_lzSend() returns LayerZeroTellerWithRateLimiting.MessagingReceipt {
    LayerZeroTellerWithRateLimiting.MessagingReceipt res;
    return res;
}

function CVL_nondetbytes() returns bytes {
    bytes res;
    return res;
}
