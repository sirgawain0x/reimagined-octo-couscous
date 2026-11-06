// Read-only, anonymous certified metadata and ckBTC default-account queries.
import { readFile } from 'node:fs/promises'
import { Actor, CanisterStatus, HttpAgent } from '@dfinity/agent'
import { Principal } from '@dfinity/principal'

const mapping = JSON.parse(await readFile(new URL('../canister_ids.json', import.meta.url), 'utf8'))
const agent = await HttpAgent.create({ host: 'https://icp-api.io' })
const ledger = Actor.createActor(({ IDL }) => IDL.Service({
  icrc1_balance_of: IDL.Func([IDL.Record({ owner: IDL.Principal, subaccount: IDL.Opt(IDL.Vec(IDL.Nat8)) })], [IDL.Nat], ['query']),
}), { agent, canisterId: 'mxzaz-hqaaa-aaaar-qaada-cai' })

for (const name of ['rewards_canister', 'lending_canister', 'swap_canister', 'portfolio_canister']) {
  const canisterId = Principal.fromText(mapping[name].ic)
  const status = await CanisterStatus.request({ agent, canisterId, paths: ['controllers', 'module_hash', 'candid'] })
  const controllers = status.get('controllers')
  const hash = status.get('module_hash')
  if (!controllers || !hash) throw new Error(`Certified metadata unavailable for ${name}`)
  const candid = status.get('candid')
  const ckbtc = await ledger.icrc1_balance_of({ owner: canisterId, subaccount: [] })
  console.log(JSON.stringify({ checkedAt: new Date().toISOString(), name, id: canisterId.toText(),
    controllers: controllers.map(p => p.toText()), moduleHash: hash, ckbtcDefaultSats: ckbtc.toString(),
    advertisedMethods: typeof candid === 'string' ? candid.split('service :').pop().match(/^\s*[\w]+(?=: \()/gm)?.map(s => s.trim()) ?? [] : null }))
}
