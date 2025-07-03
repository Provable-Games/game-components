#[starknet::contract]
pub mod MockMetagameContract {
    use game_components_metagame::metagame::MetagameComponent;
    use game_components_metagame::extensions::context::interface::{IMetagameContext, IMETAGAME_CONTEXT_ID};
    use game_components_metagame::extensions::context::structs::{GameContextDetails, GameContext};
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess};

    component!(path: MetagameComponent, storage: metagame, event: MetagameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl MetagameImpl = MetagameComponent::MetagameImpl<ContractState>;
    
    impl MetagameInternalImpl = MetagameComponent::InternalImpl<ContractState>;
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        metagame: MetagameComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // Storage for context data when testing embedded context
        // We use a simple approach - just tracking if context exists
        context_exists: Map<u64, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MetagameEvent: MetagameComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        minigame_token_address: ContractAddress,
        context_address: Option<ContractAddress>,
        supports_context: bool,
    ) {
        self.metagame.initializer(context_address, minigame_token_address);
        
        // If we should support context interface for embedded context testing
        if supports_context {
            self.src5.register_interface(IMETAGAME_CONTEXT_ID);
        }
    }

    // IMetagameContext implementation for testing embedded context
    #[abi(embed_v0)]
    impl MetagameContextImpl of IMetagameContext<ContractState> {
        fn has_context(self: @ContractState, token_id: u64) -> bool {
            self.context_exists.entry(token_id).read()
        }
        
        fn context(self: @ContractState, token_id: u64) -> GameContextDetails {
            // For testing, return a dummy context
            GameContextDetails {
                name: "Test Context",
                description: "Test Description",
                id: Option::Some(1),
                context: array![
                    GameContext { name: "key1", value: "value1" },
                    GameContext { name: "key2", value: "value2" },
                ].span(),
            }
        }
    }

    // Helper functions for testing
    #[external(v0)]
    fn set_context_data(ref self: ContractState, token_id: u64, context: GameContextDetails) {
        // Just mark that context exists for this token
        self.context_exists.entry(token_id).write(true);
    }

    #[external(v0)]
    fn test_mint(
        ref self: ContractState,
        game_address: Option<ContractAddress>,
        player_name: Option<ByteArray>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_ids: Option<Span<u32>>,
        context: Option<GameContextDetails>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        to: ContractAddress,
        soulbound: bool,
    ) -> u64 {
        self.metagame.mint(
            game_address,
            player_name,
            settings_id,
            start,
            end,
            objective_ids,
            context,
            client_url,
            renderer_address,
            to,
            soulbound
        )
    }

    #[external(v0)]
    fn test_assert_game_registered(
        ref self: ContractState,
        game_address: ContractAddress,
    ) {
        self.metagame.assert_game_registered(game_address);
    }
}