contract BytesLibMock {
    function toUint16(bytes memory _bytes, uint256 _start) external pure returns (uint16) {
        require(_bytes.length >= _start + 2, "toUint16_outOfBounds");

        return uint8(_bytes[_start + 1]) + (uint16(uint8(_bytes[_start])) << 8);
    }
}