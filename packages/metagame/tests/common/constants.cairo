use starknet::ContractAddress;
use starknet::contract_address_const;

// Test addresses
pub fn ZERO_ADDRESS() -> ContractAddress {
    contract_address_const::<0>()
}

pub fn ALICE() -> ContractAddress {
    contract_address_const::<'ALICE'>()
}

pub fn BOB() -> ContractAddress {
    contract_address_const::<'BOB'>()
}

pub fn GAME_ADDRESS() -> ContractAddress {
    contract_address_const::<'GAME'>()
}

pub fn TOKEN_ADDRESS() -> ContractAddress {
    contract_address_const::<'TOKEN'>()
}

pub fn CONTEXT_ADDRESS() -> ContractAddress {
    contract_address_const::<'CONTEXT'>()
}

pub fn RENDERER_ADDRESS() -> ContractAddress {
    contract_address_const::<'RENDERER'>()
}

// Test strings
pub fn PLAYER_NAME() -> ByteArray {
    "Alice Player"
}

pub fn CLIENT_URL() -> ByteArray {
    "https://game.example.com"
}

pub fn CONTEXT_NAME() -> ByteArray {
    "Test Context"
}

pub fn CONTEXT_DESCRIPTION() -> ByteArray {
    "A test context for metagame"
}

// Test values
pub const SETTINGS_ID: u32 = 123;
pub const CONTEXT_ID: u32 = 456;
pub const TIME_START: u64 = 1000000;
pub const TIME_END: u64 = 2000000;

// Interface IDs
pub const IMETAGAME_ID: felt252 = 0x0260d5160a283a03815f6c3799926c7bdbec5f22e759f992fb8faf172243ab20;
pub const IMETAGAME_CONTEXT_ID: felt252 = 0x0c2e78065b81a310a1cb470d14a7b88875542ad05286b3263cf3c254082386e;
pub const ISRC5_ID: felt252 = 0x3f918d17e5ee77373b56385708f855659a07f75997f365cf87748628532a055;