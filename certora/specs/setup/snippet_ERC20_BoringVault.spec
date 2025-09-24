using BoringVault as BoringVault;

methods {
    function BoringVault.totalSupply() external returns uint256 envfree;
    function BoringVault.balanceOf(address) external returns uint256 envfree;
}

ghost mapping(address => uint256) ERC20_balance_BoringVault;

hook Sstore BoringVault.balanceOf[KEY address addr] uint256 balance (uint256 before) {
    ERC20_balance_BoringVault[addr] = balance;
}
hook Sload uint256 balance BoringVault.balanceOf[KEY address addr] {
    require(ERC20_balance_BoringVault[addr] == balance);
}

invariant totalSupplyHolds_BoringVault()
    BoringVault.totalSupply() >= (usum address a. ERC20_balance_BoringVault[a]);
