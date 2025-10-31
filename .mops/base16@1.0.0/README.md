## Motoko Base16 (Hex) Library

This library encodes and decodes base16 strings to blobs.

Example:

```
let encoded = Base16.encode(Blob.fromArray([0x00, 0x01, 0x02, 0x03]));
// "00010203"
let decoded = Base16.decode(encoded);
// ?Blob.fromArray([0x00, 0x01, 0x02, 0x03])
```

Decoding returns a `?Blob` because the string may not be valid base16.

### MOPS

```
mops install base16
```

# Testing

```
mops test
```
