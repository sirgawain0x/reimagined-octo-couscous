import { verify } from 'node:crypto'
import { Principal } from '@icp-sdk/core/principal'

// Test protocol: a signed, cumulative USD order snapshot, never a refund delta.
// The actor's configured caller authenticates the second hop to the local canister.
export function verifyOrder(body, signature, publicKey, audience) {
  if (body.length > 4096 || !verify(null, body, publicKey, signature)) {
    throw new Error('Invalid fixture signature or size')
  }
  const order = JSON.parse(body.toString('utf8'))
  if (order.audience !== audience || order.merchant !== 'creative-tv-simulation' || order.currency !== 'USD') {
    throw new Error('Wrong pilot destination, merchant or currency')
  }
  if (!['paid', 'partialRefund', 'cancelled', 'refunded'].includes(order.status) ||
      !Number.isSafeInteger(order.netCents) || order.netCents < 0 ||
      !Number.isSafeInteger(order.revision) || order.revision < 1) {
    throw new Error('Invalid order snapshot')
  }
  for (const id of [order.orderId, order.eventId]) {
    if (typeof id !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(id)) throw new Error('Invalid fixture identifier')
  }
  return {
    merchant: order.merchant, currency: order.currency, shopper: Principal.fromText(order.shopper),
    orderId: order.orderId, eventId: order.eventId, revision: BigInt(order.revision),
    status: { [order.status]: null }, netCents: BigInt(order.netCents),
  }
}
