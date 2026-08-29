use core::num::traits::Zero;
use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
use game_components_interfaces::structs::token::{GameFeeTerms, MintBatchRecipient};
use game_components_interfaces::token::core::{
    IMINIGAME_TOKEN_ID, IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
};
use game_components_interfaces::token::game_fee::{
    FEE_DENOMINATOR, IMINIGAME_TOKEN_GAME_FEE_ID, IMinigameTokenGameFeeDispatcher,
    IMinigameTokenGameFeeDispatcherTrait, default_license,
};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use starknet::ContractAddress;
use crate::metagame::structs::MintMetagameParams;

/// A game is valid exactly when its address is a standard token: the game IS
/// its token, so minting and fees go to that address directly.
fn assert_is_standard_game(game_address: ContractAddress) {
    assert!(
        ISRC5Dispatcher { contract_address: game_address }.supports_interface(IMINIGAME_TOKEN_ID),
        "Game is not registered",
    );
}

/// Per-token renderers and skills belonged to the retired generation. Reject
/// them where they are still passed rather than dropping them quietly — a
/// caller that asked for a custom renderer must not be told the mint honoured
/// it.
fn assert_no_retired_extensions(
    renderer_address: Option<ContractAddress>, skills_address: Option<ContractAddress>,
) {
    assert!(renderer_address.is_none(), "Metagame: tokens have no per-token renderer");
    assert!(skills_address.is_none(), "Metagame: tokens have no per-token skills");
}

/// Asserts that `game_address` is a game whose token is itself.
///
/// # Arguments
/// * `game_address` - The address of the game contract to check
pub fn assert_game_registered(game_address: ContractAddress) {
    assert_is_standard_game(game_address);
}

/// Mints a game token through the game's own token contract.
///
/// Every game brings its own token — it is resolved from `game_address` on
/// every mint, so there is no metagame-wide default token.
///
/// # Arguments
/// * `game_address` - The address of the game contract minting the token
/// * `to` - Address to mint the token to
///
/// # Returns
/// * `felt252` - The minted token id
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
    assert_is_standard_game(game_address);
    assert_no_retired_extensions(renderer_address, skills_address);

    IMinigameTokenDispatcher { contract_address: game_address }
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
    assert_is_standard_game(game_address);
    assert_no_retired_extensions(renderer_address, skills_address);

    IMinigameTokenDispatcher { contract_address: game_address }
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
        )
}

/// Mints multiple game tokens in batch through their games' token contracts
///
/// Each entry names its own game; the token is resolved per mint. When a batch
/// shares one game, prefer `mint_batch_recipients` — this costs one
/// cross-contract dispatch per token.
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

/// True when the token exposes the game-fee surface
/// (`IMINIGAME_TOKEN_GAME_FEE_ID`).
pub fn supports_game_fee_surface(token_address: ContractAddress) -> bool {
    ISRC5Dispatcher { contract_address: token_address }
        .supports_interface(IMINIGAME_TOKEN_GAME_FEE_ID)
}

/// A game's fee terms — rate, license and recipient — read from its token's
/// game-fee surface.
///
/// A game whose token does not advertise the surface declares no terms at all,
/// which is the same answer as declaring zero: nobody is owed anything.
/// Answering rather than reverting keeps the fee question total, so
/// `calculate_game_fee` returns 0, `pay_game_fee` exits before transferring,
/// and no caller has to pre-check. The recipient is zero in that case and is
/// never reached, because a zero fee never gets that far.
///
/// This replaces the old `get_game_fee_info` / `get_game_fee_recipient` pair.
/// Those were two separate resolutions because the retired generation answered
/// the two questions in different places — terms from the registry, payee from
/// the registry NFT's owner. One surface now answers both in one call.
pub fn get_game_fee_terms(game_address: ContractAddress) -> GameFeeTerms {
    assert_is_standard_game(game_address);

    if !supports_game_fee_surface(game_address) {
        return GameFeeTerms {
            recipient: Zero::zero(), license: default_license(), fee_numerator: 0,
        };
    }
    IMinigameTokenGameFeeDispatcher { contract_address: game_address }.game_fee_terms()
}
