use starknet::ContractAddress;

#[starknet::interface]
pub trait IMetagameMock<TContractState> {
    fn mint_game(
        ref self: TContractState,
        game_address: ContractAddress,
        player_name: Option<felt252>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_id: Option<u32>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        skills_address: Option<ContractAddress>,
        to: ContractAddress,
        soulbound: bool,
        paymaster: bool,
        salt: u16,
        metadata: u128,
    ) -> felt252;
}

#[starknet::interface]
pub trait IMetagameMockInit<TContractState> {
    fn initializer(
        ref self: TContractState,
        context_address: Option<ContractAddress>,
        minigame_token_address: ContractAddress,
        supports_context: bool,
    );
}

#[starknet::interface]
pub trait IMetagameCallbackMockView<TContractState> {
    fn game_action_count(self: @TContractState) -> u32;
    fn game_over_count(self: @TContractState) -> u32;
    fn objective_complete_count(self: @TContractState) -> u32;
}

#[starknet::contract]
pub mod metagame_mock {
    use game_components_embeddable_game_standard::metagame::extensions::context::interface::{
        IMETAGAME_CONTEXT_ID, IMetagameContext, IMetagameContextDetails,
    };
    use game_components_embeddable_game_standard::metagame::extensions::context::structs::{
        GameContext, GameContextDetails,
    };
    use game_components_embeddable_game_standard::metagame::metagame;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Callback hooks implementation that tracks calls for test assertions

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // Metagame storage
        token_counter: u64,
        // Token context storage - mimicking the Dojo Context model
        token_context_count: Map<felt252, u32>, // token_id -> count of contexts
        token_context_name: Map<(felt252, u32), felt252>, // (token_id, index) -> context name
        token_context_value: Map<(felt252, u32), felt252>, // (token_id, index) -> context value
        token_context_exists: Map<felt252, bool>, // token_id -> exists
        // Callback tracking storage
        cb_game_action_count: u32,
        cb_game_over_count: u32,
        cb_objective_complete_count: u32,
        cb_last_token_id: u256,
        cb_last_score: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[abi(embed_v0)]
    impl MetagameContextImpl of IMetagameContext<ContractState> {
        fn has_context(
            self: @ContractState, game_address: ContractAddress, token_id: felt252,
        ) -> bool {
            // The mock keys only by token_id — enough for tests, which use one
            // game. A real metagame must key by the (game, token) pair.
            let _ = game_address;
            self.token_context_exists.read(token_id)
        }
    }

    #[abi(embed_v0)]
    impl MetagameContextDetailsImpl of IMetagameContextDetails<ContractState> {
        fn context_details(
            self: @ContractState, game_address: ContractAddress, token_id: felt252,
        ) -> GameContextDetails {
            let _ = game_address;
            let context_count = self.token_context_count.read(token_id);
            let mut contexts = array![];

            let mut i = 0;
            while i < context_count {
                let name = self.token_context_name.read((token_id, i));
                let value = self.token_context_value.read((token_id, i));

                contexts.append(GameContext { name, value });
                i += 1;
            }

            GameContextDetails {
                name: "Test Game Context",
                description: "Test context for testing",
                id: Option::None,
                context: contexts.span(),
            }
        }
    }

    #[abi(embed_v0)]
    impl MetagameMockImpl of super::IMetagameMock<ContractState> {
        fn mint_game(
            ref self: ContractState,
            game_address: ContractAddress,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            skills_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u128,
        ) -> felt252 {
            let context = array![GameContext { name: 'Test Context 1', value: 'Test Context' }]
                .span();
            let context_details = GameContextDetails {
                name: "Test App",
                description: "Test App Description",
                id: Option::None,
                context: context,
            };
            // Call the metagame component mint function
            let token_id = metagame::mint(
                game_address,
                player_name,
                settings_id,
                start,
                end,
                objective_id,
                Option::Some(context_details),
                client_url,
                renderer_address,
                skills_address,
                to,
                soulbound,
                paymaster,
                salt,
                metadata,
            );

            // Store the context data in our local storage
            self.token_context_count.write(token_id, 1);
            self.token_context_name.write((token_id, 0), 'Test Context 1');
            self.token_context_value.write((token_id, 0), 'Test Context');
            self.token_context_exists.write(token_id, true);

            token_id
        }
    }

    #[abi(embed_v0)]
    impl MetagameCallbackMockViewImpl of super::IMetagameCallbackMockView<ContractState> {
        fn game_action_count(self: @ContractState) -> u32 {
            self.cb_game_action_count.read()
        }

        fn game_over_count(self: @ContractState) -> u32 {
            self.cb_game_over_count.read()
        }

        fn objective_complete_count(self: @ContractState) -> u32 {
            self.cb_objective_complete_count.read()
        }
    }

    #[abi(embed_v0)]
    impl MetagameInitializerImpl of super::IMetagameMockInit<ContractState> {
        fn initializer(
            ref self: ContractState,
            context_address: Option<ContractAddress>,
            minigame_token_address: ContractAddress,
            supports_context: bool,
        ) {
            // Initialize the metagame component

            // Initialize local storage
            self.token_counter.write(0);

            // Initialize context support if needed
            if supports_context {
                self.src5.register_interface(IMETAGAME_CONTEXT_ID);
            }
        }
    }
}
