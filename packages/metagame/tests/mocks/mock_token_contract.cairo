// This is essentially the same as MockMinigameToken but with a different contract name
// for use in integration tests that expect "MockTokenContract"
use game_components_metagame::extensions::context::structs::GameContextDetails;
use game_components_token::core::interface::{IMINIGAME_TOKEN_ID, IMinigameToken};
use game_components_token::structs::{
    Lifecycle, MintParams, PlayerNameUpdate, SetTokenMetadataParams, TokenMetadata,
};
use openzeppelin_interfaces::introspection::ISRC5;
use starknet::ContractAddress;

#[starknet::contract]
pub mod MockTokenContract {
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::*;

    #[storage]
    struct Storage {
        // Token storage
        next_token_id: u64,
        token_game_address: Map<u64, ContractAddress>,
        token_player_names: Map<u64, felt252>,
        token_lifecycle_start: Map<u64, u64>,
        token_lifecycle_end: Map<u64, u64>,
        game_address: ContractAddress,
        game_registry_address: ContractAddress,
        // Mock behavior flags
        should_fail_mint: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.next_token_id.write(1);
    }

    #[abi(embed_v0)]
    impl MinigameTokenImpl of IMinigameToken<ContractState> {
        fn token_metadata(self: @ContractState, token_id: u64) -> TokenMetadata {
            TokenMetadata {
                game_id: 0,
                minted_at: 0,
                settings_id: 0,
                lifecycle: Lifecycle {
                    start: self.token_lifecycle_start.read(token_id),
                    end: self.token_lifecycle_end.read(token_id),
                },
                minted_by: 0,
                soulbound: false,
                game_over: false,
                completed_objective: false,
                has_context: false,
                objective_id: 0,
            }
        }

        fn is_playable(self: @ContractState, token_id: u64) -> bool {
            token_id < self.next_token_id.read()
        }

        fn settings_id(self: @ContractState, token_id: u64) -> u32 {
            0
        }

        fn player_name(self: @ContractState, token_id: u64) -> felt252 {
            self.token_player_names.read(token_id)
        }

        fn objective_id(self: @ContractState, token_id: u64) -> u32 {
            0
        }

        fn minted_by(self: @ContractState, token_id: u64) -> u64 {
            0
        }

        fn game_address(self: @ContractState) -> ContractAddress {
            self.game_address.read()
        }

        fn game_registry_address(self: @ContractState) -> ContractAddress {
            self.game_registry_address.read()
        }

        fn is_soulbound(self: @ContractState, token_id: u64) -> bool {
            false
        }

        fn renderer_address(self: @ContractState, token_id: u64) -> ContractAddress {
            Zero::zero()
        }

        fn token_game_address(self: @ContractState, token_id: u64) -> ContractAddress {
            self.token_game_address.read(token_id)
        }

        // Batch view functions
        fn token_metadata_batch(
            self: @ContractState, token_ids: Span<u64>,
        ) -> Array<TokenMetadata> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.token_metadata(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn is_playable_batch(self: @ContractState, token_ids: Span<u64>) -> Array<bool> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.is_playable(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn settings_id_batch(self: @ContractState, token_ids: Span<u64>) -> Array<u32> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.settings_id(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn player_name_batch(self: @ContractState, token_ids: Span<u64>) -> Array<felt252> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.player_name(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn objective_id_batch(self: @ContractState, token_ids: Span<u64>) -> Array<u32> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.objective_id(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn minted_by_batch(self: @ContractState, token_ids: Span<u64>) -> Array<u64> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.minted_by(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn is_soulbound_batch(self: @ContractState, token_ids: Span<u64>) -> Array<bool> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.is_soulbound(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn renderer_address_batch(
            self: @ContractState, token_ids: Span<u64>,
        ) -> Array<ContractAddress> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.renderer_address(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn token_game_address_batch(
            self: @ContractState, token_ids: Span<u64>,
        ) -> Array<ContractAddress> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.token_game_address(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn mint(
            ref self: ContractState,
            game_address: Option<ContractAddress>,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            if self.should_fail_mint.read() {
                panic!("Mint failed");
            }

            let token_id = self.next_token_id.read();
            self.next_token_id.write(token_id + 1);

            // Store game address
            if let Option::Some(game_addr) = game_address {
                self.token_game_address.write(token_id, game_addr);
            }

            // Store player name
            if let Option::Some(name) = player_name {
                self.token_player_names.write(token_id, name);
            }

            // Store lifecycle data
            if let Option::Some(start_time) = start {
                self.token_lifecycle_start.write(token_id, start_time);
            }

            if let Option::Some(end_time) = end {
                self.token_lifecycle_end.write(token_id, end_time);
            }

            token_id
        }

        fn mint_batch(ref self: ContractState, mints: Array<MintParams>) -> Array<u64> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= mints.len() {
                    break;
                }
                let params = mints.at(i);
                let context_clone = match params.context {
                    Option::Some(ctx) => Option::Some(ctx.clone()),
                    Option::None => Option::None,
                };
                let client_url_clone = match params.client_url {
                    Option::Some(url) => Option::Some(url.clone()),
                    Option::None => Option::None,
                };
                let token_id = self
                    .mint(
                        *params.game_address,
                        *params.player_name,
                        *params.settings_id,
                        *params.start,
                        *params.end,
                        *params.objective_id,
                        context_clone,
                        client_url_clone,
                        *params.renderer_address,
                        *params.to,
                        *params.soulbound,
                    );
                results.append(token_id);
                i += 1;
            }
            results
        }

        fn set_token_metadata(
            ref self: ContractState,
            token_id: u64,
            game_address: ContractAddress,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
        ) { // Mock implementation - no-op
        }

        fn update_game(ref self: ContractState, token_id: u64) { // Mock implementation - no-op
        }

        fn update_player_name(ref self: ContractState, token_id: u64, name: felt252) {
            self.token_player_names.write(token_id, name);
        }

        fn set_token_metadata_batch(
            ref self: ContractState, updates: Array<SetTokenMetadataParams>,
        ) { // Mock implementation - no-op
        }

        fn update_game_batch(
            ref self: ContractState, token_ids: Span<u64>,
        ) { // Mock implementation - no-op
        }

        fn update_player_name_batch(ref self: ContractState, updates: Span<PlayerNameUpdate>) {
            let mut i = 0;
            loop {
                if i >= updates.len() {
                    break;
                }
                let update = *updates.at(i);
                self.update_player_name(update.token_id, update.name);
                i += 1;
            };
        }
    }

    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == IMINIGAME_TOKEN_ID
                || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
        }
    }

    // Helper functions for testing
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn set_should_fail_mint(ref self: ContractState, should_fail: bool) {
            self.should_fail_mint.write(should_fail);
        }
    }
}
