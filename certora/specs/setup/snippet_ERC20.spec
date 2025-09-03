using ERC20Mock as ERC20Mock;

methods {
    function _.allowance(address,address) external
        => DISPATCH(optimistic=true) [ ERC20Mock.allowance(address,address) ];
    function _.approve(address,uint256) external
        => DISPATCH(optimistic=true) [ ERC20Mock.approve(address,uint256) ];
    function _.decimals() external
        => DISPATCH(optimistic=true) [ ERC20Mock.decimals() ];
    function _.transfer(address,uint256) external
        => DISPATCH(optimistic=true) [ ERC20Mock.transfer(address,uint256) ];
    function _.transferFrom(address,address,uint256) external
        => DISPATCH(optimistic=true) [ ERC20Mock.transferFrom(address,address,uint256) ];
    function _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32) external
        => DISPATCH(optimistic=true) [ ERC20Mock.permit(address,address,uint256,uint256,uint8,bytes32,bytes32) ];
}
