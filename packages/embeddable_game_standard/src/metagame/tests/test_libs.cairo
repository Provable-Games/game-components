// =============================================================================
// TEST: metagame::metagame libs
// =============================================================================
//
// These ran against three token shapes while the metagame served two
// generations: registry-backed, single-game legacy, and the self-bound
// standard. The legacy generation is retired, so what remains exercises the
// one shape that exists — against the real merged game+token contract
// (`StandardGameMock`), never a mock ABI.

#[cfg(test)]
mod standard_token_paths {
    use game_components_embeddable_game_standard::token::interface::{
        IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
    };
    use game_components_interfaces::token::game_fee::{
        IMinigameTokenGameFeeDispatcher, IMinigameTokenGameFeeDispatcherTrait,
    };
    use game_components_testing::constants::{ALICE, BOB, OWNER};
    use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
    use starknet::ContractAddress;
    use crate::metagame::metagame as libs;

    /// One contract that is both the game and the standard token.
    fn deploy_standard_game(game_fee_recipient: ContractAddress) -> ContractAddress {
        let contract = declare("StandardGameMock").unwrap().contract_class();
        let mut calldata: Array<felt252> = array![];
        let name: ByteArray = "StandardToken";
        let symbol: ByteArray = "STD";
        let base_uri: ByteArray = "https://token.test/";
        name.serialize(ref calldata);
        symbol.serialize(ref calldata);
        base_uri.serialize(ref calldata);
        game_fee_recipient.serialize(ref calldata);
        OWNER().serialize(ref calldata);
        let (contract_address, _) = contract.deploy(@calldata).unwrap();
        contract_address
    }

    /// The self-bound pairing is what "registered" means for a standard token.
    #[test]
    fn test_assert_game_registered_accepts_standard_token() {
        let game = deploy_standard_game(ALICE());
        libs::assert_game_registered(game);
    }

    /// Regression: the gate accepted standard tokens while `mint` still spoke
    /// the legacy 15-arg ABI, so every accepted game reverted at mint.
    #[test]
    fn test_mint_through_standard_token() {
        let game = deploy_standard_game(ALICE());

        let token_id = libs::mint(
            game,
            Option::Some('player'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None, // renderer — unsupported, must be None
            Option::None, // skills — unsupported, must be None
            BOB(),
            false,
            false,
            0,
            0,
        );

        assert!(token_id != 0, "mint returned a zero token id");
        let erc721 = IERC721Dispatcher { contract_address: game };
        assert!(erc721.owner_of(token_id.into()) == BOB(), "token not minted to recipient");
        let token = IMinigameTokenDispatcher { contract_address: game };
        assert!(token.player_name(token_id) == 'player', "player name not stored");
    }

    /// `metadata` is u128 so the single-mint path reaches the same 65-bit field
    /// the batch path does — a u16 here would silently narrow a consumer that
    /// threads a wider value through.
    #[test]
    fn test_mint_carries_wide_metadata() {
        let game = deploy_standard_game(ALICE());
        let wide: u128 = 0x100000000;

        let token_id = libs::mint(
            game,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
            false,
            0,
            wide,
        );

        let token = IMinigameTokenDispatcher { contract_address: game };
        assert!(token.mint_metadata(token_id) == wide, "wide metadata lost on the single mint");
    }

    /// Minimal mint through a standard game — every optional param None.
    #[test]
    fn test_mint_standard_token_minimal() {
        let game = deploy_standard_game(ALICE());

        let token_id = libs::mint(
            game,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
            false,
            0,
            0,
        );

        let erc721 = IERC721Dispatcher { contract_address: game };
        assert!(erc721.owner_of(token_id.into()) == BOB(), "token not minted to recipient");
    }

    /// Unsupported params are rejected loudly, never silently dropped.
    #[test]
    #[should_panic(expected: "Metagame: tokens have no per-token renderer")]
    fn test_mint_rejects_renderer_on_standard_token() {
        let game = deploy_standard_game(ALICE());
        libs::mint(
            game,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(BOB()),
            Option::None,
            BOB(),
            false,
            false,
            0,
            0,
        );
    }

    #[test]
    #[should_panic(expected: "Metagame: tokens have no per-token skills")]
    fn test_mint_rejects_skills_on_standard_token() {
        let game = deploy_standard_game(ALICE());
        libs::mint(
            game,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(BOB()),
            BOB(),
            false,
            false,
            0,
            0,
        );
    }

    /// One call answers both the rate and the payee. They were two separate
    /// resolutions only while the retired generation answered them in
    /// different places — terms from the registry, payee from the registry
    /// NFT's owner.
    #[test]
    fn test_get_game_fee_terms_reads_the_game_fee_surface() {
        let game = deploy_standard_game(ALICE());
        let terms = libs::get_game_fee_terms(game);
        let declared = IMinigameTokenGameFeeDispatcher { contract_address: game };
        assert!(
            terms.fee_numerator == declared.game_fee_terms().fee_numerator,
            "fee numerator does not match the token's declared fee",
        );
        assert!(terms.recipient == ALICE(), "payee is not the declared fee recipient");
    }
}

// =============================================================================
// HOSTILE GAME POINTING AT SOMEONE ELSE'S TOKEN
// =============================================================================
//
// The token is self-bound, so `token_address() == game_address` IS its
// registration check. Any path that trusts a game's `token_address()` must
// enforce it: otherwise a contract that merely implements `token_address()`
// can name a token it does not own and have the metagame mint on it or pay
// its fee recipient — at a rate the attacker controls.

#[cfg(test)]
mod hostile_game_paths {
    use game_components_testing::constants::{ALICE, BOB, OWNER};
    use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
    use starknet::ContractAddress;
    use crate::metagame::metagame as libs;

    fn deploy_standard_game(game_fee_recipient: ContractAddress) -> ContractAddress {
        let contract = declare("StandardGameMock").unwrap().contract_class();
        let mut calldata: Array<felt252> = array![];
        let name: ByteArray = "StandardToken";
        let symbol: ByteArray = "STD";
        let base_uri: ByteArray = "https://token.test/";
        name.serialize(ref calldata);
        symbol.serialize(ref calldata);
        base_uri.serialize(ref calldata);
        game_fee_recipient.serialize(ref calldata);
        OWNER().serialize(ref calldata);
        let (contract_address, _) = contract.deploy(@calldata).unwrap();
        contract_address
    }

    /// A hostile "game" that reports a victim's standard token as its own.
    fn hostile_game_pointing_at(victim_token: ContractAddress) -> ContractAddress {
        let hostile: ContractAddress = 0xBAD.try_into().unwrap();
        mock_call(hostile, selector!("token_address"), victim_token, 10);
        hostile
    }

    #[test]
    #[should_panic(expected: "Game is not registered")]
    fn test_mint_rejects_game_pointing_at_foreign_standard_token() {
        let victim = deploy_standard_game(ALICE());
        let hostile = hostile_game_pointing_at(victim);

        libs::mint(
            hostile,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
            false,
            0,
            0,
        );
    }

    /// Fee terms — rate AND payee — must not be readable through a game that
    /// does not own the token. This is the path that mattered: a metagame
    /// trusting them pays out real funds at a rate the attacker sets.
    #[test]
    #[should_panic(expected: "Game is not registered")]
    fn test_get_game_fee_terms_rejects_foreign_standard_token() {
        let victim = deploy_standard_game(ALICE());
        let hostile = hostile_game_pointing_at(victim);
        libs::get_game_fee_terms(hostile);
    }

    /// The self-bound game itself still passes every guarded path — three
    /// should_panic tests would also pass if the guard were simply too broad.
    #[test]
    fn test_self_bound_game_still_passes_every_path() {
        let game = deploy_standard_game(ALICE());
        libs::assert_game_registered(game);
        let terms = libs::get_game_fee_terms(game);
        assert!(terms.recipient == ALICE(), "payee should be the declared recipient");
        assert!(terms.fee_numerator == 500, "default fee is 500 bps");
    }
}

// =============================================================================
// FUZZED MINT PARAMETERS
// =============================================================================
//
// Property coverage that ran against a legacy fuzz mock until that generation
// was retired. Re-established here against the real merged game+token
// contract, so the properties are checked on the code that actually ships
// rather than on a mock's approximation of it.

#[cfg(test)]
mod fuzz_mint_parameters {
    use game_components_embeddable_game_standard::token::interface::{
        IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
    };
    use game_components_testing::constants::{ALICE, BOB, OWNER};
    use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
    use starknet::ContractAddress;
    use crate::metagame::metagame as libs;

    fn deploy_standard_game() -> ContractAddress {
        let contract = declare("StandardGameMock").unwrap().contract_class();
        let mut calldata: Array<felt252> = array![];
        let name: ByteArray = "StandardToken";
        let symbol: ByteArray = "STD";
        let base_uri: ByteArray = "https://token.test/";
        name.serialize(ref calldata);
        symbol.serialize(ref calldata);
        base_uri.serialize(ref calldata);
        ALICE().serialize(ref calldata);
        OWNER().serialize(ref calldata);
        let (contract_address, _) = contract.deploy(@calldata).unwrap();
        contract_address
    }

    fn mint_with_name(game: ContractAddress, player_name: felt252, salt: u16) -> felt252 {
        libs::mint(
            game,
            Option::Some(player_name),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
            false,
            salt,
            0,
        )
    }

    /// Any player name survives the mint intact — the id packs no part of it,
    /// so nothing can truncate or collide it.
    #[fuzzer(runs: 64)]
    #[test]
    fn test_fuzz_player_name_round_trips(player_name: felt252) {
        let game = deploy_standard_game();
        let token_id = mint_with_name(game, player_name, 0);

        let token = IMinigameTokenDispatcher { contract_address: game };
        assert!(token.player_name(token_id) == player_name, "player name did not round trip");
    }

    /// `settings_id` is a 16-bit field in the packed id. Any value that fits
    /// must come back exactly; the widening to `Option<u32>` at the ABI is
    /// call-site ergonomics, not extra range.
    #[fuzzer(runs: 64)]
    #[test]
    fn test_fuzz_settings_id_round_trips(raw: u16) {
        let game = deploy_standard_game();
        let settings_id: u32 = raw.into();

        let token_id = libs::mint(
            game,
            Option::None,
            Option::Some(settings_id),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
            false,
            0,
            0,
        );

        let token = IMinigameTokenDispatcher { contract_address: game };
        assert!(token.settings_id(token_id) == settings_id, "settings id did not round trip");
    }

    /// The 65-bit metadata field carries any value that fits, unchanged. This
    /// is the field a consumer threads a wide value through, so truncation
    /// here would be silent data loss.
    #[fuzzer(runs: 64)]
    #[test]
    fn test_fuzz_metadata_round_trips(raw: u64) {
        let game = deploy_standard_game();
        let metadata: u128 = raw.into();

        let token_id = libs::mint(
            game,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
            false,
            0,
            metadata,
        );

        let token = IMinigameTokenDispatcher { contract_address: game };
        assert!(token.mint_metadata(token_id) == metadata, "metadata did not round trip");
    }

    /// Distinct salts within one transaction produce distinct ids — the
    /// property the salt field exists to guarantee for multicall minting.
    #[fuzzer(runs: 32)]
    #[test]
    fn test_fuzz_distinct_salts_give_distinct_ids(salt_a: u16, salt_b: u16) {
        if salt_a == salt_b {
            return;
        }
        let game = deploy_standard_game();
        let first = mint_with_name(game, 'player', salt_a);
        let second = mint_with_name(game, 'player', salt_b);
        assert!(first != second, "distinct salts collided");
    }
}
