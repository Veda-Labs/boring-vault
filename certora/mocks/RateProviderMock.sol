import {IRateProvider} from "src/interfaces/IRateProvider.sol";

contract RateProviderMock is IRateProvider {
    uint256 _rate;
    function getRate() public view returns (uint256) {
        return _rate;
    }
}