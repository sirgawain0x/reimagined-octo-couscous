import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";

module {
  // RIPEMD-160 implementation in Motoko
  public class RIPEMD160() {
    // Selection of message word
    private let r : [Nat] = [
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
      7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8,
      3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12,
      1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2,
      4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13
    ];

    private let rh : [Nat] = [
      5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12,
      6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2,
      15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13,
      8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14,
      12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11
    ];

    // Amount for rotate left (rol)
    private let s : [Nat] = [
      11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8,
      7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12,
      11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5,
      11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12,
      9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6
    ];

    private let sh : [Nat] = [
      8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6,
      9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11,
      9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5,
      15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8,
      8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11
    ];

    // Initial hash values
    private var h0 : Nat32 = 0x67452301;
    private var h1 : Nat32 = 0xEFCDAB89;
    private var h2 : Nat32 = 0x98BADCFE;
    private var h3 : Nat32 = 0x10325476;
    private var h4 : Nat32 = 0xC3D2E1F0;

    // Helper functions
    private func rol(n : Nat32, b : Nat) : Nat32 {
      let shift = Nat32.fromNat(b % 32);
      (n << shift) | (n >> (32 - shift))
    };

    private func f(j : Nat, x : Nat32, y : Nat32, z : Nat32) : Nat32 {
      if (j < 16) {
        x ^ y ^ z
      } else if (j < 32) {
        (x & y) | ((^x) & z)
      } else if (j < 48) {
        (x | (^y)) ^ z
      } else if (j < 64) {
        (x & z) | (y & (^z))
      } else {
        x ^ (y | (^z))
      }
    };

    private func K(j : Nat) : Nat32 {
      if (j < 16) {
        0x00000000
      } else if (j < 32) {
        0x5A827999
      } else if (j < 48) {
        0x6ED9EBA1
      } else if (j < 64) {
        0x8F1BBCDC
      } else {
        0xA953FD4E
      }
    };

    private func Kh(j : Nat) : Nat32 {
      if (j < 16) {
        0x50A28BE6
      } else if (j < 32) {
        0x5C4DD124
      } else if (j < 48) {
        0x6D703EF3
      } else if (j < 64) {
        0x7A6D76E9
      } else {
        0x00000000
      }
    };

    private func padMessage(message : [Nat8]) : [Nat8] {
      let msgLen = message.size();
      let msgBitLen = msgLen * 8;
      
      // Start with message + mandatory 0x80 byte
      let buffer = Buffer.Buffer<Nat8>(msgLen + 72); // enough space
      
      // Copy original message
      for (byte in message.vals()) {
        buffer.add(byte);
      };
      
      // Add mandatory 0x80 byte  
      buffer.add(0x80);
      
      // Add zero bytes until length ≡ 56 (mod 64)
      // This ensures that after adding 8 bytes for length, total ≡ 0 (mod 64)
      while (buffer.size() % 64 != 56) {
        buffer.add(0x00);
      };
      
      // Append original length in bits as 64-bit little-endian integer
      let len64 = Nat64.fromNat(msgBitLen);
      for (i in Iter.range(0, 7)) {
        let byte = Nat8.fromNat(Nat64.toNat((len64 >> (Nat64.fromNat(i * 8))) & (0xFF : Nat64)));
        buffer.add(byte);
      };
      
      buffer.toArray()
    };

    private func processChunk(chunk : [Nat8]) {
      // Break chunk into sixteen 32-bit little-endian words
      var w = Array.init<Nat32>(16, 0);
      for (i in Iter.range(0, 15)) {
        let idx = i * 4;
        w[i] := Nat32.fromNat(Nat8.toNat(chunk[idx])) |
               (Nat32.fromNat(Nat8.toNat(chunk[idx + 1])) << 8) |
               (Nat32.fromNat(Nat8.toNat(chunk[idx + 2])) << 16) |
               (Nat32.fromNat(Nat8.toNat(chunk[idx + 3])) << 24);
      };

      // Initialize hash value for this chunk
      var al = h0; var bl = h1; var cl = h2; var dl = h3; var el = h4;
      var ar = h0; var br = h1; var cr = h2; var dr = h3; var er = h4;

      // Main loop
      for (j in Iter.range(0, 79)) {
        var t = al +% f(j, bl, cl, dl) +% w[r[j]] +% K(j);
        t := rol(t, s[j]) +% el;
        al := el; el := dl; dl := rol(cl, 10); cl := bl; bl := t;

        t := ar +% f(79 - j, br, cr, dr) +% w[rh[j]] +% Kh(j);
        t := rol(t, sh[j]) +% er;
        ar := er; er := dr; dr := rol(cr, 10); cr := br; br := t;
      };

      // Add this chunk's hash to result so far
      let t = h1 +% cl +% dr;
      h1 := h2 +% dl +% er;
      h2 := h3 +% el +% ar;
      h3 := h4 +% al +% br;
      h4 := h0 +% bl +% cr;
      h0 := t;
    };

    public func hash(message : [Nat8]) : [Nat8] {
      // Initialize hash values
      h0 := 0x67452301;
      h1 := 0xEFCDAB89;
      h2 := 0x98BADCFE;
      h3 := 0x10325476;
      h4 := 0xC3D2E1F0;

      // Pad message
      let padded = padMessage(message);

      // Process message in 64-byte chunks
      let chunkCount = padded.size() / 64;
      if (chunkCount > 0) {
        for (i in Iter.range(0, chunkCount - 1)) {
          let chunk = Array.tabulate<Nat8>(64, func(j : Nat) : Nat8 {
            padded[i * 64 + j]
          });
          processChunk(chunk);
        };
      };

      // Produce the final hash value as a 160-bit number (little-endian)
      let result = Buffer.Buffer<Nat8>(20);
      for (h in [h0, h1, h2, h3, h4].vals()) {
        result.add(Nat8.fromNat(Nat32.toNat(h & (0xFF : Nat32))));
        result.add(Nat8.fromNat(Nat32.toNat((h >> 8) & (0xFF : Nat32))));
        result.add(Nat8.fromNat(Nat32.toNat((h >> 16) & (0xFF : Nat32))));
        result.add(Nat8.fromNat(Nat32.toNat((h >> 24) & (0xFF : Nat32))));
      };

      result.toArray()
    };
  };
}