//! Hash functions optimized for zero-knowledge circuits
//!
//! This module provides multiple hash function implementations:
//! - Blake3: Fast, general-purpose hashing
//! - Poseidon: ZK-friendly algebraic hash function

use blake3::Hasher as Blake3Hasher;
use pasta_curves::pallas;
use serde::{Deserialize, Serialize};
use std::fmt;

use crate::Result;

/// Trait for hash functions
pub trait Hasher: Clone {
    type Output: AsRef<[u8]> + Clone;

    /// Create a new hasher
    fn new() -> Self;

    /// Update the hasher with data
    fn update(&mut self, data: &[u8]);

    /// Finalize and return the hash
    fn finalize(self) -> Self::Output;

    /// Convenience function to hash data in one call
    fn hash(data: &[u8]) -> Self::Output {
        let mut hasher = Self::new();
        hasher.update(data);
        hasher.finalize()
    }
}

/// A Blake3 hash (256 bits)
#[derive(Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Blake3Hash([u8; 32]);

impl Blake3Hash {
    /// Create a new Blake3 hash from bytes
    pub fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    /// Get the hash as bytes
    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    /// Hash some data using Blake3
    pub fn hash(data: &[u8]) -> Self {
        Blake3::hash(data)
    }
}

impl fmt::Debug for Blake3Hash {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Blake3Hash({})", hex::encode(&self.0[..8]))
    }
}

impl fmt::Display for Blake3Hash {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", hex::encode(&self.0))
    }
}

impl AsRef<[u8]> for Blake3Hash {
    fn as_ref(&self) -> &[u8] {
        &self.0
    }
}

impl From<[u8; 32]> for Blake3Hash {
    fn from(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }
}

/// Blake3 hasher implementation
#[derive(Clone)]
pub struct Blake3 {
    hasher: Blake3Hasher,
}

impl Hasher for Blake3 {
    type Output = Blake3Hash;

    fn new() -> Self {
        Self {
            hasher: Blake3Hasher::new(),
        }
    }

    fn update(&mut self, data: &[u8]) {
        self.hasher.update(data);
    }

    fn finalize(self) -> Self::Output {
        let hash = self.hasher.finalize();
        Blake3Hash(*hash.as_bytes())
    }
}

/// Poseidon hash (ZK-friendly)
#[derive(Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct PoseidonHash(pallas::Base);

impl PoseidonHash {
    /// Create from a field element
    pub fn from_field(field: pallas::Base) -> Self {
        Self(field)
    }

    /// Get as field element
    pub fn to_field(&self) -> pallas::Base {
        self.0
    }

    /// Hash two field elements (2-to-1 hash)
    pub fn hash_two(left: pallas::Base, right: pallas::Base) -> Self {
        // Simplified Poseidon permutation
        // In production, this would use the full Poseidon specification
        // with proper round constants and S-box operations

        // Placeholder: simple combination
        let sum = left + right;
        let squared = sum.square();
        let cubed = squared * sum;

        Self(cubed)
    }

    /// Hash multiple field elements
    pub fn hash_fields(fields: &[pallas::Base]) -> Self {
        if fields.is_empty() {
            return Self(pallas::Base::zero());
        }

        let mut result = fields[0];
        for field in &fields[1..] {
            result = Self::hash_two(result, *field).0;
        }

        Self(result)
    }

    /// Convert bytes to field elements and hash
    pub fn hash_bytes(data: &[u8]) -> Self {
        // Convert bytes to field elements (32 bytes per element)
        let mut fields = Vec::new();

        for chunk in data.chunks(31) {
            // Use 31 bytes to ensure we're below the field modulus
            let mut bytes = [0u8; 32];
            bytes[1..1 + chunk.len()].copy_from_slice(chunk);
            let field = pallas::Base::from_repr(bytes.into()).unwrap_or(pallas::Base::zero());
            fields.push(field);
        }

        Self::hash_fields(&fields)
    }
}

impl fmt::Debug for PoseidonHash {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "PoseidonHash({:?})", self.0)
    }
}

impl AsRef<[u8]> for PoseidonHash {
    fn as_ref(&self) -> &[u8] {
        // Convert field element to bytes
        // This is a simplified version
        &[]
    }
}

/// Generic hash type that can use different hash functions
#[derive(Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Hash {
    Blake3(Blake3Hash),
    Poseidon(PoseidonHash),
}

impl Hash {
    /// Create a Blake3 hash
    pub fn blake3(data: &[u8]) -> Self {
        Hash::Blake3(Blake3Hash::hash(data))
    }

    /// Create a Poseidon hash
    pub fn poseidon(data: &[u8]) -> Self {
        Hash::Poseidon(PoseidonHash::hash_bytes(data))
    }

    /// Get the hash as bytes (if possible)
    pub fn to_bytes(&self) -> Vec<u8> {
        match self {
            Hash::Blake3(h) => h.0.to_vec(),
            Hash::Poseidon(h) => {
                // Convert field element to bytes
                vec![]
            }
        }
    }
}

impl fmt::Debug for Hash {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Hash::Blake3(h) => write!(f, "{:?}", h),
            Hash::Poseidon(h) => write!(f, "{:?}", h),
        }
    }
}

/// Domain separation for different hash contexts
pub struct DomainSeparatedHasher {
    domain: &'static str,
    hasher: Blake3,
}

impl DomainSeparatedHasher {
    /// Create a new domain-separated hasher
    pub fn new(domain: &'static str) -> Self {
        let mut hasher = Blake3::new();
        hasher.update(domain.as_bytes());
        hasher.update(&[0u8]); // Null separator

        Self { domain, hasher }
    }

    /// Update with data
    pub fn update(&mut self, data: &[u8]) {
        self.hasher.update(data);
    }

    /// Finalize the hash
    pub fn finalize(self) -> Blake3Hash {
        self.hasher.finalize()
    }
}

/// Hash function for Merkle trees (Poseidon 2-to-1)
pub fn merkle_hash(left: &[u8; 32], right: &[u8; 32]) -> [u8; 32] {
    // For ZK circuits, we'd use Poseidon
    // For now, using Blake3 for simplicity
    let mut hasher = Blake3::new();
    hasher.update(left);
    hasher.update(right);
    let hash = hasher.finalize();
    *hash.as_bytes()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_blake3_hash() {
        let data = b"Hello, PRIVL1!";
        let hash1 = Blake3Hash::hash(data);
        let hash2 = Blake3Hash::hash(data);

        // Deterministic
        assert_eq!(hash1, hash2);

        // Different data produces different hash
        let hash3 = Blake3Hash::hash(b"Different data");
        assert_ne!(hash1, hash3);
    }

    #[test]
    fn test_poseidon_hash() {
        let data = b"Test data";
        let hash1 = PoseidonHash::hash_bytes(data);

        // Test field element hashing
        let field1 = pallas::Base::from(42u64);
        let field2 = pallas::Base::from(123u64);
        let hash2 = PoseidonHash::hash_two(field1, field2);

        // Should be deterministic
        let hash3 = PoseidonHash::hash_two(field1, field2);
        assert_eq!(hash2, hash3);

        // Different inputs produce different outputs
        let hash4 = PoseidonHash::hash_two(field2, field1);
        assert_ne!(hash2, hash4); // Order matters
    }

    #[test]
    fn test_domain_separated_hasher() {
        let data = b"sensitive data";

        let mut hasher1 = DomainSeparatedHasher::new("PRIVL1_NOTE");
        hasher1.update(data);
        let hash1 = hasher1.finalize();

        let mut hasher2 = DomainSeparatedHasher::new("PRIVL1_NULLIFIER");
        hasher2.update(data);
        let hash2 = hasher2.finalize();

        // Same data with different domains should produce different hashes
        assert_ne!(hash1, hash2);
    }

    #[test]
    fn test_merkle_hash() {
        let left = [1u8; 32];
        let right = [2u8; 32];

        let hash1 = merkle_hash(&left, &right);
        let hash2 = merkle_hash(&left, &right);

        // Deterministic
        assert_eq!(hash1, hash2);

        // Order matters
        let hash3 = merkle_hash(&right, &left);
        assert_ne!(hash1, hash3);
    }
}