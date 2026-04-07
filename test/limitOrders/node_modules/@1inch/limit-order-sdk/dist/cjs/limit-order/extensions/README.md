## :factory: Extension

### Methods

- [decode](#gear-decode)
- [default](#gear-default)
- [keccak256](#gear-keccak256)
- [isEmpty](#gear-isempty)
- [encode](#gear-encode)

#### :gear: decode

| Method | Type |
| ---------- | ---------- |
| `decode` | `(bytes: string) => Extension` |

#### :gear: default

| Method | Type |
| ---------- | ---------- |
| `default` | `() => Extension` |

#### :gear: keccak256

| Method | Type |
| ---------- | ---------- |
| `keccak256` | `() => bigint` |

#### :gear: isEmpty

| Method | Type |
| ---------- | ---------- |
| `isEmpty` | `() => boolean` |

#### :gear: encode

Hex string with 0x

| Method | Type |
| ---------- | ---------- |
| `encode` | `() => string` |

### Properties

- [EMPTY](#gear-empty)
- [makerAssetSuffix](#gear-makerassetsuffix)
- [takerAssetSuffix](#gear-takerassetsuffix)
- [makingAmountData](#gear-makingamountdata)
- [takingAmountData](#gear-takingamountdata)
- [predicate](#gear-predicate)
- [makerPermit](#gear-makerpermit)
- [preInteraction](#gear-preinteraction)
- [postInteraction](#gear-postinteraction)
- [customData](#gear-customdata)

#### :gear: EMPTY

| Property | Type |
| ---------- | ---------- |
| `EMPTY` | `{ makerAssetSuffix: string; takerAssetSuffix: string; makingAmountData: string; takingAmountData: string; predicate: string; makerPermit: string; preInteraction: string; postInteraction: string; customData: string; }` |

#### :gear: makerAssetSuffix

| Property | Type |
| ---------- | ---------- |
| `makerAssetSuffix` | `string` |

#### :gear: takerAssetSuffix

| Property | Type |
| ---------- | ---------- |
| `takerAssetSuffix` | `string` |

#### :gear: makingAmountData

| Property | Type |
| ---------- | ---------- |
| `makingAmountData` | `string` |

#### :gear: takingAmountData

| Property | Type |
| ---------- | ---------- |
| `takingAmountData` | `string` |

#### :gear: predicate

| Property | Type |
| ---------- | ---------- |
| `predicate` | `string` |

#### :gear: makerPermit

| Property | Type |
| ---------- | ---------- |
| `makerPermit` | `string` |

#### :gear: preInteraction

| Property | Type |
| ---------- | ---------- |
| `preInteraction` | `string` |

#### :gear: postInteraction

| Property | Type |
| ---------- | ---------- |
| `postInteraction` | `string` |

#### :gear: customData

| Property | Type |
| ---------- | ---------- |
| `customData` | `string` |

## :factory: ExtensionBuilder

### Methods

- [withMakerAssetSuffix](#gear-withmakerassetsuffix)
- [withTakerAssetSuffix](#gear-withtakerassetsuffix)
- [withMakingAmountData](#gear-withmakingamountdata)
- [withTakingAmountData](#gear-withtakingamountdata)
- [withPredicate](#gear-withpredicate)
- [withMakerPermit](#gear-withmakerpermit)
- [withPreInteraction](#gear-withpreinteraction)
- [withPostInteraction](#gear-withpostinteraction)
- [withCustomData](#gear-withcustomdata)
- [build](#gear-build)

#### :gear: withMakerAssetSuffix

| Method | Type |
| ---------- | ---------- |
| `withMakerAssetSuffix` | `(suffix: string) => this` |

#### :gear: withTakerAssetSuffix

| Method | Type |
| ---------- | ---------- |
| `withTakerAssetSuffix` | `(suffix: string) => this` |

#### :gear: withMakingAmountData

| Method | Type |
| ---------- | ---------- |
| `withMakingAmountData` | `(address: Address, data: string) => this` |

Parameters:

* `address`: Address of contract which will be called with `data` to calculate making amount


#### :gear: withTakingAmountData

| Method | Type |
| ---------- | ---------- |
| `withTakingAmountData` | `(address: Address, data: string) => this` |

Parameters:

* `address`: Address of contract which will be called with `data` to calculate taking amount


#### :gear: withPredicate

| Method | Type |
| ---------- | ---------- |
| `withPredicate` | `(predicate: string) => this` |

#### :gear: withMakerPermit

| Method | Type |
| ---------- | ---------- |
| `withMakerPermit` | `(tokenFrom: Address, permitData: string) => this` |

#### :gear: withPreInteraction

| Method | Type |
| ---------- | ---------- |
| `withPreInteraction` | `(interaction: Interaction) => this` |

#### :gear: withPostInteraction

| Method | Type |
| ---------- | ---------- |
| `withPostInteraction` | `(interaction: Interaction) => this` |

#### :gear: withCustomData

| Method | Type |
| ---------- | ---------- |
| `withCustomData` | `(data: string) => this` |

#### :gear: build

| Method | Type |
| ---------- | ---------- |
| `build` | `() => Extension` |
