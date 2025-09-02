import "snippet_Authority.spec";

using ERC20Mock as ERC20Mock;

methods {

    function _.transfer(address,uint256) external
        => DISPATCH(optimistic=true) [ ERC20Mock.transfer(address,uint256) ];
    function _.transferFrom(address,address,uint256) external
        => DISPATCH(optimistic=true) [ ERC20Mock.transferFrom(address,address,uint256) ];
}
