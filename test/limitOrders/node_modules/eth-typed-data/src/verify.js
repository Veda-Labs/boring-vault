import { ec as EC } from 'elliptic'
import { keccak256 } from 'js-sha3'

import EIP712Domain from './Domain'

const secp256k1 = new EC('secp256k1')

/**
 * Verify that a particular object was signed by a given
 */
export function verify(request, signature, address) {
  const { domain, message } = EIP712Domain.fromSignatureRequest(request)

  if (!message.verifySignature(signature, address)) {
    throw new Error('Invalid signature for address over this object')
  }

  return { domain, message }
}

/**
 * Verify a signed hash made by the owner of a particular ethereum address
 * returning true if the signature is valid, and false otherwise
 * @param   {Buffer}  data qq
 * @param   {Object}  signature 
 * @param   {String}  address 
 * @returns {Boolean} indicator of the signature's validity
 */
export function verifyRawSignatureFromAddress(data, signature, address) {
  const { r, s, v } = normalizeSignature(signature)

  // Recover public key from signature, and convert to ethereum address
  const publicKey = secp256k1.recoverPubKey(data, {r, s}, v).encode('hex')

  const recoveredAddress = toEthereumAddress(publicKey)
  return recoveredAddress === address
}

/**
 * Convert a hex encoded secp256k1 public key to the equivalent ethereum address
 * @param   {String} hexPublicKey
 * @returns {String} address of account with given public key 
 */
export function toEthereumAddress(hexPublicKey) {
  hexPublicKey = hexPublicKey.startsWith('0x') ? hexPublicKey.slice(2) : hexPublicKey 
  return `0x${keccak256(Buffer.from(hexPublicKey, 'hex')).slice(-20).toString('hex')}`
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
    }
  }

  return {
    r: sig.r,
    s: sig.s,
    v: 'recoveryParam' in sig ? sig.recoveryParam : sig.v,
  }
}