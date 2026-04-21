# 1inch Limit Order Protocol v4 SDK

## Installation

```shell
npm install '@1inch/limit-order-sdk'
```

## Docs
- [Limit Order](./src/limit-order/README.md)
- [Limit Order Contract](./src/limit-order-contract/README.md)

## Usage examples

### Order creation
```typescript
import {LimitOrder, MakerTraits, Address, Sdk, randBigInt, FetchProviderConnector} from "@1inch/limit-order-sdk"
import {Wallet} from 'ethers'

// it is a well-known test private key, do not use it in production
const privKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'
const authKey = '...'
const maker = new Wallet(privKey)
const expiresIn = 120n // 2m
const expiration = BigInt(Math.floor(Date.now() / 1000)) + expiresIn

const UINT_40_MAX = (1n << 48n) - 1n

// see MakerTraits.ts
const makerTraits = MakerTraits.default()
  .withExpiration(expiration)
  .withNonce(randBigInt(UINT_40_MAX))

const sdk = new Sdk({ authKey, networkId: 1, httpConnector: new FetchProviderConnector() })

const order = await sdk.createOrder({
    makerAsset: new Address('0xdac17f958d2ee523a2206206994597c13d831ec7'),
    takerAsset: new Address('0x111111111117dc0aa78b770fa6a738034120c302'),
    makingAmount: 100_000000n, // 100 USDT
    takingAmount: 10_00000000000000000n, // 10 1INCH
    maker: new Address(maker.address),
    // salt? : bigint
    // receiver? : Address
}, makerTraits)

const typedData = order.getTypedData()
const signature = await maker.signTypedData(
    typedData.domain,
    {Order: typedData.types.Order},
    typedData.message
)

await sdk.submitOrder(order, signature)
```


### RFQ Order creation

`RfqOrder` is a light, gas efficient version of LimitOrder, but it does not support multiple fills and extension
Mainly used by market makers

```typescript
import {RfqOrder, Address, randBigInt} from "@1inch/limit-order-sdk"
import {UINT_40_MAX} from "@1inch/byte-utils"
import {Wallet} from 'ethers'

// it is a well-known test private key, do not use it in production
const privKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'

const maker = new Wallet(privKey)
const expiresIn = 120n // 2m
const expiration = BigInt(Math.floor(Date.now() / 1000)) + expiresIn

const order = new RfqOrder({
    makerAsset: new Address('0xdac17f958d2ee523a2206206994597c13d831ec7'),
    takerAsset: new Address('0x111111111117dc0aa78b770fa6a738034120c302'),
    makingAmount: 100_000000n, // 100 USDT
    takingAmount: 10_00000000000000000n, // 10 1INCH
    maker: new Address(maker.address)
}, {
    allowedSender: new Address('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'),
    expiration,
    nonce: randBigInt(UINT_40_MAX),
})

const typedData = order.getTypedData()
const signature = await maker.signTypedData(
    typedData.domain,
    {Order: typedData.types.Order},
    typedData.message
)
```

### Order filling

To execute a limit order, you need to build the appropriate calldata using the `LimitOrderContract` class. There are different methods depending on whether the order has extensions/interactions and whether the maker is an EOA or smart contract.

```typescript
import {LimitOrderContract, TakerTraits, LimitOrder} from '@1inch/limit-order-sdk'

// Assume you already have a FusionOrder in `order` variable
const order = ... // your LimitOrder instance
const signature = '0x...' // order signature
const amount = 100_000000n // amount to fill (in taker or maker asset units, based on set `AmountMode`)

// Create taker traits
const takerTraits = TakerTraits.default()
    // Optional: Configure taker preferences
    // .setAmountMode(AmountMode.TakerAmount) // or MakerAmount
    // .enableNativeUnwrap() // for WETH -> ETH conversion
    // .setAmountThreshold(minAmount) // minimum/maximum acceptable amount (based on set `AmountMode`)

// Build calldata for different scenarios:

// 1. Simple order fill (no extensions, no interactions)
const simpleCalldata = LimitOrderContract.getFillOrderCalldata(
    order.build(), // converts to LimitOrderV4Struct
    signature,
    takerTraits,
    amount
)

// 2. Fill contract order (when maker is a smart contract)
const contractCalldata = LimitOrderContract.getFillContractOrderCalldata(
    order.build(),
    signature,
    takerTraits,
    amount
)

// 3. Order with extensions or taker interactions
const extension = '0x...' // extension calldata
const interaction = '0x...' // taker interaction calldata

const takerTraitsWithArgs = TakerTraits.default()
    .setExtension(extension)
    .setInteraction(interaction)
    // .setReceiver(receiverAddress) // optional: custom receiver

const argsCalldata = LimitOrderContract.getFillOrderArgsCalldata(
    order.build(),
    signature,
    takerTraitsWithArgs,
    amount
)

// 4. Contract order with extensions/interactions
const contractArgsCalldata = LimitOrderContract.getFillContractOrderArgsCalldata(
    order.build(),
    signature,
    takerTraitsWithArgs,
    amount
)
```

The calldata should be sent to the 1inch Limit Order Protocol contract addresses can be found at [docs](https://portal.1inch.dev/documentation/contracts/aggregation-protocol/aggregation-introduction#:~:text=0x111111111117dC0aa78b770fA6A738034120C302-,Aggregation%20Router%20v6,-Name)

#### Taker Traits Configuration

`TakerTraits` allows you to configure various execution parameters:

```typescript
import {TakerTraits, AmountMode, Address} from '@1inch/limit-order-sdk'

const takerTraits = TakerTraits.default()
    // Set amount calculation mode
    .setAmountMode(AmountMode.MakerAmount) // fill by maker amount
    // or
    // .setAmountMode(AmountMode.TakerAmount) // fill by taker amount (default)

    // Enable WETH unwrapping to ETH
    .enableNativeUnwrap()

    // Skip order permit (if not needed)
    .skipOrderPermit()

    // Enable Permit2
    .enablePermit2()

    // Set amount threshold
    .setAmountThreshold(1000000n)

    // Set custom receiver for maker assets
    .setReceiver(new Address('0x...'))

    // Add extension calldata (for order extensions)
    .setExtension('0x...')

    // Add taker interaction calldata
    .setInteraction('0x...')
```

#### Choosing the Right Fill Method

| Method | Use When |
|--------|----------|
| `getFillOrderCalldata` | EOA maker, no extensions/interactions |
| `getFillContractOrderCalldata` | Smart contract maker, no extensions/interactions |
| `getFillOrderArgsCalldata` | EOA maker, with extensions/interactions |
| `getFillContractOrderArgsCalldata` | Smart contract maker, with extensions/interactions |



### API

```typescript
import {Api, FetchProviderConnector, LimitOrder, HttpProviderConnector} from '@1inch/limit-order-sdk'

const networkId = 1 // ethereum
const api = new Api({
    networkId,
    authKey: 'key', // get it at https://portal.1inch.dev/
    httpConnector: new FetchProviderConnector() // or use any connector which implements `HttpProviderConnector`
})

// submit order
const order = ... /// see `Order creation` section
const signature = '0x'
await api.submitOrder(order, signature)

// get order by hash
const orderHash = order.getOrderHash(networkId)
const orderInfo = await api.getOrderByHash(orderHash)

// get orders by maker with cursor pagination
import { CursorPager } from '@1inch/limit-order-sdk'

// First page - no cursor needed
const firstPager = new CursorPager({ limit: 10 })
const response = await api.getOrdersByMaker(order.maker, {
    pager: firstPager,
    statuses: [1] // only valid orders
})

const orders = response.items
const { hasMore, nextCursor, count } = response.meta

// Get next page if available
if (hasMore && nextCursor) {
    const nextPager = new CursorPager({ limit: 10, cursor: nextCursor })
    const nextPage = await api.getOrdersByMaker(order.maker, {
        pager: nextPager,
        statuses: [1]
    })
}

// Or use without explicit pager (defaults to limit: 100, no cursor)
const makerOrders = await api.getOrdersByMaker(order.maker, {
    statuses: [1]
})

// get all orders from orderbook with pagination
const allOrdersPager = new CursorPager({ limit: 20 })
const allOrdersResponse = await api.getAllOrders({
    pager: allOrdersPager,
    statuses: [1, 2] // valid and temporarily invalid orders
})

// pagination works the same way
if (allOrdersResponse.meta.hasMore && allOrdersResponse.meta.nextCursor) {
    const nextAllOrders = await api.getAllOrders({
        pager: new CursorPager({ 
            limit: 20, 
            cursor: allOrdersResponse.meta.nextCursor 
        })
    })
}
```

#### With `axios` as http provider

`axios` package should be installed

```typescript
import {Api, LimitOrder} from "@1inch/limit-order-sdk"
import {AxiosProviderConnector} from '@1inch/limit-order-sdk/axios'

const api = new Api({
    networkId: 1, // ethereum
    authKey: 'key', // get it at https://portal.1inch.dev/
    httpConnector: new AxiosProviderConnector()
})
```

##  Testing

### Unit tests

Install dependencies
```shell
pnpm install
```

Run tests
```shell
pnpm test
```

### Integration tests
Integration tests are inside [tests](./tests) folder.
They use [foundry](https://book.getfoundry.sh/) fork node and execute transaction on it.

Install dependencies
```shell
pnpm install && forge install
```

Run tests
```shell
pnpm test:integration
```
