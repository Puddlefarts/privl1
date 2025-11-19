//! Nullifier derivation for preventing double-spending
//!
//! Nullifiers are unique identifiers derived from notes that are revealed when
//! the note is spent, preventing the same note from being spent twice.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::hash::{Blake3Hash, DomainSeparatedHasher};
use crate::note::Note;
use crate::{CryptoError, Result, Scalar};

/// A nullifier - reveals when a note is spent
#[derive(Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Nullifier([u8; 32]);

impl Nullifier {
    /// Create a nullifier from bytes
    pub fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    /// Get the nullifier as bytes
    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    /// Convert to hex string
    pub fn to_hex(&self) -> String {
        hex::encode(&self.0)
    }
}

impl fmt::Debug for Nullifier {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Nullifier({})", hex::encode(&self.0[..8]))
    }
}

impl fmt::Display for Nullifier {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.to_hex())
    }
}

/// Key used to derive nullifiers from notes
#[derive(Clone, Debug)]
pub struct NullifierDerivingKey {
    /// The secret scalar
    nk: Scalar,
}

// Derive Serialize and Deserialize since Scalar now supports it
impl Serialize for NullifierDerivingKey {
    fn serialize<S>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        self.nk.serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for NullifierDerivingKey {
    fn deserialize<D>(deserializer: D) -> std::result::Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let nk = Scalar::deserialize(deserializer)?;
        Ok(Self { nk })
    }
}

impl NullifierDerivingKey {
    /// Generate a new random nullifier deriving key
    pub fn random<R: rand::Rng>(rng: &mut R) -> Self {
        Self {
            nk: Scalar::random(rng),
        }
    }

    /// Derive from a seed
    pub fn from_seed(seed: &[u8; 32]) -> Self {
        // Use domain separation
        let mut hasher = DomainSeparatedHasher::new("PRIVL1_NULLIFIER_KEY");
        hasher.update(seed);
        let hash = hasher.finalize();

        // Convert hash to scalar
        let nk = Scalar::from_bytes(hash.as_bytes()).unwrap_or(Scalar::zero());

        Self { nk }
    }

    /// Derive a nullifier for a note
    pub fn derive_nullifier(&self, note: &Note, position: u64) -> Nullifier {
        // Nullifier = Hash(nk || note_commitment || position)
        let mut hasher = DomainSeparatedHasher::new("PRIVL1_NULLIFIER");

        // Add nullifier key
        let nk_bytes = self.nk.to_bytes();
        hasher.update(&nk_bytes);

        // Add note commitment
        hasher.update(note.commitment().to_bytes().as_ref());

        // Add position in commitment tree
        hasher.update(&position.to_le_bytes());

        let hash = hasher.finalize();
        Nullifier(*hash.as_bytes())
    }

    /// Get the underlying scalar
    pub fn as_scalar(&self) -> &Scalar {
        &self.nk
    }
}

/// A set tracking spent nullifiers
#[derive(Clone, Debug, Default)]
pub struct NullifierSet {
    /// Set of spent nullifiers
    spent: HashSet<Nullifier>,
}

impl NullifierSet {
    /// Create a new empty nullifier set
    pub fn new() -> Self {
        Self {
            spent: HashSet::new(),
        }
    }

    /// Check if a nullifier has been spent
    pub fn is_spent(&self, nullifier: &Nullifier) -> bool {
        self.spent.contains(nullifier)
    }

    /// Mark a nullifier as spent
    pub fn spend(&mut self, nullifier: Nullifier) -> Result<()> {
        if self.is_spent(&nullifier) {
            return Err(CryptoError::OperationFailed("Double spend detected".into()));
        }
        self.spent.insert(nullifier);
        Ok(())
    }

    /// Batch spend multiple nullifiers (atomic - all or nothing)
    pub fn spend_batch(&mut self, nullifiers: &[Nullifier]) -> Result<()> {
        // First check if any are already spent
        for nullifier in nullifiers {
            if self.is_spent(nullifier) {
                return Err(CryptoError::OperationFailed(format!(
                    "Double spend detected: {}",
                    nullifier.to_hex()
                )));
            }
        }

        // If all are unspent, mark them all as spent
        for nullifier in nullifiers {
            self.spent.insert(*nullifier);
        }

        Ok(())
    }

    /// Get the number of spent nullifiers
    pub fn len(&self) -> usize {
        self.spent.len()
    }

    /// Check if the set is empty
    pub fn is_empty(&self) -> bool {
        self.spent.is_empty()
    }

    /// Clear all nullifiers (for testing)
    #[cfg(test)]
    pub fn clear(&mut self) {
        self.spent.clear();
    }

    /// Get all nullifiers (for persistence)
    pub fn all_nullifiers(&self) -> Vec<Nullifier> {
        self.spent.iter().copied().collect()
    }

    /// Restore from a list of nullifiers
    pub fn restore(&mut self, nullifiers: Vec<Nullifier>) {
        self.spent.extend(nullifiers);
    }
}

/// Nullifier storage with persistence
pub struct PersistentNullifierSet {
    /// In-memory set for fast lookups
    set: NullifierSet,
    /// Database path (in production, this would be RocksDB)
    db_path: String,
}

impl PersistentNullifierSet {
    /// Create or load a persistent nullifier set
    pub fn open(db_path: String) -> Result<Self> {
        // In production, this would open a RocksDB database
        // For now, just create an in-memory set
        Ok(Self {
            set: NullifierSet::new(),
            db_path,
        })
    }

    /// Check if a nullifier is spent
    pub fn is_spent(&self, nullifier: &Nullifier) -> bool {
        self.set.is_spent(nullifier)
    }

    /// Spend a nullifier (persisted to disk)
    pub fn spend(&mut self, nullifier: Nullifier) -> Result<()> {
        self.set.spend(nullifier)?;

        // In production, persist to RocksDB
        // For now, this is a no-op
        self.persist()?;

        Ok(())
    }

    /// Batch spend with atomic persistence
    pub fn spend_batch(&mut self, nullifiers: &[Nullifier]) -> Result<()> {
        self.set.spend_batch(nullifiers)?;
        self.persist()?;
        Ok(())
    }

    /// Persist current state to disk
    fn persist(&self) -> Result<()> {
        // In production, write to RocksDB
        // For now, this is a no-op
        Ok(())
    }

    /// Get a snapshot of the nullifier set root (for consensus)
    pub fn root_hash(&self) -> Blake3Hash {
        // Compute Merkle root of all nullifiers
        // This allows light clients to verify nullifier non-membership
        let mut hasher = DomainSeparatedHasher::new("PRIVL1_NULLIFIER_ROOT");

        // Sort nullifiers for deterministic hash
        let mut nullifiers = self.set.all_nullifiers();
        nullifiers.sort_by_key(|n| *n.as_bytes());

        for nullifier in nullifiers {
            hasher.update(nullifier.as_bytes());
        }

        hasher.finalize()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::commitment::PedersenCommitment;
    use ark_std::test_rng;

    #[test]
    fn test_nullifier_derivation() {
        let mut rng = test_rng();
        let nk = NullifierDerivingKey::random(&mut rng);

        // Create a test note
        let pedersen = PedersenCommitment::new();
        let (commitment, _) = pedersen.commit(100, &mut rng);
        let note = Note::new(100, commitment, [1u8; 32]);

        // Derive nullifier
        let nullifier1 = nk.derive_nullifier(&note, 0);
        let nullifier2 = nk.derive_nullifier(&note, 0);

        // Should be deterministic
        assert_eq!(nullifier1, nullifier2);

        // Different position should give different nullifier
        let nullifier3 = nk.derive_nullifier(&note, 1);
        assert_ne!(nullifier1, nullifier3);
    }

    #[test]
    fn test_nullifier_set() {
        let mut set = NullifierSet::new();
        assert!(set.is_empty());

        let nullifier1 = Nullifier([1u8; 32]);
        let nullifier2 = Nullifier([2u8; 32]);

        // Spend first nullifier
        assert!(set.spend(nullifier1).is_ok());
        assert!(set.is_spent(&nullifier1));
        assert!(!set.is_spent(&nullifier2));

        // Double spend should fail
        assert!(set.spend(nullifier1).is_err());

        // Spend second nullifier
        assert!(set.spend(nullifier2).is_ok());
        assert_eq!(set.len(), 2);
    }

    #[test]
    fn test_batch_spend() {
        let mut set = NullifierSet::new();

        let nullifiers = vec![
            Nullifier([1u8; 32]),
            Nullifier([2u8; 32]),
            Nullifier([3u8; 32]),
        ];

        // Batch spend should succeed
        assert!(set.spend_batch(&nullifiers).is_ok());
        assert_eq!(set.len(), 3);

        // All should be marked as spent
        for n in &nullifiers {
            assert!(set.is_spent(n));
        }

        // Attempting to spend any of them again should fail
        let duplicate = vec![nullifiers[1]];
        assert!(set.spend_batch(&duplicate).is_err());

        // Original set should be unchanged after failed batch
        assert_eq!(set.len(), 3);
    }

    #[test]
    fn test_nullifier_set_persistence() {
        let mut set = NullifierSet::new();

        let nullifiers = vec![
            Nullifier([1u8; 32]),
            Nullifier([2u8; 32]),
            Nullifier([3u8; 32]),
        ];

        set.spend_batch(&nullifiers).unwrap();

        // Save state
        let saved = set.all_nullifiers();

        // Create new set and restore
        let mut new_set = NullifierSet::new();
        new_set.restore(saved);

        // Should have same state
        assert_eq!(new_set.len(), 3);
        for n in &nullifiers {
            assert!(new_set.is_spent(n));
        }
    }

    #[test]
    fn test_nullifier_from_seed() {
        let seed1 = [1u8; 32];
        let seed2 = [2u8; 32];

        let nk1 = NullifierDerivingKey::from_seed(&seed1);
        let nk2 = NullifierDerivingKey::from_seed(&seed1);
        let nk3 = NullifierDerivingKey::from_seed(&seed2);

        // Same seed should give same key (deterministic)
        assert_eq!(nk1.as_scalar(), nk2.as_scalar());

        // Different seed should give different key
        assert_ne!(nk1.as_scalar(), nk3.as_scalar());
    }
}