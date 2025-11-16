//
////no imports up here, use your imagination
//
////we should ensure that these all have the same interface so we can call the same function per bitj
import {IModule} from "src/base/Registry/ModuleRegistry.sol"; 

contract RecipientModule is IModule {

    //encodes the rules for checking if the recipient address is the boring vault
    function checkRule(bytes calldata params) external view returns (bool) {
        // here, all we would do is decode the params into an address type, and then verify that it comes from the boring vault
        // to do this, we could pass it in as a param to here or check msg.sender 
        (address caller, address vault) = abi.decode(params, (address, address)); 
        if (caller != vault) return false; 
        
        return true; 
    } 
}
//
////these are deployed per vault on a "need" basis, they are opt in -> this is handled via factory (adds overhead, but pay it once) 
////the overhead here becomes managing each of these per vault, and dealing with each of them individually. You could imagine having to deal with different function signatures per storage contract being annoying (updateMask in one, updateList in another, updateTokenPairMask in another, etc). These would be limited per protocol, so conceptually it might make sense, but still, that is where the overhead comes in. Via a UI, this may be acceptable.
//contract TokenWhitelistStorage is Auth {
//    
//    //reuse the protocol bit from the master registry as the id
//    //register tokens PER protocol -> works for 95% of cases (approvals included naturally)
//    mapping(uint256 protocolId => uint256 tokenMask) public tokenMasks; 
//
//    function checkMask(address vault, uint256 protocolId, uint256 bit, bool remove) external view returns (bool) {
//        //check the mask here, if valid return true, if not, false 
//        return true;
//    } 
//    
//    function updateMask(address vault, uint256 protocolId, uint256 bit, bool remove) external requiresAuth {
//        //we just check if the address calling this function is allowed to set the mask for the vault 
//        //and then set the bit
//        //this should be easy to do from a ui? 
//    } 
//}
//
////The other option would be to combine these two contracts, but then you need to maintain a list somewhere of vault permissions, ie which admin can call `updateMask` for which vault
////solmate's Auth can't do that level of granularity, I don't think.
////separating does mean an extra delegatecall tho
//
////deployed once, shared across every vault
//contract TokenWhitelistModule  is Auth {
//    
//    //could be transient, could just be state variable;  
//    //we could also just have a CacheModule that does this and use it only where needed? maybe overkill 
//    address internal cachedStorage; //load this once, reuse across the entire tx, next vault that uses it has to store thier own here
//
//    function checkRule(bytes calldata params) external view returns (bool) {
//
//        //importantly, the storageContract can only come from the vault, a vault wouldn't be able to simply pass in anothers storageContract to get access to their tokens
//        //what mechanism is used here to make that happen is undecided at the moment
//        (uint256 protocolId, address storageContract, address[] memory tokens) = abi.decode(params, (uint256, address, address[])); 
//
//        for (uint256 i = 0; i < tokens.lenth; i++) {
//            //call the global registry first to check that it is an approved token 
//            bool approved = isApprovedGlobally(tokens[i]);
//            if (!approved) return false;
//        } 
//        
//        // pseudocode, imagine these exist
//        uint256 mask = createMask(tokens); //creates a mask based on the tokens passed in by looking them up in the registry 
//        bool inMask = cachedStorage.checkMask(protocolId, mask); //compares the bits against each other
//
//        return true;
//    }
//}
