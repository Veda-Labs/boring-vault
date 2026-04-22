import { keccak256 } from 'js-sha3'

/**
  * @classdesc
  * This is the abstract base class which represents all nonprimitive types in
  * the EIP712 scheme.  Both domains and proper Struct types inherit from this
  * class, as the static encoding functionality is required by each.
  */
export default class AbstractType {
  static name
  static properties

  /**
    * @static @private
    * Gather the type definition as a single string, without including 
    * definitions of dependent types
    * @returns {String} 
    */
  static encodeTypeFragment() {
    return `${this.name}(${this.properties.map(({name, type}) => `${type} ${name}`).join(',')})`
  }

  /**
   * @static @abstract @private
   * Return the encoding of all types upon which this type depends. Only implemented
   * by types that support dependencies, i.e. structure types (not Domain types)
   */
  static encodeDependentTypes() {
    return ''
  }

  /**
    * @static
    * Gather the type definition into a single string
    * @returns {String} The full encoding of the type, including all dependent types (if applicable)
    */
  static encodeType() {
    return `${this.encodeTypeFragment()}${this.encodeDependentTypes()}`
  }

  /**
    * @static
    * Calculate the keccak256 hash of the abi encoding of this type according
    * to the EIP712 specification
    * @returns {String} the typeHash of this type
    */
  static typeHash() {
    return Buffer.from(keccak256(this.encodeType()), 'hex')
  }

  /**
    * @static
    * Return a list of {name, type} pairs that define this type as a new object 
    * @returns {Object[]}
    */
  static typeDef() {
    // Use map to deep copy the properties array
    return this.properties.map(({name, type}) => ({name, type}))
  }

  /**
   * Calculate the EIP712 hash for this object according to the specification
   * @returns {String} the keccak256 hash of the concatenation of the typeHash,
   *                   and the encoded data of this instance
   */
  hashStruct() {
    return Buffer.from(keccak256(this.encodeData()), 'hex')
  }

  /********************************************************************
   * Instance methods which should be overridden by subclasses
   *******************************************************************/

  /** @abstract */
  encodeData() {
    throw new Error('This is an abstract class, Subclasses of AbstractType should override encodeData()')
  }

  /** @abstract */
  toObject() {
    throw new Error('This is an abstract class, Subclasses of AbstractType should override toObject()')
  }
}