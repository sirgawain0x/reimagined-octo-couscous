# RIPEMD-160 for Motoko

A pure Motoko implementation of the RIPEMD-160 cryptographic hash function for the Internet Computer Platform (ICP).

## Overview

RIPEMD-160 (RACE Integrity Primitives Evaluation Message Digest) is a cryptographic hash function that produces a 160-bit (20-byte) hash digest. It was developed as an open alternative to the SHA-1 and MD5 hash functions and is widely used in cryptocurrency applications, particularly Bitcoin for address generation.

This implementation provides a secure, efficient, and easy-to-use RIPEMD-160 hasher written entirely in Motoko, with no external dependencies.

## Features

- ✅ **Pure Motoko**: No external dependencies or system calls
- ✅ **Secure**: Implements the full RIPEMD-160 specification with proper padding
- ✅ **Tested**: Passes all official RIPEMD-160 test vectors
- ✅ **Efficient**: Optimized for the Internet Computer platform
- ✅ **Type-safe**: Leverages Motoko's type system for memory safety

## Installation

Add this package to your `mops.toml`:

```toml
[dependencies]
ripemd160 = "^0.1.0"
```

Or install via mops CLI:

```bash
mops add ripemd160
```

## Usage

### Basic Example

```motoko
import RIPEMD160 "mo:ripemd160";
import Text "mo:base/Text";

let hasher = RIPEMD160.RIPEMD160();

// Hash a string
let message = "Hello, Internet Computer!";
let messageBytes = Text.encodeUtf8(message);
let hashBytes = hasher.hash(messageBytes);

// Convert to hex string for display
let hexHash = Array.foldLeft<Nat8, Text>(hashBytes, "", func(acc, byte) {
    acc # (if (Nat8.toNat(byte) < 16) "0" else "") # Nat.toText(Nat8.toNat(byte), #hex)
});
```

### Bitcoin Address Generation Example

```motoko
import RIPEMD160 "mo:ripemd160";
import SHA256 "mo:sha256"; // Assuming you have SHA256 available

let hasher = RIPEMD160.RIPEMD160();

// Bitcoin uses RIPEMD-160(SHA-256(publicKey))
func generateBitcoinAddress(publicKeyBytes: [Nat8]) : [Nat8] {
    let sha256Hash = SHA256.hash(publicKeyBytes);
    let ripemd160Hash = hasher.hash(sha256Hash);
    ripemd160Hash
};
```

### Working with Different Input Types

```motoko
import RIPEMD160 "mo:ripemd160";
import Text "mo:base/Text";
import Blob "mo:base/Blob";

let hasher = RIPEMD160.RIPEMD160();

// Hash a text string
let textHash = hasher.hash(Text.encodeUtf8("hello world"));

// Hash a Blob
let blobData = Blob.fromArray([1, 2, 3, 4, 5]);
let blobHash = hasher.hash(Blob.toArray(blobData));

// Hash raw bytes
let rawBytes : [Nat8] = [0x48, 0x65, 0x6c, 0x6c, 0x6f];
let rawHash = hasher.hash(rawBytes);
```

## API Reference

### `RIPEMD160` Class

#### Constructor

```motoko
public class RIPEMD160()
```

Creates a new RIPEMD-160 hasher instance.

#### Methods

##### `hash(message: [Nat8]) : [Nat8]`

Computes the RIPEMD-160 hash of the input message.

**Parameters:**
- `message: [Nat8]` - The input message as an array of bytes

**Returns:**
- `[Nat8]` - The 160-bit (20-byte) hash digest

**Example:**
```motoko
let hasher = RIPEMD160.RIPEMD160();
let input = [0x61, 0x62, 0x63]; // "abc" in ASCII
let hash = hasher.hash(input);
// hash = [0x8e, 0xb2, 0x08, 0xf7, 0xe0, 0x5d, 0x98, 0x7a, 0x9b, 0x04, 0x4a, 0x8e, 0x98, 0xc6, 0xb0, 0x87, 0xf1, 0x5a, 0x0b, 0xfc]
```

## Test Vectors

This implementation passes all official RIPEMD-160 test vectors:

| Input | Expected Hash (hex) |
|-------|-------------------|
| `""` (empty) | `9c1185a5c5e9fc54612808977ee8f548b2258d31` |
| `"a"` | `0bdc9d2d256b3ee9daae347be6f4dc835a467ffe` |
| `"abc"` | `8eb208f7e05d987a9b044a8e98c6b087f15a0bfc` |
| `"message digest"` | `5d0689ef49d2fae572b881b123a85ffa21595f36` |
| `"abcdefghijklmnopqrstuvwxyz"` | `f71c27109c692c1b56bbdceb5b9d2865b3708dbc` |

## Algorithm Details

RIPEMD-160 operates on 512-bit (64-byte) blocks and uses:
- **Two parallel processing lines** (left and right)
- **Five rounds of 16 operations each** (80 operations total per line)
- **Message scheduling** with different permutations for each line
- **Merkle-Damgård padding** (same as MD5/SHA-1)

The algorithm produces a 160-bit digest that is resistant to collision and preimage attacks.

## Security Considerations

- RIPEMD-160 is considered cryptographically secure for most applications
- While not broken, SHA-256 or SHA-3 may be preferred for new applications
- This implementation uses safe arithmetic to prevent overflow attacks
- Always use this library with proper input validation in production

## Performance

This implementation is optimized for the Internet Computer's WebAssembly runtime:
- Uses efficient 32-bit arithmetic with wrapping operations
- Minimizes memory allocations
- Processes messages in streaming fashion for large inputs

## Contributing

Contributions are welcome! Please ensure:
- All tests pass (`mops test`)
- Code follows Motoko style guidelines
- New features include appropriate tests
- Documentation is updated

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## References

- [RIPEMD-160 Official Specification](https://homes.esat.kuleuven.be/~bosselae/ripemd160.html)
- [RFC 1320 - MD4 Message-Digest Algorithm](https://tools.ietf.org/html/rfc1320) (for padding scheme)
- [Bitcoin Protocol Documentation](https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses)

## Changelog

### v0.1.2
- Rename ripemd160.mo to lib.mo
- Rename ripemd160.test.mo to lib.test.mo

### v0.1.1
- Removed unused utils functions

### v0.1.0
- Initial release
- Full RIPEMD-160 implementation
- Passes all official test vectors
- Optimized for Internet Computer platform