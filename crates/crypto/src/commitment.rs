//! Commitment schemes for hiding values
//!
//! This module implements Pedersen commitments which are used throughout PRIVL1
//! to hide transaction amounts while maintaining homomorphic properties.

use ark_std::rand::Rng;
use serde::{Deserialize, Serialize};
use std::ops::{Add, Sub};

use crate::{Point, Result, Scalar};

/// A Pedersen commitment to a value
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Commitment {
    /// The elliptic curve point representing the commitment
    point: Point,
}

/// A homomorphic Pedersen commitment scheme
pub struct PedersenCommitment {
    /// Generator for the value component
    g: Point,
    /// Generator for the blinding factor
    h: Point,
}

impl PedersenCommitment {
    /// Create a new Pedersen commitment scheme with default generators
    pub fn new() -> Self {
        // Use standard generators for Pallas curve
        // In production, these would be generated via a transparent setup ceremony
        let g = Point::generator();

        // Generate h = hash_to_curve("PRIVL1_PEDERSEN_H")
        // For now, using a simple deterministic derivation
        let h = {
            let mut h_point = g;
            for _ in 0..128 {
                h_point = h_point + h_point; // Double the point
            }
            h_point
        };

        Self { g, h }
    }

    /// Commit to a value with a random blinding factor
    pub fn commit<R: Rng>(&self, value: u64, rng: &mut R) -> (Commitment, Scalar) {
        let blinding = Scalar::random(rng);
        let commitment = self.commit_with_blinding(value, blinding);
        (commitment, blinding)
    }

    /// Commit to a value with a specific blinding factor
    pub fn commit_with_blinding(&self, value: u64, blinding: Scalar) -> Commitment {
        // C = v*G + r*H
        let value_scalar = Scalar::from_inner(pasta_curves::pallas::Scalar::from(value));
        let point = self.g.mul(&value_scalar) + self.h.mul(&blinding);
        Commitment { point }
    }

    /// Verify that a commitment opens to a specific value and blinding factor
    pub fn verify(&self, commitment: &Commitment, value: u64, blinding: Scalar) -> bool {
        let expected = self.commit_with_blinding(value, blinding);
        commitment == &expected
    }

    /// Create a commitment to zero (useful for dummy notes)
    pub fn zero() -> Commitment {
        Commitment {
            point: Point::identity(),
        }
    }
}

impl Default for PedersenCommitment {
    fn default() -> Self {
        Self::new()
    }
}

impl Commitment {
    /// Serialize commitment to bytes
    pub fn to_bytes(&self) -> [u8; 32] {
        self.point.to_bytes()
    }

    /// Deserialize commitment from bytes
    pub fn from_bytes(bytes: &[u8; 32]) -> Result<Self> {
        Ok(Self {
            point: Point::from_bytes(bytes)?,
        })
    }

    /// Check if this is the zero commitment
    pub fn is_zero(&self) -> bool {
        self.point.is_identity()
    }
}

/// Homomorphic addition of commitments
impl Add for Commitment {
    type Output = Self;

    fn add(self, other: Self) -> Self {
        Commitment {
            point: (self.point + other.point).into(),
        }
    }
}

/// Homomorphic subtraction of commitments
impl Sub for Commitment {
    type Output = Self;

    fn sub(self, other: Self) -> Self {
        Commitment {
            point: (self.point - other.point).into(),
        }
    }
}

/// Value commitment for hiding transaction amounts
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ValueCommitment {
    /// The commitment to the value
    pub commitment: Commitment,
    /// Asset type (for multi-asset support)
    pub asset_id: [u8; 32],
}

impl ValueCommitment {
    /// Create a new value commitment
    pub fn new<R: Rng>(
        value: u64,
        asset_id: [u8; 32],
        rng: &mut R,
    ) -> (Self, Scalar) {
        let pedersen = PedersenCommitment::new();
        let (commitment, blinding) = pedersen.commit(value, rng);

        (
            Self {
                commitment,
                asset_id,
            },
            blinding,
        )
    }

    /// Verify the value commitment
    pub fn verify(&self, value: u64, blinding: Scalar) -> bool {
        let pedersen = PedersenCommitment::new();
        pedersen.verify(&self.commitment, value, blinding)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ark_std::test_rng;

    #[test]
    fn test_pedersen_commitment_basic() {
        let mut rng = test_rng();
        let pedersen = PedersenCommitment::new();

        // Commit to a value
        let value = 42u64;
        let (commitment, blinding) = pedersen.commit(value, &mut rng);

        // Verify the commitment
        assert!(pedersen.verify(&commitment, value, blinding));

        // Wrong value should fail
        assert!(!pedersen.verify(&commitment, value + 1, blinding));

        // Wrong blinding should fail
        let wrong_blinding = pallas::Scalar::rand(&mut rng);
        assert!(!pedersen.verify(&commitment, value, wrong_blinding));
    }

    #[test]
    fn test_commitment_homomorphism() {
        let mut rng = test_rng();
        let pedersen = PedersenCommitment::new();

        // Commit to two values
        let value1 = 30u64;
        let value2 = 12u64;
        let (comm1, blind1) = pedersen.commit(value1, &mut rng);
        let (comm2, blind2) = pedersen.commit(value2, &mut rng);

        // Add the commitments
        let sum_comm = comm1 + comm2;

        // Create a commitment to the sum
        let sum_value = value1 + value2;
        let sum_blinding = blind1 + blind2;
        let expected_sum = pedersen.commit_with_blinding(sum_value, sum_blinding);

        // The homomorphic property should hold
        assert_eq!(sum_comm, expected_sum);
    }

    #[test]
    fn test_zero_commitment() {
        let zero = PedersenCommitment::zero();
        assert!(zero.is_zero());

        // Adding zero should be identity
        let mut rng = test_rng();
        let pedersen = PedersenCommitment::new();
        let (comm, _) = pedersen.commit(42, &mut rng);

        let sum = comm + zero;
        assert_eq!(sum, comm);
    }

    #[test]
    fn test_value_commitment() {
        let mut rng = test_rng();
        let asset_id = [1u8; 32];
        let value = 100u64;

        let (value_comm, blinding) = ValueCommitment::new(value, asset_id, &mut rng);

        assert!(value_comm.verify(value, blinding));
        assert!(!value_comm.verify(value + 1, blinding));
    }
}