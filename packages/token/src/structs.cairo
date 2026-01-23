use starknet::ContractAddress;
use starknet::storage_access::StorePacking;

#[derive(Copy, Drop, Serde)]
pub struct Lifecycle {
    pub start: u64,
    pub end: u64,
}

// StorePacking for Lifecycle - packs two u64 into single felt252
// This saves 1 storage slot compared to default Store derive
pub impl LifecycleStorePacking of StorePacking<Lifecycle, felt252> {
    fn pack(value: Lifecycle) -> felt252 {
        let packed: u256 = value.start.into()
            | (Into::<u64, u256>::into(value.end) * 0x10000000000000000_u256);
        packed.try_into().unwrap()
    }

    fn unpack(value: felt252) -> Lifecycle {
        let packed: u256 = value.into();
        Lifecycle {
            start: (packed & 0xFFFFFFFFFFFFFFFF_u256).try_into().unwrap(),
            end: ((packed / 0x10000000000000000_u256) & 0xFFFFFFFFFFFFFFFF_u256)
                .try_into()
                .unwrap(),
        }
    }
}

// ==============================================================================
// PACKED TOKEN ID - Embeds immutable data directly in the token_id (felt252)
// ==============================================================================
//
// Bit Layout (250 bits used, fits in felt252's ~252 bits):
// | Bits      | Field            | Size     | Max Value                      |
// |-----------|------------------|----------|--------------------------------|
// | 0-29      | game_id          | 30 bits  | 1,073,741,823 games            |
// | 30-69     | minted_by        | 40 bits  | 1,099,511,627,775 minters      |
// | 70-99     | settings_id      | 30 bits  | 1,073,741,823 settings         |
// | 100-134   | minted_at        | 35 bits  | Unix timestamp (~1000 years)   |
// | 135-159   | start_delay      | 25 bits  | 33,554,431 seconds (~388 days) |
// | 160-184   | end_delay        | 25 bits  | 33,554,431 seconds (~388 days) |
// | 185-214   | objective_id     | 30 bits  | 1,073,741,823 objectives       |
// | 215       | soulbound        | 1 bit    | bool                           |
// | 216       | has_context      | 1 bit    | bool                           |
// | 217       | paymaster        | 1 bit    | bool                           |
// | 218-227   | tx_hash          | 10 bits  | 1,024 unique per second        |
// | 228-237   | salt             | 10 bits  | 1,024 tokens per tx (multicall)|
// | 238-250   | metadata         | 13 bits  | 8,191 (reserved for future)    |
// Total: 251 bits (max for felt252)
//
// COLLISION PROTECTION:
// - tx_hash: Last 10 bits of starknet transaction hash. Since tx_hash includes
//   the sender's nonce (unique per tx), different transactions have different
//   hashes. This protects against same-block collisions.
// - salt: Client-provided value for multicall scenarios. Client must increment
//   salt for each mint within the same transaction to avoid collisions.
//
// This eliminates storage reads for immutable metadata - just decode from token_id!
// Using felt252 (Cairo's native field element) is more gas efficient than u256.

/// Data structure representing the packed token ID fields (for convenience)
#[derive(Copy, Drop, Serde)]
pub struct PackedTokenId {
    pub game_id: u32, // 30 bits
    pub minted_by: u64, // 40 bits
    pub settings_id: u32, // 30 bits
    pub minted_at: u64, // 35 bits
    pub start_delay: u32, // 25 bits
    pub end_delay: u32, // 25 bits
    pub objective_id: u32, // 30 bits
    pub soulbound: bool, // 1 bit
    pub has_context: bool, // 1 bit
    pub paymaster: bool, // 1 bit
    pub tx_hash: u16, // 10 bits - last 10 bits of transaction hash for collision protection
    pub salt: u16, // 10 bits - client-provided salt for multicall collision protection
    pub metadata: u16 // 12 bits - reserved for future use
}

/// Mutable state that still needs storage (only 2 fields!)
/// Packed into a single felt252 for gas efficiency using StorePacking.
#[derive(Copy, Drop, Serde)]
pub struct TokenMutableState {
    pub game_over: bool,
    pub completed_objective: bool,
}

impl TokenMutableStateDefault of Default<TokenMutableState> {
    fn default() -> TokenMutableState {
        TokenMutableState { game_over: false, completed_objective: false }
    }
}

/// StorePacking implementation for TokenMutableState
/// Packs 2 boolean fields into a single felt252 (uses only 2 bits)
/// This is the most gas-efficient way to store boolean flags in Cairo.
pub impl TokenMutableStateStorePacking of StorePacking<TokenMutableState, felt252> {
    fn pack(value: TokenMutableState) -> felt252 {
        let mut packed: u8 = 0;
        if value.game_over {
            packed = packed | 0x1; // bit 0
        }
        if value.completed_objective {
            packed = packed | 0x2; // bit 1
        }
        packed.into()
    }

    fn unpack(value: felt252) -> TokenMutableState {
        let packed: u8 = value.try_into().unwrap();
        TokenMutableState {
            game_over: (packed & 0x1) != 0, completed_objective: (packed & 0x2) != 0,
        }
    }
}

// ==============================================================================
// Power-of-2 Constants for Bit Shifting
// ==============================================================================
// Using module constants instead of inline functions for better gas efficiency.
// Cairo doesn't have a << operator for felt252, so we use multiplication.

pub mod PackedTokenIdBits {
    // Field widths
    pub const GAME_ID_BITS: u8 = 30;
    pub const MINTED_BY_BITS: u8 = 40;
    pub const SETTINGS_ID_BITS: u8 = 30;
    pub const MINTED_AT_BITS: u8 = 35;
    pub const START_DELAY_BITS: u8 = 25;
    pub const END_DELAY_BITS: u8 = 25;
    pub const OBJECTIVE_ID_BITS: u8 = 30;
    pub const SOULBOUND_BITS: u8 = 1;
    pub const HAS_CONTEXT_BITS: u8 = 1;
    pub const PAYMASTER_BITS: u8 = 1;
    pub const TX_HASH_BITS: u8 = 10;
    pub const SALT_BITS: u8 = 10;
    pub const METADATA_BITS: u8 = 13;

    // Bit offsets (cumulative)
    pub const GAME_ID_OFFSET: u8 = 0; // 0
    pub const MINTED_BY_OFFSET: u8 = 30; // 0 + 30
    pub const SETTINGS_ID_OFFSET: u8 = 70; // 30 + 40
    pub const MINTED_AT_OFFSET: u8 = 100; // 70 + 30
    pub const START_DELAY_OFFSET: u8 = 135; // 100 + 35
    pub const END_DELAY_OFFSET: u8 = 160; // 135 + 25
    pub const OBJECTIVE_ID_OFFSET: u8 = 185; // 160 + 25
    pub const SOULBOUND_OFFSET: u8 = 215; // 185 + 30
    pub const HAS_CONTEXT_OFFSET: u8 = 216; // 215 + 1
    pub const PAYMASTER_OFFSET: u8 = 217; // 216 + 1
    pub const TX_HASH_OFFSET: u8 = 218; // 217 + 1
    pub const SALT_OFFSET: u8 = 228; // 218 + 10
    pub const METADATA_OFFSET: u8 = 238; // 228 + 10
    // Total: 238 + 13 = 251 bits (max for felt252)

    // Masks (using u256 for intermediate calculations, result fits in felt252)
    pub const GAME_ID_MASK: u256 = 0x3FFFFFFF; // 30 bits
    pub const MINTED_BY_MASK: u256 = 0xFFFFFFFFFF; // 40 bits
    pub const SETTINGS_ID_MASK: u256 = 0x3FFFFFFF; // 30 bits
    pub const MINTED_AT_MASK: u256 = 0x7FFFFFFFF; // 35 bits
    pub const START_DELAY_MASK: u256 = 0x1FFFFFF; // 25 bits
    pub const END_DELAY_MASK: u256 = 0x1FFFFFF; // 25 bits
    pub const OBJECTIVE_ID_MASK: u256 = 0x3FFFFFFF; // 30 bits
    pub const SOULBOUND_MASK: u256 = 0x1; // 1 bit
    pub const HAS_CONTEXT_MASK: u256 = 0x1; // 1 bit
    pub const PAYMASTER_MASK: u256 = 0x1; // 1 bit
    pub const TX_HASH_MASK: u256 = 0x3FF; // 10 bits
    pub const SALT_MASK: u256 = 0x3FF; // 10 bits
    pub const METADATA_MASK: u256 = 0x1FFF; // 13 bits

    // Power-of-2 constants for bit shifting
    pub const POW2_30: u256 = 0x40000000; // 2^30
    pub const POW2_70: u256 = 0x400000000000000000; // 2^70
    pub const POW2_100: u256 = 0x10000000000000000000000000; // 2^100
    pub const POW2_135: u256 = 0x8000000000000000000000000000000000; // 2^135
    pub const POW2_160: u256 = 0x10000000000000000000000000000000000000000; // 2^160
    pub const POW2_185: u256 = 0x20000000000000000000000000000000000000000000000; // 2^185
    pub const POW2_215: u256 = 0x800000000000000000000000000000000000000000000000000000; // 2^215
    pub const POW2_216: u256 = 0x1000000000000000000000000000000000000000000000000000000; // 2^216
    pub const POW2_217: u256 = 0x2000000000000000000000000000000000000000000000000000000; // 2^217
    pub const POW2_218: u256 = 0x4000000000000000000000000000000000000000000000000000000; // 2^218
    pub const POW2_228: u256 =
        0x1000000000000000000000000000000000000000000000000000000000; // 2^228
    pub const POW2_238: u256 =
        0x400000000000000000000000000000000000000000000000000000000000; // 2^238
}

/// Packs token metadata into a felt252 token_id
/// This is a pure function - no storage access needed
/// Using felt252 (native field element) for gas efficiency
///
/// # Arguments
/// * `tx_hash` - Last 10 bits of transaction hash (for collision protection across txs)
/// * `salt` - Client-provided salt (for collision protection within multicalls)
/// * `metadata` - Reserved for future use
#[inline(always)]
pub fn pack_token_id(
    game_id: u32,
    minted_by: u64,
    settings_id: u32,
    minted_at: u64,
    start_delay: u32,
    end_delay: u32,
    objective_id: u32,
    soulbound: bool,
    has_context: bool,
    paymaster: bool,
    tx_hash: u16,
    salt: u16,
    metadata: u16,
) -> felt252 {
    use PackedTokenIdBits::{
        METADATA_MASK, POW2_100, POW2_135, POW2_160, POW2_185, POW2_215, POW2_216, POW2_217,
        POW2_218, POW2_228, POW2_238, POW2_30, POW2_70, SALT_MASK, TX_HASH_MASK,
    };

    // Build packed value using u256 for intermediate calculations
    let mut packed: u256 = 0;

    // Pack each field at its offset
    packed = packed | (game_id.into());
    packed = packed | (Into::<u64, u256>::into(minted_by) * POW2_30);
    packed = packed | (Into::<u32, u256>::into(settings_id) * POW2_70);
    packed = packed | (Into::<u64, u256>::into(minted_at) * POW2_100);
    packed = packed | (Into::<u32, u256>::into(start_delay) * POW2_135);
    packed = packed | (Into::<u32, u256>::into(end_delay) * POW2_160);
    packed = packed | (Into::<u32, u256>::into(objective_id) * POW2_185);
    packed = packed | (if soulbound {
        POW2_215
    } else {
        0
    });
    packed = packed | (if has_context {
        POW2_216
    } else {
        0
    });
    packed = packed | (if paymaster {
        POW2_217
    } else {
        0
    });
    // tx_hash: mask to 10 bits and shift to offset 218
    packed = packed | ((Into::<u16, u256>::into(tx_hash) & TX_HASH_MASK) * POW2_218);
    // salt: mask to 10 bits and shift to offset 228
    packed = packed | ((Into::<u16, u256>::into(salt) & SALT_MASK) * POW2_228);
    // metadata: mask to 12 bits and shift to offset 238
    packed = packed | ((Into::<u16, u256>::into(metadata) & METADATA_MASK) * POW2_238);

    // Convert to felt252 - safe because we only use 250 bits (fits in ~252 bit felt252)
    packed.try_into().unwrap()
}

/// Unpacks a token_id into its component fields
/// This is a pure function - no storage access needed
#[inline(always)]
pub fn unpack_token_id(token_id: felt252) -> PackedTokenId {
    use PackedTokenIdBits::{
        END_DELAY_MASK, GAME_ID_MASK, HAS_CONTEXT_MASK, METADATA_MASK, MINTED_AT_MASK,
        MINTED_BY_MASK, OBJECTIVE_ID_MASK, PAYMASTER_MASK, POW2_100, POW2_135, POW2_160, POW2_185,
        POW2_215, POW2_216, POW2_217, POW2_218, POW2_228, POW2_238, POW2_30, POW2_70, SALT_MASK,
        SETTINGS_ID_MASK, SOULBOUND_MASK, START_DELAY_MASK, TX_HASH_MASK,
    };

    // Convert felt252 to u256 for bit operations
    let packed: u256 = token_id.into();

    PackedTokenId {
        game_id: (packed & GAME_ID_MASK).try_into().unwrap(),
        minted_by: ((packed / POW2_30) & MINTED_BY_MASK).try_into().unwrap(),
        settings_id: ((packed / POW2_70) & SETTINGS_ID_MASK).try_into().unwrap(),
        minted_at: ((packed / POW2_100) & MINTED_AT_MASK).try_into().unwrap(),
        start_delay: ((packed / POW2_135) & START_DELAY_MASK).try_into().unwrap(),
        end_delay: ((packed / POW2_160) & END_DELAY_MASK).try_into().unwrap(),
        objective_id: ((packed / POW2_185) & OBJECTIVE_ID_MASK).try_into().unwrap(),
        soulbound: ((packed / POW2_215) & SOULBOUND_MASK) == 1,
        has_context: ((packed / POW2_216) & HAS_CONTEXT_MASK) == 1,
        paymaster: ((packed / POW2_217) & PAYMASTER_MASK) == 1,
        tx_hash: ((packed / POW2_218) & TX_HASH_MASK).try_into().unwrap(),
        salt: ((packed / POW2_228) & SALT_MASK).try_into().unwrap(),
        metadata: ((packed / POW2_238) & METADATA_MASK).try_into().unwrap(),
    }
}

/// Helper to unpack just game_id from token_id (most common lookup)
#[inline(always)]
pub fn unpack_game_id(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    (packed & PackedTokenIdBits::GAME_ID_MASK).try_into().unwrap()
}

/// Helper to unpack just minted_by from token_id
#[inline(always)]
pub fn unpack_minted_by(token_id: felt252) -> u64 {
    let packed: u256 = token_id.into();
    ((packed / PackedTokenIdBits::POW2_30) & PackedTokenIdBits::MINTED_BY_MASK).try_into().unwrap()
}

/// Helper to unpack just settings_id from token_id
#[inline(always)]
pub fn unpack_settings_id(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    ((packed / PackedTokenIdBits::POW2_70) & PackedTokenIdBits::SETTINGS_ID_MASK)
        .try_into()
        .unwrap()
}

/// Helper to unpack just minted_at from token_id
#[inline(always)]
pub fn unpack_minted_at(token_id: felt252) -> u64 {
    let packed: u256 = token_id.into();
    ((packed / PackedTokenIdBits::POW2_100) & PackedTokenIdBits::MINTED_AT_MASK).try_into().unwrap()
}

/// Helper to unpack start_delay from token_id
#[inline(always)]
pub fn unpack_start_delay(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    ((packed / PackedTokenIdBits::POW2_135) & PackedTokenIdBits::START_DELAY_MASK)
        .try_into()
        .unwrap()
}

/// Helper to unpack end_delay from token_id
#[inline(always)]
pub fn unpack_end_delay(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    ((packed / PackedTokenIdBits::POW2_160) & PackedTokenIdBits::END_DELAY_MASK).try_into().unwrap()
}

/// Helper to unpack objective_id from token_id
#[inline(always)]
pub fn unpack_objective_id(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    ((packed / PackedTokenIdBits::POW2_185) & PackedTokenIdBits::OBJECTIVE_ID_MASK)
        .try_into()
        .unwrap()
}

/// Helper to unpack soulbound flag from token_id
#[inline(always)]
pub fn unpack_soulbound(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    ((packed / PackedTokenIdBits::POW2_215) & PackedTokenIdBits::SOULBOUND_MASK) == 1
}

/// Helper to unpack has_context flag from token_id
#[inline(always)]
pub fn unpack_has_context(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    ((packed / PackedTokenIdBits::POW2_216) & PackedTokenIdBits::HAS_CONTEXT_MASK) == 1
}

/// Helper to unpack paymaster flag from token_id
#[inline(always)]
pub fn unpack_paymaster(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    ((packed / PackedTokenIdBits::POW2_217) & PackedTokenIdBits::PAYMASTER_MASK) == 1
}

/// Helper to unpack tx_hash from token_id (last 10 bits of transaction hash)
#[inline(always)]
pub fn unpack_tx_hash(token_id: felt252) -> u16 {
    let packed: u256 = token_id.into();
    ((packed / PackedTokenIdBits::POW2_218) & PackedTokenIdBits::TX_HASH_MASK).try_into().unwrap()
}

/// Helper to unpack salt from token_id (client-provided collision protection)
#[inline(always)]
pub fn unpack_salt(token_id: felt252) -> u16 {
    let packed: u256 = token_id.into();
    ((packed / PackedTokenIdBits::POW2_228) & PackedTokenIdBits::SALT_MASK).try_into().unwrap()
}

/// Helper to unpack metadata from token_id (reserved for future use)
#[inline(always)]
pub fn unpack_metadata(token_id: felt252) -> u16 {
    let packed: u256 = token_id.into();
    ((packed / PackedTokenIdBits::POW2_238) & PackedTokenIdBits::METADATA_MASK).try_into().unwrap()
}

/// Helper to extract the last 10 bits from a transaction hash for use in pack_token_id
#[inline(always)]
pub fn extract_tx_hash_bits(tx_hash: felt252) -> u16 {
    let hash_u256: u256 = tx_hash.into();
    (hash_u256 & PackedTokenIdBits::TX_HASH_MASK).try_into().unwrap()
}

// ==============================================================================
// TOKEN METADATA - Optimized with StorePacking
// ==============================================================================
// Packs all metadata fields into a single felt252 for maximum gas efficiency.
//
// Bit Layout (219 bits total, fits in felt252's ~252 bits):
// | Bits      | Field                     | Size     | Max Value                |
// |-----------|---------------------------|----------|--------------------------|
// | 0-29      | game_id                   | 30 bits  | ~1 billion games         |
// | 30-64     | minted_at                 | 35 bits  | Unix timestamp (~1000yr) |
// | 65-96     | settings_id               | 32 bits  | ~4 billion settings      |
// | 97-131    | lifecycle_start           | 35 bits  | Unix timestamp (~1000yr) |
// | 132-166   | lifecycle_end             | 35 bits  | Unix timestamp (~1000yr) |
// | 167-206   | minted_by                 | 40 bits  | ~1 trillion minters      |
// | 207       | soulbound                 | 1 bit    | bool                     |
// | 208       | game_over                 | 1 bit    | bool                     |
// | 209       | completed_objective  | 1 bit    | bool                     |
// | 210       | has_context               | 1 bit    | bool                     |
// | 211-218   | objectives_count          | 8 bits   | 255 objectives           |
//
// Gas savings: Reduces from ~6 storage slots to 1 slot per token.

#[derive(Copy, Drop, Serde)]
pub struct TokenMetadata {
    pub game_id: u64,
    pub minted_at: u64,
    pub settings_id: u32,
    pub lifecycle: Lifecycle,
    pub minted_by: u64,
    pub soulbound: bool,
    pub game_over: bool,
    pub completed_objective: bool,
    pub has_context: bool,
    pub objective_id: u32,
}

impl TokenMetadataDefault of Default<TokenMetadata> {
    fn default() -> TokenMetadata {
        TokenMetadata {
            game_id: 0,
            minted_at: 0,
            settings_id: 0,
            lifecycle: Lifecycle { start: 0, end: 0 },
            minted_by: 0,
            soulbound: false,
            game_over: false,
            completed_objective: false,
            has_context: false,
            objective_id: 0,
        }
    }
}

// TokenMetadata packing constants
pub mod TokenMetadataBits {
    // Power-of-2 shift constants
    pub const POW2_30: u256 = 0x40000000; // 2^30
    pub const POW2_65: u256 = 0x20000000000000000; // 2^65
    pub const POW2_97: u256 = 0x200000000000000000000000; // 2^97
    pub const POW2_132: u256 = 0x1000000000000000000000000000000000; // 2^132
    pub const POW2_167: u256 = 0x800000000000000000000000000000000000000000; // 2^167
    pub const POW2_207: u256 = 0x800000000000000000000000000000000000000000000000000000; // 2^207
    pub const POW2_208: u256 = 0x1000000000000000000000000000000000000000000000000000000; // 2^208
    pub const POW2_209: u256 = 0x2000000000000000000000000000000000000000000000000000000; // 2^209
    pub const POW2_210: u256 = 0x4000000000000000000000000000000000000000000000000000000; // 2^210
    pub const POW2_211: u256 = 0x8000000000000000000000000000000000000000000000000000000; // 2^211

    // Masks
    pub const GAME_ID_MASK: u256 = 0x3FFFFFFF; // 30 bits
    pub const MINTED_AT_MASK: u256 = 0x7FFFFFFFF; // 35 bits
    pub const SETTINGS_ID_MASK: u256 = 0xFFFFFFFF; // 32 bits
    pub const LIFECYCLE_MASK: u256 = 0x7FFFFFFFF; // 35 bits
    pub const MINTED_BY_MASK: u256 = 0xFFFFFFFFFF; // 40 bits
    pub const BOOL_MASK: u256 = 0x1; // 1 bit
    pub const OBJECTIVE_ID_MASK: u256 = 0x3FFFFFFF; // 30 bits
}

/// StorePacking implementation for TokenMetadata
/// Packs all fields into a single felt252, reducing storage from ~6 slots to 1.
pub impl TokenMetadataStorePacking of StorePacking<TokenMetadata, felt252> {
    fn pack(value: TokenMetadata) -> felt252 {
        use TokenMetadataBits::{
            GAME_ID_MASK, LIFECYCLE_MASK, MINTED_AT_MASK, MINTED_BY_MASK, POW2_132, POW2_167,
            POW2_207, POW2_208, POW2_209, POW2_210, POW2_211, POW2_30, POW2_65, POW2_97,
            SETTINGS_ID_MASK,
        };

        let mut packed: u256 = 0;

        // game_id: bits 0-29 (30 bits)
        packed = packed | (Into::<u64, u256>::into(value.game_id) & GAME_ID_MASK);
        // minted_at: bits 30-64 (35 bits)
        packed = packed | ((Into::<u64, u256>::into(value.minted_at) & MINTED_AT_MASK) * POW2_30);
        // settings_id: bits 65-96 (32 bits)
        packed = packed
            | ((Into::<u32, u256>::into(value.settings_id) & SETTINGS_ID_MASK) * POW2_65);
        // lifecycle_start: bits 97-131 (35 bits)
        packed = packed
            | ((Into::<u64, u256>::into(value.lifecycle.start) & LIFECYCLE_MASK) * POW2_97);
        // lifecycle_end: bits 132-166 (35 bits)
        packed = packed
            | ((Into::<u64, u256>::into(value.lifecycle.end) & LIFECYCLE_MASK) * POW2_132);
        // minted_by: bits 167-206 (40 bits)
        packed = packed | ((Into::<u64, u256>::into(value.minted_by) & MINTED_BY_MASK) * POW2_167);
        // soulbound: bit 207
        packed = packed | (if value.soulbound {
            POW2_207
        } else {
            0
        });
        // game_over: bit 208
        packed = packed | (if value.game_over {
            POW2_208
        } else {
            0
        });
        // completed_objective: bit 209
        packed = packed | (if value.completed_objective {
            POW2_209
        } else {
            0
        });
        // has_context: bit 210
        packed = packed | (if value.has_context {
            POW2_210
        } else {
            0
        });
        // objective_id: bits 211-240 (30 bits)
        packed = packed | (Into::<u32, u256>::into(value.objective_id) * POW2_211);

        packed.try_into().unwrap()
    }

    fn unpack(value: felt252) -> TokenMetadata {
        use TokenMetadataBits::{
            BOOL_MASK, GAME_ID_MASK, LIFECYCLE_MASK, MINTED_AT_MASK, MINTED_BY_MASK,
            OBJECTIVE_ID_MASK, POW2_132, POW2_167, POW2_207, POW2_208, POW2_209, POW2_210, POW2_211,
            POW2_30, POW2_65, POW2_97, SETTINGS_ID_MASK,
        };

        let packed: u256 = value.into();

        TokenMetadata {
            game_id: (packed & GAME_ID_MASK).try_into().unwrap(),
            minted_at: ((packed / POW2_30) & MINTED_AT_MASK).try_into().unwrap(),
            settings_id: ((packed / POW2_65) & SETTINGS_ID_MASK).try_into().unwrap(),
            lifecycle: Lifecycle {
                start: ((packed / POW2_97) & LIFECYCLE_MASK).try_into().unwrap(),
                end: ((packed / POW2_132) & LIFECYCLE_MASK).try_into().unwrap(),
            },
            minted_by: ((packed / POW2_167) & MINTED_BY_MASK).try_into().unwrap(),
            soulbound: ((packed / POW2_207) & BOOL_MASK) == 1,
            game_over: ((packed / POW2_208) & BOOL_MASK) == 1,
            completed_objective: ((packed / POW2_209) & BOOL_MASK) == 1,
            has_context: ((packed / POW2_210) & BOOL_MASK) == 1,
            objective_id: ((packed / POW2_211) & OBJECTIVE_ID_MASK).try_into().unwrap(),
        }
    }
}

// ==============================================================================
// BATCH OPERATION PARAMETERS
// ==============================================================================

use game_components_metagame::extensions::context::structs::GameContextDetails;

/// Per-token mint parameters for batch minting.
/// Contains all parameters for a single mint operation.
/// Note: Not Copy because it contains ByteArray and GameContextDetails.
#[derive(Drop, Serde)]
pub struct MintParams {
    pub game_address: Option<ContractAddress>,
    pub player_name: Option<felt252>,
    pub settings_id: Option<u32>,
    pub start: Option<u64>,
    pub end: Option<u64>,
    pub objective_id: Option<u32>,
    pub context: Option<GameContextDetails>,
    pub client_url: Option<ByteArray>,
    pub renderer_address: Option<ContractAddress>,
    pub to: ContractAddress,
    pub soulbound: bool,
}

/// Per-token name update parameters for batch name updates
#[derive(Copy, Drop, Serde)]
pub struct PlayerNameUpdate {
    pub token_id: u64,
    pub name: felt252,
}

/// Per-token metadata update parameters for batch metadata updates
/// Note: Not Copy because it contains GameContextDetails.
#[derive(Drop, Serde)]
pub struct SetTokenMetadataParams {
    pub token_id: u64,
    pub game_address: ContractAddress,
    pub player_name: Option<felt252>,
    pub settings_id: Option<u32>,
    pub start: Option<u64>,
    pub end: Option<u64>,
    pub objective_id: Option<u32>,
    pub context: Option<GameContextDetails>,
}

/// Convert PackedTokenId + TokenMutableState to TokenMetadata
#[inline(always)]
pub fn to_token_metadata(packed: PackedTokenId, mutable_state: TokenMutableState) -> TokenMetadata {
    TokenMetadata {
        game_id: packed.game_id.into(),
        minted_at: packed.minted_at.into(),
        settings_id: packed.settings_id.into(),
        lifecycle: Lifecycle { start: packed.start_delay.into(), end: packed.end_delay.into() },
        minted_by: packed.minted_by.into(),
        soulbound: packed.soulbound,
        game_over: mutable_state.game_over,
        completed_objective: mutable_state.completed_objective,
        has_context: packed.has_context,
        objective_id: packed.objective_id,
    }
}
