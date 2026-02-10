# Math

Fixed-point math library using 32.32 bit representation. Based on [Cubit by Influence](https://github.com/influenceth/cubit).

## Features

- `Fixed` type with 32-bit integer and 32-bit fractional parts
- Signed arithmetic (magnitude + sign representation)
- Standard operators: `+`, `-`, `*`, `/`, negation, comparison
- Mathematical functions: `exp`, `exp2`, `ln`, `log2`, `log10`, `pow`, `sqrt`
- Rounding functions: `ceil`, `floor`, `round`
- Conversions to/from `u64` and `felt252`
- Lookup table (LUT) based implementations for transcendental functions

## API Reference

### Fixed Type

```cairo
pub struct Fixed {
    pub mag: u64,    // Magnitude in 32.32 format
    pub sign: bool,  // true = negative
}
```

### Constants

```cairo
pub const ONE: u64 = 4294967296;  // 2^32
pub const HALF: u64 = 2147483648; // 2^31
```

### FixedTrait

| Method | Description |
|--------|-------------|
| `ZERO()` | Returns zero |
| `ONE()` | Returns one |
| `new(mag, sign)` | Create from raw magnitude and sign |
| `new_unscaled(val, sign)` | Create from integer value (auto-scales by 2^32) |
| `from_felt(val)` | Create from felt252 |
| `abs(self)` | Absolute value |
| `ceil(self)` | Round up to nearest integer |
| `floor(self)` | Round down to nearest integer |
| `round(self)` | Round to nearest integer |
| `sqrt(self)` | Square root |
| `exp(self)` | Natural exponential (e^x) |
| `exp2(self)` | Base-2 exponential (2^x) |
| `ln(self)` | Natural logarithm |
| `log2(self)` | Base-2 logarithm |
| `log10(self)` | Base-10 logarithm |
| `pow(self, b)` | Power function (self^b) |

### Operator Implementations

`Fixed` implements `Add`, `Sub`, `Mul`, `Div`, `Neg`, `PartialEq`, `PartialOrd`, `TryInto<u64>`, and `Into<felt252>`.

## Usage

```cairo
use game_components_math::{Fixed, FixedTrait, ONE};

// Create fixed-point numbers
let a = FixedTrait::new_unscaled(3, false);  // 3.0
let b = FixedTrait::new(ONE / 2, false);     // 0.5 (using raw magnitude)

// Arithmetic
let sum = a + b;          // 3.5
let product = a * b;      // 1.5
let power = a.pow(b);     // 3^0.5 = sqrt(3)

// Mathematical functions
let e = FixedTrait::ONE().exp();    // e^1 = 2.718...
let ln_3 = a.ln();                  // ln(3) = 1.098...

// Convert back to integer
let int_val: u64 = sum.try_into().unwrap();  // 3 (truncated)
```

## Dependencies

- `starknet` only (leaf package)
