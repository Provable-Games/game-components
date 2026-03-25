/// Mock contract composing ERC721 + EnumerableComponent + SRC5 for testing
/// the felt252-optimized enumerable extension.
#[starknet::contract]
pub mod EnumerableMock {
    use game_components_embeddable_game_standard::token::extensions::enumerable::enumerable::EnumerableComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::ERC721Component;
    use starknet::ContractAddress;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: EnumerableComponent, storage: erc721_enumerable, event: EnumerableEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;

    // Enumerable
    #[abi(embed_v0)]
    impl EnumerableImpl = EnumerableComponent::EnumerableImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    // Internal impls
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl EnumerableInternalImpl = EnumerableComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc721: ERC721Component::Storage,
        #[substorage(v0)]
        pub erc721_enumerable: EnumerableComponent::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        EnumerableEvent: EnumerableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.erc721_enumerable.before_update(to, token_id);
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {}
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn all_tokens_of_owner(self: @ContractState, owner: ContractAddress) -> Span<u256> {
            self.erc721_enumerable.all_tokens_of_owner(owner)
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc721.initializer("", "", "");
        self.erc721_enumerable.initializer();
    }
}
