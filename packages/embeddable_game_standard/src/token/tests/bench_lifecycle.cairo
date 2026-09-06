// ==============================================================================
// LIFECYCLE / GUARD-PATH GAS BENCHMARK
// ==============================================================================
//
// Same method as `bench_packing.cairo`: both arms compiled into ONE crate and
// measured in ONE snforge run, one single-entrypoint probe per arm, read the
// probe contract's `run` row from `--gas-report` rather than the test total.
//
// The "before" arm is `lifecycle_arms::lifecycle_before`, the pre-change path
// (`to_token_metadata(unpack_token_id(id)).lifecycle`) built on the frozen
// v2.7.0 codec. It is self-contained, so no baseline worktree is needed for
// these rows — the two arms coexist and the compiler cannot treat them
// differently.
//
// TWO ABI floors again, matched to the two return shapes:
//   `PbNoopLife` — felt252 in, a two-felt `Lifecycle` out, no codec call.
//                  The floor for every `Lifecycle`-returning probe here.
//   `PbNoop` (in bench_packing.cairo, 9,540) — the one-felt scalar floor, which
//                  is the floor for the `is_playable`-body probes (bool).
//
// Boundary: isolated entrypoint execution, not transaction cost.

use game_components_interfaces::structs::token::Lifecycle;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp};
use starknet::get_block_timestamp;
use crate::token::lifecycle::LifecycleTrait;
use crate::token::packing;
use super::{lifecycle_arms, packing_v270};

#[starknet::interface]
pub trait IProbeLifecycle<T> {
    fn run(self: @T, x: felt252) -> Lifecycle;
}

#[starknet::interface]
pub trait IProbeBool<T> {
    fn run(self: @T, x: felt252) -> bool;
}

/// ABI floor for the `Lifecycle`-returning probes: same entrypoint, same
/// two-felt return serialization, no codec call. Constant fields, so this is a
/// lower bound on the real floor; the input is still deserialized.
#[starknet::contract]
pub mod PbNoopLife {
    use game_components_interfaces::structs::token::Lifecycle;
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeLifecycle<ContractState> {
        fn run(self: @ContractState, x: felt252) -> Lifecycle {
            Lifecycle { start: 0, end: 0 }
        }
    }
}

/// Probe: the PRE-CHANGE lifecycle path — full twelve-field unpack, build a
/// `TokenMetadata`, take `.lifecycle` off it.
#[starknet::contract]
pub mod PbLifeBefore {
    use game_components_interfaces::structs::token::Lifecycle;
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeLifecycle<ContractState> {
        fn run(self: @ContractState, x: felt252) -> Lifecycle {
            crate::token::tests::lifecycle_arms::lifecycle_before(x)
        }
    }
}

/// Probe: the SHIPPED `packing::unpack_lifecycle`.
#[starknet::contract]
pub mod PbLifeNew {
    use game_components_interfaces::structs::token::Lifecycle;
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeLifecycle<ContractState> {
        fn run(self: @ContractState, x: felt252) -> Lifecycle {
            crate::token::packing::unpack_lifecycle(x)
        }
    }
}

/// Probe: arm A — two u128 DivRems + mask, u128 reconstruction, 2 downcasts.
#[starknet::contract]
pub mod PbLifeA {
    use game_components_interfaces::structs::token::Lifecycle;
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeLifecycle<ContractState> {
        fn run(self: @ContractState, x: felt252) -> Lifecycle {
            crate::token::tests::lifecycle_arms::lifecycle_a(x)
        }
    }
}

/// Probe: arm B — two u128 DivRems + mask, u64 reconstruction, 3 downcasts.
#[starknet::contract]
pub mod PbLifeB {
    use game_components_interfaces::structs::token::Lifecycle;
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeLifecycle<ContractState> {
        fn run(self: @ContractState, x: felt252) -> Lifecycle {
            crate::token::tests::lifecycle_arms::lifecycle_b(x)
        }
    }
}

/// Probe: arm C — split at bit 60, one u64 DivRem yields two fields, mask the
/// third. (The shape the shipped code adopted.)
#[starknet::contract]
pub mod PbLifeC {
    use game_components_interfaces::structs::token::Lifecycle;
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeLifecycle<ContractState> {
        fn run(self: @ContractState, x: felt252) -> Lifecycle {
            crate::token::tests::lifecycle_arms::lifecycle_c(x)
        }
    }
}

/// Probe: arm D — as C with the end_delay downcast moved inside the
/// non-sentinel branch, making cost input-dependent.
#[starknet::contract]
pub mod PbLifeD {
    use game_components_interfaces::structs::token::Lifecycle;
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeLifecycle<ContractState> {
        fn run(self: @ContractState, x: felt252) -> Lifecycle {
            crate::token::tests::lifecycle_arms::lifecycle_d(x)
        }
    }
}

/// Probe: the PRE-CHANGE `is_playable` body, verbatim.
#[starknet::contract]
pub mod PbIsPlayableBefore {
    use starknet::get_block_timestamp;
    use crate::token::lifecycle::LifecycleTrait;
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeBool<ContractState> {
        fn run(self: @ContractState, x: felt252) -> bool {
            crate::token::tests::lifecycle_arms::lifecycle_before(x)
                .is_playable(get_block_timestamp())
        }
    }
}

/// Probe: the SHIPPED `is_playable` body.
#[starknet::contract]
pub mod PbIsPlayableAfter {
    use starknet::get_block_timestamp;
    use crate::token::lifecycle::LifecycleTrait;
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeBool<ContractState> {
        fn run(self: @ContractState, x: felt252) -> bool {
            crate::token::packing::unpack_lifecycle(x).is_playable(get_block_timestamp())
        }
    }
}

// ==============================================================================
// Drivers
// ==============================================================================

/// A fully populated token id with a live, bounded window: end_delay non-zero
/// so the expiry branch is taken, and every other field non-zero so no arm is
/// measured on an accidentally cheap input.
fn bench_input() -> felt252 {
    packing_v270::pack_token_id(
        0x7EDCBA987,
        0x1ECBA98,
        0x1DBA987,
        0xBEEF,
        0x3ADCBA9,
        true,
        0x2AD,
        0xCAFE,
        true,
        true,
        0x2FEDCBA9,
        0x1DEADBEEFCAFEF00D,
    )
}

/// The same id with `end_delay == 0` — the "no expiration" sentinel, which is
/// the branch arm D was written to exploit.
fn bench_input_immortal() -> felt252 {
    packing_v270::pack_token_id(
        0x7EDCBA987,
        0x1ECBA98,
        0,
        0xBEEF,
        0x3ADCBA9,
        true,
        0x2AD,
        0xCAFE,
        true,
        true,
        0x2FEDCBA9,
        0x1DEADBEEFCAFEF00D,
    )
}

fn drive_life(name: ByteArray, input: felt252) {
    let c = declare(name).unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeLifecycleDispatcher { contract_address: a }.run(input);
}

fn drive_bool(name: ByteArray, input: felt252) {
    let c = declare(name).unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    start_cheat_block_timestamp(a, 0x7EDCBA987 + 0x1ECBA98 + 1);
    let _ = IProbeBoolDispatcher { contract_address: a }.run(input);
}

/// The `Lifecycle` ABI floor.
#[test]
fn gas_life_00_floor_noop() {
    drive_life("PbNoopLife", bench_input());
}

/// Pre-change path. Read the `PbLifeBefore` `run` row.
#[test]
fn gas_life_01_before() {
    drive_life("PbLifeBefore", bench_input());
}

/// Shipped `unpack_lifecycle`. Read the `PbLifeNew` `run` row.
#[test]
fn gas_life_02_new() {
    drive_life("PbLifeNew", bench_input());
}

#[test]
fn gas_life_03_arm_a() {
    drive_life("PbLifeA", bench_input());
}

#[test]
fn gas_life_04_arm_b() {
    drive_life("PbLifeB", bench_input());
}

#[test]
fn gas_life_05_arm_c() {
    drive_life("PbLifeC", bench_input());
}

#[test]
fn gas_life_06_arm_d() {
    drive_life("PbLifeD", bench_input());
}

/// Arm D again on the `end_delay == 0` sentinel, where it skips a downcast.
#[test]
fn gas_life_07_arm_d_immortal() {
    drive_life("PbLifeD", bench_input_immortal());
}

/// Shipped shape on the sentinel, for comparison with `gas_life_07`.
#[test]
fn gas_life_08_new_immortal() {
    drive_life("PbLifeNew", bench_input_immortal());
}

/// Pre-change `is_playable` body. Read the `PbIsPlayableBefore` `run` row.
#[test]
fn gas_life_09_is_playable_before() {
    drive_bool("PbIsPlayableBefore", bench_input());
}

/// Shipped `is_playable` body. Read the `PbIsPlayableAfter` `run` row.
#[test]
fn gas_life_10_is_playable_after() {
    drive_bool("PbIsPlayableAfter", bench_input());
}
