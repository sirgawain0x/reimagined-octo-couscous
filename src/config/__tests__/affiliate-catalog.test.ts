import { expect, it } from 'vitest'
import { affiliateCatalog } from '../affiliate-catalog'

it('keeps the configured partner tracking parameters', () => {
  const url = 'https://www.amazon.com/shop?tag=example'
  expect(affiliateCatalog({ Amazon: url })).toEqual([
    { name: 'Amazon', url }, { name: 'Walmart', url: expect.any(String) },
    { name: 'eBay', url: expect.any(String) },
  ])
})
it.each(['http://amazon.com', 'https://amazon.com.example.org', 'https://amazon.com@evil.org',
  'https://user@amazon.com', 'https://amazon.com:8000', 'javascript:alert(1)'])(
  'rejects an unsafe merchant destination', url => {
    expect(() => affiliateCatalog({ Amazon: url })).toThrow()
  })
