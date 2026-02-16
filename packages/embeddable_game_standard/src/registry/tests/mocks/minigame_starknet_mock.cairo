/// A minimal mock minigame contract for registry testing
/// Only needs to support SRC5 for interface detection
#[starknet::contract]
pub mod registry_minigame_starknet_mock {
    use game_components_embeddable_game_standard::minigame::interface::IMINIGAME_ID;
    use openzeppelin_introspection::src5::SRC5Component;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Register IMinigame interface
        self.src5.register_interface(IMINIGAME_ID);
    }
}
