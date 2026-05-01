import {BeforeTransferHook} from "src/interfaces/BeforeTransferHook.sol";

contract BeforeTransferHookMock is BeforeTransferHook {
    function beforeTransfer(address from, address to, address operator) external view {
        
    }
}