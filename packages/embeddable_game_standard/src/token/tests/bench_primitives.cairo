// Primitive cost probes: isolate the per-libfunc costs the accessor rewrite
// trades against (u128 DivRem, u64 DivRem, u32 DivRem, checked narrowing,
// bitwise AND). Each probe is a single-entrypoint contract; differences
// between adjacent probes give the cost of exactly one extra operation.

use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};

#[starknet::interface]
pub trait IProbe<T> {
    fn run(self: @T, x: felt252) -> felt252;
}

const NZ128_A: NonZero<u128> = 0x400; // 2^10
const NZ128_B: NonZero<u128> = 0x10000; // 2^16
const NZ64_A: NonZero<u64> = 0x400;
const NZ64_B: NonZero<u64> = 0x10000;
const NZ32_A: NonZero<u32> = 0x400;
const NZ32_B: NonZero<u32> = 0x10000;

// --- floor: felt in, felt out -------------------------------------------------
#[starknet::contract]
pub mod PrimNoop {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            x
        }
    }
}

// --- base: felt -> u128 -> felt ----------------------------------------------
#[starknet::contract]
pub mod PrimBase128 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            let v: u128 = x.try_into().unwrap();
            v.into()
        }
    }
}

#[starknet::contract]
pub mod PrimU128Div1 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            let v: u128 = x.try_into().unwrap();
            let (q, _) = DivRem::div_rem(v, super::NZ128_A);
            q.into()
        }
    }
}

#[starknet::contract]
pub mod PrimU128Div2 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            let v: u128 = x.try_into().unwrap();
            let (q, _) = DivRem::div_rem(v, super::NZ128_A);
            let (q, _) = DivRem::div_rem(q, super::NZ128_B);
            q.into()
        }
    }
}

#[starknet::contract]
pub mod PrimU128Div3 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            let v: u128 = x.try_into().unwrap();
            let (q, _) = DivRem::div_rem(v, super::NZ128_A);
            let (q, _) = DivRem::div_rem(q, super::NZ128_B);
            let (q, _) = DivRem::div_rem(q, super::NZ128_A);
            q.into()
        }
    }
}

// --- narrowing ----------------------------------------------------------------
#[starknet::contract]
pub mod PrimNarrow64 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            let v: u128 = x.try_into().unwrap();
            let w: u64 = v.try_into().unwrap();
            w.into()
        }
    }
}

#[starknet::contract]
pub mod PrimNarrow32 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            let v: u128 = x.try_into().unwrap();
            let w: u32 = v.try_into().unwrap();
            w.into()
        }
    }
}

#[starknet::contract]
pub mod PrimU64Div1 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            let v: u128 = x.try_into().unwrap();
            let w: u64 = v.try_into().unwrap();
            let (q, _) = DivRem::div_rem(w, super::NZ64_A);
            q.into()
        }
    }
}

#[starknet::contract]
pub mod PrimU64Div2 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            let v: u128 = x.try_into().unwrap();
            let w: u64 = v.try_into().unwrap();
            let (q, _) = DivRem::div_rem(w, super::NZ64_A);
            let (q, _) = DivRem::div_rem(q, super::NZ64_B);
            q.into()
        }
    }
}

#[starknet::contract]
pub mod PrimU32Div1 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            let v: u128 = x.try_into().unwrap();
            let w: u32 = v.try_into().unwrap();
            let (q, _) = DivRem::div_rem(w, super::NZ32_A);
            q.into()
        }
    }
}

#[starknet::contract]
pub mod PrimU32Div2 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            let v: u128 = x.try_into().unwrap();
            let w: u32 = v.try_into().unwrap();
            let (q, _) = DivRem::div_rem(w, super::NZ32_A);
            let (q, _) = DivRem::div_rem(q, super::NZ32_B);
            q.into()
        }
    }
}

// --- bitwise ------------------------------------------------------------------
#[starknet::contract]
pub mod PrimBitAnd128 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            let v: u128 = x.try_into().unwrap();
            let w = v & 0x400;
            w.into()
        }
    }
}

// --- felt -> u256 -------------------------------------------------------------
#[starknet::contract]
pub mod PrimIntoU256Low {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            let v: u256 = x.into();
            v.low.into()
        }
    }
}

#[starknet::contract]
pub mod PrimIntoU256High {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            let v: u256 = x.into();
            v.high.into()
        }
    }
}

#[starknet::contract]
pub mod PrimU256BitAnd {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            let v: u256 = x.into();
            let r: u16 = (v & 0x3FF_u256).try_into().unwrap();
            r.into()
        }
    }
}

#[starknet::contract]
pub mod PrimU256LowDivRem {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbe<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            let v: u256 = x.into();
            let (_, r) = DivRem::div_rem(v.low, super::NZ128_A);
            let r: u16 = r.try_into().unwrap();
            r.into()
        }
    }
}

// ==============================================================================
// Drivers — one test per probe so gas is attributable to exactly that probe.
// Read the probe contract's `run` row from `--gas-report`.
// ==============================================================================

const INPUT: felt252 = 0xFFFFFFF;

fn drive(name: ByteArray) {
    let contract = declare(name).unwrap().contract_class();
    let (addr, _) = contract.deploy(@array![]).unwrap();
    let p = IProbeDispatcher { contract_address: addr };
    let _ = p.run(INPUT);
}

#[test]
fn gas_prim_00_noop() {
    drive("PrimNoop");
}

#[test]
fn gas_prim_01_base128() {
    drive("PrimBase128");
}

#[test]
fn gas_prim_02_u128_div1() {
    drive("PrimU128Div1");
}

#[test]
fn gas_prim_03_u128_div2() {
    drive("PrimU128Div2");
}

#[test]
fn gas_prim_04_u128_div3() {
    drive("PrimU128Div3");
}

#[test]
fn gas_prim_05_narrow64() {
    drive("PrimNarrow64");
}

#[test]
fn gas_prim_06_u64_div1() {
    drive("PrimU64Div1");
}

#[test]
fn gas_prim_07_u64_div2() {
    drive("PrimU64Div2");
}

#[test]
fn gas_prim_08_narrow32() {
    drive("PrimNarrow32");
}

#[test]
fn gas_prim_09_u32_div1() {
    drive("PrimU32Div1");
}

#[test]
fn gas_prim_10_u32_div2() {
    drive("PrimU32Div2");
}

#[test]
fn gas_prim_11_bitand128() {
    drive("PrimBitAnd128");
}

#[test]
fn gas_prim_12_into_u256_low() {
    drive("PrimIntoU256Low");
}

#[test]
fn gas_prim_13_into_u256_high() {
    drive("PrimIntoU256High");
}

#[test]
fn gas_prim_14_u256_bitand() {
    drive("PrimU256BitAnd");
}

#[test]
fn gas_prim_15_u256_low_divrem() {
    drive("PrimU256LowDivRem");
}
