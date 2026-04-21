"use strict";

var _interopRequireDefault = require("@babel/runtime/helpers/interopRequireDefault");

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.verify = verify;
exports.verifyRawSignatureFromAddress = verifyRawSignatureFromAddress;
exports.toEthereumAddress = toEthereumAddress;

var _elliptic = require("elliptic");

var _jsSha = require("js-sha3");

var _Domain = _interopRequireDefault(require("./Domain"));

var secp256k1 = new _elliptic.ec('secp256k1');
/**
 * Verify that a particular object was signed by a given
 */

function verify(request, signature, address) {
  var _EIP712Domain$fromSig = _Domain.default.fromSignatureRequest(request),
      domain = _EIP712Domain$fromSig.domain,
      message = _EIP712Domain$fromSig.message;

  if (!message.verifySignature(signature, address)) {
    throw new Error('Invalid signature for address over this object');
  }

  return {
    domain: domain,
    message: message
  };
}
/**
 * Verify a signed hash made by the owner of a particular ethereum address
 * returning true if the signature is valid, and false otherwise
 * @param   {Buffer}  data qq
 * @param   {Object}  signature 
 * @param   {String}  address 
 * @returns {Boolean} indicator of the signature's validity
 */


function verifyRawSignatureFromAddress(data, signature, address) {
  var _normalizeSignature = normalizeSignature(signature),
      r = _normalizeSignature.r,
      s = _normalizeSignature.s,
      v = _normalizeSignature.v; // Recover public key from signature, and convert to ethereum address


  var publicKey = secp256k1.recoverPubKey(data, {
    r: r,
    s: s
  }, v).encode('hex');
  var recoveredAddress = toEthereumAddress(publicKey);
  return recoveredAddress === address;
}
/**
 * Convert a hex encoded secp256k1 public key to the equivalent ethereum address
 * @param   {String} hexPublicKey
 * @returns {String} address of account with given public key 
 */


function toEthereumAddress(hexPublicKey) {
  hexPublicKey = hexPublicKey.startsWith('0x') ? hexPublicKey.slice(2) : hexPublicKey;
  return "0x".concat((0, _jsSha.keccak256)(Buffer.from(hexPublicKey, 'hex')).slice(-20).toString('hex'));
}
/**
 * Convert a string, or buffer signature to an object containing
 * the three signature parameters r, s, v
 * @param   {String|Object} sig
 * @returns {Object}  A normalized signature object, containing strings r,s,v
 */


function normalizeSignature(sig) {
  // Parse string into buffer
  if (typeof sig === 'string') {
    sig = {
      r: Buffer.from(sig.slice(0, 64), 'hex'),
      s: Buffer.from(sig.slice(64, 128), 'hex'),
      v: parseInt(sig[128])
    };
  }

  return {
    r: sig.r,
    s: sig.s,
    v: 'recoveryParam' in sig ? sig.recoveryParam : sig.v
  };
}