use core::num::traits::Zero;
use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
use game_components_embeddable_game_standard::minigame::interface::{
    IMinigameDispatcher, IMinigameDispatcherTrait,
};
use game_components_embeddable_game_standard::registry::interface::{
    FEE_DENOMINATOR, GameFeeInfo, IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait,
};
use game_components_embeddable_game_standard::token_legacy::interface::{
    IMinigameTokenLegacyDispatcher, IMinigameTokenLegacyDispatcherTrait,
};
use game_components_interfaces::structs::token::MintBatchRecipient;
use game_components_interfaces::token::core::{
    IMINIGAME_TOKEN_ID, IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
};
use game_components_interfaces::token::creator::{
    IMINIGAME_TOKEN_CREATOR_ID, IMinigameTokenCreatorDispatcher,
    IMinigameTokenCreatorDispatcherTrait,
};
use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use starknet::ContractAddress;
use crate::metagame::structs::MintMetagameParams;

/// Asserts that a game is registered in the minigame token contract
///
/// The token is probed via SRC5 first: a token supporting
/// `IMINIGAME_TOKEN_ID` is a self-bound standard token (the game contract IS
/// the token — standard tokens expose no registry/game-address views), so
/// "registered" reduces to a plain address equality: the game's
/// `token_address()` must be the game itself. Otherwise the token is a legacy
/// token: registry-backed (multi-game) tokens ask the registry, while a zero
/// `game_registry_address()` marks a single-game legacy token, whose paired
/// game is named by its own `game_address()` view — a legacy token is a
/// SEPARATE contract from its game, so the pairing there is
/// `token.game_address() == game_address`, not an address equality against
/// the token itself.
///
/// # Arguments
/// * `game_address` - The address of the game contract to check
pub fn assert_game_registered(game_address: ContractAddress) {
    let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
    let minigame_token_address = minigame_dispatcher.token_address();
    let token_src5_dispatcher = ISRC5Dispatcher { contract_address: minigame_token_address };
    if token_src5_dispatcher.supports_interface(IMINIGAME_TOKEN_ID) {
        assert!(minigame_token_address == game_address, "Game is not registered");
        return;
    }
    let minigame_token_dispatcher = IMinigameTokenLegacyDispatcher {
        contract_address: minigame_token_address,
    };
    let minigame_registry_address = minigame_token_dispatcher.game_registry_address();
    if minigame_registry_address.is_zero() {
        assert!(minigame_token_dispatcher.game_address() == game_address, "Game is not registered");
        return;
    }
    let minigame_registry_dispatcher = IMinigameRegistryDispatcher {
        contract_address: minigame_registry_address,
    };
    let game_exists = minigame_registry_dispatcher.is_game_registered(game_address);
    assert!(game_exists, "Game is not registered");
}

/// The standard token's registration check: it is self-bound, so the game must
/// BE its token. Every path that trusts a game's `token_address()` must apply
/// this — otherwise a hostile contract can name a standard token it does not
/// own and have the metagame mint on it or pay its creator.
fn assert_self_bound(token_address: ContractAddress, game_address: ContractAddress) {
    assert!(token_address == game_address, "Game is not registered");
}

/// True when `token_address` is a self-bound standard token (SRC5
/// `IMINIGAME_TOKEN_ID`) rather than a legacy multi-game token.
fn is_standard_token(token_address: ContractAddress) -> bool {
    ISRC5Dispatcher { contract_address: token_address }.supports_interface(IMINIGAME_TOKEN_ID)
}

/// Rejects a game whose token is not itself, on the way into a legacy mint.
///
/// The mint paths discriminate on `token_address() == game_address` rather
/// than by probing SRC5, because self-boundness IS what makes a token
/// standard: a legacy token is structurally a separate contract from its
/// game. Address equality answers the same question for free, and these are
/// the hot paths — a probe there costs a cross-contract call on every mint,
/// which for a tournament metagame is every entry.
///
/// The probe still has to happen somewhere, or a game naming a standard token
/// it does not own would fall into the legacy branch and fail on a missing
/// entrypoint instead of saying what is wrong. So it happens here, on the
/// branch that is already not self-bound — legacy mints pay for it, standard
/// mints no longer do, and the panic is unchanged either way.
fn assert_not_a_foreign_standard_token(
    token_address: ContractAddress, game_address: ContractAddress,
) {
    if is_standard_token(token_address) {
        assert_self_bound(token_address, game_address);
    }
}

/// Mints on a self-bound standard token.
///
/// The standard `mint` has no game address (the token IS the game) and no
/// per-token renderer/skills. Those two parameters are rejected loudly rather
/// than silently dropped — a caller that asked for a custom renderer must not
/// be told the mint honoured it.
fn mint_standard_token(
    token_address: ContractAddress,
    player_name: Option<felt252>,
    settings_id: Option<u32>,
    start: Option<u64>,
    end: Option<u64>,
    objective_id: Option<u32>,
    context: Option<GameContextDetails>,
    client_url: Option<ByteArray>,
    renderer_address: Option<ContractAddress>,
    skills_address: Option<ContractAddress>,
    to: ContractAddress,
    soulbound: bool,
    paymaster: bool,
    salt: u16,
    metadata: u128,
) -> felt252 {
    assert!(renderer_address.is_none(), "Metagame: standard tokens have no per-token renderer");
    assert!(skills_address.is_none(), "Metagame: standard tokens have no per-token skills");
    IMinigameTokenDispatcher { contract_address: token_address }
        .mint(
            player_name,
            settings_id,
            start,
            end,
            objective_id,
            context,
            client_url,
            to,
            soulbound,
            paymaster,
            salt,
            metadata,
        )
}

/// Mints a game token through the game's own token contract.
///
/// Every game brings its own token — the token is resolved from
/// `game_address` on every mint, so there is no metagame-wide default token.
///
/// # Arguments
/// * `game_address` - The address of the game contract minting the token
/// * `player_name` - Optional player name
/// * `settings_id` - Optional settings ID
/// * `start` - Optional start time
/// * `end` - Optional end time
/// * `objective_id` - Optional objective ID
/// * `context` - Optional context data
/// * `client_url` - Optional client URL
/// * `renderer_address` - Optional renderer contract address
/// * `skills_address` - Optional skills contract address
/// * `to` - Address to mint the token to
/// * `soulbound` - Whether the token should be soulbound
///
/// # Returns
/// * `u64` - The minted token ID
pub fn mint(
    game_address: ContractAddress,
    player_name: Option<felt252>,
    settings_id: Option<u32>,
    start: Option<u64>,
    end: Option<u64>,
    objective_id: Option<u32>,
    context: Option<GameContextDetails>,
    client_url: Option<ByteArray>,
    renderer_address: Option<ContractAddress>,
    skills_address: Option<ContractAddress>,
    to: ContractAddress,
    soulbound: bool,
    paymaster: bool,
    salt: u16,
    metadata: u128,
) -> felt252 {
    let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
    let minigame_token_address = minigame_dispatcher.token_address();
    // A standard token is self-bound and carries a different mint ABI;
    // `assert_game_registered` accepts these games, so this path must be able
    // to mint for them too — under the same pairing check, which here IS the
    // discriminator rather than a follow-up to one.
    //
    // Reading self-boundness as "standard" assumes no LEGACY token is ever
    // self-bound. That is a description of deployed reality — a legacy token
    // is a separate contract from its game — and not an invariant anything
    // enforces, so state it rather than leave it implicit. A self-bound legacy
    // token would take this branch and fail loudly on the standard mint's
    // missing entrypoint, and `assert_game_registered`'s zero-registry branch
    // would still admit it (`token.game_address() == game_address` can hold
    // when the two are the same contract), so the two disagree about exactly
    // that shape. Accepted knowingly: the failure is a revert at first mint,
    // never silent, and the alternative is the per-mint probe this exists to
    // remove.
    if minigame_token_address == game_address {
        return mint_standard_token(
            minigame_token_address,
            player_name,
            settings_id,
            start,
            end,
            objective_id,
            context,
            client_url,
            renderer_address,
            skills_address,
            to,
            soulbound,
            paymaster,
            salt,
            metadata,
        );
    }
    assert_not_a_foreign_standard_token(minigame_token_address, game_address);

    // Legacy token: narrower metadata field — reject rather than truncate.
    let legacy_metadata: u16 = metadata.try_into().expect('Metagame: metadata exceeds u16');
    let minigame_token_dispatcher = IMinigameTokenLegacyDispatcher {
        contract_address: minigame_token_address,
    };
    minigame_token_dispatcher
        .mint(
            game_address,
            player_name,
            settings_id,
            start,
            end,
            objective_id,
            context,
            client_url,
            renderer_address,
            skills_address,
            to,
            soulbound,
            paymaster,
            salt,
            legacy_metadata,
        )
}

/// Mints many tokens for ONE game in a single call, via the token's own
/// `mint_batch_recipients` entrypoint.
///
/// This is NOT `mint_batch`. `mint_batch` loops over `mint`, one cross-contract
/// dispatch per token, and each entry may name a different game. This routes a
/// single dispatch to the token's batch entrypoint, which hoists the
/// batch-invariant work (packing, the shared has_context bit) and runs one
/// global salt counter across the batch. For a many-recipient single-game mint
/// — a tournament entry — that is the difference between N dispatches and one,
/// with the `context` array re-serialised N times versus once.
///
/// Both token generations are served. `metadata` is `u128` to reach the
/// standard token's 65-bit field; the legacy token's field is `u16`, so a
/// legacy mint asserts the value fits rather than truncating it silently.
///
/// # Arguments
/// * `game_address` - The game whose token mints; the token is resolved from it
/// * `recipients` - Per-recipient counts; salts run `salt .. salt + sum(counts) - 1`
///
/// # Returns
/// * `Array<felt252>` - The minted token ids, in recipient order
pub fn mint_batch_recipients(
    game_address: ContractAddress,
    player_name: Option<felt252>,
    settings_id: Option<u32>,
    start: Option<u64>,
    end: Option<u64>,
    objective_id: Option<u32>,
    context: Option<GameContextDetails>,
    client_url: Option<ByteArray>,
    renderer_address: Option<ContractAddress>,
    skills_address: Option<ContractAddress>,
    recipients: Array<MintBatchRecipient>,
    soulbound: bool,
    paymaster: bool,
    salt: u16,
    metadata: u128,
) -> Array<felt252> {
    let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
    let minigame_token_address = minigame_dispatcher.token_address();

    // Same discriminator, and the same assumption, as `mint` — see there.
    if minigame_token_address == game_address {
        assert!(renderer_address.is_none(), "Metagame: standard tokens have no per-token renderer");
        assert!(skills_address.is_none(), "Metagame: standard tokens have no per-token skills");
        return IMinigameTokenDispatcher { contract_address: minigame_token_address }
            .mint_batch_recipients(
                player_name,
                settings_id,
                start,
                end,
                objective_id,
                context,
                client_url,
                recipients,
                soulbound,
                paymaster,
                salt,
                metadata,
            );
    }

    assert_not_a_foreign_standard_token(minigame_token_address, game_address);

    // Legacy token: narrower metadata field — reject rather than truncate.
    let legacy_metadata: u16 = metadata.try_into().expect('Metagame: metadata exceeds u16');
    IMinigameTokenLegacyDispatcher { contract_address: minigame_token_address }
        .mint_batch_recipients(
            game_address,
            player_name,
            settings_id,
            start,
            end,
            objective_id,
            context,
            client_url,
            renderer_address,
            skills_address,
            recipients,
            soulbound,
            paymaster,
            salt,
            legacy_metadata,
        )
}

/// Mints multiple game tokens in batch through their games' token contracts
///
/// Each entry names its own game; the token is resolved per mint.
///
/// # Arguments
/// * `mints` - Array of mint parameters for each token
///
/// # Returns
/// * `Array<felt252>` - Array of minted token IDs
pub fn mint_batch(mints: Array<MintMetagameParams>) -> Array<felt252> {
    let mut token_ids = array![];
    let mut index = 0;

    loop {
        if index >= mints.len() {
            break;
        }

        let mint_param = mints.at(index);

        // Clone non-copyable Option types
        let context_clone = match mint_param.context {
            Option::Some(ctx) => Option::Some(ctx.clone()),
            Option::None => Option::None,
        };

        let client_url_clone = match mint_param.client_url {
            Option::Some(url) => Option::Some(url.clone()),
            Option::None => Option::None,
        };

        let token_id = mint(
            *mint_param.game_address,
            *mint_param.player_name,
            *mint_param.settings_id,
            *mint_param.start,
            *mint_param.end,
            *mint_param.objective_id,
            context_clone,
            client_url_clone,
            *mint_param.renderer_address,
            *mint_param.skills_address,
            *mint_param.to,
            *mint_param.soulbound,
            *mint_param.paymaster,
            *mint_param.salt,
            *mint_param.metadata,
        );

        token_ids.append(token_id);
        index += 1;
    }

    token_ids
}

/// Pure calculation: revenue * fee_numerator / FEE_DENOMINATOR
/// Uses u256 intermediate to avoid overflow on large revenue values.
pub fn calculate_game_fee(revenue: u128, fee_numerator: u16) -> u128 {
    if fee_numerator == 0 || revenue == 0 {
        return 0;
    }
    let result: u256 = (revenue.into() * fee_numerator.into()) / FEE_DENOMINATOR.into();
    result.try_into().unwrap()
}

/// Resolves game fee info.
///
/// Standard tokens carry the creator identity the registry used to hold, so a
/// token advertising `IMINIGAME_TOKEN_CREATOR_ID` answers directly. Legacy
/// tokens keep the game_address → token → registry → game_fee_info walk.
pub fn get_game_fee_info(game_address: ContractAddress) -> GameFeeInfo {
    let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
    let minigame_token_address = minigame_dispatcher.token_address();
    if supports_creator_surface(minigame_token_address) {
        // The creator surface belongs to the self-bound standard token.
        assert_self_bound(minigame_token_address, game_address);
        let info = IMinigameTokenCreatorDispatcher { contract_address: minigame_token_address }
            .game_creator_info();
        return GameFeeInfo { license: info.license, fee_numerator: info.fee_numerator };
    }
    let minigame_token_dispatcher = IMinigameTokenLegacyDispatcher {
        contract_address: minigame_token_address,
    };
    let minigame_registry_address = minigame_token_dispatcher.game_registry_address();
    let minigame_registry_dispatcher = IMinigameRegistryDispatcher {
        contract_address: minigame_registry_address,
    };
    let game_id = minigame_registry_dispatcher.game_id_from_address(game_address);
    minigame_registry_dispatcher.game_fee_info(game_id)
}

/// True when the token exposes the standard creator surface
/// (`IMINIGAME_TOKEN_CREATOR_ID`) that replaced the registry's fee/payee role.
pub fn supports_creator_surface(token_address: ContractAddress) -> bool {
    ISRC5Dispatcher { contract_address: token_address }
        .supports_interface(IMINIGAME_TOKEN_CREATOR_ID)
}

/// Resolves the address that should receive a game's creator fee.
///
/// Standard tokens name the payee directly (`game_creator_address`). Legacy
/// registry tokens keep the old indirection: the payee is whoever currently
/// owns the game's registry NFT.
pub fn get_game_creator_address(game_address: ContractAddress) -> ContractAddress {
    let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
    let token_address = minigame_dispatcher.token_address();
    if supports_creator_surface(token_address) {
        // Same pairing check: a hostile game must not redirect the payee.
        assert_self_bound(token_address, game_address);
        return IMinigameTokenCreatorDispatcher { contract_address: token_address }
            .game_creator_address();
    }
    let token_dispatcher = IMinigameTokenLegacyDispatcher { contract_address: token_address };
    let registry_address = token_dispatcher.game_registry_address();
    let registry_dispatcher = IMinigameRegistryDispatcher { contract_address: registry_address };
    let game_id = registry_dispatcher.game_id_from_address(game_address);
    IERC721Dispatcher { contract_address: registry_address }.owner_of(game_id.into())
}
