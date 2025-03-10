// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";


abstract contract OdosDecoderAndSanitizer is BaseDecoderAndSanitizer {

    // Reference to the OdosRouterV2 contract
    IOdosRouterV2 internal immutable odosRouter; //temp

    constructor(address _odosRouter) {
        odosRouter = IOdosRouterV2(_odosRouter); 
    }

    function swap(
        DecoderCustomTypes.swapTokenInfo memory tokenInfo,
        bytes calldata /*pathDefinition*/,
        address executor,
        uint32 /*referralCode*/
    ) external pure virtual returns (bytes memory addressesFound) {
        
        addressesFound = abi.encodePacked(tokenInfo.inputToken, tokenInfo.outputToken, tokenInfo.outputReceiver, executor); 

    }

    function swapCompact() external view virtual returns (bytes memory addressesFound) {
        DecoderCustomTypes.swapTokenInfo memory tokenInfo;
        address executor;
        uint32 referralCode;
        bytes calldata pathDefinition;

        // Variables to store indices for addresses that need lookup
        Address memory inputTokenLookup;  
        Address memory outputTokenLookup; 
        Address memory executorLookup; 

        {
            address msgSender = msg.sender;
            assembly {
                // Assembly function to get address from calldata
                function getAddress(currPos) -> result, newPos {
                    let inputPos := shr(240, calldataload(currPos))
                    
                    switch inputPos
                    // Reserve the null address as a special case that can be specified with 2 null bytes
                    case 0x0000 {
                        result := 0
                        newPos := add(currPos, 2)
                    }
                    // This case means that the address is encoded in the calldata directly following the code
                    case 0x0001 {
                        result := and(shr(80, calldataload(currPos)), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                        newPos := add(currPos, 22)
                    }
                    // For addresses from the addressList, we'll just store the index for later retrieval
                    default {
                        // We'll use this later to know we need to look up from addressList
                        result := 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE
                        newPos := add(currPos, 2)
                    }
                }
                
                let result := 0
                let pos := 4
                let fromList := 0

                // Load in the input and output token addresses
                result, pos := getAddress(pos)
                if eq(result, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE) {
                    let inputPos := shr(240, calldataload(sub(pos, 2))) //sub 2 because we added 2 in `getAddress`, shr 240 bits to get index
                    mstore(add(inputTokenLookup, 0x00), sub(inputPos, 2)) // Store index
                    mstore(add(inputTokenLookup, 0x20), 1)                // Set needsLookup to true
                }
                mstore(tokenInfo, result)

                result, pos := getAddress(pos)
                if eq(result, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE) {
                    let inputPos := shr(240, calldataload(sub(pos, 2)))
                    mstore(add(outputTokenLookup, 0x00), sub(inputPos, 2))
                    mstore(add(outputTokenLookup, 0x20), 1)
                }
                mstore(add(tokenInfo, 0x60), result)

                // Load in the input amount - a 0 byte means the full balance is to be used
                let inputAmountLength := shr(248, calldataload(pos))
                pos := add(pos, 1)

                if inputAmountLength {
                  mstore(add(tokenInfo, 0x20), shr(mul(sub(32, inputAmountLength), 8), calldataload(pos)))
                  pos := add(pos, inputAmountLength)
                }

                // Load in the quoted output amount
                let quoteAmountLength := shr(248, calldataload(pos))
                pos := add(pos, 1)

                let outputQuote := shr(mul(sub(32, quoteAmountLength), 8), calldataload(pos))
                mstore(add(tokenInfo, 0x80), outputQuote)
                pos := add(pos, quoteAmountLength)

                // Load the slippage tolerance and use to get the minimum output amount
                {
                  let slippageTolerance := shr(232, calldataload(pos))
                  mstore(add(tokenInfo, 0xA0), div(mul(outputQuote, sub(0xFFFFFF, slippageTolerance)), 0xFFFFFF))
                }
                pos := add(pos, 3)

                // Load in the executor address
                result, pos := getAddress(pos)
                if eq(result, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE) {
                    let inputPos := shr(240, calldataload(sub(pos, 2)))
                    mstore(add(executorLookup, 0x00), sub(inputPos, 2))
                    mstore(add(executorLookup, 0x20), 1)
                }
                executor := result

                // Load in the destination to send the input to - Zero denotes the executor
                result, pos := getAddress(pos)
                if eq(result, 0) { result := executor }
                mstore(add(tokenInfo, 0x40), result)

                // Load in the destination to send the output to - Zero denotes msg.sender
                result, pos := getAddress(pos)
                if eq(result, 0) { result := msgSender }
                mstore(add(tokenInfo, 0xC0), result)

                // Load in the referralCode
                referralCode := shr(224, calldataload(pos))
                pos := add(pos, 4)

                // Set the offset and size for the pathDefinition portion of the msg.data
                pathDefinition.length := mul(shr(248, calldataload(pos)), 32)
                pathDefinition.offset := add(pos, 1)
            }
        }

        // For inputToken
        if (inputTokenLookup.needsLookup) {
            tokenInfo.inputToken = odosRouter.addressList(inputTokenLookup.tokenIndex);
        }
        
        // For outputToken
        if (outputTokenLookup.needsLookup) {
            tokenInfo.outputToken = odosRouter.addressList(outputTokenLookup.tokenIndex);
        }
        
        // For executor
        if (executorLookup.needsLookup) {
            executor = odosRouter.addressList(executorLookup.tokenIndex);
        }

        addressesFound = abi.encodePacked(tokenInfo.inputToken, tokenInfo.outputToken, tokenInfo.outputReceiver, executor); 
    }
} 


interface IOdosRouterV2 {
    function addressList(uint256 index) external view returns (address); 
}

struct Address {    
    uint256 tokenIndex; 
    bool needsLookup; 
}
