//! EIP-191 personal_sign verification for Starknet recipients.
//!
//! Ported from `cartridge-gg/merkle_drop/src/forwarder/signature.cairo` so a
//! claimer holding a secp256k1 private key can sign the destination
//! Starknet recipient and the contract can recover the EVM address that
//! signed.

use starknet::ContractAddress;
use starknet::eth_address::EthAddress;
use starknet::eth_signature::verify_eth_signature;
use starknet::secp256_trait::signature_from_vrs;

#[derive(Drop, Copy, Serde)]
pub struct EthereumSignature {
    pub v: u32,
    pub r: u256,
    pub s: u256,
}

/// Verifies that `sig` is a secp256k1 signature, made by `eth_address`,
/// over the message embedding `recipient`. Panics on failure.
pub fn verify_claim_signature(
    sig: EthereumSignature, eth_address: EthAddress, recipient: ContractAddress,
) {
    let message = build_message(recipient);
    let msg_hash = hash_message(@message);
    let signature = signature_from_vrs(sig.v, sig.r, sig.s);
    verify_eth_signature(msg_hash, signature, eth_address);
}

/// Builds the canonical claim message:
///
///   `"Claim on starknet with: 0x{recipient:x}"`
///
/// Lowercase hex with no leading zeros so the format matches viem's
/// `signMessage({ message: "..." })` output.
pub fn build_message(address: ContractAddress) -> ByteArray {
    let header: ByteArray = "Ethereum Signed Message:\n";
    let addr_felt: felt252 = address.into();
    let message: ByteArray = format!("Claim on starknet with: 0x{:x}", addr_felt);
    let message_len = format!("{}", message.len());
    format!("{}{}{}", header, message_len, message)
}

/// Computes the EIP-191 personal_sign hash:
///
///   `keccak256("\x19" + "Ethereum Signed Message:\n" + len(msg) + msg)`
pub fn hash_message(message: @ByteArray) -> u256 {
    let mut bytes: ByteArray = Default::default();
    let mut i = 0;
    bytes.append_byte(0x19); // EIP-191 prefix byte
    while i < message.len() {
        let char = message.at(i).unwrap();
        bytes.append_byte(char);
        i += 1;
    }
    let keccak_le = core::keccak::compute_keccak_byte_array(@bytes);
    u256 {
        high: core::integer::u128_byte_reverse(keccak_le.low),
        low: core::integer::u128_byte_reverse(keccak_le.high),
    }
}
