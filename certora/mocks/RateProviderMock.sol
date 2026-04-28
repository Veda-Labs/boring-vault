contract RateProviderMock {
    uint256 _rate;
    function getRate(bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32) public view returns (uint256) {
        return _rate;
    }
}