use crate::math::lut;
use crate::math::types::{FixedTrait, ONE};

// ============================================================================
// LUT exp2 tests - cover all 33 branches (x=0..32)
// ============================================================================

#[test]
fn test_lut_exp2_all_values() {
    assert!(lut::exp2(0) == 1, "exp2(0)");
    assert!(lut::exp2(1) == 2, "exp2(1)");
    assert!(lut::exp2(2) == 4, "exp2(2)");
    assert!(lut::exp2(3) == 8, "exp2(3)");
    assert!(lut::exp2(4) == 16, "exp2(4)");
    assert!(lut::exp2(5) == 32, "exp2(5)");
    assert!(lut::exp2(6) == 64, "exp2(6)");
    assert!(lut::exp2(7) == 128, "exp2(7)");
    assert!(lut::exp2(8) == 256, "exp2(8)");
    assert!(lut::exp2(9) == 512, "exp2(9)");
    assert!(lut::exp2(10) == 1024, "exp2(10)");
    assert!(lut::exp2(11) == 2048, "exp2(11)");
    assert!(lut::exp2(12) == 4096, "exp2(12)");
    assert!(lut::exp2(13) == 8192, "exp2(13)");
    assert!(lut::exp2(14) == 16384, "exp2(14)");
    assert!(lut::exp2(15) == 32768, "exp2(15)");
    assert!(lut::exp2(16) == 65536, "exp2(16)");
    assert!(lut::exp2(17) == 131072, "exp2(17)");
    assert!(lut::exp2(18) == 262144, "exp2(18)");
    assert!(lut::exp2(19) == 524288, "exp2(19)");
    assert!(lut::exp2(20) == 1048576, "exp2(20)");
    assert!(lut::exp2(21) == 2097152, "exp2(21)");
    assert!(lut::exp2(22) == 4194304, "exp2(22)");
    assert!(lut::exp2(23) == 8388608, "exp2(23)");
    assert!(lut::exp2(24) == 16777216, "exp2(24)");
    assert!(lut::exp2(25) == 33554432, "exp2(25)");
    assert!(lut::exp2(26) == 67108864, "exp2(26)");
    assert!(lut::exp2(27) == 134217728, "exp2(27)");
    assert!(lut::exp2(28) == 268435456, "exp2(28)");
    assert!(lut::exp2(29) == 536870912, "exp2(29)");
    assert!(lut::exp2(30) == 1073741824, "exp2(30)");
    assert!(lut::exp2(31) == 2147483648, "exp2(31)");
    assert!(lut::exp2(32) == 4294967296, "exp2(32)");
}

#[test]
#[should_panic(expected: "exp2: input too large")]
fn test_lut_exp2_overflow() {
    lut::exp2(33);
}

// ============================================================================
// LUT msb tests - cover all branches
// ============================================================================

#[test]
fn test_lut_msb_all_boundaries() {
    // x=0: msb=0, ceil=1
    let (msb, ceil) = lut::msb(0);
    assert!(msb == 0 && ceil == 1, "msb(0)");

    // x=1: msb=0, ceil=1
    let (msb, ceil) = lut::msb(1);
    assert!(msb == 0 && ceil == 1, "msb(1)");

    // x=2: msb=1, ceil=2
    let (msb, ceil) = lut::msb(2);
    assert!(msb == 1 && ceil == 2, "msb(2)");

    // x=3: still in the <=4 bucket
    let (msb, ceil) = lut::msb(3);
    assert!(msb == 2 && ceil == 4, "msb(3)");

    // x=4: msb=2, ceil=4
    let (msb, ceil) = lut::msb(4);
    assert!(msb == 2 && ceil == 4, "msb(4)");

    // x=5: in <=8 bucket
    let (msb, ceil) = lut::msb(5);
    assert!(msb == 3 && ceil == 8, "msb(5)");

    let (msb, ceil) = lut::msb(8);
    assert!(msb == 3 && ceil == 8, "msb(8)");

    let (msb, ceil) = lut::msb(9);
    assert!(msb == 4 && ceil == 16, "msb(9)");

    let (msb, ceil) = lut::msb(16);
    assert!(msb == 4 && ceil == 16, "msb(16)");

    let (msb, ceil) = lut::msb(17);
    assert!(msb == 5 && ceil == 32, "msb(17)");

    let (msb, ceil) = lut::msb(32);
    assert!(msb == 5 && ceil == 32, "msb(32)");

    let (msb, ceil) = lut::msb(33);
    assert!(msb == 6 && ceil == 64, "msb(33)");

    let (msb, ceil) = lut::msb(64);
    assert!(msb == 6 && ceil == 64, "msb(64)");

    let (msb, ceil) = lut::msb(65);
    assert!(msb == 7 && ceil == 128, "msb(65)");

    let (msb, ceil) = lut::msb(128);
    assert!(msb == 7 && ceil == 128, "msb(128)");

    let (msb, ceil) = lut::msb(129);
    assert!(msb == 8 && ceil == 256, "msb(129)");

    let (msb, ceil) = lut::msb(256);
    assert!(msb == 8 && ceil == 256, "msb(256)");

    let (msb, ceil) = lut::msb(257);
    assert!(msb == 9 && ceil == 512, "msb(257)");

    let (msb, ceil) = lut::msb(512);
    assert!(msb == 9 && ceil == 512, "msb(512)");

    let (msb, ceil) = lut::msb(513);
    assert!(msb == 10 && ceil == 1024, "msb(513)");

    let (msb, ceil) = lut::msb(1024);
    assert!(msb == 10 && ceil == 1024, "msb(1024)");

    let (msb, ceil) = lut::msb(1025);
    assert!(msb == 11 && ceil == 2048, "msb(1025)");

    let (msb, ceil) = lut::msb(2048);
    assert!(msb == 11 && ceil == 2048, "msb(2048)");

    let (msb, ceil) = lut::msb(2049);
    assert!(msb == 12 && ceil == 4096, "msb(2049)");

    let (msb, ceil) = lut::msb(4096);
    assert!(msb == 12 && ceil == 4096, "msb(4096)");

    let (msb, ceil) = lut::msb(4097);
    assert!(msb == 13 && ceil == 8192, "msb(4097)");

    let (msb, ceil) = lut::msb(8192);
    assert!(msb == 13 && ceil == 8192, "msb(8192)");

    let (msb, ceil) = lut::msb(8193);
    assert!(msb == 14 && ceil == 16384, "msb(8193)");

    let (msb, ceil) = lut::msb(16384);
    assert!(msb == 14 && ceil == 16384, "msb(16384)");

    let (msb, ceil) = lut::msb(16385);
    assert!(msb == 15 && ceil == 32768, "msb(16385)");

    let (msb, ceil) = lut::msb(32768);
    assert!(msb == 15 && ceil == 32768, "msb(32768)");

    let (msb, ceil) = lut::msb(32769);
    assert!(msb == 16 && ceil == 65536, "msb(32769)");

    let (msb, ceil) = lut::msb(65536);
    assert!(msb == 16 && ceil == 65536, "msb(65536)");

    let (msb, ceil) = lut::msb(65537);
    assert!(msb == 17 && ceil == 131072, "msb(65537)");

    let (msb, ceil) = lut::msb(131072);
    assert!(msb == 17 && ceil == 131072, "msb(131072)");

    let (msb, ceil) = lut::msb(131073);
    assert!(msb == 18 && ceil == 262144, "msb(131073)");

    let (msb, ceil) = lut::msb(262144);
    assert!(msb == 18 && ceil == 262144, "msb(262144)");

    let (msb, ceil) = lut::msb(262145);
    assert!(msb == 19 && ceil == 524288, "msb(262145)");

    let (msb, ceil) = lut::msb(524288);
    assert!(msb == 19 && ceil == 524288, "msb(524288)");

    let (msb, ceil) = lut::msb(524289);
    assert!(msb == 20 && ceil == 1048576, "msb(524289)");

    let (msb, ceil) = lut::msb(1048576);
    assert!(msb == 20 && ceil == 1048576, "msb(1048576)");

    let (msb, ceil) = lut::msb(1048577);
    assert!(msb == 21 && ceil == 2097152, "msb(1048577)");

    let (msb, ceil) = lut::msb(2097152);
    assert!(msb == 21 && ceil == 2097152, "msb(2097152)");

    let (msb, ceil) = lut::msb(2097153);
    assert!(msb == 22 && ceil == 4194304, "msb(2097153)");

    let (msb, ceil) = lut::msb(4194304);
    assert!(msb == 22 && ceil == 4194304, "msb(4194304)");

    let (msb, ceil) = lut::msb(4194305);
    assert!(msb == 23 && ceil == 8388608, "msb(4194305)");

    let (msb, ceil) = lut::msb(8388608);
    assert!(msb == 23 && ceil == 8388608, "msb(8388608)");

    let (msb, ceil) = lut::msb(8388609);
    assert!(msb == 24 && ceil == 16777216, "msb(8388609)");

    let (msb, ceil) = lut::msb(16777216);
    assert!(msb == 24 && ceil == 16777216, "msb(16777216)");

    let (msb, ceil) = lut::msb(16777217);
    assert!(msb == 25 && ceil == 33554432, "msb(16777217)");

    let (msb, ceil) = lut::msb(33554432);
    assert!(msb == 25 && ceil == 33554432, "msb(33554432)");

    let (msb, ceil) = lut::msb(33554433);
    assert!(msb == 26 && ceil == 67108864, "msb(33554433)");

    let (msb, ceil) = lut::msb(67108864);
    assert!(msb == 26 && ceil == 67108864, "msb(67108864)");

    let (msb, ceil) = lut::msb(67108865);
    assert!(msb == 27 && ceil == 134217728, "msb(67108865)");

    let (msb, ceil) = lut::msb(134217728);
    assert!(msb == 27 && ceil == 134217728, "msb(134217728)");

    let (msb, ceil) = lut::msb(134217729);
    assert!(msb == 28 && ceil == 268435456, "msb(134217729)");

    let (msb, ceil) = lut::msb(268435456);
    assert!(msb == 28 && ceil == 268435456, "msb(268435456)");

    let (msb, ceil) = lut::msb(268435457);
    assert!(msb == 29 && ceil == 536870912, "msb(268435457)");

    let (msb, ceil) = lut::msb(536870912);
    assert!(msb == 29 && ceil == 536870912, "msb(536870912)");

    let (msb, ceil) = lut::msb(536870913);
    assert!(msb == 30 && ceil == 1073741824, "msb(536870913)");

    let (msb, ceil) = lut::msb(1073741824);
    assert!(msb == 30 && ceil == 1073741824, "msb(1073741824)");

    let (msb, ceil) = lut::msb(1073741825);
    assert!(msb == 31 && ceil == 2147483648, "msb(1073741825)");

    let (msb, ceil) = lut::msb(2147483648);
    assert!(msb == 31 && ceil == 2147483648, "msb(2147483648)");

    // x > 2147483648: falls to else branch
    let (msb, ceil) = lut::msb(2147483649);
    assert!(msb == 32 && ceil == 4294967296, "msb(2147483649)");

    let (msb, ceil) = lut::msb(4294967296);
    assert!(msb == 32 && ceil == 4294967296, "msb(4294967296)");
}

// ============================================================================
// math.cairo branch coverage tests
// ============================================================================

#[test]
fn test_exp2_negative_exponent() {
    // exp2(-2.0) = 2^(-2) = 0.25
    // Covers the a.sign == true branch in math::exp2 (lines 88-89)
    let neg_two = FixedTrait::new_unscaled(2, true); // -2.0
    let result = neg_two.exp2();

    // 0.25 in 32.32 fixed point = ONE / 4 = 1073741824
    let expected = FixedTrait::new(ONE / 4, false);
    let diff = if result.mag > expected.mag {
        result.mag - expected.mag
    } else {
        expected.mag - result.mag
    };
    // Allow small rounding error
    assert!(diff < 100, "exp2(-2) should be ~0.25");
    assert!(result.sign == false, "exp2(-2) should be positive");
}

#[test]
fn test_log2_fractional_input() {
    // log2(0.5) = -1.0
    // Covers the a.mag < ONE branch in math::log2 (lines 144-147)
    let half = FixedTrait::new(ONE / 2, false); // 0.5
    let result = half.log2();

    // -1.0 in 32.32 = ONE with sign true
    assert!(result.sign == true, "log2(0.5) should be negative");
    let diff = if result.mag > ONE {
        result.mag - ONE
    } else {
        ONE - result.mag
    };
    assert!(diff < 100, "log2(0.5) should be ~-1.0");
}

#[test]
fn test_log2_exact_power_of_2() {
    // log2(4.0) = 2.0
    // Covers a.mag == div * ONE branch (line 153-154)
    let four = FixedTrait::new_unscaled(4, false);
    let result = four.log2();

    let expected = FixedTrait::new_unscaled(2, false);
    assert!(result.mag == expected.mag, "log2(4) should be exactly 2.0");
    assert!(result.sign == false, "log2(4) should be positive");
}

#[test]
fn test_log2_of_one() {
    // log2(1.0) = 0
    // Covers a.mag == ONE branch (line 142-143)
    let one = FixedTrait::new_unscaled(1, false);
    let result = one.log2();

    assert!(result.mag == 0, "log2(1) should be 0");
}
