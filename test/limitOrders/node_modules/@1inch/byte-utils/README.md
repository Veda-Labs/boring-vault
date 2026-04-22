# @1inch/byte-utils
Contains helpers to work with bytes

## Installation

```shell
npm install @1inch/byte-utils
```

## Docs

<!-- TSDOC_START -->

## :toolbox: Functions

- [isHexString](#gear-ishexstring)
- [isHexBytes](#gear-ishexbytes)

### :gear: isHexString

Check that string starts with 0x and has only valid hex symbols

| Function | Type |
| ---------- | ---------- |
| `isHexString` | `(val: string) => boolean` |

### :gear: isHexBytes

Check that string is valid hex with 0x prefix and length is even

| Function | Type |
| ---------- | ---------- |
| `isHexBytes` | `(val: string) => boolean` |


## :wrench: Constants

- [UINT_8_MAX](#gear-uint_8_max)
- [UINT_24_MAX](#gear-uint_24_max)
- [UINT_32_MAX](#gear-uint_32_max)
- [UINT_40_MAX](#gear-uint_40_max)
- [UINT_48_MAX](#gear-uint_48_max)
- [UINT_80_MAX](#gear-uint_80_max)
- [UINT_160_MAX](#gear-uint_160_max)
- [UINT_128_MAX](#gear-uint_128_max)
- [UINT_256_MAX](#gear-uint_256_max)

### :gear: UINT_8_MAX

| Constant | Type |
| ---------- | ---------- |
| `UINT_8_MAX` | `bigint` |

### :gear: UINT_24_MAX

| Constant | Type |
| ---------- | ---------- |
| `UINT_24_MAX` | `bigint` |

### :gear: UINT_32_MAX

| Constant | Type |
| ---------- | ---------- |
| `UINT_32_MAX` | `bigint` |

### :gear: UINT_40_MAX

| Constant | Type |
| ---------- | ---------- |
| `UINT_40_MAX` | `bigint` |

### :gear: UINT_48_MAX

| Constant | Type |
| ---------- | ---------- |
| `UINT_48_MAX` | `bigint` |

### :gear: UINT_80_MAX

| Constant | Type |
| ---------- | ---------- |
| `UINT_80_MAX` | `bigint` |

### :gear: UINT_160_MAX

| Constant | Type |
| ---------- | ---------- |
| `UINT_160_MAX` | `bigint` |

### :gear: UINT_128_MAX

| Constant | Type |
| ---------- | ---------- |
| `UINT_128_MAX` | `bigint` |

### :gear: UINT_256_MAX

| Constant | Type |
| ---------- | ---------- |
| `UINT_256_MAX` | `bigint` |


## :factory: BitMask

Class to define bit mask: new BitMask(16, 32) is for bits from [16, 32) => 0xffff0000

### Methods

- [toString](#gear-tostring)
- [toBigInt](#gear-tobigint)

#### :gear: toString

| Method | Type |
| ---------- | ---------- |
| `toString` | `() => string` |

#### :gear: toBigInt

| Method | Type |
| ---------- | ---------- |
| `toBigInt` | `() => bigint` |


## :factory: BN

Class to work with bits in bignumber
Immutable, all methods return new value

### Methods

- [fromNumber](#gear-fromnumber)
- [fromHex](#gear-fromhex)
- [add](#gear-add)
- [sub](#gear-sub)
- [setBit](#gear-setbit)
- [getBit](#gear-getbit)
- [shiftLeft](#gear-shiftleft)
- [shiftRight](#gear-shiftright)
- [and](#gear-and)
- [or](#gear-or)
- [xor](#gear-xor)
- [isZero](#gear-iszero)
- [isOne](#gear-isone)
- [getMask](#gear-getmask)
- [setMask](#gear-setmask)
- [clearMask](#gear-clearmask)
- [toHex](#gear-tohex)
- [toNumber](#gear-tonumber)

#### :gear: fromNumber

| Method | Type |
| ---------- | ---------- |
| `fromNumber` | `(n: number) => BN` |

#### :gear: fromHex

| Method | Type |
| ---------- | ---------- |
| `fromHex` | `(hex: string) => BN` |

#### :gear: add

Add value

| Method | Type |
| ---------- | ---------- |
| `add` | `(other: BN) => BN` |

#### :gear: sub

Subtract value

| Method | Type |
| ---------- | ---------- |
| `sub` | `(other: BN) => BN` |

#### :gear: setBit

| Method | Type |
| ---------- | ---------- |
| `setBit` | `(n: bigint, value: 0 or 1) => BN` |

#### :gear: getBit

| Method | Type |
| ---------- | ---------- |
| `getBit` | `(n: bigint) => 0 or 1` |

#### :gear: shiftLeft

| Method | Type |
| ---------- | ---------- |
| `shiftLeft` | `(n: bigint) => BN` |

#### :gear: shiftRight

| Method | Type |
| ---------- | ---------- |
| `shiftRight` | `(n: bigint) => BN` |

#### :gear: and

| Method | Type |
| ---------- | ---------- |
| `and` | `(other: bigint or BN) => BN` |

#### :gear: or

| Method | Type |
| ---------- | ---------- |
| `or` | `(other: bigint or BN) => BN` |

#### :gear: xor

| Method | Type |
| ---------- | ---------- |
| `xor` | `(other: bigint or BN) => BN` |

#### :gear: isZero

| Method | Type |
| ---------- | ---------- |
| `isZero` | `() => boolean` |

#### :gear: isOne

| Method | Type |
| ---------- | ---------- |
| `isOne` | `() => boolean` |

#### :gear: getMask

Return bits defined in `mask` as BN

| Method | Type |
| ---------- | ---------- |
| `getMask` | `(mask: BitMask) => BN` |

#### :gear: setMask

Set bits defined in `mask` to `value`
if value is bigger than mask then error will be thrown

| Method | Type |
| ---------- | ---------- |
| `setMask` | `(mask: BitMask, value: bigint or BN) => BN` |

#### :gear: clearMask

Set bits defined in `mask` to 0s

| Method | Type |
| ---------- | ---------- |
| `clearMask` | `(mask: BitMask) => BN` |

#### :gear: toHex

Return 0x prefixed string with hex representation of BN, padded with '0s' if `padNum` specified

| Method | Type |
| ---------- | ---------- |
| `toHex` | `(padNum?: number) => string` |

#### :gear: toNumber

Convert BN to Number

Caution: value will be rounded for numbers > `Number.MAX_SAFE_INTEGER`

| Method | Type |
| ---------- | ---------- |
| `toNumber` | `() => number` |


## :factory: BytesIter

Class to iterate through bytes string by parsing individual bytes

### Methods

- [BigInt](#gear-bigint)
- [String](#gear-string)
- [rest](#gear-rest)
- [isEmpty](#gear-isempty)
- [nextByte](#gear-nextbyte)
- [nextBytes](#gear-nextbytes)
- [nextAddress](#gear-nextaddress)
- [nextUint8](#gear-nextuint8)
- [nextUint16](#gear-nextuint16)
- [nextUint24](#gear-nextuint24)
- [nextUint32](#gear-nextuint32)
- [nextUint128](#gear-nextuint128)
- [nextUint160](#gear-nextuint160)
- [nextUint256](#gear-nextuint256)

#### :gear: BigInt

| Method | Type |
| ---------- | ---------- |
| `BigInt` | `(bytes: string) => BytesIter<bigint>` |

#### :gear: String

| Method | Type |
| ---------- | ---------- |
| `String` | `(bytes: string) => BytesIter<string>` |

#### :gear: rest

Returns all not consumed bytes

| Method | Type |
| ---------- | ---------- |
| `rest` | `() => T` |

#### :gear: isEmpty

| Method | Type |
| ---------- | ---------- |
| `isEmpty` | `() => boolean` |

#### :gear: nextByte

| Method | Type |
| ---------- | ---------- |
| `nextByte` | `(side?: Side) => T` |

#### :gear: nextBytes

| Method | Type |
| ---------- | ---------- |
| `nextBytes` | `(n: number, side?: Side) => T` |

#### :gear: nextAddress

| Method | Type |
| ---------- | ---------- |
| `nextAddress` | `(side?: Side) => T` |

#### :gear: nextUint8

| Method | Type |
| ---------- | ---------- |
| `nextUint8` | `(side?: Side) => T` |

#### :gear: nextUint16

| Method | Type |
| ---------- | ---------- |
| `nextUint16` | `(side?: Side) => T` |

#### :gear: nextUint24

| Method | Type |
| ---------- | ---------- |
| `nextUint24` | `(side?: Side) => T` |

#### :gear: nextUint32

| Method | Type |
| ---------- | ---------- |
| `nextUint32` | `(side?: Side) => T` |

#### :gear: nextUint128

| Method | Type |
| ---------- | ---------- |
| `nextUint128` | `(side?: Side) => T` |

#### :gear: nextUint160

| Method | Type |
| ---------- | ---------- |
| `nextUint160` | `(side?: Side) => T` |

#### :gear: nextUint256

| Method | Type |
| ---------- | ---------- |
| `nextUint256` | `(side?: Side) => T` |


## :factory: BytesBuilder

Helper class to build an arbitrary bytes sequence

### Methods

- [addAddress](#gear-addaddress)
- [addBytes](#gear-addbytes)
- [addByte](#gear-addbyte)
- [addUint8](#gear-adduint8)
- [addUint16](#gear-adduint16)
- [addUint24](#gear-adduint24)
- [addUint32](#gear-adduint32)
- [addUint64](#gear-adduint64)
- [addUint128](#gear-adduint128)
- [addUint160](#gear-adduint160)
- [addUint256](#gear-adduint256)
- [asBigInt](#gear-asbigint)
- [asHex](#gear-ashex)

#### :gear: addAddress

| Method | Type |
| ---------- | ---------- |
| `addAddress` | `(address: string or bigint or BN) => this` |

#### :gear: addBytes

| Method | Type |
| ---------- | ---------- |
| `addBytes` | `(bytes: string) => this` |

#### :gear: addByte

| Method | Type |
| ---------- | ---------- |
| `addByte` | `(byte: string or bigint or BN) => this` |

#### :gear: addUint8

| Method | Type |
| ---------- | ---------- |
| `addUint8` | `(val: string or bigint or BN) => this` |

#### :gear: addUint16

| Method | Type |
| ---------- | ---------- |
| `addUint16` | `(val: string or bigint or BN) => this` |

#### :gear: addUint24

| Method | Type |
| ---------- | ---------- |
| `addUint24` | `(val: string or bigint or BN) => this` |

#### :gear: addUint32

| Method | Type |
| ---------- | ---------- |
| `addUint32` | `(val: string or bigint or BN) => this` |

#### :gear: addUint64

| Method | Type |
| ---------- | ---------- |
| `addUint64` | `(val: string or bigint or BN) => this` |

#### :gear: addUint128

| Method | Type |
| ---------- | ---------- |
| `addUint128` | `(val: string or bigint or BN) => this` |

#### :gear: addUint160

| Method | Type |
| ---------- | ---------- |
| `addUint160` | `(val: string or bigint or BN) => this` |

#### :gear: addUint256

| Method | Type |
| ---------- | ---------- |
| `addUint256` | `(val: string or bigint or BN) => this` |

#### :gear: asBigInt

Returns bytes as single bigint value

| Method | Type |
| ---------- | ---------- |
| `asBigInt` | `() => bigint` |

#### :gear: asHex

Returns hex string

| Method | Type |
| ---------- | ---------- |
| `asHex` | `(prefixed?: boolean) => string` |

Parameters:

* `prefixed`: should be string prefixed with 0x or not, true by default



<!-- TSDOC_END -->
