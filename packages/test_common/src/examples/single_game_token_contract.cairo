// Example: Single Game Token Contract
// This contract is optimized for single-game scenarios where each token collection
// is associated with exactly one game. It includes all the same components as
// FullTokenContract but initializes with a specific game address rather than a registry.

use core::num::traits::Zero;
use game_components_metagame::extensions::context::structs::GameContextDetails;
use game_components_minigame::extensions::settings::structs::GameSettingDetails;
use game_components_minigame::structs::GameDetail;
use game_components_registry::interface::GameMetadata;

// Game components imports - use the actual package paths
use game_components_token::core::core_token::CoreTokenComponent;
use game_components_token::extensions::context::context::ContextComponent;
use game_components_token::extensions::minter::minter::MinterComponent;
use game_components_token::extensions::objectives::objectives::ObjectivesComponent;
use game_components_token::extensions::renderer::renderer::RendererComponent;
use game_components_token::extensions::settings::settings::SettingsComponent;
use game_components_token::structs::TokenMetadata;
use game_components_utils::renderer::create_custom_metadata;
use openzeppelin_interfaces::erc2981::IERC2981;
use openzeppelin_interfaces::erc721::IERC721Metadata;
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_token::common::erc2981::erc2981::{DefaultConfig, ERC2981Component};

// Core imports
use openzeppelin_token::erc721::ERC721Component;
use starknet::ContractAddress;
use starknet::storage::StoragePointerReadAccess;
use starknet::syscalls::call_contract_syscall;


#[starknet::contract]
pub mod SingleGameTokenContract {
    use super::*;

    // ================================================================================================
    // COMPONENT DECLARATIONS
    // ================================================================================================

    // Core components (always included)
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: ERC2981Component, storage: erc2981, event: ERC2981Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);

    // Optional components
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    component!(path: ObjectivesComponent, storage: objectives, event: ObjectivesEvent);
    component!(path: SettingsComponent, storage: settings, event: SettingsEvent);
    component!(path: ContextComponent, storage: context, event: ContextEvent);
    component!(path: RendererComponent, storage: renderer, event: RendererEvent);

    // ================================================================================================
    // STORAGE
    // ================================================================================================

    #[storage]
    struct Storage {
        // Core storage (always included)
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        erc2981: ERC2981Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        core_token: CoreTokenComponent::Storage,
        // Optional storage
        #[substorage(v0)]
        minter: MinterComponent::Storage,
        #[substorage(v0)]
        objectives: ObjectivesComponent::Storage,
        #[substorage(v0)]
        settings: SettingsComponent::Storage,
        #[substorage(v0)]
        context: ContextComponent::Storage,
        #[substorage(v0)]
        renderer: RendererComponent::Storage,
    }

    // ================================================================================================
    // EVENTS
    // ================================================================================================

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        ERC2981Event: ERC2981Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        CoreTokenEvent: CoreTokenComponent::Event,
        #[flat]
        MinterEvent: MinterComponent::Event,
        #[flat]
        ObjectivesEvent: ObjectivesComponent::Event,
        #[flat]
        SettingsEvent: SettingsComponent::Event,
        #[flat]
        ContextEvent: ContextComponent::Event,
        #[flat]
        RendererEvent: RendererComponent::Event,
    }

    // ================================================================================================
    // COMPONENT IMPLEMENTATIONS
    // ================================================================================================

    // Core implementations (always included)
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC2981InfoImpl = ERC2981Component::ERC2981InfoImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl CoreTokenImpl = CoreTokenComponent::CoreTokenImpl<ContractState>;

    // Simple ERC2981 implementation using default royalty from ERC2981Component
    #[abi(embed_v0)]
    impl ERC2981Impl of IERC2981<ContractState> {
        fn royalty_info(
            self: @ContractState, token_id: u256, sale_price: u256,
        ) -> (ContractAddress, u256) {
            // Single-game token: use ERC2981Component's default royalty
            let (receiver, _, royalty_fraction) = self.erc2981.default_royalty();

            // Calculate royalty amount: (sale_price * royalty_fraction) / 10000
            let royalty_amount = if royalty_fraction > 0 && !receiver.is_zero() {
                (sale_price * royalty_fraction.into()) / 10000
            } else {
                0
            };

            (receiver, royalty_amount)
        }
    }

    // Optional implementations
    #[abi(embed_v0)]
    impl MinterImpl = MinterComponent::MinterImpl<ContractState>;
    #[abi(embed_v0)]
    impl ObjectivesImpl = ObjectivesComponent::ObjectivesImpl<ContractState>;
    #[abi(embed_v0)]
    impl SettingsImpl = SettingsComponent::SettingsImpl<ContractState>;
    #[abi(embed_v0)]
    impl RendererImpl = RendererComponent::RendererImpl<ContractState>;

    // Internal implementations
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl ERC2981InternalImpl = ERC2981Component::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    impl CoreTokenInternalImpl = CoreTokenComponent::InternalImpl<ContractState>;
    impl MinterInternalImpl = MinterComponent::InternalImpl<ContractState>;
    impl ObjectivesInternalImpl = ObjectivesComponent::InternalImpl<ContractState>;
    impl SettingsInternalImpl = SettingsComponent::InternalImpl<ContractState>;
    impl ContextInternalImpl = ContextComponent::InternalImpl<ContractState>;
    impl RendererInternalImpl = RendererComponent::InternalImpl<ContractState>;

    // ================================================================================================
    // OPTIONAL TRAIT IMPLEMENTATIONS
    // ================================================================================================

    impl MinterOptionalImpl = MinterComponent::MinterOptionalImpl<ContractState>;
    impl ObjectivesOptionalImpl = ObjectivesComponent::ObjectivesOptionalImpl<ContractState>;
    impl SettingsOptionalImpl = SettingsComponent::SettingsOptionalImpl<ContractState>;
    impl ContextOptionalImpl = ContextComponent::ContextOptionalImpl<ContractState>;
    impl RendererOptionalImpl = RendererComponent::RendererOptionalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721Metadata of IERC721Metadata<ContractState> {
        /// Returns the NFT name.
        fn name(self: @ContractState) -> ByteArray {
            self.erc721.ERC721_name.read()
        }

        /// Returns the NFT symbol.
        fn symbol(self: @ContractState) -> ByteArray {
            self.erc721.ERC721_symbol.read()
        }

        fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.erc721._require_owned(token_id);

            let token_metadata: TokenMetadata = self
                .core_token
                .token_metadata(token_id.try_into().unwrap());

            // For single-game tokens, we get the game address directly
            let game_address = self.core_token.game_address();

            if !game_address.is_zero() {
                let renderer_address = self
                    .core_token
                    .renderer_address(token_id.try_into().unwrap());

                let score_selector = selector!("score");
                let token_name_selector = selector!("token_name");
                let token_description_selector = selector!("token_description");
                let details_svg_selector = selector!("game_details_svg");
                let details_selector = selector!("game_details");
                let mut calldata = array![];
                calldata.append(token_id.low.into());

                // For single-game tokens, we need to get game metadata from the game contract
                // In production, you'd get these from the game contract or store them
                // Get royalty fraction from ERC2981Component default royalty
                let (_, _, royalty_frac) = self.erc2981.default_royalty();
                let game_metadata = GameMetadata {
                    contract_address: game_address,
                    name: "Game",
                    description: "A sample game",
                    developer: "Developer",
                    publisher: "Publisher",
                    genre: "Strategy",
                    image: "https://example.com/image.png",
                    color: "#ffffff",
                    client_url: "https://example.com/game",
                    renderer_address: renderer_address,
                    royalty_fraction: royalty_frac,
                };

                let score =
                    match call_contract_syscall(game_address, score_selector, calldata.span()) {
                    Result::Ok(result) => {
                        let mut result_span = result;
                        match Serde::<u64>::deserialize(ref result_span) {
                            Option::Some(score) => score,
                            Option::None => 0,
                        }
                    },
                    Result::Err(_) => 0,
                };

                let token_name =
                    match call_contract_syscall(
                        renderer_address, token_name_selector, calldata.span(),
                    ) {
                    Result::Ok(result) => {
                        // Try to deserialize the result as ByteArray
                        let mut result_span = result;
                        match Serde::<ByteArray>::deserialize(ref result_span) {
                            Option::Some(token_name) => token_name,
                            Option::None => game_metadata.name.clone(),
                        }
                    },
                    Result::Err(_) => game_metadata.name.clone(),
                };

                let token_description =
                    match call_contract_syscall(
                        renderer_address, token_description_selector, calldata.span(),
                    ) {
                    Result::Ok(result) => {
                        let mut result_span = result;
                        match Serde::<ByteArray>::deserialize(ref result_span) {
                            Option::Some(description) => description,
                            Option::None => "An NFT representing ownership of an embeddable game.",
                        }
                    },
                    Result::Err(_) => "An NFT representing ownership of an embeddable game.",
                };

                let game_details_svg =
                    match call_contract_syscall(
                        renderer_address, details_svg_selector, calldata.span(),
                    ) {
                    Result::Ok(result) => {
                        let mut result_span = result;
                        match Serde::<ByteArray>::deserialize(ref result_span) {
                            Option::Some(svg) => svg,
                            Option::None => "https://denshokan.dev/game/1",
                        }
                    },
                    Result::Err(_) => "https://denshokan.dev/game/1",
                };

                let game_details =
                    match call_contract_syscall(
                        renderer_address, details_selector, calldata.span(),
                    ) {
                    Result::Ok(result) => {
                        let mut result_span = result;
                        match Serde::<Span<GameDetail>>::deserialize(ref result_span) {
                            Option::Some(details) => details,
                            Option::None => [].span(),
                        }
                    },
                    Result::Err(_) => [].span(),
                };

                let _state = 0; // Unused for now, but may be needed for future game state tracking
                let player_name = self.core_token.player_name(token_id.try_into().unwrap());

                // Default settings details - empty
                let settings_details = GameSettingDetails {
                    name: "", description: "", settings: [].span(),
                };

                // Default context details - empty
                let context_details = GameContextDetails {
                    name: "", description: "", id: Option::None, context: [].span(),
                };

                let minted_by_address = self.minter.get_minter_address(token_metadata.minted_by);
                let objective_id = token_metadata.objective_id;

                create_custom_metadata(
                    token_id.try_into().unwrap(),
                    token_name,
                    token_description,
                    game_metadata,
                    game_details_svg,
                    game_details,
                    settings_details,
                    context_details,
                    token_metadata,
                    score,
                    minted_by_address,
                    player_name,
                    array![objective_id].span(),
                )
            } else {
                // Fallback if no game address is set
                let base_uri = self.erc721.ERC721_base_uri.read();
                format!("{}{}", base_uri, token_id)
            }
        }
    }


    // ================================================================================================
    // ERC721 HOOKS
    // ================================================================================================

    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            // Only check soulbound restriction for transfers, not mints or burns
            let current_owner = self._owner_of(token_id);
            if current_owner.into() != 0 && to.into() != 0 {
                // This is a transfer (not mint or burn)
                let contract_state = self.get_contract();
                if contract_state.is_soulbound(token_id.try_into().unwrap()) {
                    panic!("Token is soulbound and cannot be transferred");
                }
            }
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) { // Post-transfer hook - can emit custom events if needed
        }
    }

    // ================================================================================================
    // CONSTRUCTOR
    // ================================================================================================

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        royalty_fraction: u128,
        game_address: ContractAddress,
        creator_address: ContractAddress,
    ) {
        // Initialize core components
        self.erc721.initializer(name, symbol, base_uri);
        // Initialize ERC2981 with creator as royalty receiver
        self.erc2981.initializer(creator_address, royalty_fraction);

        // For single-game token, initialize with game_address and creator_address
        // No registry is needed for single-game scenarios
        self
            .core_token
            .initializer(
                Option::Some(game_address),
                Option::Some(creator_address),
                Option::None // No registry for single-game
            );

        self.minter.initializer();
        self.objectives.initializer();
        self.settings.initializer();
        self.context.initializer();
        self.renderer.initializer();
    }
}
