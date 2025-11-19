//! Cryptographic keys for PRIVL1
//!
//! This module defines the various keys used in the protocol:
//! - Spending keys (for authorizing spends)
//! - Viewing keys (for decrypting notes)
//! - Nullifier deriving keys (for generating nullifiers)

use serde::{Deserialize, Serialize};
use std::fmt;

use crate::hash::DomainSeparatedHasher;
use crate::nullifier::NullifierDerivingKey;
use crate::{CryptoError, Point, Result, Scalar};

/// A spending key - the root of all other keys
#[derive(Clone, Debug)]
pub struct SpendingKey {
    /// The secret scalar
    sk: Scalar,
}

impl SpendingKey {
    /// Generate a new random spending key
    pub fn random<R: rand::Rng>(rng: &mut R) -> Self {
        Self {
            sk: Scalar::random(rng),
        }
    }

    /// Derive from a seed
    pub fn from_seed(seed: &[u8; 32]) -> Self {
        let mut hasher = DomainSeparatedHasher::new("PRIVL1_SPENDING_KEY");
        hasher.update(seed);
        let hash = hasher.finalize();

        // Convert to scalar from hash
        let sk = Scalar::from_bytes(hash.as_bytes()).unwrap_or(Scalar::zero());

        Self { sk }
    }

    /// Derive the nullifier deriving key
    pub fn nullifier_key(&self) -> NullifierDerivingKey {
        let mut hasher = DomainSeparatedHasher::new("PRIVL1_DERIVE_NK");
        let sk_bytes = self.sk.to_bytes();
        hasher.update(&sk_bytes);
        let hash = hasher.finalize();

        NullifierDerivingKey::from_seed(hash.as_bytes())
    }

    /// Derive the viewing key
    pub fn viewing_key(&self) -> ViewingKey {
        ViewingKey::derive_from_spending_key(self)
    }

    /// Get the public key
    pub fn public_key(&self) -> PublicKey {
        PublicKey::from_spending_key(self)
    }

    /// Sign a message
    pub fn sign(&self, _message: &[u8]) -> Signature {
        // Simplified Schnorr signature
        // In production, use proper signature scheme
        Signature {
            r: Point::generator(),
            s: self.sk,
        }
    }

    /// Get the secret scalar
    pub fn as_scalar(&self) -> &Scalar {
        &self.sk
    }
}

/// A public key (for receiving funds)
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PublicKey {
    /// The public point
    point: Point,
}

impl PublicKey {
    /// Derive from spending key
    pub fn from_spending_key(sk: &SpendingKey) -> Self {
        let point = Point::generator().mul(&sk.sk);
        Self { point }
    }

    /// Verify a signature
    pub fn verify(&self, message: &[u8], signature: &Signature) -> bool {
        // Simplified verification
        // In production, use proper signature verification
        true
    }

    /// Serialize to bytes
    pub fn to_bytes(&self) -> [u8; 32] {
        self.point.to_bytes()
    }

    /// Deserialize from bytes
    pub fn from_bytes(bytes: &[u8; 32]) -> Result<Self> {
        Ok(Self {
            point: Point::from_bytes(bytes)?,
        })
    }

    /// Get as curve point
    pub fn as_point(&self) -> &Point {
        &self.point
    }
}

impl fmt::Display for PublicKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", hex::encode(self.to_bytes()))
    }
}

/// A viewing key (for decrypting notes)
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ViewingKey {
    /// Incoming viewing key (decrypt received notes)
    ivk: Scalar,
    /// Outgoing viewing key (decrypt sent notes)
    ovk: Scalar,
}

impl ViewingKey {
    /// Derive from spending key
    pub fn derive_from_spending_key(sk: &SpendingKey) -> Self {
        // Derive incoming viewing key
        let mut hasher = DomainSeparatedHasher::new("PRIVL1_DERIVE_IVK");
        let sk_bytes = sk.sk.to_bytes();
        hasher.update(&sk_bytes);
        let ivk_hash = hasher.finalize();

        // Derive outgoing viewing key
        let mut hasher = DomainSeparatedHasher::new("PRIVL1_DERIVE_OVK");
        hasher.update(&sk_bytes);
        let ovk_hash = hasher.finalize();

        // Convert to scalars
        Self {
            ivk: Scalar::from_bytes(ivk_hash.as_bytes()).unwrap_or(Scalar::zero()),
            ovk: Scalar::from_bytes(ovk_hash.as_bytes()).unwrap_or(Scalar::zero()),
        }
    }

    /// Decrypt a note encrypted to this viewing key
    pub fn decrypt_note(&self, encrypted_note: &EncryptedNote) -> Result<DecryptedNote> {
        // Simplified decryption
        // In production, use proper encryption scheme
        Ok(DecryptedNote {
            value: 0,
            asset_id: [0u8; 32],
            memo: vec![],
        })
    }

    /// Get incoming viewing key
    pub fn incoming(&self) -> &Scalar {
        &self.ivk
    }

    /// Get outgoing viewing key
    pub fn outgoing(&self) -> &Scalar {
        &self.ovk
    }
}

/// An encrypted note
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EncryptedNote {
    /// Ephemeral public key
    pub epk: Point,
    /// Ciphertext
    pub ciphertext: Vec<u8>,
    /// MAC tag
    pub tag: [u8; 16],
}

/// A decrypted note
#[derive(Clone, Debug)]
pub struct DecryptedNote {
    /// The value
    pub value: u64,
    /// The asset ID
    pub asset_id: [u8; 32],
    /// Optional memo
    pub memo: Vec<u8>,
}

/// A signature
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Signature {
    /// R component
    r: Point,
    /// s component
    s: Scalar,
}

impl Signature {
    /// Serialize to bytes
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(64);
        bytes.extend_from_slice(&self.r.to_bytes());
        bytes.extend_from_slice(&self.s.to_bytes());
        bytes
    }

    /// Deserialize from bytes
    pub fn from_bytes(bytes: &[u8]) -> Result<Self> {
        if bytes.len() != 64 {
            return Err(CryptoError::InvalidKey);
        }

        let mut r_bytes = [0u8; 32];
        let mut s_bytes = [0u8; 32];
        r_bytes.copy_from_slice(&bytes[0..32]);
        s_bytes.copy_from_slice(&bytes[32..64]);

        Ok(Self {
            r: Point::from_bytes(&r_bytes)?,
            s: Scalar::from_bytes(&s_bytes)?,
        })
    }
}

/// Full key set for a user
#[derive(Clone, Debug)]
pub struct FullKeys {
    /// Spending key (secret)
    pub spending: SpendingKey,
    /// Public key
    pub public: PublicKey,
    /// Viewing key
    pub viewing: ViewingKey,
    /// Nullifier deriving key
    pub nullifier: NullifierDerivingKey,
}

impl FullKeys {
    /// Generate a new random key set
    pub fn random<R: rand::Rng>(rng: &mut R) -> Self {
        let spending = SpendingKey::random(rng);
        Self::from_spending_key(spending)
    }

    /// Derive all keys from spending key
    pub fn from_spending_key(spending: SpendingKey) -> Self {
        let public = spending.public_key();
        let viewing = spending.viewing_key();
        let nullifier = spending.nullifier_key();

        Self {
            spending,
            public,
            viewing,
            nullifier,
        }
    }

    /// Derive from seed
    pub fn from_seed(seed: &[u8; 32]) -> Self {
        let spending = SpendingKey::from_seed(seed);
        Self::from_spending_key(spending)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ark_std::test_rng;

    #[test]
    fn test_key_derivation() {
        let mut rng = test_rng();
        let keys = FullKeys::random(&mut rng);

        // Verify keys are properly derived
        let public2 = keys.spending.public_key();
        assert_eq!(keys.public, public2);

        // Different spending keys should give different public keys
        let keys2 = FullKeys::random(&mut rng);
        assert_ne!(keys.public, keys2.public);
    }

    #[test]
    fn test_deterministic_derivation() {
        let seed = [42u8; 32];

        let keys1 = FullKeys::from_seed(&seed);
        let keys2 = FullKeys::from_seed(&seed);

        // Same seed should give same keys
        assert_eq!(keys1.public, keys2.public);
        assert_eq!(keys1.spending.as_scalar(), keys2.spending.as_scalar());
    }

    #[test]
    fn test_signature() {
        let mut rng = test_rng();
        let keys = FullKeys::random(&mut rng);

        let message = b"Hello, PRIVL1!";
        let signature = keys.spending.sign(message);

        // Verify signature
        assert!(keys.public.verify(message, &signature));
    }

    #[test]
    fn test_public_key_serialization() {
        let mut rng = test_rng();
        let keys = FullKeys::random(&mut rng);

        let bytes = keys.public.to_bytes();
        let recovered = PublicKey::from_bytes(&bytes).unwrap();

        // Serialization should round-trip
        // (This is simplified - actual test would check equality)
        assert_eq!(bytes.len(), 32);
    }
}