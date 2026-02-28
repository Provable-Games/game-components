// SPDX-License-Identifier: BUSL-1.1

/// Pure Cairo library for registry operations.
/// This library provides core registry functionality without storage dependencies.
pub mod registry {
    use starknet::ContractAddress;

    pub mod Errors {
        pub const CALLER_NOT_MINIGAME: felt252 = 'Registry: not IMinigame';
        pub const GAME_ALREADY_REGISTERED: felt252 = 'Registry: already registered';
        pub const NOT_GAME_OWNER: felt252 = 'Registry: not game owner';
        pub const INVALID_GAME_ID: felt252 = 'Registry: invalid game id';
        pub const GAME_IDS_EMPTY: felt252 = 'Registry: game_ids empty';
        pub const ADDRESSES_EMPTY: felt252 = 'Registry: addresses empty';
    }

    /// Apply defaults for optional metadata fields.
    /// Returns resolved values for color, client_url, renderer_address, royalty_fraction,
    /// and agent_skills.
    pub fn apply_metadata_defaults(
        color: Option<ByteArray>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        royalty_fraction: Option<u128>,
        agent_skills: Option<ByteArray>,
    ) -> (ByteArray, ByteArray, ContractAddress, u128, ByteArray) {
        let final_color = match color {
            Option::Some(c) => c,
            Option::None => "",
        };
        let final_client_url = match client_url {
            Option::Some(url) => url,
            Option::None => "",
        };
        let final_renderer_address: ContractAddress = match renderer_address {
            Option::Some(addr) => addr,
            Option::None => 0.try_into().unwrap(),
        };
        let final_royalty_fraction: u128 = match royalty_fraction {
            Option::Some(fraction) => fraction,
            Option::None => 0,
        };
        let final_agent_skills = match agent_skills {
            Option::Some(skills) => skills,
            Option::None => "",
        };
        (
            final_color,
            final_client_url,
            final_renderer_address,
            final_royalty_fraction,
            final_agent_skills,
        )
    }
}
