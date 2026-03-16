pub trait ToBytes<T> {
    fn to_bytes(self: T) -> ByteArray;
}

pub mod elements;
pub use elements::{Tag, TagImpl};

// New modules
pub mod encoding;
pub mod escape;
pub mod format;

pub mod json;
pub mod strings;
pub mod svg;
pub mod utils;
