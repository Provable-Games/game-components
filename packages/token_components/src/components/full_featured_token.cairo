//! Full Featured Token Component
//!
//! This component combines all available features:
//! - Core token functionality (ERC721 + minigame token)
//! - Minter tracking
//! - Multi-game support
//! - Objectives tracking
//!
//! Use this component when you need all features in one place.

use starknet::ContractAddress;
use starknet::storage::{
    StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
};
use openzeppelin_token::erc721::ERC721Component;
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
use crate::interface::{IMinigameToken, IMinterToken, IMultiGameToken, IObjectivesToken};

#[starknet::component]
pub mod FullFeaturedTokenComponent {
    use super::*;

    #[storage]
    pub struct Storage {
        // Core token metadata
        token_settings: Map<u64, u32>,
        token_game_addresses: Map<u64, ContractAddress>,
        token_objective_ids: Map<u64, Array<u32>>,
        token_count: u64,
        // Minter tracking
        token_minted_by: Map<u64, u64>,
        minter_registry: Map<ContractAddress, u64>,
        minter_registry_id: Map<u64, ContractAddress>,
        minter_count: u64,
        // Multi-game support
        game_count: u64,
        game_id_by_address: Map<ContractAddress, u64>,
        game_address_by_id: Map<u64, ContractAddress>,
        game_metadata: Map<u64, GameMetadata>,
        // Objectives tracking
        token_objective_count: Map<u64, u32>,
        token_objectives_completed: Map<(u64, u32), bool>,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct GameMetadata {
        pub creator_address: ContractAddress,
        pub name: ByteArray,
        pub description: ByteArray,
        pub developer: ByteArray,
        pub publisher: ByteArray,
        pub genre: ByteArray,
        pub image: ByteArray,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenMinted: TokenMinted,
        MinterRegistered: MinterRegistered,
        GameRegistered: GameRegistered,
        ObjectiveCreated: ObjectiveCreated,
        ObjectiveCompleted: ObjectiveCompleted,
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

    #[derive(Drop, starknet::Event)]
    pub struct GameRegistered {
        pub game_id: u64,
        pub contract_address: ContractAddress,
        pub name: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ObjectiveCreated {
        pub game_address: ContractAddress,
        pub objective_id: u32,
        pub objective_data: game_components_minigame::extensions::objectives::structs::GameObjective,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ObjectiveCompleted {
        pub token_id: u64,
        pub objective_id: u32,
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

            // Initialize objectives tracking
            self.token_objective_count.entry(token_id).write(objectives.len());

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

    #[embeddable_as(MultiGameTokenImpl)]
    impl MultiGameToken<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMultiGameToken<ComponentState<TContractState>> {
        fn register_game(
            ref self: ComponentState<TContractState>,
            creator_address: ContractAddress,
            name: ByteArray,
            description: ByteArray,
            developer: ByteArray,
            publisher: ByteArray,
            genre: ByteArray,
            image: ByteArray,
            color: Option<ByteArray>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
        ) -> u64 {
            let game_count = self.game_count.read();
            let game_id = game_count + 1;
            let caller_address = starknet::get_caller_address();

            // Store game metadata
            let metadata = GameMetadata {
                creator_address,
                name: name.clone(),
                description,
                developer,
                publisher,
                genre,
                image,
            };

            self.game_id_by_address.entry(caller_address).write(game_id);
            self.game_address_by_id.entry(game_id).write(caller_address);
            self.game_metadata.entry(game_id).write(metadata);
            self.game_count.write(game_id);

            self.emit(GameRegistered { game_id, contract_address: caller_address, name });

            game_id
        }

        fn game_count(self: @ComponentState<TContractState>) -> u64 {
            self.game_count.read()
        }

        fn game_id_from_address(self: @ComponentState<TContractState>, contract_address: ContractAddress) -> u64 {
            self.game_id_by_address.entry(contract_address).read()
        }

        fn is_game_registered(self: @ComponentState<TContractState>, contract_address: ContractAddress) -> bool {
            let game_id = self.game_id_by_address.entry(contract_address).read();
            game_id != 0
        }
    }

    #[embeddable_as(ObjectivesTokenImpl)]
    impl ObjectivesToken<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IObjectivesToken<ComponentState<TContractState>> {
        fn objectives_count(self: @ComponentState<TContractState>, token_id: u64) -> u32 {
            self.token_objective_count.entry(token_id).read()
        }

        fn all_objectives_completed(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            let objective_count = self.token_objective_count.entry(token_id).read();
            let mut completed_count = 0;
            let mut i = 0;

            while i < objective_count {
                if self.token_objectives_completed.entry((token_id, i)).read() {
                    completed_count += 1;
                }
                i += 1;
            };

            completed_count == objective_count
        }

        fn create_objective(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
            objective_id: u32,
            objective_data: game_components_minigame::extensions::objectives::structs::GameObjective,
        ) {
            self.emit(ObjectiveCreated { game_address, objective_id, objective_data });
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
            // Register all interfaces
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(0x1234567890abcdef); // IMinigameToken interface ID
            src5_component.register_interface(0xfedcba0987654321); // IMinterToken interface ID
            src5_component.register_interface(0x1111222233334444); // IMultiGameToken interface ID
            src5_component.register_interface(0x5555666677778888); // IObjectivesToken interface ID
        }

        fn add_minter(ref self: ComponentState<TContractState>, minter_address: ContractAddress) -> u64 {
            let minter_count = self.minter_count.read();
            let minter_id = self.minter_registry.entry(minter_address).read();

            let mut registered_minter_id: u64 = 0;

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

        fn complete_objective(ref self: ComponentState<TContractState>, token_id: u64, objective_index: u32) {
            self.token_objectives_completed.entry((token_id, objective_index)).write(true);
            self.emit(ObjectiveCompleted { token_id, objective_id: objective_index });
        }
    }
} 