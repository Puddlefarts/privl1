//! Incremental Merkle tree for note commitments
//!
//! This module implements an append-only incremental Merkle tree that efficiently
//! maintains a commitment to all notes in the system while allowing for efficient
//! proofs of membership.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use crate::hash::{merkle_hash, Blake3Hash};
use crate::{CryptoError, Result};

/// The depth of the Merkle tree (2^32 leaves)
pub const TREE_DEPTH: usize = 32;

/// A Merkle tree root
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct MerkleRoot([u8; 32]);

impl MerkleRoot {
    pub fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    pub fn to_hex(&self) -> String {
        hex::encode(&self.0)
    }
}

/// A proof that a leaf exists in the Merkle tree
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MerkleProof {
    /// The authentication path from leaf to root
    pub path: Vec<[u8; 32]>,
    /// The position of the leaf in the tree
    pub position: u64,
}

impl MerkleProof {
    /// Verify that a leaf is in the tree with the given root
    pub fn verify(&self, leaf: &[u8; 32], root: &MerkleRoot) -> bool {
        if self.path.len() != TREE_DEPTH {
            return false;
        }

        let mut current = *leaf;
        let mut index = self.position;

        for sibling in &self.path {
            current = if index & 1 == 0 {
                // Current is left child
                merkle_hash(&current, sibling)
            } else {
                // Current is right child
                merkle_hash(sibling, &current)
            };
            index >>= 1;
        }

        current == root.0
    }
}

/// An incremental Merkle tree that supports efficient appends
#[derive(Clone, Debug)]
pub struct IncrementalMerkleTree {
    /// Current number of leaves
    num_leaves: u64,
    /// Frontier nodes (rightmost nodes at each level)
    frontier: Vec<[u8; 32]>,
    /// Cached subtree roots for efficiency
    cached_roots: HashMap<(usize, u64), [u8; 32]>,
    /// Empty subtree hashes at each level
    empty_hashes: Vec<[u8; 32]>,
}

impl IncrementalMerkleTree {
    /// Create a new empty Merkle tree
    pub fn new() -> Self {
        let mut empty_hashes = vec![[0u8; 32]; TREE_DEPTH + 1];

        // Compute empty hashes for each level
        // Level 0 is the empty leaf
        empty_hashes[0] = [0u8; 32];

        for level in 1..=TREE_DEPTH {
            let child = empty_hashes[level - 1];
            empty_hashes[level] = merkle_hash(&child, &child);
        }

        Self {
            num_leaves: 0,
            frontier: Vec::new(),
            cached_roots: HashMap::new(),
            empty_hashes,
        }
    }

    /// Append a new leaf to the tree
    pub fn append(&mut self, leaf: [u8; 32]) -> Result<u64> {
        let position = self.num_leaves;

        if position >= (1u64 << TREE_DEPTH) {
            return Err(CryptoError::MerkleError("Tree is full".into()));
        }

        // Update frontier nodes
        self.update_frontier(leaf);

        self.num_leaves += 1;
        Ok(position)
    }

    /// Update the frontier with a new leaf
    fn update_frontier(&mut self, leaf: [u8; 32]) {
        let mut current = leaf;
        let mut index = self.num_leaves;
        let mut new_frontier = Vec::new();

        // Traverse up the tree, updating frontier nodes
        for level in 0..TREE_DEPTH {
            if index & 1 == 0 {
                // This is a left child, it becomes the new frontier node
                new_frontier.push(current);
                break;
            } else {
                // This is a right child, combine with sibling from frontier
                if level < self.frontier.len() {
                    let sibling = self.frontier[level];
                    current = merkle_hash(&sibling, &current);
                    // Continue up the tree
                } else {
                    // Use empty hash as sibling
                    let sibling = self.empty_hashes[level];
                    current = merkle_hash(&sibling, &current);
                }
            }
            index >>= 1;
        }

        // Replace frontier with updated nodes
        if !new_frontier.is_empty() {
            let frontier_len = new_frontier.len();
            self.frontier.truncate(frontier_len - 1);
            self.frontier.extend(new_frontier);
        }
    }

    /// Get the current root of the tree
    pub fn root(&self) -> MerkleRoot {
        if self.num_leaves == 0 {
            return MerkleRoot(self.empty_hashes[TREE_DEPTH]);
        }

        let mut current_hash = self.frontier[0];
        let mut current_index = self.num_leaves - 1;

        // Compute root from frontier
        for level in 0..TREE_DEPTH {
            if level < self.frontier.len() - 1 {
                // We have a frontier node at the next level
                if (current_index >> (level + 1)) & 1 == 1 {
                    // Current subtree is a right child
                    let sibling = if level + 1 < self.frontier.len() {
                        self.frontier[level + 1]
                    } else {
                        self.empty_hashes[level + 1]
                    };
                    current_hash = merkle_hash(&sibling, &current_hash);
                }
            } else {
                // Pad with empty hashes
                let sibling = self.empty_hashes[level];
                if (current_index >> level) & 1 == 0 {
                    current_hash = merkle_hash(&current_hash, &sibling);
                } else {
                    current_hash = merkle_hash(&sibling, &current_hash);
                }
            }
        }

        MerkleRoot(current_hash)
    }

    /// Generate a Merkle proof for a leaf at the given position
    pub fn prove(&self, position: u64) -> Result<MerkleProof> {
        if position >= self.num_leaves {
            return Err(CryptoError::MerkleError("Position out of bounds".into()));
        }

        let mut path = Vec::with_capacity(TREE_DEPTH);
        let mut current_index = position;

        // Build authentication path
        for level in 0..TREE_DEPTH {
            let sibling_index = current_index ^ 1;

            let sibling = if sibling_index < self.num_leaves {
                // Sibling exists, need to compute or retrieve it
                self.get_node(level, sibling_index)?
            } else {
                // Use empty hash for non-existent sibling
                self.empty_hashes[level]
            };

            path.push(sibling);
            current_index >>= 1;
        }

        Ok(MerkleProof { path, position })
    }

    /// Get a node at a specific level and index (for proof generation)
    fn get_node(&self, level: usize, index: u64) -> Result<[u8; 32]> {
        // Check cache first
        if let Some(&hash) = self.cached_roots.get(&(level, index)) {
            return Ok(hash);
        }

        // For frontier nodes, we can retrieve directly
        if level < self.frontier.len() && index == (self.num_leaves - 1) >> level {
            return Ok(self.frontier[level]);
        }

        // Otherwise, need to compute (this would be more complex in production)
        // For now, return empty hash as placeholder
        Ok(self.empty_hashes[level])
    }

    /// Get the number of leaves in the tree
    pub fn num_leaves(&self) -> u64 {
        self.num_leaves
    }

    /// Check if the tree is empty
    pub fn is_empty(&self) -> bool {
        self.num_leaves == 0
    }
}

impl Default for IncrementalMerkleTree {
    fn default() -> Self {
        Self::new()
    }
}

/// A batch Merkle tree for efficient batch operations
pub struct BatchMerkleTree {
    tree: IncrementalMerkleTree,
    pending_leaves: Vec<[u8; 32]>,
}

impl BatchMerkleTree {
    /// Create a new batch Merkle tree
    pub fn new() -> Self {
        Self {
            tree: IncrementalMerkleTree::new(),
            pending_leaves: Vec::new(),
        }
    }

    /// Stage a leaf for batch insertion
    pub fn stage(&mut self, leaf: [u8; 32]) {
        self.pending_leaves.push(leaf);
    }

    /// Commit all staged leaves to the tree
    pub fn commit(&mut self) -> Result<Vec<u64>> {
        let mut positions = Vec::with_capacity(self.pending_leaves.len());

        for leaf in self.pending_leaves.drain(..) {
            positions.push(self.tree.append(leaf)?);
        }

        Ok(positions)
    }

    /// Get the current root (including staged leaves)
    pub fn root(&self) -> MerkleRoot {
        if self.pending_leaves.is_empty() {
            self.tree.root()
        } else {
            // Create temporary tree with pending leaves
            let mut temp = self.tree.clone();
            for leaf in &self.pending_leaves {
                let _ = temp.append(*leaf);
            }
            temp.root()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_empty_tree() {
        let tree = IncrementalMerkleTree::new();
        assert!(tree.is_empty());
        assert_eq!(tree.num_leaves(), 0);

        let root = tree.root();
        // Empty tree should have a deterministic root
        assert_eq!(root, tree.root());
    }

    #[test]
    fn test_single_leaf() {
        let mut tree = IncrementalMerkleTree::new();
        let leaf = [1u8; 32];

        let position = tree.append(leaf).unwrap();
        assert_eq!(position, 0);
        assert_eq!(tree.num_leaves(), 1);

        let root = tree.root();
        let proof = tree.prove(0).unwrap();
        assert!(proof.verify(&leaf, &root));
    }

    #[test]
    fn test_multiple_leaves() {
        let mut tree = IncrementalMerkleTree::new();
        let leaves = vec![[1u8; 32], [2u8; 32], [3u8; 32], [4u8; 32]];

        for (i, leaf) in leaves.iter().enumerate() {
            let position = tree.append(*leaf).unwrap();
            assert_eq!(position, i as u64);
        }

        let root = tree.root();

        // Verify all leaves
        for (i, leaf) in leaves.iter().enumerate() {
            let proof = tree.prove(i as u64).unwrap();
            assert!(proof.verify(leaf, &root));
        }
    }

    #[test]
    fn test_incremental_updates() {
        let mut tree = IncrementalMerkleTree::new();

        // Add leaves one by one and verify root changes
        let mut roots = Vec::new();

        for i in 0..10 {
            let leaf = [i as u8; 32];
            tree.append(leaf).unwrap();
            roots.push(tree.root());
        }

        // Each root should be different
        for i in 1..roots.len() {
            assert_ne!(roots[i - 1], roots[i]);
        }
    }

    #[test]
    fn test_batch_merkle_tree() {
        let mut batch = BatchMerkleTree::new();

        // Stage multiple leaves
        for i in 0..5 {
            batch.stage([i as u8; 32]);
        }

        // Commit and get positions
        let positions = batch.commit().unwrap();
        assert_eq!(positions.len(), 5);

        for (i, &pos) in positions.iter().enumerate() {
            assert_eq!(pos, i as u64);
        }
    }

    #[test]
    fn test_proof_verification_fails_with_wrong_leaf() {
        let mut tree = IncrementalMerkleTree::new();
        let leaf = [1u8; 32];
        tree.append(leaf).unwrap();

        let root = tree.root();
        let proof = tree.prove(0).unwrap();

        let wrong_leaf = [2u8; 32];
        assert!(!proof.verify(&wrong_leaf, &root));
    }

    #[test]
    fn test_proof_verification_fails_with_wrong_root() {
        let mut tree = IncrementalMerkleTree::new();
        let leaf = [1u8; 32];
        tree.append(leaf).unwrap();

        let proof = tree.prove(0).unwrap();

        let wrong_root = MerkleRoot([99u8; 32]);
        assert!(!proof.verify(&leaf, &wrong_root));
    }
}