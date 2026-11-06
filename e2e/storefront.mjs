// Tests the production bundle locally. Partner and identity-provider requests are intercepted.
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { preview } from 'vite'
import { chromium } from 'playwright-core'

const origin = 'http://127.0.0.1:4287'
const headers = JSON.parse(await readFile(new URL('../config/storefront-headers.json', import.meta.url), 'utf8'))
const server = await preview({ preview: { host: '127.0.0.1', port: 4287, strictPort: true, headers } })
let browser
try {
  browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined })
  const context = await browser.newContext()
  const external = []
  const errors = []
  await context.route('**/*', async route => {
    const url = new URL(route.request().url())
    if (url.origin === origin) return route.continue()
    external.push(url)
    return route.fulfill({ status: 200, contentType: 'text/html', body: '<title>Intercepted test destination</title>' })
  })
  const page = await context.newPage()
  page.on('pageerror', error => errors.push(error.message))
  await page.goto(origin)
  await page.getByRole('heading', { name: 'Shop Stores' }).waitFor()
  const links = page.getByRole('link', { name: 'Shop Now' })
  assert.equal(await links.count(), 3)
  assert.deepEqual(external, [], 'Browsing must not contact any retailer, wallet or canister')
  for (const link of await links.all()) {
    const destination = new URL(await link.getAttribute('href'))
    const [popup] = await Promise.all([context.waitForEvent('page'), link.click()])
    await popup.waitForLoadState()
    assert.equal(popup.url(), destination.href)
    assert.equal(await popup.evaluate(() => window.opener === null), true)
    await popup.close()
  }
  const [login] = await Promise.all([context.waitForEvent('page'),
    page.getByRole('button', { name: 'Sign in with Internet Identity' }).click()])
  await login.waitForLoadState()
  assert.ok(['https://identity.ic0.app', 'https://id.ai'].includes(new URL(login.url()).origin))
  assert.equal(external.length, 4)
  assert.deepEqual(errors, [])
  console.log('PASS: anonymous storefront, three isolated affiliate handoffs, Internet Identity popup, no unexpected external calls.')
} finally {
  await browser?.close()
  await new Promise(resolve => server.httpServer.close(resolve))
}
