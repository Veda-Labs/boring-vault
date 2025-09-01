using BytesLibMock as BytesLibMock;

methods {
    function BytesLibMock.toUint16(bytes _bytes, uint256 _start) external returns (uint16) envfree;

    function BytesLib.toUint16(bytes memory _bytes, uint256 _start) internal returns (uint16)
        => CVL_toUint16(_bytes, _start);

}

function CVL_toUint16(bytes _bytes, uint256 _start) returns (uint16) {
    return BytesLibMock.toUint16(_bytes, _start);
}