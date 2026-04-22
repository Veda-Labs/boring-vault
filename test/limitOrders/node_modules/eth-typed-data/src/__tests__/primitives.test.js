import { validate, isPrimitiveType, isAtomicType, isDynamicType, isArrayType, isNotStructureType, getElementaryType } from '../primitives'

const POWERS = [1, 2, 4, 8, 16, 32]

describe('type indicators', () => {
  it('identifies atomic types', () => {
    for (const p of POWERS) {
      expect(isAtomicType(`bytes${p}`)).toBe(true)
      expect(isAtomicType(`int${8*p}`)).toBe(true)
      expect(isAtomicType(`uint${8*p}`)).toBe(true)
    }

    expect(isAtomicType('address')).toBe(true)
    expect(isAtomicType('bool')).toBe(true)

    expect(isAtomicType('string')).toBe(false)
    expect(isAtomicType('bytes')).toBe(false)
    
  })
  
  it('identifies dynamic types', () => {
    expect(isDynamicType('string')).toBe(true)
    expect(isDynamicType('bytes')).toBe(true)

    for (const p of POWERS) {
      expect(isDynamicType(`bytes${p}`)).toBe(false)
      expect(isDynamicType(`int${8*p}`)).toBe(false)
      expect(isDynamicType(`uint${8*p}`)).toBe(false)
    }

    expect(isDynamicType('address')).toBe(false)
    expect(isDynamicType('bool')).toBe(false)
  })

  it('identifies primitive types', () => {
    for (const p of POWERS) {
      expect(isPrimitiveType(`bytes${p}`)).toBe(true)
      expect(isPrimitiveType(`int${8*p}`)).toBe(true)
      expect(isPrimitiveType(`uint${8*p}`)).toBe(true)
    }
    
    expect(isPrimitiveType('address')).toBe(true)
    expect(isPrimitiveType('bool')).toBe(true)
    expect(isPrimitiveType('string')).toBe(true)
    expect(isPrimitiveType('bytes')).toBe(true)

    expect(isPrimitiveType('EIP712Domain')).toBe(false)
  })

  it('identifies array types', () => {
    expect(isArrayType('mytype[]')).toBe(true)
 
    expect(isArrayType('[]')).toBe(false)
    expect(isArrayType('mytype[')).toBe(false)
    expect(isArrayType('mytype]')).toBe(false)
    expect(isArrayType('mytype][')).toBe(false)
    expect(isArrayType('mytype[] ')).toBe(false)
  })

  it('identifies elementary types of array types', () => {
    expect(getElementaryType('scoopity[]')).toEqual('scoopity')
    expect(() => getElementaryType('woopity')).toThrow()
  })

  it('identifies arbitrarily nested arrays of primitive types as non-structure types', () => {
    expect(isNotStructureType('bool')).toBe(true)
    expect(isNotStructureType('bool[]')).toBe(true)
    expect(isNotStructureType('string[][][][][][][][][][][][][][][]')).toBe(true)

    expect(isNotStructureType('MyType')).toBe(false)
    expect(isNotStructureType('YourType[]')).toBe(false)
  })
})

describe('validate', () => {
  it('validates primitive types', () => {
    for (const p of POWERS) {
      expect(() => validate[`bytes${p}`]()).not.toThrow()
      expect(() => validate[`int${8*p}`]()).not.toThrow()
      expect(() => validate[`uint${8*p}`]()).not.toThrow()
    }
    
    expect(() => validate['address']()).not.toThrow()
    expect(() => validate['bool']()).not.toThrow()
    expect(() => validate['string']()).not.toThrow()
    expect(() => validate['bytes']([0])).not.toThrow()
  })
})