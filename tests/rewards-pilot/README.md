# Local rewards pilot

Run from this directory with Node 22.12 or later:

```sh
npm ci
npm test
```

The test compiles the rewards canister, starts a temporary PocketIC instance, generates an ephemeral Ed25519 fixture key, and verifies signed synthetic order snapshots before submitting them as the configured verifier. It never contacts a merchant or a live canister. Only a controller can set or revoke the verifier. PocketIC simulates caller identities.

The fixture merchant is `creative-tv-simulation`. Each USD snapshot supplies an order ID, a monotonically increasing revision, the same shopper, and the remaining eligible net amount after refunds. A repeated event cannot credit twice. Conflicting snapshots are rejected, and a cancellation can arrive before the purchase. The actor records the verifier, outcome, and adjustment for each accepted event. Shoppers can read their own test balance. Admins can inspect an event by its ID.

The simulation grants one nonredeemable unit per full dollar, with outstanding caps of 100 per order, 500 per shopper, and 1,000 across the pilot. Exceeding a shopper or campaign cap rejects the entire event without consuming its ID. Reversals release capacity. These are test parameters. Legacy balances and payout paths are separate.

A merchant adapter still needs authenticated records, reliable order-to-shopper attribution, documented revision or reconciliation semantics, and a real source of eligible line totals. This fixture protocol makes no assumptions about xMerch supporting those fields.
