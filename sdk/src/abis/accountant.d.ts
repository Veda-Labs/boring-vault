/**
 * ABI fragments for AccountantWithRateProviders.
 * Source: src/base/Roles/AccountantWithRateProviders.sol
 */
export declare const accountantAbi: readonly [{
    readonly name: "getRate";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "rate";
        readonly type: "uint256";
    }];
}, {
    readonly name: "getRateSafe";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "rate";
        readonly type: "uint256";
    }];
}, {
    readonly name: "getRateInQuote";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [{
        readonly name: "quote";
        readonly type: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "rateInQuote";
        readonly type: "uint256";
    }];
}, {
    readonly name: "getRateInQuoteSafe";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [{
        readonly name: "quote";
        readonly type: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "rateInQuote";
        readonly type: "uint256";
    }];
}, {
    readonly name: "accountantState";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "payoutAddress";
        readonly type: "address";
    }, {
        readonly name: "highwaterMark";
        readonly type: "uint96";
    }, {
        readonly name: "feesOwedInBase";
        readonly type: "uint128";
    }, {
        readonly name: "totalSharesLastUpdate";
        readonly type: "uint128";
    }, {
        readonly name: "exchangeRate";
        readonly type: "uint96";
    }, {
        readonly name: "allowedExchangeRateChangeUpper";
        readonly type: "uint16";
    }, {
        readonly name: "allowedExchangeRateChangeLower";
        readonly type: "uint16";
    }, {
        readonly name: "lastUpdateTimestamp";
        readonly type: "uint64";
    }, {
        readonly name: "isPaused";
        readonly type: "bool";
    }, {
        readonly name: "minimumUpdateDelayInSeconds";
        readonly type: "uint24";
    }, {
        readonly name: "managementFee";
        readonly type: "uint16";
    }, {
        readonly name: "performanceFee";
        readonly type: "uint16";
    }];
}, {
    readonly name: "base";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
    }];
}, {
    readonly name: "decimals";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint8";
    }];
}, {
    readonly name: "rateProviderData";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [{
        readonly name: "asset";
        readonly type: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "isPeggedToBase";
        readonly type: "bool";
    }, {
        readonly name: "rateProvider";
        readonly type: "address";
    }];
}, {
    readonly name: "ExchangeRateUpdated";
    readonly type: "event";
    readonly inputs: readonly [{
        readonly name: "oldExchangeRate";
        readonly type: "uint96";
        readonly indexed: false;
    }, {
        readonly name: "newExchangeRate";
        readonly type: "uint96";
        readonly indexed: false;
    }, {
        readonly name: "currentTime";
        readonly type: "uint64";
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
//# sourceMappingURL=accountant.d.ts.map