## :toolbox: Functions

- [calcTakingAmount](#gear-calctakingamount)
- [calcMakingAmount](#gear-calcmakingamount)

### :gear: calcTakingAmount

Calculates taker amount by linear proportion

| Function | Type |
| ---------- | ---------- |
| `calcTakingAmount` | `(swapMakerAmount: bigint, orderMakerAmount: bigint, orderTakerAmount: bigint) => bigint` |

### :gear: calcMakingAmount

Calculates maker amount by linear proportion

| Function | Type |
| ---------- | ---------- |
| `calcMakingAmount` | `(swapTakerAmount: bigint, orderMakerAmount: bigint, orderTakerAmount: bigint) => bigint` |


## :factory: MakerTraits

The MakerTraits type is an uint256, and different parts of the number are used to encode different traits.
High bits are used for flags
255 bit `NO_PARTIAL_FILLS_FLAG`          - if set, the order does not allow partial fills
254 bit `ALLOW_MULTIPLE_FILLS_FLAG`      - if set, the order permits multiple fills
253 bit                                  - unused
252 bit `PRE_INTERACTION_CALL_FLAG`      - if set, the order requires pre-interaction call
251 bit `POST_INTERACTION_CALL_FLAG`     - if set, the order requires post-interaction call
250 bit `NEED_CHECK_EPOCH_MANAGER_FLAG`  - if set, the order requires to check the epoch manager
249 bit `HAS_EXTENSION_FLAG`             - if set, the order has extension(s)
248 bit `USE_PERMIT2_FLAG`               - if set, the order uses permit2
247 bit `UNWRAP_WETH_FLAG`               - if set, the order requires to unwrap WETH

Low 200 bits are used for allowed sender, expiration, nonceOrEpoch, and series
uint80 last 10 bytes of allowed sender address (0 if any)
uint40 expiration timestamp (0 if none)
uint40 nonce or epoch
uint40 series

### Methods

- [default](#gear-default)
- [allowedSender](#gear-allowedsender)
- [isPrivate](#gear-isprivate)
- [withAllowedSender](#gear-withallowedsender)
- [withAnySender](#gear-withanysender)
- [expiration](#gear-expiration)
- [withExpiration](#gear-withexpiration)
- [nonceOrEpoch](#gear-nonceorepoch)
- [withNonce](#gear-withnonce)
- [withEpoch](#gear-withepoch)
- [series](#gear-series)
- [hasExtension](#gear-hasextension)
- [withExtension](#gear-withextension)
- [isPartialFillAllowed](#gear-ispartialfillallowed)
- [disablePartialFills](#gear-disablepartialfills)
- [allowPartialFills](#gear-allowpartialfills)
- [setPartialFills](#gear-setpartialfills)
- [isMultipleFillsAllowed](#gear-ismultiplefillsallowed)
- [allowMultipleFills](#gear-allowmultiplefills)
- [disableMultipleFills](#gear-disablemultiplefills)
- [setMultipleFills](#gear-setmultiplefills)
- [hasPreInteraction](#gear-haspreinteraction)
- [enablePreInteraction](#gear-enablepreinteraction)
- [disablePreInteraction](#gear-disablepreinteraction)
- [hasPostInteraction](#gear-haspostinteraction)
- [enablePostInteraction](#gear-enablepostinteraction)
- [disablePostInteraction](#gear-disablepostinteraction)
- [isEpochManagerEnabled](#gear-isepochmanagerenabled)
- [isPermit2](#gear-ispermit2)
- [enablePermit2](#gear-enablepermit2)
- [disablePermit2](#gear-disablepermit2)
- [isNativeUnwrapEnabled](#gear-isnativeunwrapenabled)
- [enableNativeUnwrap](#gear-enablenativeunwrap)
- [disableNativeUnwrap](#gear-disablenativeunwrap)
- [asBigInt](#gear-asbigint)
- [isBitInvalidatorMode](#gear-isbitinvalidatormode)

#### :gear: default

| Method | Type |
| ---------- | ---------- |
| `default` | `() => MakerTraits` |

#### :gear: allowedSender

Last 10bytes of address

| Method | Type |
| ---------- | ---------- |
| `allowedSender` | `() => string` |

#### :gear: isPrivate

| Method | Type |
| ---------- | ---------- |
| `isPrivate` | `() => boolean` |

#### :gear: withAllowedSender

| Method | Type |
| ---------- | ---------- |
| `withAllowedSender` | `(sender: Address) => this` |

#### :gear: withAnySender

Removes `sender` check on contract

| Method | Type |
| ---------- | ---------- |
| `withAnySender` | `() => this` |

#### :gear: expiration

If null is return than order has no expiration

| Method | Type |
| ---------- | ---------- |
| `expiration` | `() => bigint or null` |

#### :gear: withExpiration

Set order expiration time

| Method | Type |
| ---------- | ---------- |
| `withExpiration` | `(expiration: bigint) => this` |

Parameters:

* `expiration`: expiration timestamp in sec


#### :gear: nonceOrEpoch

Returns epoch in case `isEpochManagerEnabled()` and nonce otherwise

| Method | Type |
| ---------- | ---------- |
| `nonceOrEpoch` | `() => bigint` |

#### :gear: withNonce

Set nonce
Note: nonce and epoch share the same field, so they cant be set together

| Method | Type |
| ---------- | ---------- |
| `withNonce` | `(nonce: bigint) => this` |

Parameters:

* `nonce`: must be less or equal to `uint40::max`


#### :gear: withEpoch

Enable epoch manager check

If set, the contract will check that order epoch equals to epoch on `SeriesEpochManager` contract
Note: epoch manager can be used only when `partialFills` AND `multipleFills` allowed
Note: nonce and epoch share the same field, so they cant be set together

| Method | Type |
| ---------- | ---------- |
| `withEpoch` | `(series: bigint, epoch: bigint) => this` |

Parameters:

* `series`: subgroup for epoch
* `epoch`: unique order id inside series


#### :gear: series

Get current series

| Method | Type |
| ---------- | ---------- |
| `series` | `() => bigint` |

#### :gear: hasExtension

Returns true if order has an extension and false otherwise

| Method | Type |
| ---------- | ---------- |
| `hasExtension` | `() => boolean` |

#### :gear: withExtension

Mark that order has an extension

| Method | Type |
| ---------- | ---------- |
| `withExtension` | `() => this` |

#### :gear: isPartialFillAllowed

Is partial fills allowed for order

| Method | Type |
| ---------- | ---------- |
| `isPartialFillAllowed` | `() => boolean` |

#### :gear: disablePartialFills

Disable partial fills for order

| Method | Type |
| ---------- | ---------- |
| `disablePartialFills` | `() => this` |

#### :gear: allowPartialFills

Allow partial fills for order

| Method | Type |
| ---------- | ---------- |
| `allowPartialFills` | `() => this` |

#### :gear: setPartialFills

Set partial fill flag to passed value

| Method | Type |
| ---------- | ---------- |
| `setPartialFills` | `(val: boolean) => this` |

#### :gear: isMultipleFillsAllowed

Returns true if order allowing more than one fill and false otherwise

| Method | Type |
| ---------- | ---------- |
| `isMultipleFillsAllowed` | `() => boolean` |

#### :gear: allowMultipleFills

Allow many fills for order

| Method | Type |
| ---------- | ---------- |
| `allowMultipleFills` | `() => this` |

#### :gear: disableMultipleFills

Allow at max 1 fill for order

| Method | Type |
| ---------- | ---------- |
| `disableMultipleFills` | `() => this` |

#### :gear: setMultipleFills

If `val` is true, then multiple fills allowed, otherwise disallowed

| Method | Type |
| ---------- | ---------- |
| `setMultipleFills` | `(val: boolean) => this` |

#### :gear: hasPreInteraction

Returns true if maker has pre-interaction and false otherwise

| Method | Type |
| ---------- | ---------- |
| `hasPreInteraction` | `() => boolean` |

#### :gear: enablePreInteraction

Enable maker pre-interaction

| Method | Type |
| ---------- | ---------- |
| `enablePreInteraction` | `() => this` |

#### :gear: disablePreInteraction

Disable maker pre-interaction

| Method | Type |
| ---------- | ---------- |
| `disablePreInteraction` | `() => this` |

#### :gear: hasPostInteraction

Returns true if maker has post-interaction and false otherwise

| Method | Type |
| ---------- | ---------- |
| `hasPostInteraction` | `() => boolean` |

#### :gear: enablePostInteraction

Enable maker post-interaction

| Method | Type |
| ---------- | ---------- |
| `enablePostInteraction` | `() => this` |

#### :gear: disablePostInteraction

Disable maker post-interaction

| Method | Type |
| ---------- | ---------- |
| `disablePostInteraction` | `() => this` |

#### :gear: isEpochManagerEnabled

Returns true if epoch manager enabled

| Method | Type |
| ---------- | ---------- |
| `isEpochManagerEnabled` | `() => boolean` |

#### :gear: isPermit2

Returns true if `permit2` enabled for maker funds transfer

| Method | Type |
| ---------- | ---------- |
| `isPermit2` | `() => boolean` |

#### :gear: enablePermit2

Use `permit2` to transfer maker funds to contract

| Method | Type |
| ---------- | ---------- |
| `enablePermit2` | `() => this` |

#### :gear: disablePermit2

Do not use `permit2` to transfer maker funds to contract

| Method | Type |
| ---------- | ---------- |
| `disablePermit2` | `() => this` |

#### :gear: isNativeUnwrapEnabled

Is WRAPPED token will be unwrapped to NATIVE before sending to maker

| Method | Type |
| ---------- | ---------- |
| `isNativeUnwrapEnabled` | `() => boolean` |

#### :gear: enableNativeUnwrap

Unwrap WRAPPED token to NATIVE before sending it to maker

| Method | Type |
| ---------- | ---------- |
| `enableNativeUnwrap` | `() => this` |

#### :gear: disableNativeUnwrap

Do not unwrap WRAPPED token to NATIVE before sending it to maker

| Method | Type |
| ---------- | ---------- |
| `disableNativeUnwrap` | `() => this` |

#### :gear: asBigInt

| Method | Type |
| ---------- | ---------- |
| `asBigInt` | `() => bigint` |

#### :gear: isBitInvalidatorMode

Returns true if bit invalidator mode is used to invalidate order (cancel/mark as filled)

Bit invalidator is cheaper in terms of gas, but can be used only when partial fills OR multiple fills are disabled

| Method | Type |
| ---------- | ---------- |
| `isBitInvalidatorMode` | `() => boolean` |

## :factory: LimitOrder

### Methods

- [buildSalt](#gear-buildsalt)
- [verifySalt](#gear-verifysalt)
- [fromCalldata](#gear-fromcalldata)
- [fromDataAndExtension](#gear-fromdataandextension)
- [toCalldata](#gear-tocalldata)
- [build](#gear-build)
- [getTypedData](#gear-gettypeddata)
- [getOrderHash](#gear-getorderhash)
- [isPrivate](#gear-isprivate)

#### :gear: buildSalt

Build correct salt for order

If order has extension - it is crucial to build correct salt
otherwise order won't be ever filled

| Method | Type |
| ---------- | ---------- |
| `buildSalt` | `(extension: Extension, baseSalt?: bigint) => bigint` |

#### :gear: verifySalt

| Method | Type |
| ---------- | ---------- |
| `verifySalt` | `(salt: bigint, extension: Extension) => bigint` |

#### :gear: fromCalldata

| Method | Type |
| ---------- | ---------- |
| `fromCalldata` | `(bytes: string) => LimitOrder` |

#### :gear: fromDataAndExtension

| Method | Type |
| ---------- | ---------- |
| `fromDataAndExtension` | `(data: LimitOrderV4Struct, extension: Extension) => LimitOrder` |

#### :gear: toCalldata

| Method | Type |
| ---------- | ---------- |
| `toCalldata` | `() => string` |

#### :gear: build

| Method | Type |
| ---------- | ---------- |
| `build` | `() => LimitOrderV4Struct` |

#### :gear: getTypedData

| Method | Type |
| ---------- | ---------- |
| `getTypedData` | `(chainId: number) => EIP712TypedData` |

#### :gear: getOrderHash

| Method | Type |
| ---------- | ---------- |
| `getOrderHash` | `(chainId: number) => string` |

#### :gear: isPrivate

Returns true if only a specific address can fill order

| Method | Type |
| ---------- | ---------- |
| `isPrivate` | `() => boolean` |

### Properties

- [salt](#gear-salt)
- [maker](#gear-maker)
- [receiver](#gear-receiver)
- [makerAsset](#gear-makerasset)
- [takerAsset](#gear-takerasset)
- [makingAmount](#gear-makingamount)
- [takingAmount](#gear-takingamount)
- [makerTraits](#gear-makertraits)

#### :gear: salt

| Property | Type |
| ---------- | ---------- |
| `salt` | `bigint` |

#### :gear: maker

| Property | Type |
| ---------- | ---------- |
| `maker` | `Address` |

#### :gear: receiver

| Property | Type |
| ---------- | ---------- |
| `receiver` | `Address` |

#### :gear: makerAsset

| Property | Type |
| ---------- | ---------- |
| `makerAsset` | `Address` |

#### :gear: takerAsset

| Property | Type |
| ---------- | ---------- |
| `takerAsset` | `Address` |

#### :gear: makingAmount

| Property | Type |
| ---------- | ---------- |
| `makingAmount` | `bigint` |

#### :gear: takingAmount

| Property | Type |
| ---------- | ---------- |
| `takingAmount` | `bigint` |

#### :gear: makerTraits

| Property | Type |
| ---------- | ---------- |
| `makerTraits` | `MakerTraits` |

## :factory: Interaction

### Methods

- [decode](#gear-decode)
- [encode](#gear-encode)

#### :gear: decode

Create `Interaction` from bytes

| Method | Type |
| ---------- | ---------- |
| `decode` | `(bytes: string) => Interaction` |

Parameters:

* `bytes`: Hex string with 0x. First 20 bytes are target, then data


#### :gear: encode

Hex string with 0x. First 20 bytes are target, then data

| Method | Type |
| ---------- | ---------- |
| `encode` | `() => string` |

## :factory: LimitOrderWithFee

### Methods

- [withRandomNonce](#gear-withrandomnonce)
- [fromDataAndExtension](#gear-fromdataandextension)
- [getTakingAmount](#gear-gettakingamount)
- [getMakingAmount](#gear-getmakingamount)
- [getResolverFee](#gear-getresolverfee)
- [getIntegratorFee](#gear-getintegratorfee)
- [getProtocolFee](#gear-getprotocolfee)

#### :gear: withRandomNonce

Set random nonce to `makerTraits` and creates `LimitOrderWithFee`

| Method | Type |
| ---------- | ---------- |
| `withRandomNonce` | `(orderInfo: Omit<OrderInfoData, "receiver">, feeExtension: FeeTakerExtension, makerTraits?: MakerTraits) => LimitOrderWithFee` |

#### :gear: fromDataAndExtension

| Method | Type |
| ---------- | ---------- |
| `fromDataAndExtension` | `(data: LimitOrderV4Struct, extension: Extension) => LimitOrderWithFee` |

#### :gear: getTakingAmount

Calculates the `takingAmount` required from the taker in exchange for the `makingAmount`

| Method | Type |
| ---------- | ---------- |
| `getTakingAmount` | `(taker: Address, makingAmount?: bigint) => bigint` |

Parameters:

* `makingAmount`: amount to be filled


#### :gear: getMakingAmount

Calculates the `makingAmount` that the taker receives in exchange for the `takingAmount`

| Method | Type |
| ---------- | ---------- |
| `getMakingAmount` | `(taker: Address, takingAmount?: bigint) => bigint` |

Parameters:

* `takingAmount`: amount to be filled


#### :gear: getResolverFee

Fee in `takerAsset` which resolver pays to resolver fee receiver

| Method | Type |
| ---------- | ---------- |
| `getResolverFee` | `(taker: Address, makingAmount?: bigint) => bigint` |

Parameters:

* `taker`: who will fill order
* `makingAmount`: amount wanted to fill


#### :gear: getIntegratorFee

Fee in `takerAsset` which integrator gets to integrator wallet

| Method | Type |
| ---------- | ---------- |
| `getIntegratorFee` | `(taker: Address, makingAmount?: bigint) => bigint` |

Parameters:

* `taker`: who will fill order
* `makingAmount`: amount wanted to fill


#### :gear: getProtocolFee

Fee in `takerAsset` which protocol gets
It equals to `share from integrator fee plus resolver fee`

| Method | Type |
| ---------- | ---------- |
| `getProtocolFee` | `(taker: Address, makingAmount?: bigint) => bigint` |

Parameters:

* `taker`: who will fill order
* `makingAmount`: amount wanted to fill


## :factory: TakerTraits

TakerTraitsLib
This class defines TakerTraits, which are used to encode the taker's preferences for an order in a single uint256.

The TakerTraits are structured as follows:
High bits are used for flags
255 bit `_MAKER_AMOUNT_FLAG`           - If set, the taking amount is calculated based on making amount, otherwise making amount is calculated based on taking amount.
254 bit `_UNWRAP_WETH_FLAG`            - If set, the WETH will be unwrapped into ETH before sending to taker.
253 bit `_SKIP_ORDER_PERMIT_FLAG`      - If set, the order skips maker's permit execution.
252 bit `_USE_PERMIT2_FLAG`            - If set, the order uses the permit2 function for authorization.
251 bit `_ARGS_HAS_TARGET`             - If set, then first 20 bytes of args are treated as receiver address for maker’s funds transfer.
224-247 bits `ARGS_EXTENSION_LENGTH`   - The length of the extension calldata in the args.
200-223 bits `ARGS_INTERACTION_LENGTH` - The length of the interaction calldata in the args.
0-184 bits                             - The threshold amount (the maximum amount a taker agrees to give in exchange for a making amount).

### Methods

- [default](#gear-default)
- [getAmountMode](#gear-getamountmode)
- [setAmountMode](#gear-setamountmode)
- [isNativeUnwrapEnabled](#gear-isnativeunwrapenabled)
- [enableNativeUnwrap](#gear-enablenativeunwrap)
- [disableNativeUnwrap](#gear-disablenativeunwrap)
- [isOrderPermitSkipped](#gear-isorderpermitskipped)
- [skipOrderPermit](#gear-skiporderpermit)
- [isPermit2Enabled](#gear-ispermit2enabled)
- [enablePermit2](#gear-enablepermit2)
- [disablePermit2](#gear-disablepermit2)
- [setReceiver](#gear-setreceiver)
- [removeReceiver](#gear-removereceiver)
- [setExtension](#gear-setextension)
- [removeExtension](#gear-removeextension)
- [setAmountThreshold](#gear-setamountthreshold)
- [getAmountThreshold](#gear-getamountthreshold)
- [removeAmountThreshold](#gear-removeamountthreshold)
- [setInteraction](#gear-setinteraction)
- [removeInteraction](#gear-removeinteraction)
- [encode](#gear-encode)

#### :gear: default

| Method | Type |
| ---------- | ---------- |
| `default` | `() => TakerTraits` |

#### :gear: getAmountMode

Returns enabled amount mode, it defines how to treat passed amount in `fillContractOrderArgs` function

| Method | Type |
| ---------- | ---------- |
| `getAmountMode` | `() => AmountMode` |

#### :gear: setAmountMode

| Method | Type |
| ---------- | ---------- |
| `setAmountMode` | `(mode: AmountMode) => this` |

#### :gear: isNativeUnwrapEnabled

Is the Wrapped native currency will be unwrapped into Native currency before sending to taker

| Method | Type |
| ---------- | ---------- |
| `isNativeUnwrapEnabled` | `() => boolean` |

#### :gear: enableNativeUnwrap

Wrapped native currency will be unwrapped into Native currency before sending to taker

| Method | Type |
| ---------- | ---------- |
| `enableNativeUnwrap` | `() => this` |

#### :gear: disableNativeUnwrap

Wrapped native currency will NOT be unwrapped into Native currency before sending to taker

| Method | Type |
| ---------- | ---------- |
| `disableNativeUnwrap` | `() => this` |

#### :gear: isOrderPermitSkipped

If true, then maker's permit execution is skipped

| Method | Type |
| ---------- | ---------- |
| `isOrderPermitSkipped` | `() => boolean` |

#### :gear: skipOrderPermit

The order skips maker's permit execution

| Method | Type |
| ---------- | ---------- |
| `skipOrderPermit` | `() => this` |

#### :gear: isPermit2Enabled

Should use permit2 function for authorization or not

| Method | Type |
| ---------- | ---------- |
| `isPermit2Enabled` | `() => boolean` |

#### :gear: enablePermit2

Use permit2 function for authorization

| Method | Type |
| ---------- | ---------- |
| `enablePermit2` | `() => this` |

#### :gear: disablePermit2

NOT use permit2 function for authorization

| Method | Type |
| ---------- | ---------- |
| `disablePermit2` | `() => this` |

#### :gear: setReceiver

Sets address where order filled to, `msg.sender` used if not set

| Method | Type |
| ---------- | ---------- |
| `setReceiver` | `(receiver: Address) => this` |

#### :gear: removeReceiver

Set order receiver as `msg.sender`

| Method | Type |
| ---------- | ---------- |
| `removeReceiver` | `() => this` |

#### :gear: setExtension

Sets extension, it is required to provide same extension as in order creation (if any)

| Method | Type |
| ---------- | ---------- |
| `setExtension` | `(ext: Extension) => this` |

#### :gear: removeExtension

| Method | Type |
| ---------- | ---------- |
| `removeExtension` | `() => this` |

#### :gear: setAmountThreshold

Set threshold amount

In taker amount mode: the minimum amount a taker agrees to receive in exchange for a taking amount.
In maker amount mode: the maximum amount a taker agrees to give in exchange for a making amount.

| Method | Type |
| ---------- | ---------- |
| `setAmountThreshold` | `(threshold: bigint) => this` |

#### :gear: getAmountThreshold

Get threshold amount

In taker amount mode: the minimum amount a taker agrees to receive in exchange for a taking amount.
In maker amount mode: the maximum amount a taker agrees to give in exchange for a making amount.

| Method | Type |
| ---------- | ---------- |
| `getAmountThreshold` | `() => bigint` |

#### :gear: removeAmountThreshold

| Method | Type |
| ---------- | ---------- |
| `removeAmountThreshold` | `() => this` |

#### :gear: setInteraction

Sets taker interaction

`interaction.target` should implement `ITakerInteraction` interface

| Method | Type |
| ---------- | ---------- |
| `setInteraction` | `(interaction: Interaction) => this` |

#### :gear: removeInteraction

| Method | Type |
| ---------- | ---------- |
| `removeInteraction` | `() => this` |

#### :gear: encode

| Method | Type |
| ---------- | ---------- |
| `encode` | `() => { trait: bigint; args: string; }` |

## :nut_and_bolt: Enum

- [AmountMode](#gear-amountmode)

### :gear: AmountMode



| Property | Type | Description |
| ---------- | ---------- | ---------- |
| `taker` | `` | Amount provided to fill function treated as `takingAmount` and `makingAmount` calculated based on it |
| `maker` | `` | Amount provided to fill function treated as `makingAmount` and `takingAmount` calculated based on it |

