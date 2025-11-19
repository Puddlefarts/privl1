//! Scalar wrapper with proper serialization

use ark_ff::UniformRand;
use pasta_curves::group::ff::PrimeField;
use pasta_curves::pallas;
use serde::{Deserialize, Serialize};
use std::ops::{Add, Mul, Sub};

use crate::{CryptoError, Result};

/// A scalar field element (wrapper around pallas::Scalar)
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Scalar(pub(crate) pallas::Scalar);

impl Scalar {
    /// The zero scalar
    pub fn zero() -> Self {
        Self(pallas::Scalar::zero())
    }

    /// The one scalar
    pub fn one() -> Self {
        Self(pallas::Scalar::one())
    }

    /// Generate a random scalar
    pub fn random<R: rand::RngCore>(rng: &mut R) -> Self {
        // Generate random u64 values and create scalar from raw representation
        let val = [
            rng.next_u64(),
            rng.next_u64(),
            rng.next_u64(),
            rng.next_u64(),
        ];
        Self(pallas::Scalar::from_raw(val))
    }

    /// Create from bytes (little-endian)
    pub fn from_bytes(bytes: &[u8; 32]) -> Result<Self> {
        let repr: [u8; 32] = *bytes;
        Option::from(pallas::Scalar::from_repr(repr.into()))
            .ok_or(CryptoError::InvalidKey)
            .map(Self)
    }

    /// Convert to bytes (little-endian)
    pub fn to_bytes(&self) -> [u8; 32] {
        let repr = self.0.to_repr();
        repr.into()
    }

    /// Get the inner pallas::Scalar
    pub fn inner(&self) -> &pallas::Scalar {
        &self.0
    }

    /// Create from inner pallas::Scalar
    pub fn from_inner(scalar: pallas::Scalar) -> Self {
        Self(scalar)
    }
}

// Serialization
impl Serialize for Scalar {
    fn serialize<S>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        self.to_bytes().serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for Scalar {
    fn deserialize<D>(deserializer: D) -> std::result::Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let bytes = <[u8; 32]>::deserialize(deserializer)?;
        Self::from_bytes(&bytes).map_err(serde::de::Error::custom)
    }
}

// Arithmetic operations
impl Add for Scalar {
    type Output = Self;

    fn add(self, other: Self) -> Self {
        Self(self.0 + other.0)
    }
}

impl Sub for Scalar {
    type Output = Self;

    fn sub(self, other: Self) -> Self {
        Self(self.0 - other.0)
    }
}

impl Mul for Scalar {
    type Output = Self;

    fn mul(self, other: Self) -> Self {
        Self(self.0 * other.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ark_std::test_rng;

    #[test]
    fn test_scalar_serialization() {
        let mut rng = test_rng();
        let scalar = Scalar::random(&mut rng);

        let bytes = scalar.to_bytes();
        let recovered = Scalar::from_bytes(&bytes).unwrap();

        assert_eq!(scalar, recovered);
    }

    #[test]
    fn test_scalar_arithmetic() {
        let mut rng = test_rng();
        let a = Scalar::random(&mut rng);
        let b = Scalar::random(&mut rng);

        let sum = a + b;
        let expected = Scalar::from_inner(a.0 + b.0);

        assert_eq!(sum, expected);
    }
}
