// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../security/ReentrancyGuard.sol";

/**
 * @title PuddelCollectionFactory
 * @notice Factory for deploying NFT collections with built-in royalties and PUDDeL integration
 * @dev Uses minimal proxy pattern for gas-efficient deployments
 */
contract PuddelCollectionFactory is Ownable, ReentrancyGuard {
    using Clones for address;

    // Implementation contracts
    address public erc721Implementation;
    address public erc1155Implementation;

    // Platform configuration
    address public immutable VOTING_ESCROW;
    address public immutable PEL_TOKEN;
    address public marketplace;
    uint256 public constant MAX_ROYALTY_BPS = 1000; // 10% max
    uint256 public deploymentFee = 0.1 ether; // Fee to deploy collection
    uint256 public veNFTDiscount = 5000; // 50% discount for veNFT holders

    // Collection registry
    mapping(address => CollectionInfo) public collections;
    mapping(address => address[]) public creatorCollections;
    address[] public allCollections;

    struct CollectionInfo {
        address creator;
        string name;
        string symbol;
        CollectionType collectionType;
        uint96 royaltyBps;
        address royaltyReceiver;
        bool verified;
        uint256 deployedAt;
    }

    enum CollectionType {
        ERC721,
        ERC1155
    }

    // Events
    event CollectionDeployed(
        address indexed collection,
        address indexed creator,
        string name,
        string symbol,
        CollectionType collectionType
    );

    event RoyaltyConfigured(
        address indexed collection,
        address indexed receiver,
        uint96 royaltyBps
    );

    event CollectionVerified(address indexed collection);
    event ImplementationUpdated(CollectionType collectionType, address implementation);
    event FeeUpdated(uint256 newFee);

    constructor(
        address _votingEscrow,
        address _pelToken,
        address _marketplace
    ) {
        VOTING_ESCROW = _votingEscrow;
        PEL_TOKEN = _pelToken;
        marketplace = _marketplace;
    }

    /**
     * @notice Deploy a new ERC721 collection
     * @param name Collection name
     * @param symbol Collection symbol
     * @param baseURI Base URI for metadata
     * @param maxSupply Maximum supply (0 for unlimited)
     * @param royaltyReceiver Address to receive royalties
     * @param royaltyBps Royalty percentage in basis points
     * @param mintPrice Price per mint in AVAX
     * @param maxPerWallet Maximum mints per wallet
     */
    function deployERC721Collection(
        string memory name,
        string memory symbol,
        string memory baseURI,
        uint256 maxSupply,
        address royaltyReceiver,
        uint96 royaltyBps,
        uint256 mintPrice,
        uint256 maxPerWallet
    ) external payable nonReentrant returns (address collection) {
        require(erc721Implementation != address(0), "Implementation not set");
        require(royaltyBps <= MAX_ROYALTY_BPS, "Royalty too high");
        require(bytes(name).length > 0 && bytes(symbol).length > 0, "Invalid name/symbol");

        // Calculate deployment fee with veNFT discount
        uint256 requiredFee = _calculateDeploymentFee(msg.sender);
        require(msg.value >= requiredFee, "Insufficient fee");

        // Deploy minimal proxy
        collection = erc721Implementation.clone();

        // Initialize collection
        IPuddelERC721(collection).initialize(
            name,
            symbol,
            baseURI,
            msg.sender, // owner
            maxSupply,
            royaltyReceiver,
            royaltyBps,
            mintPrice,
            maxPerWallet,
            marketplace
        );

        // Register collection
        _registerCollection(
            collection,
            msg.sender,
            name,
            symbol,
            CollectionType.ERC721,
            royaltyReceiver,
            royaltyBps
        );

        // Refund excess payment
        if (msg.value > requiredFee) {
            payable(msg.sender).transfer(msg.value - requiredFee);
        }

        emit CollectionDeployed(collection, msg.sender, name, symbol, CollectionType.ERC721);
        emit RoyaltyConfigured(collection, royaltyReceiver, royaltyBps);
    }

    /**
     * @notice Deploy a new ERC1155 collection
     * @param name Collection name
     * @param symbol Collection symbol
     * @param uri Metadata URI
     * @param royaltyReceiver Address to receive royalties
     * @param royaltyBps Royalty percentage in basis points
     */
    function deployERC1155Collection(
        string memory name,
        string memory symbol,
        string memory uri,
        address royaltyReceiver,
        uint96 royaltyBps
    ) external payable nonReentrant returns (address collection) {
        require(erc1155Implementation != address(0), "Implementation not set");
        require(royaltyBps <= MAX_ROYALTY_BPS, "Royalty too high");
        require(bytes(name).length > 0, "Invalid name");

        // Calculate deployment fee with veNFT discount
        uint256 requiredFee = _calculateDeploymentFee(msg.sender);
        require(msg.value >= requiredFee, "Insufficient fee");

        // Deploy minimal proxy
        collection = erc1155Implementation.clone();

        // Initialize collection
        IPuddelERC1155(collection).initialize(
            name,
            symbol,
            uri,
            msg.sender, // owner
            royaltyReceiver,
            royaltyBps,
            marketplace
        );

        // Register collection
        _registerCollection(
            collection,
            msg.sender,
            name,
            symbol,
            CollectionType.ERC1155,
            royaltyReceiver,
            royaltyBps
        );

        // Refund excess payment
        if (msg.value > requiredFee) {
            payable(msg.sender).transfer(msg.value - requiredFee);
        }

        emit CollectionDeployed(collection, msg.sender, name, symbol, CollectionType.ERC1155);
        emit RoyaltyConfigured(collection, royaltyReceiver, royaltyBps);
    }

    /**
     * @notice Verify a collection (admin only)
     * @param collection The collection to verify
     */
    function verifyCollection(address collection) external onlyOwner {
        require(collections[collection].creator != address(0), "Collection not found");
        collections[collection].verified = true;
        emit CollectionVerified(collection);
    }

    /**
     * @notice Set ERC721 implementation contract
     * @param implementation The implementation address
     */
    function setERC721Implementation(address implementation) external onlyOwner {
        require(implementation != address(0), "Invalid address");
        erc721Implementation = implementation;
        emit ImplementationUpdated(CollectionType.ERC721, implementation);
    }

    /**
     * @notice Set ERC1155 implementation contract
     * @param implementation The implementation address
     */
    function setERC1155Implementation(address implementation) external onlyOwner {
        require(implementation != address(0), "Invalid address");
        erc1155Implementation = implementation;
        emit ImplementationUpdated(CollectionType.ERC1155, implementation);
    }

    /**
     * @notice Update deployment fee
     * @param newFee The new deployment fee
     */
    function setDeploymentFee(uint256 newFee) external onlyOwner {
        deploymentFee = newFee;
        emit FeeUpdated(newFee);
    }

    /**
     * @notice Update veNFT discount
     * @param discount New discount in basis points (10000 = 100%)
     */
    function setVeNFTDiscount(uint256 discount) external onlyOwner {
        require(discount <= 10000, "Invalid discount");
        veNFTDiscount = discount;
    }

    /**
     * @notice Update marketplace address
     * @param newMarketplace The new marketplace address
     */
    function setMarketplace(address newMarketplace) external onlyOwner {
        marketplace = newMarketplace;
    }

    /**
     * @notice Withdraw accumulated fees
     */
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner()).transfer(balance);
    }

    // ============ Internal Functions ============

    /**
     * @dev Register a new collection
     */
    function _registerCollection(
        address collection,
        address creator,
        string memory name,
        string memory symbol,
        CollectionType collectionType,
        address royaltyReceiver,
        uint96 royaltyBps
    ) internal {
        collections[collection] = CollectionInfo({
            creator: creator,
            name: name,
            symbol: symbol,
            collectionType: collectionType,
            royaltyBps: royaltyBps,
            royaltyReceiver: royaltyReceiver,
            verified: false,
            deployedAt: block.timestamp
        });

        creatorCollections[creator].push(collection);
        allCollections.push(collection);
    }

    /**
     * @dev Calculate deployment fee with veNFT discount
     * @param deployer The address deploying the collection
     * @return fee The deployment fee after discount
     */
    function _calculateDeploymentFee(address deployer) internal view returns (uint256 fee) {
        fee = deploymentFee;

        // Apply veNFT holder discount
        if (VOTING_ESCROW != address(0)) {
            try IVotingEscrow(VOTING_ESCROW).balanceOf(deployer) returns (uint256 balance) {
                if (balance > 0) {
                    fee = (fee * (10000 - veNFTDiscount)) / 10000;
                }
            } catch {}
        }
    }

    // ============ View Functions ============

    /**
     * @notice Get all collections by a creator
     * @param creator The creator address
     * @return The array of collection addresses
     */
    function getCreatorCollections(address creator) external view returns (address[] memory) {
        return creatorCollections[creator];
    }

    /**
     * @notice Get total number of deployed collections
     * @return The total count
     */
    function totalCollections() external view returns (uint256) {
        return allCollections.length;
    }

    /**
     * @notice Get collections in a range
     * @param start Start index
     * @param end End index (exclusive)
     * @return collections Array of collection addresses
     */
    function getCollections(uint256 start, uint256 end) external view returns (address[] memory) {
        require(start < end && end <= allCollections.length, "Invalid range");

        address[] memory result = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = allCollections[i];
        }
        return result;
    }

    /**
     * @notice Check if an address is a deployed collection
     * @param collection The address to check
     * @return Whether it's a deployed collection
     */
    function isCollection(address collection) external view returns (bool) {
        return collections[collection].deployedAt != 0;
    }
}

// ============ Implementation Interfaces ============

interface IPuddelERC721 {
    function initialize(
        string memory name,
        string memory symbol,
        string memory baseURI,
        address owner,
        uint256 maxSupply,
        address royaltyReceiver,
        uint96 royaltyBps,
        uint256 mintPrice,
        uint256 maxPerWallet,
        address marketplace
    ) external;
}

interface IPuddelERC1155 {
    function initialize(
        string memory name,
        string memory symbol,
        string memory uri,
        address owner,
        address royaltyReceiver,
        uint96 royaltyBps,
        address marketplace
    ) external;
}

interface IVotingEscrow {
    function balanceOf(address owner) external view returns (uint256);
}