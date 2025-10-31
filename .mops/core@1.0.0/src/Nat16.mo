/// Utility functions on 16-bit unsigned integers.
///
/// Note that most operations are available as built-in operators (e.g. `1 + 1`).
///
/// Import from the core library to use this module.
/// ```motoko name=import
/// import Nat16 "mo:core/Nat16";
/// ```
import Nat "Nat";
import Iter "Iter";
import Prim "mo:⛔";
import Order "Order";

module {

  /// 16-bit natural numbers.
  public type Nat16 = Prim.Types.Nat16;

  /// Maximum 16-bit natural number. `2 ** 16 - 1`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.maxValue == (65535 : Nat16);
  /// ```
  public let maxValue : Nat16 = 65535;

  /// Converts a 16-bit unsigned integer to an unsigned integer with infinite precision.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.toNat(123) == (123 : Nat);
  /// ```
  public let toNat : Nat16 -> Nat = Prim.nat16ToNat;

  /// Converts an unsigned integer with infinite precision to a 16-bit unsigned integer.
  ///
  /// Traps on overflow.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.fromNat(123) == (123 : Nat16);
  /// ```
  public let fromNat : Nat -> Nat16 = Prim.natToNat16;

  /// Converts an 8-bit unsigned integer to a 16-bit unsigned integer.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.fromNat8(123) == (123 : Nat16);
  /// ```
  public func fromNat8(x : Nat8) : Nat16 {
    Prim.nat8ToNat16(x)
  };

  /// Converts a 16-bit unsigned integer to an 8-bit unsigned integer.
  ///
  /// Traps on overflow.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.toNat8(123) == (123 : Nat8);
  /// ```
  public func toNat8(x : Nat16) : Nat8 {
    Prim.nat16ToNat8(x)
  };

  /// Converts a 32-bit unsigned integer to a 16-bit unsigned integer.
  ///
  /// Traps on overflow.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.fromNat32(123) == (123 : Nat16);
  /// ```
  public func fromNat32(x : Nat32) : Nat16 {
    Prim.nat32ToNat16(x)
  };

  /// Converts a 16-bit unsigned integer to a 32-bit unsigned integer.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.toNat32(123) == (123 : Nat32);
  /// ```
  public func toNat32(x : Nat16) : Nat32 {
    Prim.nat16ToNat32(x)
  };

  /// Converts a signed integer with infinite precision to a 16-bit unsigned integer.
  ///
  /// Wraps on overflow/underflow.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.fromIntWrap(123 : Int) == (123 : Nat16);
  /// ```
  public let fromIntWrap : Int -> Nat16 = Prim.intToNat16Wrap;

  /// Converts `x` to its textual representation. Textual representation _do not_
  /// contain underscores to represent commas.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.toText(1234) == ("1234" : Text);
  /// ```
  public func toText(x : Nat16) : Text {
    Nat.toText(toNat(x))
  };

  /// Returns the minimum of `x` and `y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.min(123, 200) == (123 : Nat16);
  /// ```
  public func min(x : Nat16, y : Nat16) : Nat16 {
    if (x < y) { x } else { y }
  };

  /// Returns the maximum of `x` and `y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.max(123, 200) == (200 : Nat16);
  /// ```
  public func max(x : Nat16, y : Nat16) : Nat16 {
    if (x < y) { y } else { x }
  };

  /// Equality function for Nat16 types.
  /// This is equivalent to `x == y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.equal(1, 1);
  /// assert (1 : Nat16) == (1 : Nat16);
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `==` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `==`
  /// as a function value at the moment.
  ///
  /// Example:
  /// ```motoko include=import
  /// let a : Nat16 = 111;
  /// let b : Nat16 = 222;
  /// assert not Nat16.equal(a, b);
  /// ```
  public func equal(x : Nat16, y : Nat16) : Bool { x == y };

  /// Inequality function for Nat16 types.
  /// This is equivalent to `x != y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.notEqual(1, 2);
  /// assert (1 : Nat16) != (2 : Nat16);
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `!=` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `!=`
  /// as a function value at the moment.
  public func notEqual(x : Nat16, y : Nat16) : Bool { x != y };

  /// "Less than" function for Nat16 types.
  /// This is equivalent to `x < y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.less(1, 2);
  /// assert (1 : Nat16) < (2 : Nat16);
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `<` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `<`
  /// as a function value at the moment.
  public func less(x : Nat16, y : Nat16) : Bool { x < y };

  /// "Less than or equal" function for Nat16 types.
  /// This is equivalent to `x <= y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.lessOrEqual(1, 2);
  /// assert (1 : Nat16) <= (2 : Nat16);
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `<=` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `<=`
  /// as a function value at the moment.
  public func lessOrEqual(x : Nat16, y : Nat16) : Bool { x <= y };

  /// "Greater than" function for Nat16 types.
  /// This is equivalent to `x > y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.greater(2, 1);
  /// assert (2 : Nat16) > (1 : Nat16);
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `>` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `>`
  /// as a function value at the moment.
  public func greater(x : Nat16, y : Nat16) : Bool { x > y };

  /// "Greater than or equal" function for Nat16 types.
  /// This is equivalent to `x >= y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.greaterOrEqual(2, 1);
  /// assert (2 : Nat16) >= (1 : Nat16);
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `>=` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `>=`
  /// as a function value at the moment.
  public func greaterOrEqual(x : Nat16, y : Nat16) : Bool { x >= y };

  /// General purpose comparison function for `Nat16`. Returns the `Order` (
  /// either `#less`, `#equal`, or `#greater`) of comparing `x` with `y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.compare(2, 3) == #less;
  /// ```
  ///
  /// This function can be used as value for a high order function, such as a sort function.
  ///
  /// Example:
  /// ```motoko include=import
  /// import Array "mo:core/Array";
  /// assert Array.sort([2, 3, 1] : [Nat16], Nat16.compare) == [1, 2, 3];
  /// ```
  public func compare(x : Nat16, y : Nat16) : Order.Order {
    if (x < y) { #less } else if (x == y) { #equal } else { #greater }
  };

  /// Returns the sum of `x` and `y`, `x + y`.
  /// Traps on overflow.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.add(1, 2) == 3;
  /// assert (1 : Nat16) + (2 : Nat16) == 3;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `+` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `+`
  /// as a function value at the moment.
  ///
  /// Example:
  /// ```motoko include=import
  /// import Array "mo:core/Array";
  /// assert Array.foldLeft<Nat16, Nat16>([2, 3, 1], 0, Nat16.add) == 6;
  /// ```
  public func add(x : Nat16, y : Nat16) : Nat16 { x + y };

  /// Returns the difference of `x` and `y`, `x - y`.
  /// Traps on underflow.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.sub(2, 1) == 1;
  /// assert (2 : Nat16) - (1 : Nat16) == 1;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `-` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `-`
  /// as a function value at the moment.
  ///
  /// Example:
  /// ```motoko include=import
  /// import Array "mo:core/Array";
  /// assert Array.foldLeft<Nat16, Nat16>([2, 3, 1], 20, Nat16.sub) == 14;
  /// ```
  public func sub(x : Nat16, y : Nat16) : Nat16 { x - y };

  /// Returns the product of `x` and `y`, `x * y`.
  /// Traps on overflow.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.mul(2, 3) == 6;
  /// assert (2 : Nat16) * (3 : Nat16) == 6;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `*` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `*`
  /// as a function value at the moment.
  ///
  /// Example:
  /// ```motoko include=import
  /// import Array "mo:core/Array";
  /// assert Array.foldLeft<Nat16, Nat16>([2, 3, 1], 1, Nat16.mul) == 6;
  /// ```
  public func mul(x : Nat16, y : Nat16) : Nat16 { x * y };

  /// Returns the quotient of `x` divided by `y`, `x / y`.
  /// Traps when `y` is zero.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.div(6, 2) == 3;
  /// assert (6 : Nat16) / (2 : Nat16) == 3;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `/` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `/`
  /// as a function value at the moment.
  public func div(x : Nat16, y : Nat16) : Nat16 { x / y };

  /// Returns the remainder of `x` divided by `y`, `x % y`.
  /// Traps when `y` is zero.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.rem(6, 4) == 2;
  /// assert (6 : Nat16) % (4 : Nat16) == 2;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `%` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `%`
  /// as a function value at the moment.
  public func rem(x : Nat16, y : Nat16) : Nat16 { x % y };

  /// Returns the power of `x` to `y`, `x ** y`.
  /// Traps on overflow.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.pow(2, 3) == 8;
  /// assert (2 : Nat16) ** (3 : Nat16) == 8;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `**` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `**`
  /// as a function value at the moment.
  public func pow(x : Nat16, y : Nat16) : Nat16 { x ** y };

  /// Returns the bitwise negation of `x`, `^x`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.bitnot(0) == 65535;
  /// assert ^(0 : Nat16) == 65535;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `^` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `^`
  /// as a function value at the moment.
  public func bitnot(x : Nat16) : Nat16 { ^x };

  /// Returns the bitwise and of `x` and `y`, `x & y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.bitand(0, 1) == 0;
  /// assert (0 : Nat16) & (1 : Nat16) == 0;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `&` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `&`
  /// as a function value at the moment.
  public func bitand(x : Nat16, y : Nat16) : Nat16 { x & y };

  /// Returns the bitwise or of `x` and `y`, `x | y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.bitor(0, 1) == 1;
  /// assert (0 : Nat16) | (1 : Nat16) == 1;
  /// ```
  public func bitor(x : Nat16, y : Nat16) : Nat16 { x | y };

  /// Returns the bitwise exclusive or of `x` and `y`, `x ^ y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.bitxor(0, 1) == 1;
  /// assert (0 : Nat16) ^ (1 : Nat16) == 1;
  /// ```
  public func bitxor(x : Nat16, y : Nat16) : Nat16 { x ^ y };

  /// Returns the bitwise shift left of `x` by `y`, `x << y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.bitshiftLeft(1, 3) == 8;
  /// assert (1 : Nat16) << (3 : Nat16) == 8;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `<<` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `<<`
  /// as a function value at the moment.
  public func bitshiftLeft(x : Nat16, y : Nat16) : Nat16 { x << y };

  /// Returns the bitwise shift right of `x` by `y`, `x >> y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.bitshiftRight(8, 3) == 1;
  /// assert (8 : Nat16) >> (3 : Nat16) == 1;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `>>` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `>>`
  /// as a function value at the moment.
  public func bitshiftRight(x : Nat16, y : Nat16) : Nat16 { x >> y };

  /// Returns the bitwise rotate left of `x` by `y`, `x <<> y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.bitrotLeft(2, 1) == 4;
  /// assert (2 : Nat16) <<> (1 : Nat16) == 4;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `<<>` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `<<>`
  /// as a function value at the moment.
  public func bitrotLeft(x : Nat16, y : Nat16) : Nat16 { x <<> y };

  /// Returns the bitwise rotate right of `x` by `y`, `x <>> y`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.bitrotRight(1, 1) == 32768;
  /// assert (1 : Nat16) <>> (1 : Nat16) == 32768;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `<>>` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `<>>`
  /// as a function value at the moment.
  public func bitrotRight(x : Nat16, y : Nat16) : Nat16 { x <>> y };

  /// Returns the value of bit `p mod 16` in `x`, `(x & 2^(p mod 16)) == 2^(p mod 16)`.
  /// This is equivalent to checking if the `p`-th bit is set in `x`, using 0 indexing.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.bittest(5, 2);
  /// ```
  public func bittest(x : Nat16, p : Nat) : Bool {
    Prim.btstNat16(x, Prim.natToNat16(p))
  };

  /// Returns the value of setting bit `p mod 16` in `x` to `1`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.bitset(0, 2) == 4;
  /// ```
  public func bitset(x : Nat16, p : Nat) : Nat16 {
    x | (1 << Prim.natToNat16(p))
  };

  /// Returns the value of clearing bit `p mod 16` in `x` to `0`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.bitclear(5, 2) == 1;
  /// ```
  public func bitclear(x : Nat16, p : Nat) : Nat16 {
    x & ^(1 << Prim.natToNat16(p))
  };

  /// Returns the value of flipping bit `p mod 16` in `x`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.bitflip(5, 2) == 1;
  /// ```
  public func bitflip(x : Nat16, p : Nat) : Nat16 {
    x ^ (1 << Prim.natToNat16(p))
  };

  /// Returns the count of non-zero bits in `x`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.bitcountNonZero(5) == 2;
  /// ```
  public let bitcountNonZero : (x : Nat16) -> Nat16 = Prim.popcntNat16;

  /// Returns the count of leading zero bits in `x`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.bitcountLeadingZero(5) == 13;
  /// ```
  public let bitcountLeadingZero : (x : Nat16) -> Nat16 = Prim.clzNat16;

  /// Returns the count of trailing zero bits in `x`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.bitcountTrailingZero(5) == 0;
  /// ```
  public let bitcountTrailingZero : (x : Nat16) -> Nat16 = Prim.ctzNat16;

  /// Returns the upper (i.e. most significant) and lower (least significant) byte of `x`.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.explode 0xaa88 == (170, 136);
  /// ```
  public let explode : (x : Nat16) -> (msb : Nat8, lsb : Nat8) = Prim.explodeNat16;

  /// Returns the sum of `x` and `y`, `x +% y`. Wraps on overflow.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.addWrap(65532, 5) == 1;
  /// assert (65532 : Nat16) +% (5 : Nat16) == 1;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `+%` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `+%`
  /// as a function value at the moment.
  public func addWrap(x : Nat16, y : Nat16) : Nat16 { x +% y };

  /// Returns the difference of `x` and `y`, `x -% y`. Wraps on underflow.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.subWrap(1, 2) == 65535;
  /// assert (1 : Nat16) -% (2 : Nat16) == 65535;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `-%` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `-%`
  /// as a function value at the moment.
  public func subWrap(x : Nat16, y : Nat16) : Nat16 { x -% y };

  /// Returns the product of `x` and `y`, `x *% y`. Wraps on overflow.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.mulWrap(655, 101) == 619;
  /// assert (655 : Nat16) *% (101 : Nat16) == 619;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `*%` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `*%`
  /// as a function value at the moment.
  public func mulWrap(x : Nat16, y : Nat16) : Nat16 { x *% y };

  /// Returns `x` to the power of `y`, `x **% y`. Wraps on overflow.
  ///
  /// Example:
  /// ```motoko include=import
  /// assert Nat16.powWrap(2, 16) == 0;
  /// assert (2 : Nat16) **% (16 : Nat16) == 0;
  /// ```
  ///
  /// Note: The reason why this function is defined in this library (in addition
  /// to the existing `**%` operator) is so that you can use it as a function
  /// value to pass to a higher order function. It is not possible to use `**%`
  /// as a function value at the moment.
  public func powWrap(x : Nat16, y : Nat16) : Nat16 { x **% y };

  /// Returns an iterator over `Nat16` values from the first to second argument with an exclusive upper bound.
  /// ```motoko include=import
  /// import Iter "mo:core/Iter";
  ///
  /// let iter = Nat16.range(1, 4);
  /// assert iter.next() == ?1;
  /// assert iter.next() == ?2;
  /// assert iter.next() == ?3;
  /// assert iter.next() == null;
  /// ```
  ///
  /// If the first argument is greater than the second argument, the function returns an empty iterator.
  /// ```motoko include=import
  /// import Iter "mo:core/Iter";
  ///
  /// let iter = Nat16.range(4, 1);
  /// assert iter.next() == null; // empty iterator
  /// ```
  public func range(fromInclusive : Nat16, toExclusive : Nat16) : Iter.Iter<Nat16> {
    if (fromInclusive >= toExclusive) {
      Iter.empty()
    } else {
      object {
        var n = fromInclusive;
        public func next() : ?Nat16 {
          if (n == toExclusive) {
            null
          } else {
            let result = n;
            n += 1;
            ?result
          }
        }
      }
    }
  };

  /// Returns an iterator over `Nat16` values from the first to second argument, inclusive.
  /// ```motoko include=import
  /// import Iter "mo:core/Iter";
  ///
  /// let iter = Nat16.rangeInclusive(1, 3);
  /// assert iter.next() == ?1;
  /// assert iter.next() == ?2;
  /// assert iter.next() == ?3;
  /// assert iter.next() == null;
  /// ```
  ///
  /// If the first argument is greater than the second argument, the function returns an empty iterator.
  /// ```motoko include=import
  /// import Iter "mo:core/Iter";
  ///
  /// let iter = Nat16.rangeInclusive(4, 1);
  /// assert iter.next() == null; // empty iterator
  /// ```
  public func rangeInclusive(from : Nat16, to : Nat16) : Iter.Iter<Nat16> {
    if (from > to) {
      Iter.empty()
    } else {
      object {
        var n = from;
        var done = false;
        public func next() : ?Nat16 {
          if (done) {
            null
          } else {
            let result = n;
            if (n == to) {
              done := true
            } else {
              n += 1
            };
            ?result
          }
        }
      }
    }
  };

  /// Returns an iterator over all Nat16 values, from 0 to maxValue.
  /// ```motoko include=import
  /// import Iter "mo:core/Iter";
  ///
  /// let iter = Nat16.allValues();
  /// assert iter.next() == ?0;
  /// assert iter.next() == ?1;
  /// assert iter.next() == ?2;
  /// // ...
  /// ```
  public func allValues() : Iter.Iter<Nat16> {
    rangeInclusive(0, maxValue)
  };

}
