/**
 * ABI fragments for AtomicQueue.
 * Source: src/atomic-queue/AtomicQueue.sol
 *
 * The AtomicQueue implements a solver-based withdrawal system. Users submit
 * withdrawal requests that third-party solvers fulfil asynchronously.
 */
export declare const atomicQueueAbi: readonly [{
    readonly name: "updateAtomicRequest";
    readonly type: "function";
    readonly stateMutability: "nonpayable";
    readonly inputs: readonly [{
        readonly name: "offer";
        readonly type: "address";
    }, {
        readonly name: "want";
        readonly type: "address";
    }, {
        readonly name: "userRequest";
        readonly type: "tuple";
        readonly components: readonly [{
            readonly name: "deadline";
            readonly type: "uint64";
        }, {
            readonly name: "atomicPrice";
            readonly type: "uint88";
        }, {
            readonly name: "offerAmount";
            readonly type: "uint96";
        }, {
            readonly name: "inSolve";
            readonly type: "bool";
        }];
    }];
    readonly outputs: readonly [];
}, {
    readonly name: "safeUpdateAtomicRequest";
    readonly type: "function";
    readonly stateMutability: "nonpayable";
    readonly inputs: readonly [{
        readonly name: "offer";
        readonly type: "address";
    }, {
        readonly name: "want";
        readonly type: "address";
    }, {
        readonly name: "userRequest";
        readonly type: "tuple";
        readonly components: readonly [{
            readonly name: "deadline";
            readonly type: "uint64";
        }, {
            readonly name: "atomicPrice";
            readonly type: "uint88";
        }, {
            readonly name: "offerAmount";
            readonly type: "uint96";
        }, {
            readonly name: "inSolve";
            readonly type: "bool";
        }];
    }, {
        readonly name: "accountant";
        readonly type: "address";
    }, {
        readonly name: "maxDiscount";
        readonly type: "uint256";
    }];
    readonly outputs: readonly [];
}, {
    readonly name: "getUserAtomicRequest";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
    }, {
        readonly name: "offer";
        readonly type: "address";
    }, {
        readonly name: "want";
        readonly type: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "request";
        readonly type: "tuple";
        readonly components: readonly [{
            readonly name: "deadline";
            readonly type: "uint64";
        }, {
            readonly name: "atomicPrice";
            readonly type: "uint88";
        }, {
            readonly name: "offerAmount";
            readonly type: "uint96";
        }, {
            readonly name: "inSolve";
            readonly type: "bool";
        }];
    }];
}, {
    readonly name: "isAtomicRequestValid";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [{
        readonly name: "offer";
        readonly type: "address";
    }, {
        readonly name: "user";
        readonly type: "address";
    }, {
        readonly name: "userRequest";
        readonly type: "tuple";
        readonly components: readonly [{
            readonly name: "deadline";
            readonly type: "uint64";
        }, {
            readonly name: "atomicPrice";
            readonly type: "uint88";
        }, {
            readonly name: "offerAmount";
            readonly type: "uint96";
        }, {
            readonly name: "inSolve";
            readonly type: "bool";
        }];
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
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
    readonly name: "viewVerboseSolveMetaData";
    readonly type: "function";
    readonly stateMutability: "view";
    readonly inputs: readonly [{
        readonly name: "offer";
        readonly type: "address";
    }, {
        readonly name: "want";
        readonly type: "address";
    }, {
        readonly name: "users";
        readonly type: "address[]";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple[]";
        readonly components: readonly [{
            readonly name: "user";
            readonly type: "address";
        }, {
            readonly name: "deadlineExceeded";
            readonly type: "bool";
        }, {
            readonly name: "zeroOfferAmount";
            readonly type: "bool";
        }, {
            readonly name: "insufficientOfferBalance";
            readonly type: "bool";
        }, {
            readonly name: "insufficientOfferAllowance";
            readonly type: "bool";
        }, {
            readonly name: "assetsToOffer";
            readonly type: "uint256";
        }, {
            readonly name: "assetsForWant";
            readonly type: "uint256";
        }];
    }];
}, {
    readonly name: "AtomicRequestUpdated";
    readonly type: "event";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly indexed: true;
    }, {
        readonly name: "offerToken";
        readonly type: "address";
        readonly indexed: true;
    }, {
        readonly name: "wantToken";
        readonly type: "address";
        readonly indexed: true;
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
    }, {
        readonly name: "deadline";
        readonly type: "uint64";
        readonly indexed: false;
    }, {
        readonly name: "minPrice";
        readonly type: "uint88";
        readonly indexed: false;
    }];
}, {
    readonly name: "AtomicRequestFulfilled";
    readonly type: "event";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly indexed: true;
    }, {
        readonly name: "offerToken";
        readonly type: "address";
        readonly indexed: true;
    }, {
        readonly name: "wantToken";
        readonly type: "address";
        readonly indexed: true;
    }, {
        readonly name: "offerAmountSpent";
        readonly type: "uint256";
        readonly indexed: false;
    }, {
        readonly name: "wantAmountReceived";
        readonly type: "uint256";
        readonly indexed: false;
    }];
}];
//# sourceMappingURL=atomicQueue.d.ts.map