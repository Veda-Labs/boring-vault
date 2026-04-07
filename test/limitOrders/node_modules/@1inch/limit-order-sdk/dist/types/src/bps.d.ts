/**
 * Basis point in range [0, 100]%
 *
 * 1bps = 0.01%
 */
export declare class Bps {
    readonly value: bigint;
    static ZERO: Bps;
    constructor(value: bigint);
    /**
     * Create BPS from percent value.
     * If `value` has precision more than 1bps (with accounting to `base`), it will be rounded down
     * @param val
     * @param base what represents 100%
     */
    static fromPercent(val: number, base?: bigint): Bps;
    /**
     * Create BPS from fraction value.
     * If `value` has precision more than 1bps (with accounting to `base`), it will be rounded down
     * @param val
     * @param base what represents 100%
     */
    static fromFraction(val: number, base?: bigint): Bps;
    equal(other: Bps): boolean;
    isZero(): boolean;
    /**
     * @param base what represents 100%
     */
    toPercent(base?: bigint): number;
    /**
     * @param base what represents 100%
     */
    toFraction(base?: bigint): number;
    toString(): string;
}
