methods {
    function ERC20Mock.totalSupply() external returns uint256 envfree;
}

ghost mapping(address => uint256) ERC20_balance_ERC20Mock;

hook Sstore ERC20Mock.balanceOf[KEY address addr] uint256 balance (uint256 before) {
    ERC20_balance_ERC20Mock[addr] = balance;
}
hook Sload uint256 balance ERC20Mock.balanceOf[KEY address addr] {
    require(ERC20_balance_ERC20Mock[addr] == balance);
}

invariant totalSupplyHolds_ERC20Mock()
    ERC20Mock.totalSupply() >= (usum address a. ERC20_balance_ERC20Mock[a]);
