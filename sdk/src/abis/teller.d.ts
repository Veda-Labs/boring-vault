/**
 * ABI fragments for TellerWithMultiAssetSupport.
 * Source: src/base/Roles/TellerWithMultiAssetSupport.sol
 */
export declare const tellerAbi: readonly [{
    readonly name: "deposit";
    readonly type: "function";
    readonly stateMutability: "payable";
    readonly inputs: readonly [{
        readonly name: "depositAsset";
        readonly type: "address";
    }, {
        readonly name: "depositAmount";
        readonly type: "uint256";
    }, {
        readonly name: "minimumMint";
        readonly type: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
    }];
}, {
    readonly name: "depositWithPermit";
    readonly type: "function";
    readonly stateMutability: "nonpayable";
    readonly inputs: readonly [{
        readonly name: "depositAsset";
        readonly type: "address";
    }, {
        readonly name: "depositAmount";
        readonly type: "uint256";
    }, {
        readonly name: "minimumMint";
        readonly type: "uint256";
    }, {
        readonly name: "deadline";
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
        readonly name: "shares";
        readonly type: "uint256";
    }];
}, {
    readonly name: "bulkDeposit";
    readonly type: "function";
    readonly stateMutability: "nonpayable";
    readonly inputs: readonly [{
        readonly name: "depositAsset";
        readonly type: "address";
    }, {
        readonly name: "depositAmount";
        readonly type: "uint256";
    }, {
        readonly name: "minimumMint";
        readonly type: "uint256";
    }, {
        readonly name: "to";
        readonly type: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
    }];
}, {
    readonly name: "bulkWithdraw";
    readonly type: "function";
    readonly stateMutability: "nonpayable";
    readonly inputs: readonly [{
        readonly name: "withdrawAsset";
        readonly type: "address";
    }, {
        readonly name: "shareAmount";
        readonly type: "uint256";
    }, {
        readonly name: "minimumAssets";
        readonly type: "uint256";
    }, {
        readonly name: "to";
        readonly type: "address";
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
    readonly name: "isSupported";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [{
        readonly name: "asset";
        readonly type: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
    }];
}, {
    readonly name: "shareLockPeriod";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint64";
    }];
}, {
    readonly name: "shareUnlockTime";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
    }];
}, {
    readonly name: "Deposit";
    readonly type: "event";
    readonly inputs: readonly [{
        readonly name: "nonce";
        readonly type: "uint256";
        readonly indexed: true;
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly indexed: true;
    }, {
        readonly name: "depositAsset";
        readonly type: "address";
        readonly indexed: true;
    }, {
        readonly name: "depositAmount";
        readonly type: "uint256";
        readonly indexed: false;
    }, {
        readonly name: "shareAmount";
        readonly type: "uint256";
        readonly indexed: false;
    }, {
        readonly name: "depositTimestamp";
        readonly type: "uint256";
        readonly indexed: false;
    }, {
        readonly name: "shareLockPeriodAtTimeOfDeposit";
        readonly type: "uint256";
        readonly indexed: false;
    }];
}, {
    readonly name: "Paused";
    readonly type: "event";
    readonly inputs: readonly [];
}, {
    readonly name: "Unpaused";
    readonly type: "event";
    readonly inputs: readonly [];
}];
//# sourceMappingURL=teller.d.ts.map