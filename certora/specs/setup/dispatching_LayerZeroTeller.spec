import "snippet_Authority.spec";
import "snippet_BytesLib.spec";

methods {

    function OAppAuthSender._quote(uint32 _dstEid, bytes memory _message, bytes memory _options, bool _payInLzToken) internal returns (LayerZeroTeller.MessagingFee memory)
        => CVL_quote();

    function OAppAuthSender._lzSend(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        LayerZeroTeller.MessagingFee memory _fee,
        address _refundAddress
    ) internal returns (LayerZeroTeller.MessagingReceipt memory)
        => CVL_lzSend();

}

function CVL_quote() returns LayerZeroTeller.MessagingFee {
    LayerZeroTeller.MessagingFee res;
    return res;
}

function CVL_lzSend() returns LayerZeroTeller.MessagingReceipt {
    LayerZeroTeller.MessagingReceipt res;
    return res;
}
