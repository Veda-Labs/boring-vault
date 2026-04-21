# Typed Structured Data, On-Chain and Off
[![js-standard-style](https://img.shields.io/badge/code%20style-standard-brightgreen.svg)](http://standardjs.com)
[![Twitter Follow](https://img.shields.io/twitter/follow/uport_me.svg?style=social&label=Follow)](https://twitter.com/uport_me)

*Thanks for checking out EthTypedData!  This library is currently in beta, and we don't yet recommend using it in production applications -- please file an issue if you encounter any bugs or would like to request a feature!*

With the new [EIP712 specification](https://eips.ethereum.org/EIPS/eip-712) poised to be the new standard for representing data structures in the ethereum world, the uPort team has developed a convenient library to interact with types and domains as defined by the spec.  In particular, we've made it easy to manage domains with multiple different types, and provide convenient methods for encoding, hashing, and signing EIP712 typed data structures, as well as for converting objects to signature requests for use with `eth_signTypedData`.

## Creating a Domain
To use `eth-typed-data`, the first step is to create a domain.  Domains are special types that encode a particular application or use-case, and are used to distinguish between objects with the same structure but created for different applications.  In particular, this protects users by avoiding the possibility that a signature on one object in one application can be reused in a different application.

We create a domain as follows:
```javascript
import { EIP712Domain } from 'eth-typed-data'

const myDomain = new EIP712Domain({
  name: 'Ether Mail',               // Name of the domain
  version: '1',                     // Version identifier for this domain
  chainId: 1,                       // EIP-155 Chain id associated with this domain (1 for mainnet)
  verifyingContract: '0xdeadbeef',  // Address of smart contract associated with this domain
  salt: 'rAnD0mstr1ng'              // Random string to differentiate domain, just in case
})
```
The EIP712 Spec requires that a domain define **at least one** of the above properties, though to best protect against domain conflicts, we recommend that you define **all** of them.

## Defining Structure Types

The domain has the ability to define new struct types (modeled after Solidity `struct`s) that can be used within it using the `createType()` method.  Structure types contain properties, each with their own `name` and `type`.  The `type` of each property can be one of the EIP712 [primitive types](#primitives) or another structure type already defined in the current domain.  Note that `createType` will throw an error if a referenced structure type is not yet defined in the current domain.

To create a new Structure type in a domain, call `createType` with a list of objects `{name, type}`, giving the string name and string type name for each property of the new Structure type.  

```javascript
const Person = myDomain.createType('Person', [
  { name: 'name', type: 'string' },
  { name: 'wallet', type: 'address'}
])
const Mail = myDomain.createType('Mail', [
  {name: 'to', type: 'Person'},
  {name: 'from', type: 'Person'},
  {name: 'contents', type: 'string'}
])
```
Alternatively, and object mapping string names to string types can be used in the same way. 
```javascript
const Person = myDomain.createType('Person', {
  name: 'string',
  wallet: 'address'
})
const Mail = myDomain.createType('Mail', {
  to: 'Person',
  from: 'Person',
  contents: 'string'
})
```

## Creating Type Instances
The value returned from `myDomain.createType` is a *constructor*, which may be instantiated arbitrarily many times.  You can create an instance of a structure type in the same way you create a domain, by passing an object with a value for each property of the type.  In contrast to a domain, Structure types require a value for every property in their definition, and will raise an error if any property is `undefined`.

```javascript
// Create two new `Person`s, alice and bob
let alice = new Person({
  name: 'Alice',
  wallet: '0xCcccCcCCCCccccccCCCcCccCcCCCccCCcCcCCCCc',
})
let bob = new Person({
  name: 'Bob',
  wallet: '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB'
})
// Create a piece of mail between alice and bob
let letter = new Mail({
  from: alice,
  to: bob,
  contents: 'Woah, a well-formed piece of structured data that I can sign and verify on-chain!'
})
```

In addition to validating that each property is given a value, the type constructors also validate that the provided value is allowable for that property's `type`.  Each [primitive type](#primitive) has its own validation function, and each structure type has a recursive static `validate` method, which checks the validity of each of its properties.  With this in mind, we can also define a piece of Mail with a single object:

```javascript
// Create a piece of mail from alice to bob, without explicitly creating alice or bob
let explicitLetter = new Mail({
  from: {
    name: 'Alice',
    wallet: '0xaaAAaaaAaaAAAAaaaaaAaaAAAaAAAAAAAaaAaaAA'
  },
  to: {
    name: 'Bob',
    wallet: '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB'
  },
  contents: 'Look! Another message!'
})
```

If you attempt to construct a type with an invalid value for any property, you will get an error.

```javascript
// ERROR
let badletter = new Mail({
  from: alice,
  to: 'bob', // Invalid value for type `Person`!
  contents: 'A malformed message'
})
// ERROR
let badperson = new Person({
  name: 'Bad',
  wallet: 25 // Invalid value for type `address`
})
```

## Encoding, Hashing, and Signing
Once you've created a type, there are a number of methods available to encode, hash, and sign your data.  Each type class has static methods for generating the abi encoding according to the EIP712 spec, and returning the `typeHash`, which is simply the `keccak256` hash of the abi encoding.

```javascript
> Person.encodeType()
'Person(string name,address wallet)'
> Person.typeHash()
'b9d8c78acf9b987311de6c7b45bb6a9c8e1bf361fa7fd3467a2163f994c79500'
> Mail.encodeType()
'Mail(Person from,Person to,string contents)Person(string name,address wallet)'
> Mail.typeHash()
'a0cedeb2dc280ba39b857546d74f5549c3a1d7bdc2dd96bf881f76108e23dac2'
```

Instances of a type represent actual data that can be signed along with the hash of the type.  To convert a type instance to a signature request for use with `eth_signTypedData`, call the `toSignatureRequest()` method.  This will encode the domain, types, primaryType, and message, in preparation to be signed.

```javascript
> letter.toSignatureRequest()
{
  types: {
    EIP712Domain: [
      { name: 'name', type: 'string' },
      { name: 'version', type: 'string' },
      { name: 'chainId', type: 'uint256' },
      { name: 'verifyingContract', type: 'address' },
      { name: 'salt', type: 'string' }
    ],
    Person: [
      { name: 'name', type: 'string' },
      { name: 'wallet', type: 'address' }
    ],
    Mail: [
      { name: 'from', type: 'Person' },
      { name: 'to', type: 'Person' },
      { name: 'contents', type: 'string' }
    ],
  },
  primaryType: 'Mail',
  domain: {
    name: 'Ether Mail',
    version: '1',
    chainId: 1,
    verifyingContract: '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
    salt: 'rAnD0mstr1ng'
  },
  message: {
    from: {
      name: 'Alice',
      wallet: '0xaaAAaaaAaaAAAAaaaaaAaaAAAaAAAAAAAaaAaaAA'
    },
    to: {
      name: 'Bob',
      wallet: '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB'
    },
    contents: 'Woah, a well-formed piece of structured data that I can sign and verify on-chain!',
  },
}
```

To do the signing off chain in javascript, you can encode a structures type and data using the `hashStruct` instance method.  This will return the `keccak256` hash of the concatenation of the `typeHash` and the abi encoded data according to the EIP712 spec, which we will not repeat here.  The abi encoding of the data alone can be calculated with the `encodeData()` instance method.  Finally, the `encode()` method prefixes the `hashStruct` with `\x19\x01` and the `domainSeparator`, equivalent to the `hashStruct` of the current domain.  This can be be used to properly encode the data for signing elsewhere, or you can simply pass a signer to the `sign()` method, for example the `SimpleSigner` from `did-jwt`

```javascript
import { SimpleSigner } from 'did-jwt'

const signer = new SimpleSigner(process.env.PRIVATE_KEY)
const signature = letter.sign(signer)
```

## <a name="primitives"></a> Primitive Types
The primitive types in the EIP712 spec are divided into two categories: 
1) Atomic types, with a fixed size in bytes, and well-defined encoding
  - `bytes1`, `bytes2`, `bytes4`, `bytes8`, `bytes16`, `bytes32`, `uint8`, `uint16`, `uint32`, `uint64`, `uint128`, `uint256`, `int8`, `int16`, `int32`, `int64`, `int128`, `int256`, `address`, `bool`
2) Dynamic types, with variable length, and a hash-based encoding
  - `bytes`, `string`

**TODO: Table defining each type and equivalent/compatible javascript type and validation**

