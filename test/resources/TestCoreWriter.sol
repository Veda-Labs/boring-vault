// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

contract TestCoreWriter {
    event RawAction(address indexed user, bytes data);
    event TestCoreWriter__LimitOrder(
        uint32 asset, bool isBuy, uint64 limitPx, uint64 sz, bool reduceOnly, uint8 encodedTif, uint128 cloid
    );
    event TestCoreWriter__VaultTransfer(address vault, bool isDeposit, uint64 usd);
    event TestCoreWriter__TokenDelegate(address validator, uint64 _wei, bool isUndelegate);
    event TestCoreWriter__StakingDeposit(uint64 _wei);
    event TestCoreWriter__StakingWithdraw(uint64 _wei);
    event TestCoreWriter__SpotSend(address destination, uint64 token, uint64 _wei);
    event TestCoreWriter__UsdClassTransfer(uint64 ntl, bool toPerp);
    event TestCoreWriter__FinalizeEvmContract(
        uint64 token, uint8 encodedFinalizeEvmContractVariant, uint64 createNonce
    );
    event TestCoreWriter__AddApiWallet(address apiWalletAddress, string apiWalletName);
    event TestCoreWriter__CancelOrderByOid(uint32 asset, uint64 cloid);
    event TestCoreWriter__CancelOrderByCloid(uint32 asset, uint128 cloid);

    function sendRawAction(bytes calldata data) external {
        for (uint256 i = 0; i < 400; i++) {}
        emit RawAction(msg.sender, data);
        _handleRawAction(data);
    }

    /*
    ==============================================================================================================================================================================================================================
    | ID | Action Name                | Parameters (name : type)                                                                 | Notes                                                                                         |
    |----|----------------------------|------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|
    | 1  | Limit Order                | asset:uint32, isBuy:bool, limitPx:uint64, sz:uint64, reduceOnly:bool, encodedTif:uint8,  | TIF: 1=ALO, 2=GTC, 3=IOC. Cloid: 0=none, else specific number. limitPx & sz sent as 1e8*x.    |
    |    |                            | cloid:uint128                                                                            |                                                                                               |
    | 2  | Vault Transfer             | vault:address, isDeposit:bool, usd:uint64                                                | usd scaled as per system                                                                      |
    | 3  | Token Delegate             | validator:address, wei:uint64, isUndelegate:bool                                         | Amount in wei                                                                                 |
    | 4  | Staking Deposit            | wei:uint64                                                                               | Amount in wei                                                                                 |
    | 5  | Staking Withdraw           | wei:uint64                                                                               | Amount in wei                                                                                 |
    | 6  | Spot Send                  | destination:address, token:uint64, wei:uint64                                            | Amount in wei                                                                                 |
    | 7  | USD Class Transfer         | ntl:uint64, toPerp:bool                                                                  |                                                                                               |
    | 8  | Finalize EVM Contract      | token:uint64, encodedFinalizeEvmContractVariant:uint8, createNonce:uint64                | Variant: 1=Create, 2=FirstStorageSlot, 3=CustomStorageSlot. createNonce used for Create only  |
    | 9  | Add API Wallet             | apiWallet:address, apiWalletName:string                                                  | Empty name => main API wallet/agent                                                           |
    | 10 | Cancel Order by OID        | asset:uint32, oid:uint64                                                                 | Order ID                                                                                      |
    | 11 | Cancel Order by CLoID      | asset:uint32, cloid:uint128                                                              | Client Order ID                                                                               |
    ==============================================================================================================================================================================================================================
    */

    function _handleRawAction(bytes calldata data) internal {
        require(data[0] == 0x01, "only encoding type 1 supported");
        bytes1 actionID = data[3];

        if (actionID == 0x01) {
            (uint32 asset, bool isBuy, uint64 limitPx, uint64 sz, bool reduceOnly, uint8 encodedTif, uint128 cloid) =
                abi.decode(data[4:], (uint32, bool, uint64, uint64, bool, uint8, uint128));
            emit TestCoreWriter__LimitOrder(asset, isBuy, limitPx, sz, reduceOnly, encodedTif, cloid);
        } else if (actionID == 0x02) {
            (address vault, bool isDeposit, uint64 usd) = abi.decode(data[4:], (address, bool, uint64));
            emit TestCoreWriter__VaultTransfer(vault, isDeposit, usd);
        } else if (actionID == 0x03) {
            (address validator, uint64 _wei, bool isUndelegate) = abi.decode(data[4:], (address, uint64, bool));
            emit TestCoreWriter__TokenDelegate(validator, _wei, isUndelegate);
        } else if (actionID == 0x04) {
            uint64 _wei = abi.decode(data[4:], (uint64));
            emit TestCoreWriter__StakingDeposit(_wei);
        } else if (actionID == 0x05) {
            uint64 _wei = abi.decode(data[4:], (uint64));
            emit TestCoreWriter__StakingWithdraw(_wei);
        } else if (actionID == 0x06) {
            (address destination, uint64 token, uint64 _wei) = abi.decode(data[4:], (address, uint64, uint64));
            emit TestCoreWriter__SpotSend(destination, token, _wei);
        } else if (actionID == 0x07) {
            (uint64 ntl, bool toPerp) = abi.decode(data[4:], (uint64, bool));
            emit TestCoreWriter__UsdClassTransfer(ntl, toPerp);
        } else if (actionID == 0x08) {
            (uint64 token, uint8 encodedFinalizeEvmContractVariant, uint64 createNonce) =
                abi.decode(data[4:], (uint64, uint8, uint64));
            emit TestCoreWriter__FinalizeEvmContract(token, encodedFinalizeEvmContractVariant, createNonce);
        } else if (actionID == 0x09) {
            (address apiWalletAddress, string memory apiWalletName) = abi.decode(data[4:], (address, string));
            emit TestCoreWriter__AddApiWallet(apiWalletAddress, apiWalletName);
        } else if (actionID == 0x0A) {
            (uint32 asset, uint64 oid) = abi.decode(data[4:], (uint32, uint64));
        } else if (actionID == 0x0B) {
            (uint32 asset, uint128 cloid) = abi.decode(data[4:], (uint32, uint128));
            emit TestCoreWriter__CancelOrderByCloid(asset, cloid);
        }
    }
}
