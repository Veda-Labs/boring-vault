using RateProviderMock as RateProviderMock;

methods {

    function _.getRate() external => DISPATCHER(true);

    unresolved external in GenericRateProvider.getRate() => 
        DISPATCH(optimistic=true) [RateProviderMock.getRate()];
    unresolved external in GenericRateProviderWithDecimalScaling.getRate() => 
        DISPATCH(optimistic=true) [RateProviderMock.getRate()];
}