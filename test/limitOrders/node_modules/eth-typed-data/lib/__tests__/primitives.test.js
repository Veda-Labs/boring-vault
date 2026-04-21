"use strict";

var _primitives = require("../primitives");

var POWERS = [1, 2, 4, 8, 16, 32];
describe('type indicators', function () {
  it('identifies atomic types', function () {
    for (var _i = 0; _i < POWERS.length; _i++) {
      var p = POWERS[_i];
      expect((0, _primitives.isAtomicType)("bytes".concat(p))).toBe(true);
      expect((0, _primitives.isAtomicType)("int".concat(8 * p))).toBe(true);
      expect((0, _primitives.isAtomicType)("uint".concat(8 * p))).toBe(true);
    }

    expect((0, _primitives.isAtomicType)('address')).toBe(true);
    expect((0, _primitives.isAtomicType)('bool')).toBe(true);
    expect((0, _primitives.isAtomicType)('string')).toBe(false);
    expect((0, _primitives.isAtomicType)('bytes')).toBe(false);
  });
  it('identifies dynamic types', function () {
    expect((0, _primitives.isDynamicType)('string')).toBe(true);
    expect((0, _primitives.isDynamicType)('bytes')).toBe(true);

    for (var _i2 = 0; _i2 < POWERS.length; _i2++) {
      var p = POWERS[_i2];
      expect((0, _primitives.isDynamicType)("bytes".concat(p))).toBe(false);
      expect((0, _primitives.isDynamicType)("int".concat(8 * p))).toBe(false);
      expect((0, _primitives.isDynamicType)("uint".concat(8 * p))).toBe(false);
    }

    expect((0, _primitives.isDynamicType)('address')).toBe(false);
    expect((0, _primitives.isDynamicType)('bool')).toBe(false);
  });
  it('identifies primitive types', function () {
    for (var _i3 = 0; _i3 < POWERS.length; _i3++) {
      var p = POWERS[_i3];
      expect((0, _primitives.isPrimitiveType)("bytes".concat(p))).toBe(true);
      expect((0, _primitives.isPrimitiveType)("int".concat(8 * p))).toBe(true);
      expect((0, _primitives.isPrimitiveType)("uint".concat(8 * p))).toBe(true);
    }

    expect((0, _primitives.isPrimitiveType)('address')).toBe(true);
    expect((0, _primitives.isPrimitiveType)('bool')).toBe(true);
    expect((0, _primitives.isPrimitiveType)('string')).toBe(true);
    expect((0, _primitives.isPrimitiveType)('bytes')).toBe(true);
    expect((0, _primitives.isPrimitiveType)('EIP712Domain')).toBe(false);
  });
  it('identifies array types', function () {
    expect((0, _primitives.isArrayType)('mytype[]')).toBe(true);
    expect((0, _primitives.isArrayType)('[]')).toBe(false);
    expect((0, _primitives.isArrayType)('mytype[')).toBe(false);
    expect((0, _primitives.isArrayType)('mytype]')).toBe(false);
    expect((0, _primitives.isArrayType)('mytype][')).toBe(false);
    expect((0, _primitives.isArrayType)('mytype[] ')).toBe(false);
  });
  it('identifies elementary types of array types', function () {
    expect((0, _primitives.getElementaryType)('scoopity[]')).toEqual('scoopity');
    expect(function () {
      return (0, _primitives.getElementaryType)('woopity');
    }).toThrow();
  });
  it('identifies arbitrarily nested arrays of primitive types as non-structure types', function () {
    expect((0, _primitives.isNotStructureType)('bool')).toBe(true);
    expect((0, _primitives.isNotStructureType)('bool[]')).toBe(true);
    expect((0, _primitives.isNotStructureType)('string[][][][][][][][][][][][][][][]')).toBe(true);
    expect((0, _primitives.isNotStructureType)('MyType')).toBe(false);
    expect((0, _primitives.isNotStructureType)('YourType[]')).toBe(false);
  });
});
describe('validate', function () {
  it('validates primitive types', function () {
    var _loop = function _loop() {
      var p = POWERS[_i4];
      expect(function () {
        return _primitives.validate["bytes".concat(p)]();
      }).not.toThrow();
      expect(function () {
        return _primitives.validate["int".concat(8 * p)]();
      }).not.toThrow();
      expect(function () {
        return _primitives.validate["uint".concat(8 * p)]();
      }).not.toThrow();
    };

    for (var _i4 = 0; _i4 < POWERS.length; _i4++) {
      _loop();
    }

    expect(function () {
      return _primitives.validate['address']();
    }).not.toThrow();
    expect(function () {
      return _primitives.validate['bool']();
    }).not.toThrow();
    expect(function () {
      return _primitives.validate['string']();
    }).not.toThrow();
    expect(function () {
      return _primitives.validate['bytes']([0]);
    }).not.toThrow();
  });
});