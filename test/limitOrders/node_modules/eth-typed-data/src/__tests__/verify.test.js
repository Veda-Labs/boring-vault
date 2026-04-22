import { ec as EC } from 'elliptic'
import { verify, verifyRawSignatureFromAddress, toEthereumAddress } from '../verify'

const secp256k1 = EC('secp256k1')

function kp() {
  const keypair = secp256k1.genKeyPair()
  const address = toEthereumAddress(keypair.getPublic().encode('hex'))

  return { keypair, address }
}

describe('toEthereumAddress', () => {
  it('handles 0x prefix', () => {
    const { keypair } = kp()
    const pubKey = keypair.getPublic().encode('hex')
    expect(toEthereumAddress(pubKey)).toEqual(toEthereumAddress(`0x${pubKey}`))
  })
})

describe('verifyRawSignatureFromAddress', () => {
  it('verifies an arbitrary signature from a signature object', () => {
    const { keypair, address } = kp()
    const hash = Buffer.from('deadbeef', 'hex')
    const sig = keypair.sign(hash)
    expect(verifyRawSignatureFromAddress(hash, sig, address)).toBe(true)
  })

  it('verifies a concatenated buffer signature', () => {
    // uncomment to be *extra* sure
    // for (let i = 0; i < 100; i++) {
      const { keypair, address } = kp()
      const hash = Buffer.from('deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', 'hex')
      const sig = keypair.sign(hash)
      const [r, s] = [sig.r.toString('hex'), sig.s.toString('hex')]
      const buf =  `${r.padStart(64, '0')}${s.padStart(64, '0')}${sig.recoveryParam}`
      expect(verifyRawSignatureFromAddress(hash, buf, address)).toBe
    // }
  })
})

describe('verify', () => {
  const MailExample = require('./data/Mail.json')

  it('verifies a request', () => {
    const { keypair, address } = kp()
    const signHash = Buffer.from(MailExample.results.Mail.signHash.slice(2), 'hex')
    const sig = keypair.sign(signHash)
    expect(() => verify(MailExample.request, sig, address)).not.toThrow()
  })

  it('throws an error for an invalid signature', () => {
    const { keypair } = kp()
    const signHash = Buffer.from(MailExample.results.Mail.signHash.slice(2), 'hex')
    const sig = keypair.sign(signHash)
    const { address } = kp() // different keypair!
    expect(() => verify(MailExample.request, sig, address)).toThrow()
  })
})