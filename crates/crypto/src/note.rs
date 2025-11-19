//! Note structure for UTXO-based privacy
//!
//! Notes are the fundamental unit of value in PRIVL1, similar to UTXOs
//! but with privacy-preserving properties via commitments.

use pasta_curves::pallas;
use serde::{Deserialize, Serialize};
use std::fmt;

use crate::commitment::{Commitment, PedersenCommitment};
use crate::hash::Blake3Hash;
use crate::keys::{EncryptedNote, PublicKey, ViewingKey};
use crate::{CryptoError, Result};

/// A note representing value in the system
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Note {
    /// The value held by this note
    value: u64,
    /// The asset type (for multi-asset support)
    asset_id: [u8; 32],
    /// The owner's public key
    owner: PublicKey,
    /// Random blinding factor
    randomness: pallas::Scalar,
    /// Optional memo (encrypted)
    memo: Option<Vec<u8>>,
    /// Cached commitment (for the simplified test version)
    #[serde(skip)]
    cached_commitment: Option<Commitment>,
}

impl Note {
    /// Create a new note (simplified for testing - uses provided commitment)
    pub fn new(value: u64, commitment: Commitment, asset_id: [u8; 32]) -> Self {
        use ark_ff::UniformRand;
        let mut rng = rand::thread_rng();

        // For testing, we'll create a simplified note with dummy owner
        let owner = PublicKey::from_bytes(&[0u8; 32]).unwrap();

        Self {
            value,
            asset_id,
            owner,
            randomness: pallas::Scalar::rand(&mut rng),
            memo: None,
            cached_commitment: Some(commitment),
        }
    }

    /// Create a new note with owner
    pub fn new_with_owner(value: u64, owner: PublicKey, asset_id: [u8; 32]) -> Self {
        use ark_ff::UniformRand;
        let mut rng = rand::thread_rng();

        Self {
            value,
            asset_id,
            owner,
            randomness: pallas::Scalar::rand(&mut rng),
            memo: None,
            cached_commitment: None,
        }
    }

    /// Create a note with specific randomness
    pub fn with_randomness(
        value: u64,
        owner: PublicKey,
        asset_id: [u8; 32],
        randomness: pallas::Scalar,
    ) -> Self {
        Self {
            value,
            asset_id,
            owner,
            randomness,
            memo: None,
            cached_commitment: None,
        }
    }

    /// Add a memo to the note
    pub fn with_memo(mut self, memo: Vec<u8>) -> Self {
        self.memo = Some(memo);
        self
    }

    /// Get the note's value
    pub fn value(&self) -> u64 {
        self.value
    }

    /// Get the asset ID
    pub fn asset_id(&self) -> &[u8; 32] {
        &self.asset_id
    }

    /// Get the owner's public key
    pub fn owner(&self) -> &PublicKey {
        &self.owner
    }

    /// Get the randomness
    pub fn randomness(&self) -> &pallas::Scalar {
        &self.randomness
    }

    /// Compute the note commitment
    pub fn commitment(&self) -> NoteCommitment {
        // Use cached commitment if available (for testing)
        let commitment = if let Some(cached) = self.cached_commitment {
            cached
        } else {
            let pedersen = PedersenCommitment::new();
            // Commit to all note components
            // In production, this would be a more complex commitment
            // that includes all fields
            pedersen.commit_with_blinding(self.value, self.randomness)
        };

        NoteCommitment {
            inner: commitment,
            asset_id: self.asset_id,
        }
    }

    /// Encrypt the note for the recipient
    pub fn encrypt(&self, recipient: &PublicKey) -> EncryptedNote {
        // Simplified encryption
        // In production, use proper encryption (ChaCha20Poly1305)
        EncryptedNote {
            epk: pallas::Point::identity(),
            ciphertext: vec![],
            tag: [0u8; 16],
        }
    }

    /// Try to decrypt a note with a viewing key
    pub fn decrypt(encrypted: &EncryptedNote, vk: &ViewingKey) -> Result<Self> {
        let decrypted = vk.decrypt_note(encrypted)?;

        Ok(Self {
            value: decrypted.value,
            asset_id: decrypted.asset_id,
            owner: PublicKey::from_bytes(&[0u8; 32])?,
            randomness: pallas::Scalar::zero(),
            memo: Some(decrypted.memo),
        })
    }

    /// Check if this note is owned by a public key
    pub fn is_owned_by(&self, pubkey: &PublicKey) -> bool {
        &self.owner == pubkey
    }

    /// Create a dummy note (for padding transactions)
    pub fn dummy() -> Self {
        Self {
            value: 0,
            asset_id: [0u8; 32],
            owner: PublicKey::from_bytes(&[0u8; 32]).unwrap(),
            randomness: pallas::Scalar::zero(),
            memo: None,
            cached_commitment: None,
        }
    }

    /// Check if this is a dummy note
    pub fn is_dummy(&self) -> bool {
        self.value == 0 && self.randomness == pallas::Scalar::zero()
    }
}

/// A note commitment (hides the note's contents)
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct NoteCommitment {
    inner: Commitment,
    asset_id: [u8; 32],
}

impl NoteCommitment {
    /// Create from a commitment and asset ID
    pub fn new(commitment: Commitment, asset_id: [u8; 32]) -> Self {
        Self {
            inner: commitment,
            asset_id,
        }
    }

    /// Get the inner commitment
    pub fn inner(&self) -> &Commitment {
        &self.inner
    }

    /// Get the asset ID
    pub fn asset_id(&self) -> &[u8; 32] {
        &self.asset_id
    }

    /// Convert to bytes
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(64);
        bytes.extend_from_slice(&self.inner.to_bytes());
        bytes.extend_from_slice(&self.asset_id);
        bytes
    }

    /// Compute hash of the commitment
    pub fn hash(&self) -> Blake3Hash {
        Blake3Hash::hash(&self.to_bytes())
    }
}

impl fmt::Display for NoteCommitment {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", hex::encode(&self.to_bytes()[..8]))
    }
}

/// A spent note with its nullifier revealed
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SpentNote {
    /// The original note
    pub note: Note,
    /// The nullifier (prevents double-spending)
    pub nullifier: crate::nullifier::Nullifier,
    /// Position in the commitment tree
    pub position: u64,
    /// Merkle proof of inclusion
    pub merkle_proof: crate::merkle::MerkleProof,
}

/// A transaction's input (spending a note)
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct InputNote {
    /// The nullifier (public)
    pub nullifier: crate::nullifier::Nullifier,
    /// The Merkle root it's anchored to
    pub anchor: crate::merkle::MerkleRoot,
    /// ZK proof of valid spend (would be Halo2 proof)
    pub spend_proof: Vec<u8>,
}

/// A transaction's output (creating a note)
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct OutputNote {
    /// The note commitment (public)
    pub commitment: NoteCommitment,
    /// Encrypted note for recipient
    pub encrypted_note: EncryptedNote,
    /// ZK proof of valid creation
    pub output_proof: Vec<u8>,
}

/// Multi-asset support
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AssetId([u8; 32]);

impl AssetId {
    /// The native PRIV token
    pub const NATIVE: Self = Self([0u8; 32]);

    /// Create a custom asset ID
    pub fn custom(id: [u8; 32]) -> Self {
        Self(id)
    }

    /// Create from a token contract address
    pub fn from_contract(address: &[u8; 20]) -> Self {
        let mut id = [0u8; 32];
        id[..20].copy_from_slice(address);
        Self(id)
    }

    /// Get as bytes
    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }
}

impl fmt::Display for AssetId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        if *self == Self::NATIVE {
            write!(f, "PRIV")
        } else {
            write!(f, "{}", hex::encode(&self.0[..8]))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ark_std::test_rng;

    #[test]
    fn test_note_creation() {
        let mut rng = test_rng();
        let owner = crate::keys::FullKeys::random(&mut rng).public;

        let note = Note::new_with_owner(100, owner, AssetId::NATIVE.0);

        assert_eq!(note.value(), 100);
        assert_eq!(note.asset_id(), &AssetId::NATIVE.0);
        assert!(note.is_owned_by(&owner));
        assert!(!note.is_dummy());
    }

    #[test]
    fn test_note_commitment() {
        let mut rng = test_rng();
        let owner = crate::keys::FullKeys::random(&mut rng).public;

        let note1 = Note::new_with_owner(100, owner, AssetId::NATIVE.0);
        let note2 = Note::new_with_owner(100, owner, AssetId::NATIVE.0);

        // Different randomness should give different commitments
        let comm1 = note1.commitment();
        let comm2 = note2.commitment();
        assert_ne!(comm1, comm2);

        // Same note should give same commitment (deterministic)
        let comm1b = note1.commitment();
        assert_eq!(comm1, comm1b);
    }

    #[test]
    fn test_dummy_note() {
        let dummy = Note::dummy();

        assert!(dummy.is_dummy());
        assert_eq!(dummy.value(), 0);
        assert_eq!(dummy.randomness, pallas::Scalar::zero());
    }

    #[test]
    fn test_note_with_memo() {
        let mut rng = test_rng();
        let owner = crate::keys::FullKeys::random(&mut rng).public;

        let memo = b"Payment for services".to_vec();
        let note = Note::new_with_owner(100, owner, AssetId::NATIVE.0).with_memo(memo.clone());

        assert_eq!(note.memo, Some(memo));
    }

    #[test]
    fn test_asset_id() {
        let native = AssetId::NATIVE;
        assert_eq!(format!("{}", native), "PRIV");

        let custom = AssetId::custom([1u8; 32]);
        assert_ne!(native, custom);

        let contract_addr = [42u8; 20];
        let contract_asset = AssetId::from_contract(&contract_addr);
        assert_eq!(contract_asset.as_bytes()[..20], contract_addr);
    }

    #[test]
    fn test_note_commitment_serialization() {
        let mut rng = test_rng();
        let owner = crate::keys::FullKeys::random(&mut rng).public;
        let note = Note::new_with_owner(100, owner, AssetId::NATIVE.0);

        let commitment = note.commitment();
        let bytes = commitment.to_bytes();
        assert_eq!(bytes.len(), 64); // 32 for commitment + 32 for asset_id

        let hash1 = commitment.hash();
        let hash2 = commitment.hash();
        assert_eq!(hash1, hash2); // Hashing is deterministic
    }
}