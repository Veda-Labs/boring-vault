// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringDrone, DroneLib} from "src/base/Drones/BoringDrone.sol";
import {ISafe} from "src/interfaces/ISafe.sol";

contract BoringModule is BoringDrone {
    //============================== CONSTANTS ===============================

    /**
     * @notice The operation to use when calling the safe.
     */
    uint8 constant CALL_OPERATION = 0;

    //============================== IMMUTABLES ===============================

    /**
     * @notice The safe to forward calls to.
     */
    ISafe internal immutable safe;

    constructor(address _boringVault, uint256 _safeGasToForwardNative, address _safe)
        BoringDrone(_boringVault, _safeGasToForwardNative)
    {
        safe = ISafe(_safe);
    }

    //============================== WITHDRAW ===============================

    /**
     * @notice Withdraws all native from the safe.
     */
    function withdrawNativeFromSafe() external onlyBoringVault {
        uint256 safeBalance = address(safe).balance;
        safe.execTransactionFromModule(boringVault, safeBalance, "", CALL_OPERATION);
    }

    //============================== FALLBACK ===============================

    /**
     * @notice This contract in its current state can only be interacted with by the BoringVault.
     * @notice The real target is extracted from the call data using `extractTargetFromCalldata()`.
     * @notice The drone then forwards the call to the safe.
     */
    fallback() external payable override onlyBoringVault {
        // Extract real target from end of calldata
        address target = DroneLib.extractTargetFromCalldata();

        // Forward call to safe.
        safe.execTransactionFromModule(target, msg.value, msg.data, CALL_OPERATION);
    }
}
