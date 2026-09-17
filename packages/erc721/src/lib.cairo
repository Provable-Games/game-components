pub mod common;
pub mod erc721;
pub use erc721::{
    ERC721Component, ERC721HooksEmptyImpl, ERC721OwnerOfDefaultImpl, ERC721TokenURIDefaultImpl,
};
#[cfg(test)]
mod tests;
