/// Entry data stored per (context_id, entry_id).
/// game_token_id != 0 means the entry exists.
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct RegistrationEntryData {
    pub game_token_id: felt252,
    pub has_submitted: bool,
    pub is_banned: bool,
}
