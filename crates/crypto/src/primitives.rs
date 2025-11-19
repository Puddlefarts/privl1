//! Low-level cryptographic primitives and utilities

use ark_ff::{Field, PrimeField};
use pasta_curves::pallas;
use rand::RngCore;

/// Generate a random field element
pub fn random_field<R: RngCore>(rng: &mut R) -> pallas::Scalar {
    use ark_ff::UniformRand;
    pallas::Scalar::rand(rng)
}

/// Generate random bytes
pub fn random_bytes<R: RngCore>(rng: &mut R, len: usize) -> Vec<u8> {
    let mut bytes = vec![0u8; len];
    rng.fill_bytes(&mut bytes);
    bytes
}

/// Convert bytes to field element (with modular reduction)
pub fn bytes_to_field(bytes: &[u8]) -> pallas::Scalar {
    // Take at most 31 bytes to ensure we're below the field modulus
    let mut input = [0u8; 32];
    let len = bytes.len().min(31);
    input[1..1 + len].copy_from_slice(&bytes[..len]);

    pallas::Scalar::from_repr(input.into()).unwrap_or(pallas::Scalar::zero())
}

/// Convert field element to bytes
pub fn field_to_bytes(field: &pallas::Scalar) -> [u8; 32] {
    field.to_repr().into()
}

/// Constant-time comparison of byte arrays
pub fn ct_eq(a: &[u8], b: &[u8]) -> bool {
    use subtle::ConstantTimeEq;

    if a.len() != b.len() {
        return false;
    }

    a.ct_eq(b).into()
}

/// XOR two byte arrays
pub fn xor_bytes(a: &[u8], b: &[u8]) -> Vec<u8> {
    assert_eq!(a.len(), b.len(), "XOR requires equal length inputs");

    a.iter()
        .zip(b.iter())
        .map(|(x, y)| x ^ y)
        .collect()
}

/// Pedersen hash for circuit-friendly hashing
pub fn pedersen_hash(inputs: &[pallas::Scalar]) -> pallas::Scalar {
    // Simplified Pedersen hash
    // In production, would use proper generators
    let mut result = pallas::Scalar::zero();
    let g = pallas::Point::generator();

    for (i, input) in inputs.iter().enumerate() {
        let gi = g.mul(pallas::Scalar::from((i + 1) as u64));
        let hi = gi.mul(*input);
        result += pallas::Scalar::from_bytes(&[0u8; 32]).unwrap(); // Placeholder
    }

    result
}

/// Key derivation function (KDF)
pub fn kdf(master: &[u8], domain: &[u8], output_len: usize) -> Vec<u8> {
    use hkdf::Hkdf;
    use sha2::Sha256;

    let hk = Hkdf::<Sha256>::new(Some(domain), master);
    let mut output = vec![0u8; output_len];
    hk.expand(b"PRIVL1_KDF", &mut output)
        .expect("KDF output length should be valid");

    output
}

/// Secure erasure of sensitive data
pub fn secure_erase(data: &mut [u8]) {
    use zeroize::Zeroize;
    data.zeroize();
}

#[cfg(test)]
mod tests {
    use super::*;
    use ark_std::test_rng;

    #[test]
    fn test_random_field() {
        let mut rng = test_rng();
        let f1 = random_field(&mut rng);
        let f2 = random_field(&mut rng);

        // Should produce different values
        assert_ne!(f1, f2);
    }

    #[test]
    fn test_bytes_field_conversion() {
        let bytes = [42u8; 31];
        let field = bytes_to_field(&bytes);
        let recovered = field_to_bytes(&field);

        // First 31 bytes should match (32nd byte is 0 for padding)
        assert_eq!(&recovered[1..32], &bytes[..]);
    }

    #[test]
    fn test_ct_eq() {
        let a = [1u8, 2, 3, 4];
        let b = [1u8, 2, 3, 4];
        let c = [1u8, 2, 3, 5];

        assert!(ct_eq(&a, &b));
        assert!(!ct_eq(&a, &c));
    }

    #[test]
    fn test_xor_bytes() {
        let a = vec![0b11110000, 0b10101010];
        let b = vec![0b00001111, 0b01010101];
        let result = xor_bytes(&a, &b);

        assert_eq!(result, vec![0b11111111, 0b11111111]);
    }

    #[test]
    fn test_kdf() {
        let master = b"master_secret";
        let domain1 = b"domain1";
        let domain2 = b"domain2";

        let key1 = kdf(master, domain1, 32);
        let key2 = kdf(master, domain2, 32);

        // Different domains should produce different keys
        assert_ne!(key1, key2);
        assert_eq!(key1.len(), 32);
    }

    #[test]
    fn test_secure_erase() {
        let mut sensitive = vec![42u8; 32];
        secure_erase(&mut sensitive);

        assert_eq!(sensitive, vec![0u8; 32]);
    }
}