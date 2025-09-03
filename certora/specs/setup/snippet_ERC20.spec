using ERC20Mock as ERC20Mock;

methods {
    function totalSupply() external returns uint256 envfree;

    function _.transfer(address,uint256) external
        => DISPATCH(optimistic=true) [ ERC20Mock.transfer(address,uint256) ];
    function _.transferFrom(address,address,uint256) external
        => DISPATCH(optimistic=true) [ ERC20Mock.transferFrom(address,address,uint256) ];
}

ghost mapping(address => uint256) ERC20_balance;

hook Sstore balanceOf[KEY address addr] uint256 balance (uint256 before) {
    ERC20_balance[addr] = balance;
}
hook Sload uint256 balance balanceOf[KEY address addr] {
    require(ERC20_balance[addr] == balance);
}

invariant totalSupplyHolds()
    totalSupply() >= (usum address a. ERC20_balance[a]);
