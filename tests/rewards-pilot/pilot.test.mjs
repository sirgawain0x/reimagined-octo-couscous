import assert from 'node:assert/strict'
import { generateKeyPairSync, sign } from 'node:crypto'
import { test } from 'node:test'
import { PocketIc, PocketIcServer } from '@dfinity/pic'
import { Principal } from '@icp-sdk/core/principal'
import { compileRewards } from './compile.mjs'
import { verifyOrder } from './verify-order.mjs'

function pilotInterface({ IDL: i }) {
  const variants = names => i.Variant(Object.fromEntries(names.map(name => [name, i.Null])))
  const result = ok => i.Variant({ ok, err: i.Text })
  const outcome = variants(['applied', 'duplicate', 'stale'])
  const event = i.Record({
    merchant: i.Text, currency: i.Text, eventId: i.Text, orderId: i.Text, revision: i.Nat64,
    shopper: i.Principal, status: variants(['paid', 'partialRefund', 'refunded', 'cancelled']), netCents: i.Nat64,
  })
  return i.Service({
    setPilotVerifier: i.Func([i.Opt(i.Principal)], [result(i.Null)], []),
    recordPilotOrder: i.Func([event], [result(outcome)], []),
    getMyPilotUnits: i.Func([], [i.Nat], ['query']),
    getPilotEntry: i.Func([i.Text], [i.Opt(i.Record({ delta: i.Int, outcome, verifier: i.Principal }))], ['query']),
    claimRewards: i.Func([], [result(i.Reserved)], []),
    getUserRewards: i.Func([i.Principal], [i.Nat64], ['query']),
  })
}

test('signed synthetic orders, reversals, caps and upgrades on a local replica', async t => {
  const wasm = compileRewards()
  const server = await PocketIcServer.start()
  t.after(() => server.stop())
  const pic = await PocketIc.create(server.getUrl())
  try {
    const principal = n => Principal.selfAuthenticating(Uint8Array.of(n))
    const owner = principal(1), verifier = principal(2), shopper = principal(3)
    const canisterId = await pic.createCanister({ sender: owner, controllers: [owner] })
    await pic.installCode({ canisterId, sender: owner, wasm })
    const actor = sender => pic.createActor({ canisterId, sender, idlFactory: pilotInterface })
    const admin = actor(owner), ingress = actor(verifier), buyer = actor(shopper)
    const { privateKey, publicKey } = generateKeyPairSync('ed25519')
    const audience = 'local-rewards/' + canisterId.toText()
    const purchase = { audience, merchant: 'creative-tv-simulation', currency: 'USD',
      eventId: 'payment', orderId: 'shirt', revision: 1, status: 'paid', netCents: 15000, shopper: shopper.toText() }
    function fixture(changes = {}) {
      const body = Buffer.from(JSON.stringify({ ...purchase, ...changes }))
      return verifyOrder(body, sign(null, body, privateKey), publicKey, audience)
    }
    const submit = changes => ingress.recordPilotOrder(fixture(changes))
    const expectOutcome = (reply, expected) => assert.deepEqual(reply, { ok: { [expected]: null } })
    const raw = Buffer.from(JSON.stringify(purchase))
    assert.throws(() => verifyOrder(Buffer.concat([raw, Buffer.from(' ')]), sign(null, raw, privateKey), publicKey, audience))
    assert.throws(() => fixture({ audience: 'other-canister' }))
    assert.throws(() => fixture({ merchant: 'other-store' }))
    assert.throws(() => fixture({ netCents: -1 }))
    assert.ok((await submit({})).err)
    assert.ok((await buyer.setPilotVerifier([shopper])).err)
    assert.ok((await admin.setPilotVerifier([Principal.anonymous()])).err)
    assert.deepEqual(await admin.setPilotVerifier([verifier]), { ok: null })
    assert.ok((await buyer.recordPilotOrder(fixture())).err)
    const simultaneous = await Promise.all([submit({}), submit({})])
    assert.deepEqual(simultaneous.map(reply => Object.keys(reply.ok)[0]).sort(), ['applied', 'duplicate'])
    expectOutcome(await submit({}), 'duplicate')
    expectOutcome(await submit({ eventId: 'second-delivery' }), 'duplicate')
    assert.ok((await submit({ netCents: 999 })).err)
    assert.ok((await submit({ eventId: 'conflict', netCents: 999 })).err)
    assert.ok((await submit({ eventId: 'reassigned', shopper: owner.toText() })).err)
    assert.equal(await buyer.getMyPilotUnits(), 100n)
    assert.equal(await buyer.getUserRewards(shopper), 0n)
    assert.ok((await buyer.claimRewards()).err)
    await pic.upgradeCanister({ canisterId, sender: owner, wasm,
      upgradeModeOptions: { skip_pre_upgrade: [], wasm_memory_persistence: [{ keep: null }] } })
    assert.equal(await buyer.getMyPilotUnits(), 100n)
    expectOutcome(await submit({}), 'duplicate')
    expectOutcome(await submit({ eventId: 'partial', revision: 2, status: 'partialRefund', netCents: 6000 }), 'applied')
    assert.equal(await buyer.getMyPilotUnits(), 60n)
    assert.deepEqual(await buyer.getPilotEntry('partial'), [])
    const [entry] = await admin.getPilotEntry('partial')
    assert.equal(entry.delta, -40n)
    assert.equal(entry.verifier.toText(), verifier.toText())
    expectOutcome(await submit({ eventId: 'full', revision: 3, status: 'refunded', netCents: 0 }), 'applied')
    expectOutcome(await submit({ eventId: 'cancel', orderId: 'hoodie', revision: 2, status: 'cancelled', netCents: 0 }), 'applied')
    expectOutcome(await submit({ eventId: 'late', orderId: 'hoodie' }), 'stale')
    assert.ok((await submit({ eventId: 'resurrect', orderId: 'hoodie', revision: 3 })).err)
    assert.equal(await buyer.getMyPilotUnits(), 0n)
    for (const user of [shopper, principal(4)]) {
      for (let n = 0; n < 5; n++) {
        const id = 'cap-' + user.toText() + '-' + n
        expectOutcome(await submit({ eventId: id, orderId: id, shopper: user.toText() }), 'applied')
      }
      assert.equal(await actor(user).getMyPilotUnits(), 500n)
      assert.ok((await submit({ eventId: 'over-user', orderId: 'over-user', shopper: user.toText() })).err)
    }
    assert.ok((await submit({ eventId: 'over-budget', orderId: 'over-budget', shopper: principal(5).toText() })).err)
    assert.deepEqual(await admin.setPilotVerifier([]), { ok: null })
    assert.ok((await submit({})).err)
  } finally {
    await pic.tearDown()
  }
})
