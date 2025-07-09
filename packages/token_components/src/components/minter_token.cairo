//! Minter Token Component
//!
//! This component extends the CoreTokenComponent by adding minter tracking functionality.
//! It implements both IMinigameToken and IMinterToken interfaces.
//!
//! Use this component when you need basic token functionality + minter tracking.

use starknet::ContractAddress;
use starknet::storage::{
    StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
};
use openzeppelin_token::erc721::ERC721Component;
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
use crate::interface::{IMinigameToken, IMinterToken};

#[starknet::component]
pub mod MinterTokenComponent {
    use super::*;

    #[storage]
    pub struct Storage {
        // Core token metadata
        token_settings: Map<u64, u32>,
        token_game_addresses: Map<u64, ContractAddress>,
        token_objective_ids: Map<u64, Array<u32>>,
        token_count: u64,
        // Minter tracking
        token_minted_by: Map<u64, u64>, // token_id -> minter_id
        minter_registry: Map<ContractAddress, u64>, // minter_address -> minter_id
        minter_registry_id: Map<u64, ContractAddress>, // minter_id -> minter_address
        minter_count: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenMinted: TokenMinted,
        MinterRegistered: MinterRegistered,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenMinted {
        pub token_id: u64,
        pub to: ContractAddress,
        pub game_address: ContractAddress,
        pub settings_id: u32,
        pub objectives: Array<u32>,
        pub minted_by: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MinterRegistered {
        pub minter_id: u64,
        pub minter_address: ContractAddress,
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

            // Track the minter
            let minter_id = self.add_minter(starknet::get_caller_address());

            // Store token metadata
            self.token_settings.entry(token_id).write(settings_id);
            self.token_game_addresses.entry(token_id).write(game_address);
            self.token_objective_ids.entry(token_id).write(objectives.clone());
            self.token_minted_by.entry(token_id).write(minter_id);
            self.token_count.write(token_id);

            // Emit event
            self.emit(TokenMinted { token_id, to, game_address, settings_id, objectives, minted_by: minter_id });

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

    #[embeddable_as(MinterTokenImpl)]
    impl MinterToken<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinterToken<ComponentState<TContractState>> {
        fn minted_by(self: @ComponentState<TContractState>, token_id: u64) -> u64 {
            self.token_minted_by.entry(token_id).read()
        }

        fn minter_address(self: @ComponentState<TContractState>, minter_id: u64) -> ContractAddress {
            self.minter_registry_id.entry(minter_id).read()
        }

        fn minter_count(self: @ComponentState<TContractState>) -> u64 {
            self.minter_count.read()
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
            // Register interfaces
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(0x1234567890abcdef); // IMinigameToken interface ID
            src5_component.register_interface(0xfedcba0987654321); // IMinterToken interface ID
        }

        fn add_minter(ref self: ComponentState<TContractState>, minter_address: ContractAddress) -> u64 {
            let minter_count = self.minter_count.read();
            let minter_id = self.minter_registry.entry(minter_address).read();

            let mut registered_minter_id: u64 = 0;

            // If minter is not registered, register it
            if minter_id == 0 {
                registered_minter_id = minter_count + 1;
                self.minter_registry.entry(minter_address).write(registered_minter_id);
                self.minter_registry_id.entry(registered_minter_id).write(minter_address);
                self.minter_count.write(registered_minter_id);
                
                self.emit(MinterRegistered { minter_id: registered_minter_id, minter_address });
            } else {
                registered_minter_id = minter_id;
            }

            registered_minter_id
        }
    }
} 