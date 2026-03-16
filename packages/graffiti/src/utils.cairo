pub mod constants {
    pub const BRACKET_OPEN: felt252 = '{';
    pub const BRACKET_CLOSE: felt252 = '}';

    pub const QUOTE: felt252 = '"';
    pub const COLON: felt252 = ':';
    pub const COMMA: felt252 = ',';

    pub const NAME: felt252 = 'name';
    pub const DESCRIPTION: felt252 = 'description';
    pub const IMAGE: felt252 = 'image';
    pub const ATTRIBUTES: felt252 = 'attributes';

    pub const TRAIT_TYPE: felt252 = 'trait_type';
    pub const VALUE: felt252 = 'value';

    pub const SQUARE_BRACKET_OPEN: felt252 = '[';
    pub const SQUARE_BRACKET_CLOSE: felt252 = ']';
}

// Check if a string starts with a bracket (either square or curly)
pub fn starts_with_bracket(str: @ByteArray) -> bool {
    match str.at(0) {
        Option::Some(first_byte) => first_byte == '[' || first_byte == '{',
        Option::None => false,
    }
}
