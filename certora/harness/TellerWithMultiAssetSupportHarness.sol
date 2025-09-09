
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";

contract TellerWithMultiAssetSupportHarness is TellerWithMultiAssetSupport {

    constructor(address _owner, address _vault, address _accountant, address _weth)
        TellerWithMultiAssetSupport(_owner, _vault, _accountant, _weth)
    {}

    function getRateInQuoteSafe(ERC20 quote) external view returns (uint256) {
        return accountant.getRateInQuoteSafe(quote);
    }

    function getAssetData(address asset) external view returns (Asset memory) {
        return assetData[ERC20(asset)];
    }

    function isAuthorizedHarness(address user, bytes4 functionSig) public view returns (bool) {
        return isAuthorized(user, functionSig);
    }
}