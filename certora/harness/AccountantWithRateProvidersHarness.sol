
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";

contract AccountantWithRateProvidersHarness is AccountantWithRateProviders {

    constructor(
        address _owner,
        address _vault,
        address payoutAddress,
        uint96 startingExchangeRate,
        address _base,
        uint16 allowedExchangeRateChangeUpper,
        uint16 allowedExchangeRateChangeLower,
        uint24 minimumUpdateDelayInSeconds,
        uint16 platformFee,
        uint16 performanceFee
    ) AccountantWithRateProviders(_owner, _vault, payoutAddress, startingExchangeRate, _base, allowedExchangeRateChangeUpper, allowedExchangeRateChangeLower, minimumUpdateDelayInSeconds, platformFee, performanceFee)
    {}

    function isAuthorizedHarness(address user, bytes4 functionSig) public view returns (bool) {
        return isAuthorized(user, functionSig);
    }
}