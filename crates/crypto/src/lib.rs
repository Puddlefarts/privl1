//! PRIVL1 Cryptographic Primitives
//!
//! This crate provides the core cryptographic building blocks for the PRIVL1 blockchain:
//! - Pedersen commitments for hiding values
//! - Incremental Merkle trees for note commitments
//! - Nullifier derivation for preventing double-spending
//! - Key generation and management
//! - Hash functions optimized for zero-knowledge circuits

pub mod commitment;
pub mod hash;
pub mod keys;
pub mod merkle;
pub mod note;
pub mod nullifier;
pub mod primitives;
pub mod proof;

// Re-export commonly used types
pub use commitment::{Commitment, PedersenCommitment};
pub use hash::{Blake3Hash, Hash, Hasher, PoseidonHash};
pub use keys::{PublicKey, SpendingKey, ViewingKey};
pub use merkle::{IncrementalMerkleTree, MerkleProof, MerkleRoot};
pub use note::{Note, NoteCommitment};
pub use nullifier::{Nullifier, NullifierDerivingKey};

/// Common error type for cryptographic operations
#[derive(Debug, thiserror::Error)]
pub enum CryptoError {
    #[error("Invalid key material")]
    InvalidKey,

    #[error("Invalid commitment")]
    InvalidCommitment,

    #[error("Invalid proof")]
    InvalidProof,

    #[error("Merkle tree error: {0}")]
    MerkleError(String),

    #[error("Serialization error: {0}")]
    SerializationError(String),

    #[error("Cryptographic operation failed: {0}")]
    OperationFailed(String),
}

pub type Result<T> = std::result::Result<T, CryptoError>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_crypto_module_imports() {
        // Basic smoke test to ensure module structure is correct
        assert_eq!(std::mem::size_of::<CryptoError>(), std::mem::size_of::<CryptoError>());
    }
}