// Example "denshokan lite" deployment: single-game ERC721 with the lite core,
// minter tracking, and a soulbound transfer guard. No registry, no enumerable,
// no objectives/context/skills/renderer extensions, no mutable token state.
//
// Lives in test_common so downstream consumers (e.g. tournament platforms) can
// declare it from their own test suites via `build-external-contracts`.
//
// A production deployment would additionally override `token_uri` to call its
// game renderer contract (one stored address, one call) and add
// Ownable/Upgradeable — omitted here to keep the example focused on the
// component wiring.

#[starknet::contract]
pub mod TokenLiteContract {
    use core::num::traits::Zero;
    use game_components_embeddable_game_standard::token::extensions::minter::minter::MinterComponent;
    use game_components_embeddable_game_standard::token::structs::unpack_soulbound;
    use game_components_embeddable_game_standard::token_lite::token_lite_component::CoreTokenLiteComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::ERC721Component;
    use starknet::ContractAddress;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: CoreTokenLiteComponent, storage: core_token_lite, event: CoreTokenLiteEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        core_token_lite: CoreTokenLiteComponent::Storage,
        #[substorage(v0)]
        minter: MinterComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        CoreTokenLiteEvent: CoreTokenLiteComponent::Event,
        #[flat]
        MinterEvent: MinterComponent::Event,
    }

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl CoreTokenLiteImpl =
        CoreTokenLiteComponent::CoreTokenLiteImpl<ContractState>;
    #[abi(embed_v0)]
    impl MinterImpl = MinterComponent::MinterImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    impl CoreTokenLiteInternalImpl = CoreTokenLiteComponent::InternalImpl<ContractState>;
    impl MinterInternalImpl = MinterComponent::InternalImpl<ContractState>;

    // Minter is the only optional feature the lite core consumes.
    impl MinterOptionalImpl = MinterComponent::MinterOptionalImpl<ContractState>;

    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            // Soulbound is a bit in the token id — pure unpack, no storage.
            // Only transfers are blocked; mints (owner == 0) and burns
            // (to == 0) pass through.
            let current_owner = self._owner_of(token_id);
            if !current_owner.is_zero() && !to.is_zero() {
                if unpack_soulbound(token_id.try_into().unwrap()) {
                    panic!("Token is soulbound and cannot be transferred");
                }
            }
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {}
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        game_address: ContractAddress,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.core_token_lite.initializer(game_address);
        self.minter.initializer();
    }
}
