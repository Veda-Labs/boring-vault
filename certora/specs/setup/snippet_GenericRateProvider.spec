methods {

    function _.getRate() external => DISPATCHER(true);

    unresolved external in GenericRateProvider.getRate() => 
        DISPATCH(optimistic=false) [] default NONDET;
    unresolved external in GenericRateProviderWithDecimalScaling.getRate() => 
        DISPATCH(optimistic=false) [] default NONDET;
}