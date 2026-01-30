use starknet::ContractAddress;

#[starknet::interface]
pub trait IMetagameStarknetMock<TContractState> {
    fn mint_game(
        ref self: TContractState,
        game_address: Option<ContractAddress>,
        player_name: Option<felt252>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_id: Option<u32>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        to: ContractAddress,
        soulbound: bool,
        paymaster: bool,
        salt: u16,
        metadata: u16,
    ) -> felt252;
}

#[starknet::interface]
pub trait IMetagameStarknetMockInit<TContractState> {
    fn initializer(
        ref self: TContractState,
        context_address: Option<ContractAddress>,
        minigame_token_address: ContractAddress,
        supports_context: bool,
    );
}

#[starknet::interface]
pub trait IMetagameCallbackMockView<TContractState> {
    fn score_update_count(self: @TContractState) -> u32;
    fn game_over_count(self: @TContractState) -> u32;
    fn objective_complete_count(self: @TContractState) -> u32;
    fn last_callback_token_id(self: @TContractState) -> felt252;
    fn last_callback_score(self: @TContractState) -> u64;
}

#[starknet::contract]
pub mod metagame_starknet_mock {
    use game_components_metagame::extensions::callback::callback::MetagameCallbackComponent;
    use game_components_metagame::extensions::context::context::ContextComponent;
    use game_components_metagame::extensions::context::interface::{
        IMetagameContext, IMetagameContextDetails,
    };
    use game_components_metagame::extensions::context::structs::{GameContext, GameContextDetails};
    use game_components_metagame::metagame::MetagameComponent;
    use game_components_metagame::metagame::MetagameComponent::InternalTrait as MetagameInternalTrait;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    component!(path: MetagameComponent, storage: metagame, event: MetagameEvent);
    component!(path: ContextComponent, storage: context, event: ContextEvent);
    component!(path: MetagameCallbackComponent, storage: callback, event: CallbackEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Callback hooks implementation that tracks calls for test assertions
    impl CallbackHooksImpl of MetagameCallbackComponent::MetagameCallbackHooksTrait<ContractState> {
        fn on_score_update(ref self: ContractState, token_id: u256, score: u64) {
            self.cb_score_update_count.write(self.cb_score_update_count.read() + 1);
            self.cb_last_token_id.write(token_id);
            self.cb_last_score.write(score);
        }

        fn on_game_over(ref self: ContractState, token_id: u256, final_score: u64) {
            self.cb_game_over_count.write(self.cb_game_over_count.read() + 1);
            self.cb_last_token_id.write(token_id);
            self.cb_last_score.write(final_score);
        }

        fn on_objective_complete(ref self: ContractState, token_id: u256) {
            self.cb_objective_complete_count.write(self.cb_objective_complete_count.read() + 1);
            self.cb_last_token_id.write(token_id);
        }
    }

    #[abi(embed_v0)]
    impl MetagameImpl = MetagameComponent::MetagameImpl<ContractState>;
    impl MetagameInternalImpl = MetagameComponent::InternalImpl<ContractState>;
    impl ContextInternalImpl = ContextComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl MetagameCallbackImpl =
        MetagameCallbackComponent::MetagameCallbackImpl<ContractState>;
    impl CallbackInternalImpl = MetagameCallbackComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        metagame: MetagameComponent::Storage,
        #[substorage(v0)]
        context: ContextComponent::Storage,
        #[substorage(v0)]
        callback: MetagameCallbackComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // Metagame storage
        token_counter: u64,
        // Token context storage - mimicking the Dojo Context model
        token_context_count: Map<felt252, u32>, // token_id -> count of contexts
        token_context_name: Map<(felt252, u32), ByteArray>, // (token_id, index) -> context name
        token_context_value: Map<(felt252, u32), ByteArray>, // (token_id, index) -> context value
        token_context_exists: Map<felt252, bool>, // token_id -> exists
        // Callback tracking storage
        cb_score_update_count: u32,
        cb_game_over_count: u32,
        cb_objective_complete_count: u32,
        cb_last_token_id: u256,
        cb_last_score: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MetagameEvent: MetagameComponent::Event,
        #[flat]
        ContextEvent: ContextComponent::Event,
        #[flat]
        CallbackEvent: MetagameCallbackComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[abi(embed_v0)]
    impl MetagameContextImpl of IMetagameContext<ContractState> {
        fn has_context(self: @ContractState, token_id: felt252) -> bool {
            self.token_context_exists.read(token_id)
        }
    }

    #[abi(embed_v0)]
    impl MetagameContextDetailsImpl of IMetagameContextDetails<ContractState> {
        fn context_details(self: @ContractState, token_id: felt252) -> GameContextDetails {
            let context_count = self.token_context_count.read(token_id);
            let mut contexts = array![];

            let mut i = 0;
            while i < context_count {
                let context_name = self.token_context_name.read((token_id, i));
                let context_value = self.token_context_value.read((token_id, i));

                let game_context = GameContext { name: context_name, value: context_value };
                contexts.append(game_context);
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
    impl MetagameMockImpl of super::IMetagameStarknetMock<ContractState> {
        fn mint_game(
            ref self: ContractState,
            game_address: Option<ContractAddress>,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u16,
        ) -> felt252 {
            let context = array![GameContext { name: "Test Context 1", value: "Test Context" }]
                .span();
            let context_details = GameContextDetails {
                name: "Test App",
                description: "Test App Description",
                id: Option::None,
                context: context,
            };
            // Call the metagame component mint function
            let token_id = self
                .metagame
                .mint(
                    game_address,
                    player_name,
                    settings_id,
                    start,
                    end,
                    objective_id,
                    Option::Some(context_details),
                    client_url,
                    renderer_address,
                    to,
                    soulbound,
                    paymaster,
                    salt,
                    metadata,
                );

            // Store the context data in our local storage
            self.token_context_count.write(token_id, 1);
            self.token_context_name.write((token_id, 0), "Test Context 1");
            self.token_context_value.write((token_id, 0), "Test Context");
            self.token_context_exists.write(token_id, true);

            token_id
        }
    }

    #[abi(embed_v0)]
    impl MetagameCallbackMockViewImpl of super::IMetagameCallbackMockView<ContractState> {
        fn score_update_count(self: @ContractState) -> u32 {
            self.cb_score_update_count.read()
        }

        fn game_over_count(self: @ContractState) -> u32 {
            self.cb_game_over_count.read()
        }

        fn objective_complete_count(self: @ContractState) -> u32 {
            self.cb_objective_complete_count.read()
        }

        fn last_callback_token_id(self: @ContractState) -> felt252 {
            self.cb_last_token_id.read().try_into().unwrap()
        }

        fn last_callback_score(self: @ContractState) -> u64 {
            self.cb_last_score.read()
        }
    }

    #[abi(embed_v0)]
    impl MetagameInitializerImpl of super::IMetagameStarknetMockInit<ContractState> {
        fn initializer(
            ref self: ContractState,
            context_address: Option<ContractAddress>,
            minigame_token_address: ContractAddress,
            supports_context: bool,
        ) {
            // Initialize the metagame component
            self.metagame.initializer(context_address, minigame_token_address);

            // Initialize local storage
            self.token_counter.write(0);

            // Initialize context support if needed
            if supports_context {
                self.context.initializer();
            }

            // Initialize callback component (registers SRC5 interface)
            self.callback.initializer();
        }
    }
}
