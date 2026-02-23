import "snippet_Authority.spec";
import "snippet_ERC20.spec";
import "snippet_RateProvider.spec";

function getAccountant_summary() returns address
{
    return accountant_contract;
}

function updateExchangeRate_summary(env e)
{
    accountant_contract.updateExchangeRate(e);
}

function lastVirtualSharePrice_summary(env e) returns uint256
{
    return accountant_contract.lastVirtualSharePrice(e);
}

function setFirstDepositTimestamp_summary(env e) {
    accountant_contract.setFirstDepositTimestamp(e);
}

methods
{
    //function vault_contract.decimals() external returns (uint8) envfree;
    function TellerWithYieldStreaming._getAccountant() internal returns address => getAccountant_summary();
    function _.updateExchangeRate() external with (env e) => updateExchangeRate_summary(e) expect void;
    function _.lastVirtualSharePrice() external with (env e) => lastVirtualSharePrice_summary(e) expect uint256;
    function _.setFirstDepositTimestamp() external with (env e) => setFirstDepositTimestamp_summary(e) expect void;
}
