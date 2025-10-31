# Bitcoin Integration with ICP - UTXO Model and Address Generation

## Overview

Bitcoin uses a **UTXO (Unspent Transaction Output) model**, not an account-based model like Ethereum. Each UTXO represents a specific amount of Bitcoin that can be spent, and each UTXO is associated with a Bitcoin address.

## Key Concepts

### UTXO Model

- **UTXO** = Unspent Transaction Output
- Each UTXO is locked to a Bitcoin address (derived from a public key or script)
- To spend Bitcoin, you must reference specific UTXOs and create new UTXOs
- Bitcoin addresses are often used as **single-use invoices** for privacy

### Bitcoin Address Types

#### Legacy Addresses

1. **P2PKH (Pay-to-PubKey-Hash)** - Starts with `1`
   - Encodes the hash of an ECDSA public key
   - Format: `RIPEMD160(SHA256(publicKey))`
   - Example: `1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa`

2. **P2SH (Pay-to-Script-Hash)** - Starts with `3`
   - Encodes the hash of a script
   - Allows complex spending conditions (multisig, timelocks)
   - Example: `3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy`

#### SegWit Addresses (Bech32 format, starts with `bc1`)

3. **P2WPKH (Pay-to-Witness-PubKey-Hash)** - Starts with `bc1q`
   - Cheaper to spend than legacy addresses
   - Solves transaction malleability issues
   - Example: `bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4`

4. **P2WSH (Pay-to-Witness-Script-Hash)** - Starts with `bc1q`
   - SegWit version of P2SH
   - Example: `bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4`

5. **P2TR (Pay-to-Taproot)** - Starts with `bc1p`
   - Most modern and efficient address type
   - Can be unlocked by Schnorr signature or script
   - Example: `bc1p5d7rjq7g6rdk2yhzks9smlaqtedr4dekq08ge8ztwac72sfr9rusxg3297`

## Generating Addresses on ICP

ICP provides two system APIs for generating Bitcoin addresses:

### 1. Threshold ECDSA (`ecdsa_public_key`)

Used for:
- **P2PKH addresses** (legacy)
- **P2SH addresses** (legacy)
- **P2WPKH addresses** (SegWit)

**How it works:**
1. Call `ecdsa_public_key` system API to get the canister's ECDSA public key
2. Hash the public key: `RIPEMD160(SHA256(publicKey))`
3. Encode according to address type:
   - P2PKH: Base58Check with version byte `0x00` (mainnet) or `0x6f` (testnet)
   - P2SH: Base58Check with version byte `0x05` (mainnet) or `0xc4` (testnet)
   - P2WPKH: Bech32 encoding with witness version `0x00`

**Example in Motoko:**
```motoko
public func get_p2pkh_address() : async BitcoinAddress {
  let derivationPath = [Blob.fromArray([0])]; // Use index 0
  let publicKey = await get_ecdsa_public_key(derivationPath);
  let publicKeyHash = hashPublicKey(publicKey);
  generateP2PKH(publicKeyHash, #Mainnet)
};
```

### 2. Threshold Schnorr (`schnorr_public_key`)

Used for:
- **P2TR addresses** (Taproot)

**Two types of P2TR addresses:**

#### Key-Only P2TR Address
- Can only be spent with a Schnorr signature
- No script path committed
- Simplest Taproot address

**Example:**
```motoko
public func get_p2tr_key_only_address() : async BitcoinAddress {
  let derivationPath = [Blob.fromArray([0])]; // Index 0 for key-only
  let xOnlyPublicKey = await get_schnorr_public_key(derivationPath);
  generateP2TRKeyOnly(xOnlyPublicKey, #Mainnet)
};
```

#### Key-or-Script P2TR Address
- Can be spent with either Schnorr signature or script
- Commits to a Merkle root of a script tree
- More flexible but requires script commitment

**Example:**
```motoko
public func get_p2tr_address() : async BitcoinAddress {
  let derivationPath = [Blob.fromArray([1])]; // Index 1 for key-or-script
  let xOnlyPublicKey = await get_schnorr_public_key(derivationPath);
  let merkleRoot = createScriptMerkleRoot(...); // Optional
  generateP2TR(xOnlyPublicKey, merkleRoot, #Mainnet)
};
```

## Implementation in This Project

### Current Status

✅ **Address Types Defined**: All address types (P2PKH, P2SH, P2WPKH, P2WSH, P2TR) are supported in `BitcoinUtils.mo`

⚠️ **ICP Integration Pending**: The actual system API calls need to be implemented in `BitcoinUtilsICP.mo`

### Files

1. **`src/canisters/shared/BitcoinUtils.mo`**
   - Contains address encoding/decoding utilities
   - Uses Base58Check and Bech32 encoding
   - Provides address validation

2. **`src/canisters/shared/BitcoinUtilsICP.mo`** (NEW)
   - Integrates with ICP system APIs
   - Provides wrapper functions for ECDSA/Schnorr public key retrieval
   - Bridges system APIs with BitcoinUtils encoding functions

3. **`src/canisters/shared/BitcoinUtilsStub.mo`**
   - Placeholder implementations for development
   - Used when full Bitcoin libraries aren't available

### Next Steps

1. **Implement System API Calls**
   ```motoko
   // Replace placeholder in BitcoinUtilsICP.mo
   public func getEcdsaPublicKey(derivationPath : DerivationPath) : async Result.Result<[Nat8], Text> {
     // Use IC.canister_sign_with_ecdsa or direct system API
     // Get public key from threshold ECDSA
   }
   ```

2. **Update Canisters to Use ICP APIs**
   - Update `rewards_canister` to generate addresses using `BitcoinUtilsICP`
   - Update `lending_canister` for deposit addresses
   - Update `swap_canister` for ckBTC integration

3. **Test Address Generation**
   ```bash
   # Test P2PKH address generation
   dfx canister call rewards_canister getCanisterRewardAddress

   # Test P2TR address generation
   dfx canister call rewards_canister getP2TRAddress
   ```

## Address Derivation Strategy

For this project, we recommend:

- **Index 0**: P2PKH addresses for main reward distribution
- **Index 1**: P2WPKH addresses for SegWit transactions (lower fees)
- **Index 2**: P2TR addresses for modern Taproot support
- **Index 3+**: Reserved for future use or user-specific addresses

## UTXO Management

When handling Bitcoin deposits:

1. **Monitor UTXOs**: Use ICP Bitcoin API to query UTXOs for your address
   ```motoko
   let utxos = await BitcoinAPI.get_utxos(address, ?min_confirmations);
   ```

2. **Track UTXOs**: Store UTXO information in canister state
   ```motoko
   type UtxoInfo = {
     txid : Text;
     vout : Nat32;
     value : Nat64;
     scriptPubKey : [Nat8];
   };
   ```

3. **Select UTXOs**: When spending, select appropriate UTXOs
   - Sum up values to cover transaction amount + fees
   - Use coin selection algorithm (oldest-first, largest-first, etc.)

## Resources

- [ICP Bitcoin Integration Docs](https://internetcomputer.org/docs/current/developer-docs/integrations/bitcoin/)
- [Bitcoin Address Generation on ICP](https://internetcomputer.org/docs/current/developer-docs/integrations/bitcoin/bitcoin-address-generation)
- [Taproot BIPs](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki):
  - BIP 340: Schnorr Signatures
  - BIP 341: Taproot Addresses
  - BIP 342: Taproot Scripts
- [ECDSA Public Key API](https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-ecdsa_public_key)
- [Schnorr Public Key API](https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-schnorr_public_key)

## Example: Complete Address Generation Flow

```motoko
import BitcoinUtilsICP "BitcoinUtilsICP";
import BitcoinUtils "BitcoinUtils";

public func generateRewardAddress() : async Result.Result<Text, Text> {
  // 1. Create derivation path
  let derivationPath = BitcoinUtilsICP.createDerivationPath(0);
  
  // 2. Get ECDSA public key from ICP
  let publicKeyResult = await BitcoinUtilsICP.getEcdsaPublicKey(derivationPath);
  switch publicKeyResult {
    case (#err(msg)) return #err(msg);
    case (#ok(publicKey)) {
      // 3. Hash the public key
      let publicKeyHash = BitcoinUtils.hashPublicKey(publicKey);
      
      // 4. Generate P2PKH address
      let address = BitcoinUtils.generateAddress(publicKeyHash, #P2PKH);
      
      #ok(address)
    }
  }
};
```

