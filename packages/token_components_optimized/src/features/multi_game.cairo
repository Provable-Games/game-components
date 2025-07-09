#[starknet::interface]
pub trait IMultiGameComponent<TState> {
    fn game_count(self: @TState) -> u64;
    fn game_id_from_address(self: @TState, contract_address: starknet::ContractAddress) -> u64;
    fn game_address_from_id(self: @TState, game_id: u64) -> starknet::ContractAddress;
    fn game_metadata(self: @TState, game_id: u64) -> GameMetadata;
    fn is_game_registered(self: @TState, contract_address: starknet::ContractAddress) -> bool;
    fn game_address(self: @TState, token_id: u64) -> starknet::ContractAddress;
    fn creator_token_id(self: @TState, game_id: u64) -> u64;
    fn client_url(self: @TState, token_id: u64) -> ByteArray;
    fn register_game(
        ref self: TState,
        creator_address: starknet::ContractAddress,
        name: ByteArray,
        description: ByteArray,
        developer: ByteArray,
        publisher: ByteArray,
        genre: ByteArray,
        image: ByteArray,
        color: Option<ByteArray>,
        client_url: Option<ByteArray>,
        renderer_address: Option<starknet::ContractAddress>,
    ) -> u64;
    fn enable_game(ref self: TState, game_id: u64);
    fn disable_game(ref self: TState, game_id: u64);
}

#[derive(Drop, Serde, starknet::Store)]
pub struct GameMetadata {
    pub creator_token_id: u64,
    pub contract_address: starknet::ContractAddress,
    pub name: ByteArray,
    pub description: ByteArray,
    pub developer: ByteArray,
    pub publisher: ByteArray,
    pub genre: ByteArray,
    pub image: ByteArray,
    pub color: ByteArray,
    pub client_url: ByteArray,
    pub renderer_address: starknet::ContractAddress,
    pub settings_address: starknet::ContractAddress,
    pub objectives_address: starknet::ContractAddress,
    pub is_active: bool,
}

#[starknet::component]
pub mod MultiGameComponent {
    use starknet::ContractAddress;
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    use crate::core::traits::OptionalMultiGame;
    use super::{IMultiGameComponent, GameMetadata};

    #[storage]
    pub struct Storage {
        game_counter: u64,
        game_metadata: Map<u64, GameMetadata>,
        game_id_by_address: Map<ContractAddress, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        GameRegistered: GameRegistered,
        GameEnabled: GameEnabled,
        GameDisabled: GameDisabled,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GameRegistered {
        game_id: u64,
        game_address: ContractAddress,
        name: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GameEnabled {
        game_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GameDisabled {
        game_id: u64,
    }

    #[embeddable_as(MultiGameImpl)]
    pub impl MultiGame<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMultiGameComponent<ComponentState<TContractState>> {
        
        fn game_count(self: @ComponentState<TContractState>) -> u64 {
            self.game_counter.read()
        }

        fn game_id_from_address(self: @ComponentState<TContractState>, contract_address: ContractAddress) -> u64 {
            self.game_id_by_address.entry(contract_address).read()
        }

        fn game_address_from_id(self: @ComponentState<TContractState>, game_id: u64) -> ContractAddress {
            self.game_metadata.entry(game_id).read().contract_address
        }

        fn game_metadata(self: @ComponentState<TContractState>, game_id: u64) -> GameMetadata {
            self.game_metadata.entry(game_id).read()
        }

        fn is_game_registered(self: @ComponentState<TContractState>, contract_address: ContractAddress) -> bool {
            self.game_id_by_address.entry(contract_address).read() != 0
        }

        fn game_address(self: @ComponentState<TContractState>, token_id: u64) -> ContractAddress {
            // TODO: Implement token to game address mapping
            starknet::contract_address_const::<0>()
        }

        fn creator_token_id(self: @ComponentState<TContractState>, game_id: u64) -> u64 {
            self.game_metadata.entry(game_id).read().creator_token_id
        }

        fn client_url(self: @ComponentState<TContractState>, token_id: u64) -> ByteArray {
            // TODO: Implement token to client URL mapping
            ""
        }
        
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
            let game_id = self.game_counter.read() + 1;
            
            let final_color = match color {
                Option::Some(color) => color,
                Option::None => "",
            };

            let final_client_url = match client_url {
                Option::Some(client_url) => client_url,
                Option::None => "",
            };

            let final_renderer_address = match renderer_address {
                Option::Some(renderer_address) => renderer_address,
                Option::None => starknet::contract_address_const::<0>(),
            };
            
            let metadata = GameMetadata {
                creator_token_id: 0, // TODO: Implement creator token minting
                contract_address: creator_address,
                name: name.clone(),
                description,
                developer,
                publisher,
                genre,
                image,
                color: final_color,
                client_url: final_client_url,
                renderer_address: final_renderer_address,
                settings_address: starknet::contract_address_const::<0>(),
                objectives_address: starknet::contract_address_const::<0>(),
                is_active: true,
            };
            
            self.game_metadata.entry(game_id).write(metadata);
            self.game_id_by_address.entry(creator_address).write(game_id);
            self.game_counter.write(game_id);
            
            self.emit(GameRegistered {
                game_id,
                game_address: creator_address,
                name,
            });
            
            game_id
        }

        fn enable_game(ref self: ComponentState<TContractState>, game_id: u64) {
            let mut metadata = self.game_metadata.entry(game_id).read();
            metadata.is_active = true;
            self.game_metadata.entry(game_id).write(metadata);
            
            self.emit(GameEnabled { game_id });
        }

        fn disable_game(ref self: ComponentState<TContractState>, game_id: u64) {
            let mut metadata = self.game_metadata.entry(game_id).read();
            metadata.is_active = false;
            self.game_metadata.entry(game_id).write(metadata);
            
            self.emit(GameDisabled { game_id });
        }
    }

    // Implementation of the OptionalMultiGame trait for integration with CoreTokenComponent
    pub impl MultiGameOptionalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of OptionalMultiGame<TContractState> {
        
        fn get_game_metadata_for_address(self: @TContractState, game_address: ContractAddress) -> Option<GameMetadata> {
            let component = HasComponent::get_component(self);
            let game_id = component.game_id_by_address.entry(game_address).read();
            
            if game_id == 0 {
                Option::None
            } else {
                Option::Some(component.game_metadata.entry(game_id).read())
            }
        }

        fn is_game_registered(self: @TContractState, game_address: ContractAddress) -> bool {
            let component = HasComponent::get_component(self);
            component.game_id_by_address.entry(game_address).read() != 0
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        
        fn initializer(ref self: ComponentState<TContractState>) {
            // Initialize game counter
            self.game_counter.write(0);
        }
    }
} 