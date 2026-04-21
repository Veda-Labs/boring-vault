"use strict";

var _interopRequireDefault = require("@babel/runtime/helpers/interopRequireDefault");

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;

var _classCallCheck2 = _interopRequireDefault(require("@babel/runtime/helpers/classCallCheck"));

var _createClass2 = _interopRequireDefault(require("@babel/runtime/helpers/createClass"));

var _defineProperty2 = _interopRequireDefault(require("@babel/runtime/helpers/defineProperty"));

var _jsSha = require("js-sha3");

/**
  * @classdesc
  * This is the abstract base class which represents all nonprimitive types in
  * the EIP712 scheme.  Both domains and proper Struct types inherit from this
  * class, as the static encoding functionality is required by each.
  */
var AbstractType =
/*#__PURE__*/
function () {
  function AbstractType() {
    (0, _classCallCheck2.default)(this, AbstractType);
  }

  (0, _createClass2.default)(AbstractType, [{
    key: "hashStruct",

    /**
     * Calculate the EIP712 hash for this object according to the specification
     * @returns {String} the keccak256 hash of the concatenation of the typeHash,
     *                   and the encoded data of this instance
     */
    value: function hashStruct() {
      return Buffer.from((0, _jsSha.keccak256)(this.encodeData()), 'hex');
    }
    /********************************************************************
     * Instance methods which should be overridden by subclasses
     *******************************************************************/

    /** @abstract */

  }, {
    key: "encodeData",
    value: function encodeData() {
      throw new Error('This is an abstract class, Subclasses of AbstractType should override encodeData()');
    }
    /** @abstract */

  }, {
    key: "toObject",
    value: function toObject() {
      throw new Error('This is an abstract class, Subclasses of AbstractType should override toObject()');
    }
  }], [{
    key: "encodeTypeFragment",

    /**
      * @static @private
      * Gather the type definition as a single string, without including 
      * definitions of dependent types
      * @returns {String} 
      */
    value: function encodeTypeFragment() {
      return "".concat(this.name, "(").concat(this.properties.map(function (_ref) {
        var name = _ref.name,
            type = _ref.type;
        return "".concat(type, " ").concat(name);
      }).join(','), ")");
    }
    /**
     * @static @abstract @private
     * Return the encoding of all types upon which this type depends. Only implemented
     * by types that support dependencies, i.e. structure types (not Domain types)
     */

  }, {
    key: "encodeDependentTypes",
    value: function encodeDependentTypes() {
      return '';
    }
    /**
      * @static
      * Gather the type definition into a single string
      * @returns {String} The full encoding of the type, including all dependent types (if applicable)
      */

  }, {
    key: "encodeType",
    value: function encodeType() {
      return "".concat(this.encodeTypeFragment()).concat(this.encodeDependentTypes());
    }
    /**
      * @static
      * Calculate the keccak256 hash of the abi encoding of this type according
      * to the EIP712 specification
      * @returns {String} the typeHash of this type
      */

  }, {
    key: "typeHash",
    value: function typeHash() {
      return Buffer.from((0, _jsSha.keccak256)(this.encodeType()), 'hex');
    }
    /**
      * @static
      * Return a list of {name, type} pairs that define this type as a new object 
      * @returns {Object[]}
      */

  }, {
    key: "typeDef",
    value: function typeDef() {
      // Use map to deep copy the properties array
      return this.properties.map(function (_ref2) {
        var name = _ref2.name,
            type = _ref2.type;
        return {
          name: name,
          type: type
        };
      });
    }
  }]);
  return AbstractType;
}();

exports.default = AbstractType;
(0, _defineProperty2.default)(AbstractType, "name", void 0);
(0, _defineProperty2.default)(AbstractType, "properties", void 0);