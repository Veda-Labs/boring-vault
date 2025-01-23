pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {ChainValues} from "test/resources/ChainValues.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import "forge-std/Base.sol";
import "forge-std/Test.sol";

contract MerkleTreeStrategistVerification is CommonBase, ChainValues, Test {
    using Address for address;

    string public sourceChain;
    
    bytes32 memory manageRoot; 


    address internal boringVault; 
    address internal accountant; 
    address internal rawDataDecoderAndSanitizer;  
    address internal manager; 
    
    function setUp() external {
        //set up the test root
        manageRoot = 
    }
    
    function _setSourceChainName(string memory _chain) internal {
        sourceChain = _chain;
    }

    function _testUniswapV3(address[] memory token0, address memory token1, bool swapOnly) {


        
    }
}

