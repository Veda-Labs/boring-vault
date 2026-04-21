"use strict";

var _interopRequireDefault = require("@babel/runtime/helpers/interopRequireDefault");

var _interopRequireWildcard = require("@babel/runtime/helpers/interopRequireWildcard");

var util = _interopRequireWildcard(require("ethereumjs-util"));

var _elliptic = require("elliptic");

var _Domain = _interopRequireDefault(require("../Domain"));

var _verify = require("../verify");

var secp256k1 = (0, _elliptic.ec)('secp256k1');
describe('Type [factory]', function () {
  var Domain;
  beforeAll(function () {
    Domain = new _Domain.default({
      name: 'Test Domain',
      version: '1.0',
      chainId: 0x01,
      verifyingContract: '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
      salt: 'salt'
    });
  });
  it('Creates a new instantiable class with no properties', function () {
    var Empty = Domain.createType('Empty', []);
    expect(Empty.hasOwnProperty('properties')).toBe(true);
    expect(Empty.hasOwnProperty('dependencies')).toBe(true);
    expect(Empty.hasOwnProperty('name')).toBe(true);
    expect(function () {
      return new Empty({});
    }).not.toThrow();
  });
  it('Encodes itself including dependent types', function () {
    Domain.createType('Test', {
      test: 'string'
    });
    var Nest = Domain.createType('Nest', {
      nest: 'Test',
      more: 'string'
    });
    expect(Nest.encodeType()).toEqual('Nest(Test nest,string more)Test(string test)');
  });
  it('Throws error if type definition is invalid', function () {
    var bad1 = [{
      name: 'hello'
    }, {
      name: 'goodbye',
      type: 'string'
    }];
    var bad2 = [{
      name: 'hello',
      type: 'Missing'
    }];
    var bad3 = [{
      name: 'hello',
      type: [{
        name: 'nested',
        type: 'string'
      }]
    }];
    expect(function () {
      return Domain.createType('Bad', bad1);
    }).toThrow();
    expect(function () {
      return Domain.createType('Bad', bad2);
    }).toThrow();
    expect(function () {
      return Domain.createType('Bad', bad3);
    }).toThrow();
  });
});
describe('Sample Type', function () {
  var Domain, Inner, Outer;
  beforeAll(function () {
    Domain = new _Domain.default({
      name: 'Test Domain',
      version: '1.0',
      chainId: 0x01,
      verifyingContract: '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
      salt: 'salt'
    });
    Inner = Domain.createType('Inner', [{
      name: 'data',
      type: 'string'
    }]);
    Outer = Domain.createType('Outer', [{
      name: 'inner',
      type: 'Inner'
    }, {
      name: 'data',
      type: 'string'
    }]);
  });
  it('Throws an error if an object is instantiated with missing properties', function () {
    expect(function () {
      return new Outer({
        inner: {
          data: 'hello'
        }
      });
    }).toThrow();
    expect(function () {
      return new Inner();
    }).toThrow();
  });
  it('Throws an error if an object is edited with an invalid value', function () {
    var o = new Outer({
      data: 'hello',
      inner: {
        data: 'hello inside'
      }
    });
    expect(function () {
      return o.inner = 'hello';
    }).toThrow();
  });
  it('Throws an error when trying to encode a corrupted object', function () {
    var i = new Inner({
      data: 'hello'
    }); // Corrupt properties list

    Inner.properties = [{
      name: 'data',
      type: 'potato'
    }];
    expect(function () {
      return i.encodeData();
    }).toThrow();
  });
  it('Throws an error if you attempt to sign without a signer', function () {
    var i = new Inner({
      data: 'hello'
    });
    expect(i.sign).toThrow();
  });
});
describe('MailExample', function () {
  // The provided example from the EIP712 PR
  var MailExample = require('./data/Mail.json');

  var _MailExample$request$ = MailExample.request.types,
      personDef = _MailExample$request$.Person,
      mailDef = _MailExample$request$.Mail;
  var _MailExample$results$ = MailExample.results.Mail,
      encodeType = _MailExample$results$.encodeType,
      typeHash = _MailExample$results$.typeHash,
      encodeData = _MailExample$results$.encodeData,
      hashStruct = _MailExample$results$.hashStruct,
      signHash = _MailExample$results$.signHash;
  var Domain, Person, Mail, message;
  beforeAll(function () {
    // Build domain
    Domain = new _Domain.default(MailExample.request.domain); // Build type constructors

    Person = Domain.createType('Person', personDef);
    Mail = Domain.createType('Mail', mailDef); // Build an instance of mail to test

    message = new Mail(MailExample.request.message);
  });
  test('domainSeparator', function () {
    expect(util.bufferToHex(Domain.domainSeparator)).toEqual(MailExample.results.domainSeparator);
  });
  test('toSignatureRequest', function () {
    expect(message.toSignatureRequest()).toEqual(MailExample.request);
  });
  test('toObject', function () {
    expect(message.toObject()).toEqual(MailExample.request.message);
  });
  test('encodeType', function () {
    expect(Mail.encodeType()).toEqual(encodeType);
  });
  test('typeHash', function () {
    expect(util.bufferToHex(Mail.typeHash())).toEqual(typeHash);
  });
  test('encodeData', function () {
    expect(util.bufferToHex(message.encodeData())).toEqual(encodeData);
  });
  test('hashStruct', function () {
    expect(util.bufferToHex(message.hashStruct())).toEqual(hashStruct);
  });
  test('signHash', function () {
    expect(util.bufferToHex(message.signHash())).toEqual(signHash);
  });
  test('sign and verifySignature', function () {
    var keypair = secp256k1.genKeyPair();
    var address = (0, _verify.toEthereumAddress)(keypair.getPublic().encode('hex'));
    var signature = message.sign(keypair.sign.bind(keypair));
    expect(message.verifySignature(signature, address)).toBe(true);
  });
}); // Add more examples with different data structures here:
// TODO