# PRIVL1 Cryptographic Library

Core cryptographic primitives for the PRIVL1 zero-knowledge privacy blockchain.

## Features

### ✅ Implemented

- **Pedersen Commitments** (`commitment.rs`)
  - Homomorphic value hiding
  - Support for multi-asset commitments
  - Binding and hiding properties

- **Merkle Trees** (`merkle.rs`)
  - Incremental append-only tree
  - Efficient frontier-based updates
  - Merkle proof generation and verification
  - Batch operations support

- **Nullifiers** (`nullifier.rs`)
  - Double-spend prevention
  - Deterministic derivation from notes
  - Nullifier set management
  - Persistent storage support

- **Note Model** (`note.rs`)
  - UTXO-like private notes
  - Note commitments and encryption
  - Multi-asset support
  - Dummy notes for transaction padding

- **Key Management** (`keys.rs`)
  - Hierarchical key derivation
  - Spending keys (authorize spends)
  - Viewing keys (decrypt notes)
  - Nullifier deriving keys
  - Public keys for receiving

- **Hash Functions** (`hash.rs`)
  - Blake3 for general hashing
  - Poseidon for ZK circuits
  - Domain-separated hashing
  - Merkle tree hashing

- **Proof Structures** (`proof.rs`)
  - Halo2 proof abstractions
  - Transaction proof bundles
  - Proof aggregation support
  - Verification key management

## Usage

```rust
use privl1_crypto::{
    PedersenCommitment,
    IncrementalMerkleTree,
    Note,
    FullKeys,
};
use ark_std::test_rng;

// Generate keys
let mut rng = test_rng();
let keys = FullKeys::random(&mut rng);

// Create a note
let note = Note::new_with_owner(
    100,                    // value
    keys.public,           // owner
    AssetId::NATIVE.0,     // asset type
);

// Compute commitment
let commitment = note.commitment();

// Add to Merkle tree
let mut tree = IncrementalMerkleTree::new();
let position = tree.append(commitment.hash().as_bytes());

// Generate proof of inclusion
let proof = tree.prove(position)?;

// Derive nullifier (when spending)
let nullifier = keys.nullifier.derive_nullifier(&note, position);
```

## Architecture

The crypto crate is designed with the following principles:

1. **Zero-Knowledge Ready**: All primitives are designed to be efficient in ZK circuits
2. **Privacy First**: Default to hiding information, reveal only what's necessary
3. **Composable**: Each module can be used independently or together
4. **Performance**: Optimized for both native execution and circuit constraints

## Testing

```bash
# Run all tests
cargo test -p privl1-crypto

# Run with verbose output
cargo test -p privl1-crypto -- --nocapture

# Run benchmarks (when implemented)
cargo bench -p privl1-crypto
```

## Security Considerations

- All random values use cryptographically secure RNGs
- Constant-time operations where applicable
- Secure erasure of sensitive data (via zeroize)
- Domain separation for all hash functions
- No trusted setup required (Halo2)

## Dependencies

- `pasta_curves` - Pallas/Vesta curves optimized for recursion
- `halo2_proofs` - Zero-knowledge proof system
- `blake3` - Fast cryptographic hash
- `ark-*` - Arkworks ecosystem for field/curve arithmetic
- `zeroize` - Secure memory erasure

## Known Issues

- Some serialization traits need custom implementation for pasta_curves types
- Large array serialization (>32 bytes) requires wrapper types
- Some API refinements needed for production use

## Future Improvements

- [ ] Add benchmarks for all operations
- [ ] Implement batch verification optimizations
- [ ] Add more comprehensive property tests
- [ ] Optimize Merkle tree for circuit use
- [ ] Add support for recursive proofs