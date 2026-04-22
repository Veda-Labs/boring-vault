import abi from 'ethereumjs-abi'
import { keccak256 } from 'js-sha3'

import AbstractType from './AbstractType'
import Type from './Type'
import { validate as validatePrimitive, isArrayType, isPrimitiveType, getElementaryType, isNotStructureType } from './primitives'

// The set of properties that a EIP712Domain MAY implement
export const EIP712DomainProperties = [
  { name: "name", type: "string" },
  { name: "version", type: "string" },
  { name: "chainId", type: "uint256" },
  { name: "verifyingContract", type: "address" },
  { name: "salt", type: "bytes32" },
]

/**
 * A constructor/factory function which constructs EIP712 Domains as types,
 * then returns a new instance of the domain. Since an instantiated EIP712 
 * Domain needs to share many static methods with the types it contains
 * (e.g. encodeType, typeHash), but does not require that all properties
 * are present in a given instance, we define a new prototype for each Domain
 * which specifies the provided properties as its type definition, and then
 * instantiates that prototype with the provided values.
 * @param   {Object} def   The definition of the EIP712 domain
 * @returns {Object}       An instantiated EIP712Domain type with the specified properties
 */
export default function EIP712Domain(def) {
  const vals = {}
  // Extract the EIP712 domain properties that were provided
  const properties = EIP712DomainProperties.reduce((props, {name, type}) => {
    // Skip unused EIP712 types
    if (!(name in def)) return props
    // Validate primitive types
    vals[name] = validatePrimitive[type](def[name])
    // Include property in type definition
    return [...props, {name, type}]
  }, [])

  // Throw an error if extra properties were provided
  if (Object.keys(vals).length !== Object.keys(def).length) {
    throw new Error('Extra key in EIP712Domain definition')
  } else if (Object.keys(def).length === 0) {
    throw new Error('Must supply at least one EIP712Domain property')
  }

  /**
   * @classdesc
   * A domain is a scope in which we can define multiple Types which can
   * reference each other. A domain behaves similarly to a Type, with the 
   * primary difference that it also includes a set of types that can 
   * reference each other within it.  The primary method of a 
   * domain is `createType()` which will return a new constructor
   * for a type that lives within this domain.
   */
  class Domain extends AbstractType {
    static name = 'EIP712Domain'
    static properties = properties
    static dependencies = []

    constructor(vals) {
      super()
      this.vals = { ...vals }

      // The types object maps String names to the type prototypes that exist
      // within this domain.  Prototypes are appendended to this.types for every
      // call to this.createType()
      this.types = {}

      // Precompute the domainSeparator for use with signing types in this domain
      this.domainSeparator = this.hashStruct()
    
      /**
       * Construct a new type that will be associated with this domain
       * @returns {Function}  the constructor for the new type class
       */
      this.createType = Type.bind(this)
    }

    /**
     * Validate that a particular object conforms to a valid type definition in this domain, 
     * and return a standardized version of input value.  In particular, structure types will
     * be coerced to an instance of the corresponding structure class, array types will validate
     * each item according to the base type of the array, and primitive types will be validated
     * by the appropriate validator in `validatePrimitive`
     *
     * @param   {String}  type  the string name of the type of the value being validated
     * @param   {Any}     val   the candidate value of the type to be validated/standardized
     * @returns {Any}           the standardized/validated representation of this
     * 
     * @throws  {Error} if the input is an invalid instance of the given type
     */
    validate(type, val) {
      if (isArrayType(type)) {
        // Apply the validator to each item in an array, using the base type
        return val.map(item => this.validate(getElementaryType(type), item))
      } else if (isPrimitiveType(type)) {
        return validatePrimitive[type](val)
      } else if (type in this.types) {
        const StructType = this.types[type]
        return (val instanceof StructType) ? val : new StructType(val)
      } else {
        throw new Error(`Type ${type} not recognized in this domain`)
      }
    }

    /**
     * Recursively expand an object containing instances of structure type classes,
     * and return a bare javascript object with the same hierarchical structure
     * Conceptually the opposite of @see this.validate
     * @param   {String}  type the string name of the type of value being serialized
     * @param   {Any}     val  the type instance or primitive literal being serialized
     * @returns {Object}
     * @throws  {Error}
     */
    serialize(type, val) {
      if (type in this.types) {
        // Recursively expand nested structure types
        return val.toObject()
      } else if (isArrayType(type)) {
        // Map serializer to array types
        return val.map(item => this.serialize(getElementaryType(type), item))
      } else if (isPrimitiveType(type)) {
        return val
      } else {
        throw new Error(`Type ${type} is not a valid type in this domain`)
      }
    }

    /**
     * Return an object mapping the names of types contained by this domain
     * to their list-style type definitions
     * @returns {Object}  Mapping from type name -> type definition
     */
    listTypes() {
      return Object.keys(this.types)
        .reduce((obj, t) => ({...obj, [t]: this.types[t].typeDef()}), {})
    }

    /**
     * Concatenate the type definition for this domain, with 
     * the definition of all the types that it contains
     * @returns {Object} 
     */
    toDomainDef() {
      return {
        [this.constructor.name]: this.constructor.typeDef(), 
        ...this.listTypes()
      }
    }

    /**
     * @override
     * A simplified encodeData function that only needs to handle string
     * and atomic types.  Still defers to abi.rawEncode.
     * @returns {String} encoding of the definition of this Domain
     */
    encodeData() {
      const types = this.constructor.properties.map(({type}) => 
        type === 'string' ? 'bytes32' : type)
      const values = this.constructor.properties.map(({name, type}) => 
        type === 'string' ? Buffer.from(keccak256(this.vals[name]), 'hex') : this.vals[name])

      return abi.rawEncode(
        ['bytes32', ...types], 
        [Buffer.from(this.constructor.typeHash(), 'hex'), ...values]
      )
    }

    /**
     * @override
     */
    toObject() {
      return {...this.vals}
    }
  }

  return new Domain(vals)
}

/**
 * Create a message object and domain from a raw signature request object. 
 * @param   {Object} request An object representing a signature request
 * @returns {Object} the constructed {domain} and {message} instances
 * @throws  {Error} if signature request contains cyclic dependencies
 */
EIP712Domain.fromSignatureRequest = function fromSignatureRequest(request) {
  const { types, message: rawMessage, primaryType, domain: rawDomain } = request

  // Create the domain instance
  const domain = new EIP712Domain(rawDomain)
  
  // Perform a (reverse) topological sort for dependency resolution, keeping track of depth first search postorder 
  const postorder = [] 
  // Keep track of already visited types, as well as potential cycles
  const marked = new Set(), cyclecheck = new Set()
  
  // Define recursive depth-first search with cycle detection
  const dfs = type => {
    for (const {type: subtype} of types[type]) {
      if (marked.has(subtype) || isNotStructureType(subtype)) continue
      if (cyclecheck.has(subtype)) {
        throw new Error('Cannot construct domain from signature request with cyclic dependencies')
      }
      cyclecheck.add(subtype)
      dfs(subtype)
    }
    postorder.push(type)
    marked.add(type)
  }

  // Perform the search
  for (const type of Object.keys(types)) {
    if (type !== 'EIP712Domain' && !marked.has(type)) { 
      dfs(type)
    }
  }

  // Create all necessary structure types in this domain
  // Iterate in postorder to guarantee dependencies are satisfied
  for (const name of postorder) {
    if (name !== 'EIP712Domain') {
      domain.createType(name, types[name])
    }
  }

  // Create the message instance
  const MessageType = domain.types[primaryType]
  const message = new MessageType(rawMessage)

  return { domain, message }
}

