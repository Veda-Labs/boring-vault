"use strict";

var _interopRequireWildcard = require("@babel/runtime/helpers/interopRequireWildcard");

var _interopRequireDefault = require("@babel/runtime/helpers/interopRequireDefault");

var _objectSpread2 = _interopRequireDefault(require("@babel/runtime/helpers/objectSpread"));

var _Domain = _interopRequireWildcard(require("../Domain"));

var domainDef = {
  name: 'Test Domain',
  version: '1.0',
  chainId: 0x01,
  verifyingContract: '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
  salt: 'salt'
};
var miniDomain = {
  name: 'Mini Domain',
  version: '1.0'
};
describe('EIP712Domain', function () {
  it('creates a domain with all domain properties', function () {
    expect(function () {
      return new _Domain.default(domainDef);
    }).not.toThrow();
  });
  it('creates a domain with a subset of allowed properties', function () {
    expect(function () {
      return new _Domain.default(miniDomain);
    }).not.toThrow();
  });
  it('throws an error if no properties are provided', function () {
    expect(function () {
      return new _Domain.default({});
    }).toThrow();
  });
  it('throws an error if extra properties are provided', function () {
    expect(function () {
      return new _Domain.default((0, _objectSpread2.default)({
        extra: 'property'
      }, domainDef));
    }).toThrow();
  });
  it('precalculates the domainSeparator', function () {
    var domain = new _Domain.default(domainDef);
    expect(domain.domainSeparator).toEqual(domain.hashStruct());
  });
});
describe('validate', function () {
  var d = new _Domain.default(domainDef);
  var MyType = d.createType('MyType', {
    data: 'string'
  });
  it('validates primitive types', function () {
    var num = 25;
    expect(d.validate('uint8', num)).toEqual(num);
  });
  it('validates arrays of primitive types', function () {
    var arr = [0, 1, 2, 3];
    expect(d.validate('int32[]', arr)).toEqual(arr);
  });
  it('validates structure type instances', function () {
    var myObject = new MyType({
      data: 'hello'
    });
    expect(d.validate('MyType', myObject)).toEqual(myObject);
  });
  it('validates bare object structure types', function () {
    var data = {
      data: 'hello'
    };
    expect(d.validate('MyType', data).toObject()).toEqual(data);
  });
  it('validates arrays of structure types', function () {
    var myObjects = [new MyType({
      data: '1'
    }), new MyType({
      data: '2'
    }), new MyType({
      data: '3'
    })];
    expect(d.validate('MyType[]', myObjects)).toEqual(myObjects);
  });
  it('fails to validate invalid types', function () {
    expect(function () {
      return d.validate('FakeType', {
        data: 'fake'
      });
    }).toThrow();
  });
});
describe('serialize', function () {
  var d = new _Domain.default(domainDef);
  var MyType = d.createType('MyType', {
    data: 'string'
  });
  it('serializes primitive types', function () {
    var num = 25;
    expect(d.serialize('uint8', num)).toEqual(num);
  });
  it('serializes arrays of primitive types', function () {
    var arr = [0, 1, 2, 3];
    expect(d.serialize('int32[]', arr)).toEqual(arr);
  });
  it('serializes structure type instances', function () {
    var myObject = new MyType({
      data: 'hello'
    });
    expect(d.serialize('MyType', myObject)).toEqual(myObject.toObject());
  });
  it('serializes arrays of structure types', function () {
    var myObjects = [new MyType({
      data: '1'
    }), new MyType({
      data: '2'
    }), new MyType({
      data: '3'
    })];
    expect(d.serialize('MyType[]', myObjects)).toEqual(myObjects.map(function (x) {
      return x.toObject();
    }));
  });
  it('fails to serialize invalid types', function () {
    expect(function () {
      return d.serialize('FakeType', {
        data: 'fake'
      });
    }).toThrow();
  });
});
describe('toDomainDef', function () {
  it('lists itself if there are no other types', function () {
    var domain = new _Domain.default(domainDef);
    expect(domain.toDomainDef()).toEqual({
      EIP712Domain: _Domain.EIP712DomainProperties
    });
  });
  it('includes other types when present', function () {
    var domain = new _Domain.default(domainDef);
    var T = domain.createType('T', {
      property: 'string'
    });
    expect(domain.toDomainDef()[T.name]).toEqual(T.typeDef());
  });
});
describe('toObject', function () {
  it('matches the provided values', function () {
    var domain = new _Domain.default(domainDef);
    expect(domain.toObject()).toEqual(domainDef);
  });
});
describe('fromSignatureRequest', function () {
  it('creates a simple domain/message', function () {
    var request = {
      types: {
        EIP712Domain: _Domain.EIP712DomainProperties,
        LilType: [{
          name: 'data',
          type: 'string'
        }]
      },
      domain: domainDef,
      primaryType: 'LilType',
      message: {
        data: 'Hello World!'
      }
    };

    var _EIP712Domain$fromSig = _Domain.default.fromSignatureRequest(request),
        domain = _EIP712Domain$fromSig.domain,
        message = _EIP712Domain$fromSig.message;

    expect(domain.toObject()).toEqual(domainDef);
    expect(message.toObject()).toEqual(request.message);
  });
  it('creates a domain with nested types', function () {
    var request = {
      types: {
        EIP712Domain: _Domain.EIP712DomainProperties,
        MiddleType: [{
          name: 'woop',
          type: 'string'
        }, {
          name: 'lil',
          type: 'LilType'
        }],
        SuperType: [{
          name: 'woop',
          type: 'string'
        }, {
          name: 'lil',
          type: 'LilType'
        }, {
          name: 'middle',
          type: 'MiddleType'
        }],
        LilType: [{
          name: 'data',
          type: 'string'
        }]
      },
      domain: domainDef,
      primaryType: 'SuperType',
      message: {
        woop: 'woop',
        lil: {
          data: 'lil type'
        },
        middle: {
          woop: 'woop in the middle',
          lil: {
            data: 'lil type in the middle'
          }
        }
      }
    };

    var _EIP712Domain$fromSig2 = _Domain.default.fromSignatureRequest(request),
        domain = _EIP712Domain$fromSig2.domain,
        message = _EIP712Domain$fromSig2.message;

    expect(domain.toObject()).toEqual(domainDef);
    expect(message.toObject()).toEqual(request.message);
    expect(message.toSignatureRequest()).toEqual(request);
  });
  it('throws an error when given a domain with cyclic dependencies', function () {
    var request = {
      types: {
        EIP712Domain: _Domain.EIP712DomainProperties,
        A: [{
          name: 'b',
          type: 'B'
        }],
        B: [{
          name: 'c',
          type: 'C'
        }],
        C: [{
          name: 'a',
          type: 'A'
        }]
      },
      domain: domainDef,
      primaryType: 'A',
      message: {
        A: {
          B: {
            C: 'A'
          }
        }
      }
    };
    expect(function () {
      return _Domain.default.fromSignatureRequest(request);
    }).toThrow();
  });
});