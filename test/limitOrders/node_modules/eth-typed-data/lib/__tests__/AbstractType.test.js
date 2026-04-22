"use strict";

var _interopRequireDefault = require("@babel/runtime/helpers/interopRequireDefault");

var _classCallCheck2 = _interopRequireDefault(require("@babel/runtime/helpers/classCallCheck"));

var _createClass2 = _interopRequireDefault(require("@babel/runtime/helpers/createClass"));

var _possibleConstructorReturn2 = _interopRequireDefault(require("@babel/runtime/helpers/possibleConstructorReturn"));

var _getPrototypeOf2 = _interopRequireDefault(require("@babel/runtime/helpers/getPrototypeOf"));

var _inherits2 = _interopRequireDefault(require("@babel/runtime/helpers/inherits"));

var _defineProperty2 = _interopRequireDefault(require("@babel/runtime/helpers/defineProperty"));

var _AbstractType2 = _interopRequireDefault(require("../AbstractType"));

describe('AbstractType', function () {
  it('constructs', function () {
    expect(function () {
      return new _AbstractType2.default();
    }).not.toThrow();
  });
  it('throws errors on abstract methods', function () {
    expect(function () {
      return new _AbstractType2.default().encodeData();
    }).toThrow();
    expect(function () {
      return new _AbstractType2.default().toObject();
    }).toThrow();
  });
});
describe('Concrete subtypes of abstract type', function () {
  // Type that extends AbstractType for testing static methods
  var ConcreteType =
  /*#__PURE__*/
  function (_AbstractType) {
    (0, _inherits2.default)(ConcreteType, _AbstractType);

    function ConcreteType() {
      (0, _classCallCheck2.default)(this, ConcreteType);
      return (0, _possibleConstructorReturn2.default)(this, (0, _getPrototypeOf2.default)(ConcreteType).apply(this, arguments));
    }

    (0, _createClass2.default)(ConcreteType, [{
      key: "encodeData",
      value: function encodeData() {
        return '';
      }
    }], [{
      key: "encodeDependentTypes",
      value: function encodeDependentTypes() {
        return 'DEPENDENTTYPES';
      }
    }]);
    return ConcreteType;
  }(_AbstractType2.default);

  (0, _defineProperty2.default)(ConcreteType, "name", 'Concrete');
  (0, _defineProperty2.default)(ConcreteType, "properties", [{
    name: 'abstract',
    type: 'bool'
  }, {
    name: 'concrete',
    type: 'bool'
  }, {
    name: 'pasta',
    type: 'string'
  }]);
  it('supports typeDef', function () {
    expect(ConcreteType.typeDef()).toEqual(ConcreteType.properties);
  });
  it('supports encodeTypeFragment', function () {
    expect(ConcreteType.encodeTypeFragment()).toEqual('Concrete(bool abstract,bool concrete,string pasta)');
  });
  it('supports encodeType', function () {
    expect(ConcreteType.encodeType()).toEqual('Concrete(bool abstract,bool concrete,string pasta)DEPENDENTTYPES');
  });
  it.skip('supports typeHash', function () {
    expect(ConcreteType.typeHash()).toEqual();
  });
});