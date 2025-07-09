//! Core Token Component
//!
//! This component provides the basic ERC721 + minigame token functionality
//! without any optional features like minter tracking, multi-game support, etc.
//!
//! Use this component when you need a simple token with just the core features.

use starknet::ContractAddress;
use starknet::storage::{
    StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
};
use openzeppelin_token::erc721::ERC721Component;
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
use crate::interface::IMinigameToken;

#[starknet::component]
pub mod CoreTokenComponent {
    use super::*;

    #[storage]
    pub struct Storage {
        // Token metadata
        token_settings: Map<u64, u32>,
        token_game_addresses: Map<u64, ContractAddress>,
        token_objective_ids: Map<u64, Array<u32>>,
        // Token counter
        token_count: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenMinted: TokenMinted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenMinted {
        pub token_id: u64,
        pub to: ContractAddress,
        pub game_address: ContractAddress,
        pub settings_id: u32,
        pub objectives: Array<u32>,
    }

    #[embeddable_as(MinigameTokenImpl)]
    impl MinigameToken<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinigameToken<ComponentState<TContractState>> {
        fn mint(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            game_address: ContractAddress,
            settings_id: u32,
            objectives: Array<u32>,
        ) -> u64 {
            let token_count = self.token_count.read();
            let token_id = token_count + 1;

            // Mint the ERC721 token
            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
            erc721_component._mint(to, token_id.into());

            // Store token metadata
            self.token_settings.entry(token_id).write(settings_id);
            self.token_game_addresses.entry(token_id).write(game_address);
            self.token_objective_ids.entry(token_id).write(objectives.clone());
            self.token_count.write(token_id);

            // Emit event
            self.emit(TokenMinted { token_id, to, game_address, settings_id, objectives });

            token_id
        }

        fn settings_id(self: @ComponentState<TContractState>, token_id: u64) -> u32 {
            self.token_settings.entry(token_id).read()
        }

        fn game_address(self: @ComponentState<TContractState>, token_id: u64) -> ContractAddress {
            self.token_game_addresses.entry(token_id).read()
        }

        fn objective_ids(self: @ComponentState<TContractState>, token_id: u64) -> Span<u32> {
            self.token_objective_ids.entry(token_id).read().span()
        }

        fn token_count(self: @ComponentState<TContractState>) -> u64 {
            self.token_count.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, game_address: Option<ContractAddress>) {
            // Register the IMinigameToken interface
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(0x1234567890abcdef); // IMinigameToken interface ID
        }
    }
} 