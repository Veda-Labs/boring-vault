import EIP712Domain, { EIP712DomainProperties } from '../Domain';

const domainDef = {
  name: 'Test Domain',
  version: '1.0', 
  chainId: 0x01,
  verifyingContract: '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
  salt: 'salt'
}

const miniDomain = {
  name: 'Mini Domain',
  version: '1.0'
}


describe('EIP712Domain', () => {
  it('creates a domain with all domain properties', () => {
    expect(() => new EIP712Domain(domainDef)).not.toThrow()
  })

  it('creates a domain with a subset of allowed properties', () => {
    expect(() => new EIP712Domain(miniDomain)).not.toThrow()
  })

  it('throws an error if no properties are provided', () =>  {
    expect(() => new EIP712Domain({})).toThrow()
  })

  it('throws an error if extra properties are provided', () => {
    expect(() => new EIP712Domain({extra: 'property', ...domainDef})).toThrow()
  })

  it('precalculates the domainSeparator', () => {
    const domain = new EIP712Domain(domainDef)
    expect(domain.domainSeparator).toEqual(domain.hashStruct())
  })
})

describe('validate', () => {
  const d = new EIP712Domain(domainDef)
  const MyType = d.createType('MyType', {data: 'string'})

  it('validates primitive types', () => {
    const num = 25
    expect(d.validate('uint8', num)).toEqual(num)
  })

  it('validates arrays of primitive types', () => {
    const arr = [0, 1, 2, 3]
    expect(d.validate('int32[]', arr)).toEqual(arr)
  })

  it('validates structure type instances', () => {
    const myObject = new MyType({data: 'hello'})
    expect(d.validate('MyType', myObject)).toEqual(myObject)
  })

  it('validates bare object structure types', () => {
    const data = { data: 'hello' }
    expect(d.validate('MyType', data).toObject()).toEqual(data)
  })

  it('validates arrays of structure types', () => {
    const myObjects = [new MyType({data: '1'}), new MyType({data: '2'}), new MyType({data: '3'})]
    expect(d.validate('MyType[]', myObjects)).toEqual(myObjects)
  })

  it('fails to validate invalid types', () => {
    expect(() => d.validate('FakeType', {data: 'fake'})).toThrow()
  })
})

describe('serialize', () => {
  const d = new EIP712Domain(domainDef)
  const MyType = d.createType('MyType', {data: 'string'})

  it('serializes primitive types', () => {
    const num = 25
    expect(d.serialize('uint8', num)).toEqual(num)
  })

  it('serializes arrays of primitive types', () => {
    const arr = [0, 1, 2, 3]
    expect(d.serialize('int32[]', arr)).toEqual(arr)
  })

  it('serializes structure type instances', () => {
    const myObject = new MyType({data: 'hello'})
    expect(d.serialize('MyType', myObject)).toEqual(myObject.toObject())
  })

  it('serializes arrays of structure types', () => {
    const myObjects = [new MyType({data: '1'}), new MyType({data: '2'}), new MyType({data: '3'})]
    expect(d.serialize('MyType[]', myObjects)).toEqual(myObjects.map(x => x.toObject()))
  })

  it('fails to serialize invalid types', () => {
    expect(() => d.serialize('FakeType', {data: 'fake'})).toThrow()
  })
})

describe('toDomainDef', () => {
  it('lists itself if there are no other types', () => {
    const domain = new EIP712Domain(domainDef)
    expect(domain.toDomainDef()).toEqual({EIP712Domain: EIP712DomainProperties})
  })

  it('includes other types when present', () => {
    const domain = new EIP712Domain(domainDef)
    const T = domain.createType('T', { property: 'string' })
    expect(domain.toDomainDef()[T.name]).toEqual(T.typeDef())
  })
})

describe('toObject', () => {
  it('matches the provided values', () => {
    const domain = new EIP712Domain(domainDef)
    expect(domain.toObject()).toEqual(domainDef)
  })
})

describe('fromSignatureRequest', () => {
  it('creates a simple domain/message', () => {
    const request = {
      types: {
        EIP712Domain: EIP712DomainProperties,
        LilType: [
          {name: 'data', type: 'string'}
        ]
      },
      domain: domainDef,
      primaryType: 'LilType',
      message: {
        data: 'Hello World!'
      }
    }
    const { domain, message } = EIP712Domain.fromSignatureRequest(request)

    expect(domain.toObject()).toEqual(domainDef)
    expect(message.toObject()).toEqual(request.message)
  })

  it('creates a domain with nested types', () => {
    const request = {
      types: {
        EIP712Domain: EIP712DomainProperties,
        MiddleType: [
          {name: 'woop', type: 'string'},
          {name: 'lil', type: 'LilType'}
        ],
        SuperType: [
          {name: 'woop', type: 'string'},
          {name: 'lil', type: 'LilType'},
          {name: 'middle', type: 'MiddleType'}
        ],
        LilType: [
          {name: 'data', type: 'string'}
        ]
      },
      domain: domainDef,
      primaryType: 'SuperType',
      message: {
        woop: 'woop',
        lil: { data: 'lil type' },
        middle: {
          woop: 'woop in the middle',
          lil: { data: 'lil type in the middle' }
        }
      }
    }

    const { domain, message } = EIP712Domain.fromSignatureRequest(request)

    expect(domain.toObject()).toEqual(domainDef)
    expect(message.toObject()).toEqual(request.message)
    expect(message.toSignatureRequest()).toEqual(request)
  })

  it('throws an error when given a domain with cyclic dependencies', () => {
    const request = {
      types: {
        EIP712Domain: EIP712DomainProperties,
        A: [{name: 'b', type: 'B'}],
        B: [{name: 'c', type: 'C'}],
        C: [{name: 'a', type: 'A'}]
      },
      domain: domainDef,
      primaryType: 'A',
      message: {A: {B: {C: 'A'}}} 
    }

    expect(() => EIP712Domain.fromSignatureRequest(request)).toThrow()
  })
})
