using RateProviderMock as RateProviderMock;

methods {

    function _.getRate() external => DISPATCHER(true);

    unresolved external in GenericRateProvider.getRate() => 
        DISPATCH(optimistic=true) [RateProviderMock.getRate(bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)];
    unresolved external in GenericRateProviderWithDecimalScaling.getRate() => 
        DISPATCH(optimistic=true) [RateProviderMock.getRate(bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)];
}