/**
 * ABI fragments for BoringOnChainQueue.
 * The newer withdrawal queue (replaces AtomicQueue for vaults deployed after mid-2025).
 * Source: src/base/Roles/BoringOnChainQueue.sol
 *
 * Key difference vs AtomicQueue:
 *   - User specifies a discount (BPS) + secondsToDeadline, not an atomicPrice
 *   - withdrawAssets() mapping tells you the valid discount range per asset
 *   - BoringSolver fulfils requests on-chain; no external solver needed
 */
export declare const boringOnChainQueueAbi: readonly [{
    readonly name: "requestOnChainWithdraw";
    readonly type: "function";
    readonly stateMutability: "nonpayable";
    readonly inputs: readonly [{
        readonly name: "assetOut";
        readonly type: "address";
    }, {
        readonly name: "amountOfShares";
        readonly type: "uint128";
    }, {
        readonly name: "discount";
        readonly type: "uint16";
    }, {
        readonly name: "secondsToDeadline";
        readonly type: "uint24";
    }];
    readonly outputs: readonly [{
        readonly name: "requestId";
        readonly type: "bytes32";
    }];
}, {
    readonly name: "requestOnChainWithdrawWithPermit";
    readonly type: "function";
    readonly stateMutability: "nonpayable";
    readonly inputs: readonly [{
        readonly name: "assetOut";
        readonly type: "address";
    }, {
        readonly name: "amountOfShares";
        readonly type: "uint128";
    }, {
        readonly name: "discount";
        readonly type: "uint16";
    }, {
        readonly name: "secondsToDeadline";
        readonly type: "uint24";
    }, {
        readonly name: "permitDeadline";
        readonly type: "uint256";
    }, {
        readonly name: "v";
        readonly type: "uint8";
    }, {
        readonly name: "r";
        readonly type: "bytes32";
    }, {
        readonly name: "s";
        readonly type: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "requestId";
        readonly type: "bytes32";
    }];
}, {
    readonly name: "cancelOnChainWithdraw";
    readonly type: "function";
    readonly stateMutability: "nonpayable";
    readonly inputs: readonly [{
        readonly name: "request";
        readonly type: "tuple";
        readonly components: readonly [{
            readonly name: "user";
            readonly type: "address";
        }, {
            readonly name: "assetOut";
            readonly type: "address";
        }, {
            readonly name: "amountOfShares";
            readonly type: "uint128";
        }, {
            readonly name: "amountOfAssets";
            readonly type: "uint128";
        }, {
            readonly name: "creationTime";
            readonly type: "uint40";
        }, {
            readonly name: "secondsToMaturity";
            readonly type: "uint24";
        }, {
            readonly name: "secondsToDeadline";
            readonly type: "uint24";
        }];
    }];
    readonly outputs: readonly [];
}, {
    readonly name: "withdrawAssets";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [{
        readonly name: "asset";
        readonly type: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "allowWithdraws";
        readonly type: "bool";
    }, {
        readonly name: "secondsToMaturity";
        readonly type: "uint24";
    }, {
        readonly name: "minimumSecondsToDeadline";
        readonly type: "uint24";
    }, {
        readonly name: "minDiscount";
        readonly type: "uint16";
    }, {
        readonly name: "maxDiscount";
        readonly type: "uint16";
    }, {
        readonly name: "minimumShares";
        readonly type: "uint96";
    }, {
        readonly name: "withdrawCapacity";
        readonly type: "uint256";
    }];
}, {
    readonly name: "previewAssetsOut";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [{
        readonly name: "assetOut";
        readonly type: "address";
    }, {
        readonly name: "amountOfShares";
        readonly type: "uint128";
    }, {
        readonly name: "discount";
        readonly type: "uint16";
    }];
    readonly outputs: readonly [{
        readonly name: "assetsOut";
        readonly type: "uint256";
    }];
}, {
    readonly name: "isPaused";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
    }];
}, {
    readonly name: "OnChainWithdrawRequested";
    readonly type: "event";
    readonly inputs: readonly [{
        readonly name: "requestId";
        readonly type: "bytes32";
        readonly indexed: true;
    }, {
        readonly name: "user";
        readonly type: "address";
        readonly indexed: true;
    }, {
        readonly name: "assetOut";
        readonly type: "address";
        readonly indexed: true;
    }, {
        readonly name: "amountOfShares";
        readonly type: "uint128";
        readonly indexed: false;
    }, {
        readonly name: "amountOfAssets";
        readonly type: "uint128";
        readonly indexed: false;
    }, {
        readonly name: "creationTime";
        readonly type: "uint40";
        readonly indexed: false;
    }, {
        readonly name: "secondsToMaturity";
        readonly type: "uint24";
        readonly indexed: false;
    }, {
        readonly name: "secondsToDeadline";
        readonly type: "uint24";
        readonly indexed: false;
    }];
}, {
    readonly name: "OnChainWithdrawCancelled";
    readonly type: "event";
    readonly inputs: readonly [{
        readonly name: "requestId";
        readonly type: "bytes32";
        readonly indexed: true;
    }, {
        readonly name: "user";
        readonly type: "address";
        readonly indexed: true;
    }, {
        readonly name: "timestamp";
        readonly type: "uint256";
        readonly indexed: false;
    }];
}];
//# sourceMappingURL=boringOnChainQueue.d.ts.map