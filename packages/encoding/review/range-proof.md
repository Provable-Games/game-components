# Combined encoder range and order proof

The selected fixed-overhead component uses integer bounded DivRem, not field division. Pinned Cairo represents `usize` as u32, so a valid length n is in [0, 2^32−1]. Division by 3 returns q in [0, 0x55555555] and r in [0,2], satisfying n=3q+r. These are the exact helper result ranges.

Both byte paths initialize a felt countdown from q. Before each subtraction they test for zero. Inductively the countdown is the ordinary integer q−j at iteration j; subtraction only occurs when this integer is positive, so no field wrap occurs. There are exactly q iterations, consuming exactly 3q input bytes. The unchanged iterator and cached-cursor order therefore deliver the same triplets and then the same r tail bytes. The tiny path still handles lengths through five; larger inputs retain the cached top-aligned limbs.

Byte splits have exact integer ranges: b0/4 yields a sextet and two bits; b1/16 yields two four-bit parts; b2/64 yields two bits and a sextet. The second index is at most 3·16+15=63, and the third at most 15·4+3=63. The unchanged alphabet indexes are valid. One-byte tails multiply two bits by16, leaving four zero pad bits; two-byte tails multiply four bits by4, leaving two zero pad bits. Padding is respectively `==` or `=`.

The cached adapter splits every 31-byte word into a 16-byte high limb and a 15-byte low limb in serialization order. Pending words follow the same high-before-low order. Each nonempty limb has length1..16; multiplying by256^(16−len) produces a value below2^128, so the felt multiplication does not wrap and the u128 conversion is valid. Top-byte extraction followed by the remainder times256 keeps its value below2^128 and preserves leading zeros. Existing cursor counts consume exactly the valid input length.

Returning an empty input preserves the canonical public ByteArray representation. In pinned corelib, deserialization validates a zero-length pending word as less than256^0=1, so it is zero. Public helper constructions also preserve this invariant. No unsafe or malformed ByteArray construction is introduced.

Compile-only block research independently establishes exact power-of-two quotient and remainder ranges and 23 emitted DivRem operand pairs (18 BoundedInt plus5 native), all KnownSmallRhs. That evidence proves lowering eligibility, not a gas improvement. A block implementation must separately pass the complete accuracy and full matrix gates before selection.

# Accepted block component

Each block consumes three full31-byte words A,B,C. The split returns a16-byte high limb then15-byte low limb. peel16 emits five24-bit groups and one carry byte. Its first use consumes bytes0..14 and carries15; prepending15 to A_low emits15..29 and carries30. Prepending30 to B_high creates17bytes, emits30..44 and carries45..46. Prepending45..46 to B_low emits45..59 and carries60..61. Prepending60..61 to C_high creates18bytes and emits60..77 as sixgroups. C_low emits78..92 as fivegroups. No byte is dropped, duplicated or reordered.

Concatenated carry/limb integer widths are128,136,136,144bits; each helper's exact bounds match the disjoint multiplication and addition. All stay below2^144 and hence below the field modulus. Power-of-two DivRem extraction is fixed width and includes leading-zero groups. Each24-bit group splits into two12-bit halves, then four6-bit indices in high-to-low order.

Static output packing assigns the124characters in order to four disjoint31-byte words. Every term has nonnegative integer magnitude and disjoint byte positions; even arbitrary u8 characters would give at most2^248−1 perword, below the field modulus. Every intermediate sum is bounded by the final word, so field arithmetic never wraps. The actual alphabet contains ASCII bytes below128.

Output begins with pending length0. Corelib append_word_ex(word,31) at pending length0 takes FilledPending(split_index0), appends the whole word and sets the pending word/length to0. Thus the invariant holds after each of the four calls and between all blocks. No padding is emitted inside blocks.

Writing input length as31w+p, 0≤p≤30, proves k=floor(w/3)=floor(length/93):31(w mod3)+p≤92. The processed length93k is bounded by input length, so checked multiplication/subtraction is valid. The ByteSpan range93k..length is valid and starts on a word boundary. Converting that range preserves its bytes; cached tail encoding starts at triplet phase0 because93k is divisible by3. Base64 concatenation is consequently valid; only the tail may add padding. A zero tail returns the block output directly.

The new ByteSpan and corelib-get-trait feature annotations join the existing unstable bounded-int-utils dependency. Compiler or corelib upgrades require repeating the range/lowering and correctness gates. Whole-input serialization still uses O(n)temporary memory; the cached suffix needs fewer than93bytes of limbs, while inputs under93 retain the prior cached memory behavior. This is an allocation-shape argument, not a measured VM-memory saving.
