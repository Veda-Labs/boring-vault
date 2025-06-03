// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract DolomiteDecoderAndSanitizer {
    //============================== Errors  ===============================

    error DolomiteDecoderAndSanitizer__ArrayLengthGTOne();

    address dolomiteMargin;

    constructor(address _dolomiteMargin) {
        dolomiteMargin = _dolomiteMargin;
    }

    //============================== DepositWithdrawalProxy Functions ===============================

    /////////////////// WAD Scaled Functions //////////////////

    //account numbers are owned by wallet address, so no need to sanitize
    function depositWei(uint256, /*_toAccountNumber*/ uint256 _marketId, uint256 /*_amountWei*/ )
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_marketId);
        addressesFound = abi.encodePacked(tokenFromId);
    }

    function depositWeiIntoDefaultAccount(uint256 _marketId, uint256 /*_amountWei*/ )
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_marketId);
        addressesFound = abi.encodePacked(tokenFromId);
    }

    function withdrawWei(
        uint256, /*_fromAccountNumber*/
        uint256 _marketId,
        uint256, /*_amountWei*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external view virtual returns (bytes memory addressesFound) {
        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_marketId);
        addressesFound = abi.encodePacked(tokenFromId);
    }

    function withdrawWeiFromDefaultAccount(
        uint256 _marketId,
        uint256, /*_amountWei*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external view virtual returns (bytes memory addressesFound) {
        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_marketId);
        addressesFound = abi.encodePacked(tokenFromId);
    }

    /////////////////// Native ETH Functions //////////////////

    function depositETH(uint256 /*_toAccountNumber*/ ) external view virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function depositETHIntoDefaultAccount() external view virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function withdrawETH(
        uint256, /*_fromAccountNumber*/
        uint256, /*_amountWei*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external view virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function withdrawETHFromDefaultAccount(
        uint256, /*_amountWei*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external view virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    /////////////////// Par Scaled Functions //////////////////

    function depositPar(uint256, /*_toAccountNumber*/ uint256 _marketId, uint256 /*_amountPar*/ )
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_marketId);
        addressesFound = abi.encodePacked(tokenFromId);
    }

    function depositParIntoDefaultAccount(uint256 _marketId, uint256 /*_amountPar*/ )
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_marketId);
        addressesFound = abi.encodePacked(tokenFromId);
    }

    function withdrawPar(
        uint256, /*_fromAccountNumber*/
        uint256 _marketId,
        uint256, /*_amountPar*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external view virtual returns (bytes memory addressesFound) {
        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_marketId);
        addressesFound = abi.encodePacked(tokenFromId);
    }

    function withdrawParFromDefaultAccount(
        uint256 _marketId,
        uint256, /*_amountPar*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external view virtual returns (bytes memory addressesFound) {
        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_marketId);
        addressesFound = abi.encodePacked(tokenFromId);
    }

    //============================== BorrowPositionProxy Functions ===============================

    function openBorrowPosition(
        uint256, /*_fromAccountNumber*/
        uint256, /*_toAccountNumber*/
        uint256 _marketId,
        uint256, /*_amountWei*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external view virtual returns (bytes memory addressesFound) {
        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_marketId);
        addressesFound = abi.encodePacked(tokenFromId);
    }

    function closeBorrowPosition(
        uint256, /*_borrowAccountNumber*/
        uint256, /*_toAccountNumber*/
        uint256[] calldata _collateralMarketIds
    ) external view virtual returns (bytes memory addressesFound) {
        if (_collateralMarketIds.length > 1) revert DolomiteDecoderAndSanitizer__ArrayLengthGTOne();

        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_collateralMarketIds[0]);
        addressesFound = abi.encodePacked(tokenFromId);
    }

    function repayAllForBorrowPosition(
        uint256, /*_fromAccountNumber*/
        uint256, /*_borrowAccountNumber*/
        uint256 _marketId,
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external view virtual returns (bytes memory addressesFound) {
        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_marketId);
        addressesFound = abi.encodePacked(tokenFromId);
    }

    function transferBetweenAccounts(
        uint256, /*_fromAccountNumber*/
        uint256, /*_toAccountNumber*/
        uint256 _marketId,
        uint256, /*_amountWei*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external view virtual returns (bytes memory addressesFound) {
        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_marketId);
        addressesFound = abi.encodePacked(tokenFromId);
    }

    function openBorrowPositionWithDifferentAccounts(
        address _fromAccountOwner,
        uint256, /*_fromAccountNumber*/
        address _toAccountOwner,
        uint256, /*_toAccountNumber*/
        uint256 _marketId,
        uint256, /*_amountWei*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external view virtual returns (bytes memory addressesFound) {
        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_marketId);
        addressesFound = abi.encodePacked(_fromAccountOwner, _toAccountOwner, tokenFromId);
    }

    function closeBorrowPositionWithDifferentAccounts(
        address _borrowAccountOwner,
        uint256, /*_borrowAccountNumber*/
        address _toAccountOwner,
        uint256, /*_toAccountNumber*/
        uint256[] calldata _collateralMarketIds
    ) external view virtual returns (bytes memory addressesFound) {
        if (_collateralMarketIds.length > 1) revert DolomiteDecoderAndSanitizer__ArrayLengthGTOne();
        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_collateralMarketIds[0]);
        addressesFound = abi.encodePacked(_borrowAccountOwner, _toAccountOwner, tokenFromId);
    }

    function transferBetweenAccountsWithDifferentAccounts(
        address _fromAccountOwner,
        uint256, /*_fromAccountNumber*/
        address _toAccountOwner,
        uint256, /*_toAccountNumber*/
        uint256 _marketId,
        uint256, /*_amountWei*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external view virtual returns (bytes memory addressesFound) {
        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_marketId);
        addressesFound = abi.encodePacked(_fromAccountOwner, _toAccountOwner, tokenFromId);
    }

    function repayAllForBorrowPositionWithDifferentAccounts(
        address _fromAccountOwner,
        uint256, /*_fromAccountNumber*/
        address _borrowAccountOwner,
        uint256, /*_borrowAccountNumber*/
        uint256 _marketId,
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external view virtual returns (bytes memory addressesFound) {
        address tokenFromId = IDolomiteMargin(dolomiteMargin).getMarketTokenAddress(_marketId);
        addressesFound = abi.encodePacked(_fromAccountOwner, _borrowAccountOwner, tokenFromId);
    }
}

interface IDolomiteMargin {
    function getMarketTokenAddress(uint256 _marketId) external view returns (address);
}
