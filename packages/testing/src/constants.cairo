use starknet::ContractAddress;

// Test addresses - using try_into().unwrap() pattern
pub fn ALICE() -> ContractAddress {
    'ALICE'.try_into().unwrap()
}

pub fn BOB() -> ContractAddress {
    'BOB'.try_into().unwrap()
}

pub fn CHARLIE() -> ContractAddress {
    'CHARLIE'.try_into().unwrap()
}

pub fn ZERO_ADDRESS() -> ContractAddress {
    0.try_into().unwrap()
}

pub fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

pub fn USER1() -> ContractAddress {
    'USER1'.try_into().unwrap()
}

pub fn USER2() -> ContractAddress {
    'USER2'.try_into().unwrap()
}

pub fn RENDERER_ADDRESS() -> ContractAddress {
    'RENDERER'.try_into().unwrap()
}

pub fn NEW_OWNER() -> ContractAddress {
    'NEW_OWNER'.try_into().unwrap()
}

pub fn CREATOR() -> ContractAddress {
    'CREATOR'.try_into().unwrap()
}

// Edge case values
pub const MAX_U64: u64 = 18446744073709551615;
pub const MAX_U32: u32 = 4294967295;
// Max 35-bit timestamp - maximum value that fits in TokenMetadata lifecycle packing
pub const MAX_LIFECYCLE_TIMESTAMP: u64 = 34359738367; // 2^35 - 1 = 0x7FFFFFFFF

// Time constants
pub const PAST_TIME: u64 = 100;
pub const CURRENT_TIME: u64 = 1000;
pub const FUTURE_TIME: u64 = 2000;
pub const FAR_FUTURE_TIME: u64 = 3000;
