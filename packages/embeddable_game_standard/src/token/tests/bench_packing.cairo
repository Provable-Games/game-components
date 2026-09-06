// ==============================================================================
// PER-ACCESSOR GAS BENCHMARK — packed token id codec
// ==============================================================================
//
// Method (see also docs/): every arm is compiled into THIS crate and measured in
// ONE snforge run, so compiler, profile and invocation are identical across
// arms and cross-run noise cannot leak into a delta.
//
//   arm `v270` -> crate::token::tests::packing_v270 (frozen v2.7.0 copy)
//   arm `new`  -> crate::token::packing              (shipped implementation)
//
// Each probe is a SINGLE-ENTRYPOINT contract that does nothing but call one
// accessor and return its result. Read the probe contract's `run` row from the
// `--gas-report` table, NOT the test total: the test total includes deployment
// and dispatcher setup.
//
// `PbNoop` is the ABI floor: the same felt252 in / felt252 out entrypoint with
// no codec call at all. Everything above that floor is calldata deserialization,
// selector dispatch and return serialization, which no accessor can avoid.
//
// Command:
//   SCARB_UI_VERBOSITY=no-warnings snforge test gas_acc_ \
//     -p game_components_embeddable_game_standard \
//     --gas-report --tracked-resource sierra-gas --detailed-resources \
//     --color never --max-threads 1
//
// Boundary: these are isolated entrypoint execution measurements. They are not
// transaction costs and say nothing about calldata, storage or settlement.

use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use crate::token::packing;
use super::{packing_arms, packing_v270};

#[starknet::interface]
pub trait IProbeU64<T> {
    fn run(self: @T, x: felt252) -> u64;
}

#[starknet::interface]
pub trait IProbeU32<T> {
    fn run(self: @T, x: felt252) -> u32;
}

#[starknet::interface]
pub trait IProbeU16<T> {
    fn run(self: @T, x: felt252) -> u16;
}

#[starknet::interface]
pub trait IProbeBool<T> {
    fn run(self: @T, x: felt252) -> bool;
}

#[starknet::interface]
pub trait IProbeU128<T> {
    fn run(self: @T, x: felt252) -> u128;
}

#[starknet::interface]
pub trait IProbeFull<T> {
    fn run(self: @T, x: felt252) -> crate::token::tests::packing_v270::PackedTokenId;
}

#[starknet::interface]
pub trait IProbeFullNew<T> {
    fn run(self: @T, x: felt252) -> crate::token::packing::PackedTokenId;
}

#[starknet::interface]
pub trait IProbeFelt<T> {
    fn run(self: @T, x: felt252) -> felt252;
}

#[starknet::contract]
pub mod PbNoop {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeFelt<ContractState> {
        fn run(self: @ContractState, x: felt252) -> felt252 {
            x
        }
    }
}

#[starknet::contract]
pub mod PbMintedAtV270 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU64<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u64 {
            super::packing_v270::unpack_minted_at(x)
        }
    }
}

#[starknet::contract]
pub mod PbMintedAtNew {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU64<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u64 {
            super::packing::unpack_minted_at(x)
        }
    }
}

#[starknet::contract]
pub mod PbMintedAtA {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU64<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u64 {
            super::packing_arms::minted_at_a(x)
        }
    }
}

#[starknet::contract]
pub mod PbStartDelayV270 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing_v270::unpack_start_delay(x)
        }
    }
}

#[starknet::contract]
pub mod PbStartDelayNew {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing::unpack_start_delay(x)
        }
    }
}

#[starknet::contract]
pub mod PbStartDelayA {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing_arms::start_delay_a(x)
        }
    }
}

#[starknet::contract]
pub mod PbStartDelayB {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing_arms::start_delay_b(x)
        }
    }
}

#[starknet::contract]
pub mod PbStartDelayC {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing_arms::start_delay_c(x)
        }
    }
}

#[starknet::contract]
pub mod PbEndDelayV270 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing_v270::unpack_end_delay(x)
        }
    }
}

#[starknet::contract]
pub mod PbEndDelayNew {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing::unpack_end_delay(x)
        }
    }
}

#[starknet::contract]
pub mod PbEndDelayB {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing_arms::end_delay_b(x)
        }
    }
}

#[starknet::contract]
pub mod PbSettingsIdV270 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing_v270::unpack_settings_id(x)
        }
    }
}

#[starknet::contract]
pub mod PbSettingsIdNew {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing::unpack_settings_id(x)
        }
    }
}

#[starknet::contract]
pub mod PbSettingsIdA {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing_arms::settings_id_a(x)
        }
    }
}

#[starknet::contract]
pub mod PbSettingsIdB {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing_arms::settings_id_b(x)
        }
    }
}

#[starknet::contract]
pub mod PbMintedByV270 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU64<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u64 {
            super::packing_v270::unpack_minted_by(x)
        }
    }
}

#[starknet::contract]
pub mod PbMintedByNew {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU64<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u64 {
            super::packing::unpack_minted_by(x)
        }
    }
}

#[starknet::contract]
pub mod PbMintedByA {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU64<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u64 {
            super::packing_arms::minted_by_a(x)
        }
    }
}

#[starknet::contract]
pub mod PbMintedByB {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU64<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u64 {
            super::packing_arms::minted_by_b(x)
        }
    }
}

#[starknet::contract]
pub mod PbMintedByC {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU64<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u64 {
            super::packing_arms::minted_by_c(x)
        }
    }
}

#[starknet::contract]
pub mod PbSoulboundV270 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeBool<ContractState> {
        fn run(self: @ContractState, x: felt252) -> bool {
            super::packing_v270::unpack_soulbound(x)
        }
    }
}

#[starknet::contract]
pub mod PbSoulboundNew {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeBool<ContractState> {
        fn run(self: @ContractState, x: felt252) -> bool {
            super::packing::unpack_soulbound(x)
        }
    }
}

#[starknet::contract]
pub mod PbSoulboundA {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeBool<ContractState> {
        fn run(self: @ContractState, x: felt252) -> bool {
            super::packing_arms::soulbound_a(x)
        }
    }
}

#[starknet::contract]
pub mod PbSoulboundB {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeBool<ContractState> {
        fn run(self: @ContractState, x: felt252) -> bool {
            super::packing_arms::soulbound_b(x)
        }
    }
}

#[starknet::contract]
pub mod PbTxHashV270 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU16<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u16 {
            super::packing_v270::unpack_tx_hash(x)
        }
    }
}

#[starknet::contract]
pub mod PbTxHashNew {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU16<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u16 {
            super::packing::unpack_tx_hash(x)
        }
    }
}

#[starknet::contract]
pub mod PbTxHashA {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU16<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u16 {
            super::packing_arms::tx_hash_a(x)
        }
    }
}

#[starknet::contract]
pub mod PbSaltV270 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU16<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u16 {
            super::packing_v270::unpack_salt(x)
        }
    }
}

#[starknet::contract]
pub mod PbSaltNew {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU16<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u16 {
            super::packing::unpack_salt(x)
        }
    }
}

#[starknet::contract]
pub mod PbSaltA {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU16<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u16 {
            super::packing_arms::salt_a(x)
        }
    }
}

#[starknet::contract]
pub mod PbSaltB {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU16<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u16 {
            super::packing_arms::salt_b(x)
        }
    }
}

#[starknet::contract]
pub mod PbPaymasterV270 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeBool<ContractState> {
        fn run(self: @ContractState, x: felt252) -> bool {
            super::packing_v270::unpack_paymaster(x)
        }
    }
}

#[starknet::contract]
pub mod PbPaymasterNew {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeBool<ContractState> {
        fn run(self: @ContractState, x: felt252) -> bool {
            super::packing::unpack_paymaster(x)
        }
    }
}

#[starknet::contract]
pub mod PbPaymasterA {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeBool<ContractState> {
        fn run(self: @ContractState, x: felt252) -> bool {
            super::packing_arms::paymaster_a(x)
        }
    }
}

#[starknet::contract]
pub mod PbPaymasterB {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeBool<ContractState> {
        fn run(self: @ContractState, x: felt252) -> bool {
            super::packing_arms::paymaster_b(x)
        }
    }
}

#[starknet::contract]
pub mod PbHasContextV270 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeBool<ContractState> {
        fn run(self: @ContractState, x: felt252) -> bool {
            super::packing_v270::unpack_has_context(x)
        }
    }
}

#[starknet::contract]
pub mod PbHasContextNew {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeBool<ContractState> {
        fn run(self: @ContractState, x: felt252) -> bool {
            super::packing::unpack_has_context(x)
        }
    }
}

#[starknet::contract]
pub mod PbHasContextA {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeBool<ContractState> {
        fn run(self: @ContractState, x: felt252) -> bool {
            super::packing_arms::has_context_a(x)
        }
    }
}

#[starknet::contract]
pub mod PbHasContextB {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeBool<ContractState> {
        fn run(self: @ContractState, x: felt252) -> bool {
            super::packing_arms::has_context_b(x)
        }
    }
}

#[starknet::contract]
pub mod PbObjectiveIdV270 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing_v270::unpack_objective_id(x)
        }
    }
}

#[starknet::contract]
pub mod PbObjectiveIdNew {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing::unpack_objective_id(x)
        }
    }
}

#[starknet::contract]
pub mod PbObjectiveIdA {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing_arms::objective_id_a(x)
        }
    }
}

#[starknet::contract]
pub mod PbObjectiveIdB {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU32<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u32 {
            super::packing_arms::objective_id_b(x)
        }
    }
}

#[starknet::contract]
pub mod PbMetadataV270 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU128<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u128 {
            super::packing_v270::unpack_metadata(x)
        }
    }
}

#[starknet::contract]
pub mod PbMetadataNew {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU128<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u128 {
            super::packing::unpack_metadata(x)
        }
    }
}

#[starknet::contract]
pub mod PbExtractTxHashBitsV270 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU16<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u16 {
            super::packing_v270::extract_tx_hash_bits(x)
        }
    }
}

#[starknet::contract]
pub mod PbExtractTxHashBitsNew {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU16<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u16 {
            super::packing::extract_tx_hash_bits(x)
        }
    }
}

#[starknet::contract]
pub mod PbExtractTxHashBitsA {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU16<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u16 {
            super::packing_arms::extract_tx_hash_bits_a(x)
        }
    }
}

#[starknet::contract]
pub mod PbExtractTxHashBitsB {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeU16<ContractState> {
        fn run(self: @ContractState, x: felt252) -> u16 {
            super::packing_arms::extract_tx_hash_bits_b(x)
        }
    }
}

#[starknet::contract]
pub mod PbUnpackAllV270 {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeFull<ContractState> {
        fn run(
            self: @ContractState, x: felt252,
        ) -> crate::token::tests::packing_v270::PackedTokenId {
            super::packing_v270::unpack_token_id(x)
        }
    }
}

#[starknet::contract]
pub mod PbUnpackAllA {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeFull<ContractState> {
        fn run(
            self: @ContractState, x: felt252,
        ) -> crate::token::tests::packing_v270::PackedTokenId {
            super::packing_arms::unpack_token_id_a(x)
        }
    }
}

#[starknet::contract]
pub mod PbUnpackAllB {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeFull<ContractState> {
        fn run(
            self: @ContractState, x: felt252,
        ) -> crate::token::tests::packing_v270::PackedTokenId {
            super::packing_arms::unpack_token_id_b(x)
        }
    }
}

#[starknet::contract]
pub mod PbUnpackAllC {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeFull<ContractState> {
        fn run(
            self: @ContractState, x: felt252,
        ) -> crate::token::tests::packing_v270::PackedTokenId {
            super::packing_arms::unpack_token_id_c(x)
        }
    }
}

#[starknet::contract]
pub mod PbUnpackAllD {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeFull<ContractState> {
        fn run(
            self: @ContractState, x: felt252,
        ) -> crate::token::tests::packing_v270::PackedTokenId {
            super::packing_arms::unpack_token_id_d(x)
        }
    }
}

#[starknet::contract]
pub mod PbUnpackAllNew {
    #[storage]
    pub struct Storage {}
    #[abi(embed_v0)]
    impl P of super::IProbeFullNew<ContractState> {
        fn run(self: @ContractState, x: felt252) -> crate::token::packing::PackedTokenId {
            super::packing::unpack_token_id(x)
        }
    }
}

// ==============================================================================
// Drivers — one test per probe so gas is attributable to exactly that probe.
// ==============================================================================

/// A fully populated token id: every field at a distinct non-zero value, so no
/// accessor can be measured on an accidentally cheap input.
fn bench_input() -> felt252 {
    packing_v270::pack_token_id(
        0x7EDCBA987, // minted_at   (35 bits, top bit set)
        0x1ECBA98, // start_delay (25 bits)
        0x1DBA987, // end_delay   (25 bits)
        0xBEEF, // settings_id (16 bits)
        0x3ADCBA9, // minted_by   (26 bits)
        true,
        0x2AD, // tx_hash     (10 bits)
        0xCAFE, // salt        (16 bits)
        true,
        true,
        0x2FEDCBA9, // objective_id (30 bits)
        0x1DEADBEEFCAFEF00D // metadata (65 bits)
    )
}

#[test]
fn gas_acc_01_minted_at_v270() {
    let c = declare("PbMintedAtV270").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU64Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_02_minted_at_new() {
    let c = declare("PbMintedAtNew").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU64Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_03_minted_at_a() {
    let c = declare("PbMintedAtA").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU64Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_04_start_delay_v270() {
    let c = declare("PbStartDelayV270").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_05_start_delay_new() {
    let c = declare("PbStartDelayNew").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_06_start_delay_a() {
    let c = declare("PbStartDelayA").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_07_start_delay_b() {
    let c = declare("PbStartDelayB").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_08_start_delay_c() {
    let c = declare("PbStartDelayC").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_09_end_delay_v270() {
    let c = declare("PbEndDelayV270").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_10_end_delay_new() {
    let c = declare("PbEndDelayNew").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_11_end_delay_b() {
    let c = declare("PbEndDelayB").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_12_settings_id_v270() {
    let c = declare("PbSettingsIdV270").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_13_settings_id_new() {
    let c = declare("PbSettingsIdNew").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_14_settings_id_a() {
    let c = declare("PbSettingsIdA").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_15_settings_id_b() {
    let c = declare("PbSettingsIdB").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_16_minted_by_v270() {
    let c = declare("PbMintedByV270").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU64Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_17_minted_by_new() {
    let c = declare("PbMintedByNew").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU64Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_18_minted_by_a() {
    let c = declare("PbMintedByA").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU64Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_19_minted_by_b() {
    let c = declare("PbMintedByB").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU64Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_20_minted_by_c() {
    let c = declare("PbMintedByC").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU64Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_21_soulbound_v270() {
    let c = declare("PbSoulboundV270").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeBoolDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_22_soulbound_new() {
    let c = declare("PbSoulboundNew").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeBoolDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_23_soulbound_a() {
    let c = declare("PbSoulboundA").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeBoolDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_24_soulbound_b() {
    let c = declare("PbSoulboundB").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeBoolDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_25_tx_hash_v270() {
    let c = declare("PbTxHashV270").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU16Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_26_tx_hash_new() {
    let c = declare("PbTxHashNew").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU16Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_27_tx_hash_a() {
    let c = declare("PbTxHashA").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU16Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_28_salt_v270() {
    let c = declare("PbSaltV270").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU16Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_29_salt_new() {
    let c = declare("PbSaltNew").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU16Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_30_salt_a() {
    let c = declare("PbSaltA").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU16Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_31_salt_b() {
    let c = declare("PbSaltB").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU16Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_32_paymaster_v270() {
    let c = declare("PbPaymasterV270").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeBoolDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_33_paymaster_new() {
    let c = declare("PbPaymasterNew").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeBoolDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_34_paymaster_a() {
    let c = declare("PbPaymasterA").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeBoolDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_35_paymaster_b() {
    let c = declare("PbPaymasterB").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeBoolDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_36_has_context_v270() {
    let c = declare("PbHasContextV270").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeBoolDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_37_has_context_new() {
    let c = declare("PbHasContextNew").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeBoolDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_38_has_context_a() {
    let c = declare("PbHasContextA").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeBoolDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_39_has_context_b() {
    let c = declare("PbHasContextB").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeBoolDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_40_objective_id_v270() {
    let c = declare("PbObjectiveIdV270").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_41_objective_id_new() {
    let c = declare("PbObjectiveIdNew").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_42_objective_id_a() {
    let c = declare("PbObjectiveIdA").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_43_objective_id_b() {
    let c = declare("PbObjectiveIdB").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU32Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_44_metadata_v270() {
    let c = declare("PbMetadataV270").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU128Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_45_metadata_new() {
    let c = declare("PbMetadataNew").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU128Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_46_extract_tx_hash_bits_v270() {
    let c = declare("PbExtractTxHashBitsV270").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU16Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_47_extract_tx_hash_bits_new() {
    let c = declare("PbExtractTxHashBitsNew").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU16Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_48_extract_tx_hash_bits_a() {
    let c = declare("PbExtractTxHashBitsA").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU16Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_49_extract_tx_hash_bits_b() {
    let c = declare("PbExtractTxHashBitsB").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeU16Dispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_50_unpack_all_v270() {
    let c = declare("PbUnpackAllV270").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeFullDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_51_unpack_all_a() {
    let c = declare("PbUnpackAllA").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeFullDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_52_unpack_all_b() {
    let c = declare("PbUnpackAllB").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeFullDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_53_unpack_all_c() {
    let c = declare("PbUnpackAllC").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeFullDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_54_unpack_all_d() {
    let c = declare("PbUnpackAllD").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeFullDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_55_unpack_all_new() {
    let c = declare("PbUnpackAllNew").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeFullNewDispatcher { contract_address: a }.run(bench_input());
}

#[test]
fn gas_acc_56_floor_noop() {
    let c = declare("PbNoop").unwrap().contract_class();
    let (a, _) = c.deploy(@array![]).unwrap();
    let _ = IProbeFeltDispatcher { contract_address: a }.run(bench_input());
}
