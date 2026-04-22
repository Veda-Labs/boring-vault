"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.isArrayType = isArrayType;
exports.getElementaryType = getElementaryType;
exports.isAtomicType = isAtomicType;
exports.isDynamicType = isDynamicType;
exports.isPrimitiveType = isPrimitiveType;
exports.isNotStructureType = isNotStructureType;
exports.validate = exports.DYNAMICS = exports.ATOMICS = void 0;
var ATOMICS = ['bytes1', 'bytes2', 'bytes4', 'bytes8', 'bytes16', 'bytes32', 'uint8', 'uint16', 'uint32', 'uint64', 'uint128', 'uint256', 'int8', 'int16', 'int32', 'int64', 'int128', 'int256', 'address', 'bool'];
exports.ATOMICS = ATOMICS;
var DYNAMICS = ['string', 'bytes'];
/**
 * Return true if the argument is an array type
 * @param   {String}  type 
 * @returns {Boolean} 
 */

exports.DYNAMICS = DYNAMICS;

function isArrayType(type) {
  return type.length > 2 && type.slice(-2) === '[]';
}
/**
 * Return the type
 * @param   {String} type 
 * @returns {String} 
 */


function getElementaryType(type) {
  if (isArrayType(type)) return type.slice(0, -2);
  throw new Error("Can't get element of non-array type");
}
/**
 * Return true if the argument is an atomic type in the EIP712 schema
 * @param {String} type 
 * @returns {Boolean}
 */


function isAtomicType(type) {
  return ATOMICS.includes(type);
}
/**
 * Return true if the argument is the name of a dynamic type in the EIP712 schema
 * @param {String} type 
 * @returns {Boolean}
 */


function isDynamicType(type) {
  return DYNAMICS.includes(type);
}
/**
 * Determine if the argument is a EIP712 primitive type, i.e. a dynamic or atomic type
 * @param {String} type 
 * @returns {Boolean}
 */


function isPrimitiveType(type) {
  return isAtomicType(type) || isDynamicType(type);
}
/**
 * Determine if the argument is not a structure type, i.e. it is a primitive type or an
 * arbitrarily nested array of structure types
 * @param {String} type
 * @returns {Boolean}
 */


function isNotStructureType(type) {
  if (isPrimitiveType(type)) return true;
  if (isArrayType(type)) return isNotStructureType(getElementaryType(type));
  return false;
} // /**
//  * Validation utility function to switch on javascript types and
//  * handle each with a custom function
//  * @param   {Object}    handlers  An object mapping javascript types to a validation function for that type
//  * @returns {Function}  a validation function which will delegate to one of the provided validators
//  *                      according to the type of the input
//  */
// function handleByType(target, handlers) {
//   return input => {
//     const jstype = typeof input
//     if (jstype in handlers) return handlers[jstype](input)
//     throw new Error(`Cannot convert javascript type ${jstype} to solidity type ${target}`)
//   }
// }
// /**
//  * Throw an error with a given message. This is convenient for throwing
//  * an error inside an expression without having to create a full function.
//  * @param {String} message message for the error to be thrown
//  */
// function reject(message) {
//   throw new Error(message)
// }

/**
 * Validation functions for unifying javascript representations of solidity types
 */


var validate = {
  bytes1: function bytes1(x) {
    return x;
  },
  bytes2: function bytes2(x) {
    return x;
  },
  bytes4: function bytes4(x) {
    return x;
  },
  bytes8: function bytes8(x) {
    return x;
  },
  bytes16: function bytes16(x) {
    return x;
  },
  bytes32: function bytes32(x) {
    return x;
  },
  uint8: function uint8(x) {
    return x;
  },
  uint16: function uint16(x) {
    return x;
  },
  uint32: function uint32(x) {
    return x;
  },
  uint64: function uint64(x) {
    return x;
  },
  uint128: function uint128(x) {
    return x;
  },
  uint256: function uint256(x) {
    return x;
  },
  int8: function int8(x) {
    return x;
  },
  int16: function int16(x) {
    return x;
  },
  int32: function int32(x) {
    return x;
  },
  int64: function int64(x) {
    return x;
  },
  int128: function int128(x) {
    return x;
  },
  int256: function int256(x) {
    return x;
  },
  address: function address(x) {
    return x;
  },
  // approach for type mapping
  // address: handleByType('address', {
  //   string: x => x.slice(2) === '0x' ? x : `0x${x}`,
  //   object: x => x instanceof Buffer ? `0x${x.toString('hex')}` : reject('Cannot coerce object to address: must be string or Buffer')
  // }),
  bool: function bool(x) {
    return x;
  },
  string: function string(x) {
    return x;
  },
  bytes: function bytes(x) {
    return Buffer.from(x);
  }
};
exports.validate = validate;