## :factory: LimitOrderContract

### Methods

- [getFillOrderCalldata](#gear-getfillordercalldata)
- [getFillContractOrderCalldata](#gear-getfillcontractordercalldata)
- [getFillOrderArgsCalldata](#gear-getfillorderargscalldata)
- [getFillContractOrderArgsCalldata](#gear-getfillcontractorderargscalldata)

#### :gear: getFillOrderCalldata

Fill order WITHOUT an extension and taker interaction

| Method | Type |
| ---------- | ---------- |
| `getFillOrderCalldata` | `(order: LimitOrderV4Struct, signature: string, takerTraits: TakerTraits, amount: bigint) => string` |

#### :gear: getFillContractOrderCalldata

Fill contract order (order maker is smart-contract) WITHOUT an extension and taker interaction

| Method | Type |
| ---------- | ---------- |
| `getFillContractOrderCalldata` | `(order: LimitOrderV4Struct, signature: string, takerTraits: TakerTraits, amount: bigint) => string` |

#### :gear: getFillOrderArgsCalldata

Fill order WITH an extension or taker interaction

| Method | Type |
| ---------- | ---------- |
| `getFillOrderArgsCalldata` | `(order: LimitOrderV4Struct, signature: string, takerTraits: TakerTraits, amount: bigint) => string` |

#### :gear: getFillContractOrderArgsCalldata

Fill contract order (order maker is smart-contract) WITH an extension or taker interaction

| Method | Type |
| ---------- | ---------- |
| `getFillContractOrderArgsCalldata` | `(order: LimitOrderV4Struct, signature: string, takerTraits: TakerTraits, amount: bigint) => string` |
