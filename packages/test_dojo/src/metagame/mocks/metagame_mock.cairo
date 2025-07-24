use starknet::ContractAddress;

#[starknet::interface]
pub trait IMetagameMock<TContractState> {
    fn mint_minigame_token(
        ref self: TContractState,
        game_address: Option<ContractAddress>,
        player_name: Option<felt252>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_ids: Option<Span<u32>>,
        context: Option<ByteArray>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        to: ContractAddress,
        soulbound: bool,
    ) -> u64;
}

#[starknet::interface]
pub trait IMetagameMockInit<TContractState> {
    fn initializer(
        ref self: TContractState,
        namespace: ByteArray,
        minigame_token_address: ContractAddress,
        supports_context: bool,
    );
}

#[dojo::contract]
mod metagame_mock {
    use game_components_metagame::interface::{IMetagame, IMetagameContext};
    use game_components_metagame::metagame::metagame_component;
    use game_components_metagame::structs::context::{GameContext, GameContextDetails};
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    component!(path: metagame_component, storage: metagame, event: MetagameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl MetagameImpl = metagame_component::MetagameImpl<ContractState>;
    impl MetagameInternalImpl = metagame_component::InternalImpl<ContractState>;
    impl MetagameInternalContextImpl = metagame_component::InternalContextImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        metagame: metagame_component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MetagameEvent: metagame_component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[abi(embed_v0)]
    impl MetagameContextImpl of IMetagameContext<ContractState> {
        fn has_context(self: @ContractState, token_id: u64) -> bool {
            true // For testing, assume all tokens have context
        }

        fn context(self: @ContractState, token_id: u64) -> GameContextDetails {
            let context = array![
                GameContext { name: "Player", value: "Test Player Name" },
                GameContext { name: "Enemy Count", value: "10 Enemies" },
                GameContext { name: "Weapon", value: "Test Sword" },
                GameContext { name: "Health", value: "100 HP" },
            ];
            GameContextDetails {
                name: "Test App", description: "Test App Description", context: context.span(),
            }
        }
    }

    #[abi(embed_v0)]
    impl MetagameMockImpl of super::IMetagameMock<ContractState> {
        fn mint_minigame_token(
            ref self: ContractState,
            game_address: Option<ContractAddress>,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_ids: Option<Span<u32>>,
            context: Option<ByteArray>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            self
                .metagame
                .mint(
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
                    soulbound,
                )
        }
    }

    #[abi(embed_v0)]
    impl MetagameInitializerImpl of super::IMetagameMockInit<ContractState> {
        fn initializer(
            ref self: ContractState,
            namespace: ByteArray,
            minigame_token_address: ContractAddress,
            supports_context: bool,
        ) {
            self.metagame.initializer(namespace, minigame_token_address);
            if supports_context {
                self.metagame.initialize_context();
            }
        }
    }
}
