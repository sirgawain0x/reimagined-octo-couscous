# Solana Transaction Tracking - Implementation Guide

## Overview

To properly track individual SOL deposits and credit them to the correct users, we need to:
1. Query Solana transaction history for the canister's address
2. Parse incoming transactions to identify deposits
3. Track processed transactions to avoid double-crediting
4. Match transactions to users (via memo or transaction signature)

## Solana RPC Methods for Transaction Tracking

### Available Methods (via `jsonRequest`)

1. **`getSignaturesForAddress`** - Get transaction signatures for an address
   - Returns list of transaction signatures
   - Can filter by limit, before/after signatures
   - Useful for getting recent transactions

2. **`getTransaction`** - Get transaction details by signature
   - Returns full transaction data
   - Includes account keys, instructions, signatures
   - Can decode instruction data

3. **`getParsedTransaction`** - Get parsed transaction details
   - Returns human-readable transaction data
   - Easier to parse but requires specific encoding

## Implementation Approaches

### Approach 1: Transaction Signature Tracking (Recommended)

**How it works:**
- User sends SOL to canister address
- User calls `updateSOLBalance()` with their transaction signature
- Canister queries transaction details via RPC
- Verifies transaction is valid and credits user

**Pros:**
- User provides proof of their transaction
- No race conditions
- Can verify transaction authenticity

**Cons:**
- Requires user to provide transaction signature
- More complex user flow

### Approach 2: Automatic Transaction Scanning

**How it works:**
- Periodically scan canister's transaction history
- Parse all incoming transactions
- Track processed transaction signatures
- Credit deposits to users (requires memo or other identification)

**Pros:**
- Automatic - no user action needed
- Can process all deposits

**Cons:**
- Requires memo program for user identification
- Race conditions if multiple users deposit simultaneously
- More complex parsing logic

### Approach 3: Hybrid Approach (Best for Production)

**How it works:**
- User sends SOL with memo instruction (identifies user)
- Canister scans recent transactions
- Parses memo to identify user
- Credits deposit to correct user

**Pros:**
- Automatic processing
- No race conditions (memo identifies user)
- Most user-friendly

**Cons:**
- Requires users to include memo in transaction
- Need to parse memo instruction data

## Recommended Implementation: Transaction Signature Tracking

### Step 1: Add Transaction Tracking State

```motoko
// Track processed transaction signatures to avoid double-crediting
private transient var processedTransactions : HashMap.HashMap<Text, Bool> = HashMap.HashMap(0, Text.equal, Text.hash);

// Track last scanned slot for efficient scanning
private transient var lastScannedSlot : ?Nat64 = null;
```

### Step 2: Update `updateSOLBalance` to Accept Transaction Signature

```motoko
public shared (msg) func updateSOLBalance(
  transactionSignature : ?Text  // Optional: user provides their transaction signature
) : async Result<Nat64, Text> {
  // If signature provided, verify and credit that specific transaction
  // Otherwise, scan recent transactions (less reliable for multi-user)
}
```

### Step 3: Add Transaction Query Functions

```motoko
/// Get transaction signatures for canister address
private func getTransactionSignatures(
  address : Text,
  limit : ?Nat
) : async Result<[Text], Text> {
  // Use jsonRequest to call getSignaturesForAddress
  // Parse response to extract signatures
}

/// Get transaction details by signature
private func getTransactionDetails(
  signature : Text
) : async Result<TransactionDetails, Text> {
  // Use jsonRequest to call getTransaction
  // Parse response to extract:
  // - From address (sender)
  // - To address (recipient - should be canister)
  // - Amount
  // - Memo (if present)
}
```

### Step 4: Parse Transaction to Identify Deposits

```motoko
/// Parse Solana transaction to extract transfer information
private func parseTransferTransaction(
  txData : Text  // JSON response from getTransaction
) : Result<TransferInfo, Text> {
  // Parse JSON to extract:
  // - Instruction type (System Program Transfer = 2)
  // - From account
  // - To account
  // - Amount (lamports)
  // - Memo instruction (if present)
}
```

## Implementation with Memo Program (Best User Experience)

### Using Solana Memo Program

The Solana Memo Program allows adding text memos to transactions. Users can include their Principal ID or a unique identifier in the memo.

**Transaction Structure:**
- System Program Transfer instruction (sends SOL)
- Memo Program instruction (contains user identifier)

**Memo Program ID:** `MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr`

### Implementation Steps

1. **User Flow:**
   - User gets canister address via `getCanisterSolanaAddress()`
   - User creates transaction with:
     - Transfer instruction (SOL to canister)
     - Memo instruction (contains user's Principal ID as text)
   - User signs and sends transaction
   - User calls `updateSOLBalance()` (no signature needed)

2. **Canister Processing:**
   - Scan recent transactions for canister address
   - Parse each transaction:
     - Check if it's a transfer to canister
     - Extract memo instruction
     - Parse memo to get user Principal
     - Credit deposit to that user
   - Track processed signatures

## Code Example: Transaction Scanning

```motoko
/// Scan recent transactions and credit deposits
private func scanRecentTransactions(
  canisterAddress : Text,
  limit : Nat
) : async Result<(), Text> {
  // 1. Get recent transaction signatures
  let signaturesResult = await getTransactionSignatures(canisterAddress, ?limit);
  let signatures = switch (signaturesResult) {
    case (#ok(sigs)) sigs;
    case (#err(e)) return #err("Failed to get signatures: " # e);
  };
  
  // 2. Process each transaction
  for (sig in signatures.vals()) {
    // Skip if already processed
    if (Option.isSome(processedTransactions.get(sig))) {
      continue;
    };
    
    // Get transaction details
    let txResult = await getTransactionDetails(sig);
    switch (txResult) {
      case (#ok(tx)) {
        // Parse transaction
        let transferResult = parseTransferTransaction(tx);
        switch (transferResult) {
          case (#ok(transfer)) {
            // Verify it's a deposit to canister
            if (transfer.to == canisterAddress) {
              // Extract user from memo or use sender address mapping
              let userId = extractUserFromTransaction(transfer);
              
              // Credit deposit
              creditDeposit(userId, transfer.amount);
              
              // Mark as processed
              processedTransactions.put(sig, true);
            };
          };
          case (#err(_)) {}; // Skip invalid transactions
        };
      };
      case (#err(_)) {}; // Skip failed lookups
    };
  };
  
  #ok(())
}
```

## Alternative: Simple Signature-Based Approach

For a simpler initial implementation:

```motoko
/// Update SOL balance using transaction signature
public shared (msg) func updateSOLBalanceWithSignature(
  transactionSignature : Text
) : async Result<Nat64, Text> {
  // 1. Check if already processed
  if (Option.isSome(processedTransactions.get(transactionSignature))) {
    return #err("Transaction already processed");
  };
  
  // 2. Get transaction details
  let txResult = await getTransactionDetails(transactionSignature);
  let tx = switch (txResult) {
    case (#ok(t)) t;
    case (#err(e)) return #err("Failed to get transaction: " # e);
  };
  
  // 3. Verify transaction
  // - Verify recipient is canister address
  // - Verify transaction is finalized
  // - Verify amount > 0
  
  // 4. Credit deposit to calling user
  let amount = tx.amount;
  let userBalance = switch (solBalances.get(msg.caller)) {
    case null 0 : Nat64;
    case (?bal) bal;
  };
  solBalances.put(msg.caller, userBalance + amount);
  
  // 5. Mark as processed
  processedTransactions.put(transactionSignature, true);
  
  #ok(amount)
}
```

## JSON Request Format for Solana RPC

```motoko
// Example: Get signatures for address
let method = "getSignaturesForAddress";
let params = [
  canisterAddress,           // address
  ?{
    limit = ?10;             // number of signatures
    before = null;           // signature to start before
    until = null;            // signature to end before
  }
];
let response = await solRpcClient.jsonRequest(rpcSources, rpcConfig, method, ?params);

// Example: Get transaction details
let method = "getTransaction";
let params = [
  signature,                 // transaction signature
  ?{
    encoding = "jsonParsed"; // or "base58", "base64"
    maxSupportedTransactionVersion = ?0;
    commitment = "finalized";
  }
];
let response = await solRpcClient.jsonRequest(rpcSources, rpcConfig, method, ?params);
```

## Next Steps

1. **Implement JSON parsing** - Parse Solana RPC JSON responses
2. **Add transaction tracking state** - Track processed signatures
3. **Implement transaction query functions** - Use `jsonRequest` for transaction history
4. **Add memo parsing** - Extract user identifier from memo instructions
5. **Update `updateSOLBalance`** - Use transaction scanning or signature verification

## Recommended: Start with Signature-Based Approach

For initial implementation, use the signature-based approach:
- User provides transaction signature when calling `updateSOLBalance`
- Simpler to implement
- No race conditions
- Can verify transaction authenticity
- Can be enhanced later with automatic scanning

