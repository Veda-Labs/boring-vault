// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.21;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {IMorphoFlashLoanCallback} from "src/interfaces/IMorphoCallbacks.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

contract MorphoFlashLoanAdapter is IMorphoFlashLoanCallback {
    using SafeTransferLib for ERC20;

    error MorphoFlashLoanAdapter__OnlyVault();
    error MorphoFlashLoanAdapter__OnlyMorpho();
    error MorphoFlashLoanAdapter__FlashLoanNotInProgress();
    error MorphoFlashLoanAdapter__FlashLoanAlreadyInProgress();
    error MorphoFlashLoanAdapter__FlashLoanNotExecuted();
    error MorphoFlashLoanAdapter__BadFlashLoanIntentHash();
    error MorphoFlashLoanAdapter__InvalidLengths();

    IMorpho public immutable morpho;
    BoringVault public immutable vault;
    ManagerWithMerkleVerification public immutable manager;

    bool internal performingFlashLoan;
    bytes32 internal flashLoanIntentHash;

    constructor(address _morpho, address _vault, address _manager) {
        morpho = IMorpho(_morpho);
        vault = BoringVault(payable(_vault));
        manager = ManagerWithMerkleVerification(_manager);
    }

    /**
     * @notice Entry point — called by vault via vault.manage().
     * @dev data encoding: abi.encode(token, manageProofs, decoders, targets, targetData, values)
     */
    function morphoFlashLoan(address token, uint256 assets, bytes calldata data) external {
        if (msg.sender != address(vault)) revert MorphoFlashLoanAdapter__OnlyVault();
        if (performingFlashLoan) revert MorphoFlashLoanAdapter__FlashLoanAlreadyInProgress();

        flashLoanIntentHash = keccak256(abi.encode(token, assets, data));
        performingFlashLoan = true;
        morpho.flashLoan(token, assets, data);
        performingFlashLoan = false;
        if (flashLoanIntentHash != bytes32(0)) revert MorphoFlashLoanAdapter__FlashLoanNotExecuted();
    }

    /**
     * @notice Morpho callback — tokens already in adapter at this point.
     */
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert MorphoFlashLoanAdapter__OnlyMorpho();
        if (!performingFlashLoan) revert MorphoFlashLoanAdapter__FlashLoanNotInProgress();

        (
            address token,
            bytes32[][] memory manageProofs,
            address[] memory decodersAndSanitizers,
            address[] memory targets,
            bytes[] memory targetData,
            uint256[] memory values
        ) = abi.decode(data, (address, bytes32[][], address[], address[], bytes[], uint256[]));

        bytes32 intentHash = keccak256(abi.encode(token, assets, data));
        if (intentHash != flashLoanIntentHash) revert MorphoFlashLoanAdapter__BadFlashLoanIntentHash();
        flashLoanIntentHash = bytes32(0);

        ERC20(token).safeTransfer(address(vault), assets);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        bytes[] memory transferBack = new bytes[](1);
        transferBack[0] = abi.encodeWithSelector(ERC20.transfer.selector, address(this), assets);
        address[] memory tokenArr = new address[](1);
        tokenArr[0] = token;
        vault.manage(tokenArr, transferBack, new uint256[](1));

        ERC20(token).safeApprove(address(morpho), 0);
        ERC20(token).safeApprove(address(morpho), assets);
    }

    function emergencyRescueTokens(address[] memory assets, uint256[] memory amounts) external {
        if (msg.sender != address(vault)) revert MorphoFlashLoanAdapter__OnlyVault();
        if (performingFlashLoan) revert MorphoFlashLoanAdapter__FlashLoanAlreadyInProgress();
        if (assets.length != amounts.length) revert MorphoFlashLoanAdapter__InvalidLengths();

        for (uint256 i = 0; i < assets.length; i++) {
            ERC20(assets[i]).safeTransfer(address(vault), amounts[i]);
        }
    }
}
