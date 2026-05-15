import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";

contract IBufferHelperMock is IBufferHelper {
    function getDepositManageCall(address asset, uint256 amount)
        external
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {}

    function getWithdrawManageCall(address asset, uint256 amount)
        external
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {}
}