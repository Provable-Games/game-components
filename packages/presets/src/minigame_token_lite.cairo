// # MinigameTokenLite preset
//
// Production-deployable single-game lite token ("denshokan lite"): ERC721 +
// CoreTokenLiteComponent + minter tracking + soulbound guard + Ownable +
// Upgradeable. No registry, no enumerable, no mutable token state, no
// objectives/context/skills/renderer extensions.
//
// Deployment supports the mutual-constructor-dependency dance with the game
// contract: pass `game_address: Option::None` to deploy unbound (SRC5 ids are
// registered so the game's `MinigameComponent::initializer` accepts this
// token), deploy the game pointing here, then call `bind_game` (owner, once).
// An unbound token cannot mint.
//
// `token_uri` is OpenZeppelin's base_uri concatenation. A game wanting fully
// on-chain art should upgrade to a class that overrides `token_uri` to call
// its renderer contract.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IMinigameTokenLiteAdmin<TState> {
    /// One-time game binding for two-phase deployments. Owner-only.
    fn bind_game(ref self: TState, game_address: ContractAddress);
}

#[starknet::contract]
pub mod MinigameTokenLite {
    use core::num::traits::Zero;
    use game_components_embeddable_game_standard::token::extensions::minter::minter::MinterComponent;
    use game_components_embeddable_game_standard::token::structs::unpack_soulbound;
    use game_components_embeddable_game_standard::token_lite::token_lite_component::CoreTokenLiteComponent;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_interfaces::upgrades::IUpgradeable;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_upgrades::UpgradeableComponent;
    use starknet::{ClassHash, ContractAddress};
    use super::IMinigameTokenLiteAdmin;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: CoreTokenLiteComponent, storage: core_token_lite, event: CoreTokenLiteEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

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
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
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
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
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
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    impl CoreTokenLiteInternalImpl = CoreTokenLiteComponent::InternalImpl<ContractState>;
    impl MinterInternalImpl = MinterComponent::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

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
            // Only transfers are blocked; mints and burns pass through.
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
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        game_address: Option<ContractAddress>,
    ) {
        assert!(!owner.is_zero(), "MinigameTokenLite: owner cannot be zero");
        self.ownable.initializer(owner);
        self.erc721.initializer(name, symbol, base_uri);
        self.minter.initializer();
        match game_address {
            Option::Some(game) => self.core_token_lite.initializer(game),
            // Two-phase deployment: interfaces now, bind_game later.
            Option::None => self.core_token_lite.register_interfaces(),
        }
    }

    #[abi(embed_v0)]
    impl AdminImpl of IMinigameTokenLiteAdmin<ContractState> {
        fn bind_game(ref self: ContractState, game_address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.core_token_lite.bind_game(game_address);
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
