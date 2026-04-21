"use strict";

var _elliptic = require("elliptic");

var _verify = require("../verify");

var secp256k1 = (0, _elliptic.ec)('secp256k1');

function kp() {
  var keypair = secp256k1.genKeyPair();
  var address = (0, _verify.toEthereumAddress)(keypair.getPublic().encode('hex'));
  return {
    keypair: keypair,
    address: address
  };
}

describe('toEthereumAddress', function () {
  it('handles 0x prefix', function () {
    var _kp = kp(),
        keypair = _kp.keypair;

    var pubKey = keypair.getPublic().encode('hex');
    expect((0, _verify.toEthereumAddress)(pubKey)).toEqual((0, _verify.toEthereumAddress)("0x".concat(pubKey)));
  });
});
describe('verifyRawSignatureFromAddress', function () {
  it('verifies an arbitrary signature from a signature object', function () {
    var _kp2 = kp(),
        keypair = _kp2.keypair,
        address = _kp2.address;

    var hash = Buffer.from('deadbeef', 'hex');
    var sig = keypair.sign(hash);
    expect((0, _verify.verifyRawSignatureFromAddress)(hash, sig, address)).toBe(true);
  });
  it('verifies a concatenated buffer signature', function () {
    // uncomment to be *extra* sure
    // for (let i = 0; i < 100; i++) {
    var _kp3 = kp(),
        keypair = _kp3.keypair,
        address = _kp3.address;

    var hash = Buffer.from('deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', 'hex');
    var sig = keypair.sign(hash);
    var _ref = [sig.r.toString('hex'), sig.s.toString('hex')],
        r = _ref[0],
        s = _ref[1];
    var buf = "".concat(r.padStart(64, '0')).concat(s.padStart(64, '0')).concat(sig.recoveryParam);
    expect((0, _verify.verifyRawSignatureFromAddress)(hash, buf, address)).toBe; // }
  });
});
describe('verify', function () {
  var MailExample = require('./data/Mail.json');

  it('verifies a request', function () {
    var _kp4 = kp(),
        keypair = _kp4.keypair,
        address = _kp4.address;

    var signHash = Buffer.from(MailExample.results.Mail.signHash.slice(2), 'hex');
    var sig = keypair.sign(signHash);
    expect(function () {
      return (0, _verify.verify)(MailExample.request, sig, address);
    }).not.toThrow();
  });
  it('throws an error for an invalid signature', function () {
    var _kp5 = kp(),
        keypair = _kp5.keypair;

    var signHash = Buffer.from(MailExample.results.Mail.signHash.slice(2), 'hex');
    var sig = keypair.sign(signHash);

    var _kp6 = kp(),
        address = _kp6.address; // different keypair!


    expect(function () {
      return (0, _verify.verify)(MailExample.request, sig, address);
    }).toThrow();
  });
});