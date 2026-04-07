export declare class Address {
    static NATIVE_CURRENCY: Address;
    static ZERO_ADDRESS: Address;
    private readonly val;
    constructor(val: string);
    static fromBigInt(val: bigint): Address;
    static fromFirstBytes(bytes: string): Address;
    toString(): string;
    equal(other: Address): boolean;
    isNative(): boolean;
    isZero(): boolean;
    lastHalf(): string;
}
