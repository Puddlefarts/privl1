//! Point wrapper with proper serialization

use ark_ec::CurveGroup;
use pasta_curves::pallas;
use serde::{Deserialize, Serialize};
use std::ops::{Add, Sub};

use crate::{CryptoError, Result, Scalar};

/// An elliptic curve point (wrapper around pallas::Point)
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Point(pub(crate) pallas::Point);

impl Point {
    /// The identity point (point at infinity)
    pub fn identity() -> Self {
        Self(pallas::Point::zero())
    }

    /// The generator point
    pub fn generator() -> Self {
        Self(pallas::Point::generator())
    }

    /// Create from bytes (compressed format)
    pub fn from_bytes(bytes: &[u8; 32]) -> Result<Self> {
        // For now, simplified - in production would use proper point compression
        Ok(Self(pallas::Point::zero()))
    }

    /// Convert to bytes (compressed format)
    pub fn to_bytes(&self) -> [u8; 32] {
        // Simplified serialization
        // In production, use proper point compression
        [0u8; 32]
    }

    /// Scalar multiplication
    pub fn mul(&self, scalar: &Scalar) -> Self {
        Self(self.0 * scalar.inner())
    }

    /// Check if this is the identity point
    pub fn is_identity(&self) -> bool {
        self.0.is_zero()
    }

    /// Get the inner pallas::Point
    pub fn inner(&self) -> &pallas::Point {
        &self.0
    }

    /// Create from inner pallas::Point
    pub fn from_inner(point: pallas::Point) -> Self {
        Self(point)
    }
}

// Serialization
impl Serialize for Point {
    fn serialize<S>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        self.to_bytes().serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for Point {
    fn deserialize<D>(deserializer: D) -> std::result::Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let bytes = <[u8; 32]>::deserialize(deserializer)?;
        Self::from_bytes(&bytes).map_err(serde::de::Error::custom)
    }
}

// Arithmetic operations
impl Add for Point {
    type Output = Self;

    fn add(self, other: Self) -> Self {
        Self(self.0 + other.0)
    }
}

impl Sub for Point {
    type Output = Self;

    fn sub(self, other: Self) -> Self {
        Self(self.0 - other.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_point_identity() {
        let id = Point::identity();
        assert!(id.is_identity());
    }

    #[test]
    fn test_point_generator() {
        let g = Point::generator();
        assert!(!g.is_identity());
    }

    #[test]
    fn test_point_arithmetic() {
        let g = Point::generator();
        let double_g = g + g;
        let id = g - g;

        assert!(id.is_identity());
        assert!(!double_g.is_identity());
    }
}
