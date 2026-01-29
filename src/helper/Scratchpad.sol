// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract ScratchPad {
    error ComparisonFailed(uint256 a, uint256 b);
    
    function write(uint256 slot, bytes32 value) external {
        assembly {
            tstore(slot, value)
        }
    }
    
    function read(uint256 slot) external view returns (bytes32 value) {
        assembly {
            value := tload(slot)
        }
    }
    
    function add(uint256 slotA, uint256 slotB, uint256 resultSlot) external {
        assembly {
            tstore(resultSlot, add(tload(slotA), tload(slotB)))
        }
    }
    
    function sub(uint256 slotA, uint256 slotB, uint256 resultSlot) external {
        assembly {
            tstore(resultSlot, sub(tload(slotA), tload(slotB)))
        }
    }
    
    function eq(uint256 slotA, uint256 slotB) external view {
        uint256 a;
        uint256 b;
        assembly {
            a := tload(slotA)
            b := tload(slotB)
        }
        if (a != b) revert ComparisonFailed(a, b);
    }
    
    function gt(uint256 slotA, uint256 slotB) external view {
        uint256 a;
        uint256 b;
        assembly {
            a := tload(slotA)
            b := tload(slotB)
        }
        if (a <= b) revert ComparisonFailed(a, b);
    }
    
    function gte(uint256 slotA, uint256 slotB) external view {
        uint256 a;
        uint256 b;
        assembly {
            a := tload(slotA)
            b := tload(slotB)
        }
        if (a < b) revert ComparisonFailed(a, b);
    }
    
    function lt(uint256 slotA, uint256 slotB) external view {
        uint256 a;
        uint256 b;
        assembly {
            a := tload(slotA)
            b := tload(slotB)
        }
        if (a >= b) revert ComparisonFailed(a, b);
    }
    
    function lte(uint256 slotA, uint256 slotB) external view {
        uint256 a;
        uint256 b;
        assembly {
            a := tload(slotA)
            b := tload(slotB)
        }
        if (a > b) revert ComparisonFailed(a, b);
    }
}
