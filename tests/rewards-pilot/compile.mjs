import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import mo from 'motoko'

const root = fileURLToPath(new URL('../../', import.meta.url))
function load(directory) {
  for (const file of fs.readdirSync(path.join(root, directory), { withFileTypes: true })) {
    const name = path.posix.join(directory, file.name)
    if (file.isDirectory()) load(name)
    else if (name.endsWith('.mo')) mo.write(name, fs.readFileSync(path.join(root, name), 'utf8'))
  }
}
export function compileRewards() {
  const base = '.mops/base@0.16.0/src'
  load(base)
  mo.usePackage('base', base)
  load('src/canisters/rewards')
  load('src/canisters/shared')
  return mo.wasm('src/canisters/rewards/main.mo', 'ic').wasm
}
