// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title PuddelERC721
 * @notice ERC721 implementation with royalties, minting phases, and PUDDeL integration
 * @dev Deployed via minimal proxy pattern from factory
 */
contract PuddelERC721 is
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IERC2981
{
    // Collection configuration
    string public baseURI;
    uint256 public maxSupply;
    uint256 public mintPrice;
    uint256 public maxPerWallet;
    uint256 public totalMinted;

    // Royalty configuration (ERC2981)
    address public royaltyReceiver;
    uint96 public royaltyBps;

    // Minting phases
    enum Phase {
        Closed,
        Whitelist,
        Public
    }
    Phase public mintPhase;
    bytes32 public merkleRoot;

    // Tracking
    mapping(address => uint256) public mintedPerWallet;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => bool) public frozen;

    // PUDDeL integration
    address public marketplace;
    address public factory;

    // Events
    event PhaseChanged(Phase newPhase);
    event MerkleRootUpdated(bytes32 newRoot);
    event TokenMinted(address indexed to, uint256 tokenId);
    event TokenFrozen(uint256 tokenId);
    event TokenUnfrozen(uint256 tokenId);
    event RoyaltyUpdated(address receiver, uint96 bps);

    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory");
        _;
    }

    /**
     * @dev Initializer for proxy deployment
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        address _owner,
        uint256 _maxSupply,
        address _royaltyReceiver,
        uint96 _royaltyBps,
        uint256 _mintPrice,
        uint256 _maxPerWallet,
        address _marketplace
    ) external initializer {
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        baseURI = _baseURI;
        maxSupply = _maxSupply;
        royaltyReceiver = _royaltyReceiver;
        royaltyBps = _royaltyBps;
        mintPrice = _mintPrice;
        maxPerWallet = _maxPerWallet;
        marketplace = _marketplace;
        factory = msg.sender;

        // Transfer ownership to creator
        _transferOwnership(_owner);
    }

    // ============ Minting Functions ============

    /**
     * @notice Mint NFTs during public phase
     * @param quantity Number of NFTs to mint
     */
    function mint(uint256 quantity) external payable whenNotPaused nonReentrant {
        require(mintPhase == Phase.Public, "Public mint not active");
        require(quantity > 0, "Invalid quantity");
        require(maxSupply == 0 || totalMinted + quantity <= maxSupply, "Exceeds max supply");
        require(mintedPerWallet[msg.sender] + quantity <= maxPerWallet, "Exceeds wallet limit");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        _mintTokens(msg.sender, quantity);

        // Refund excess payment
        if (msg.value > mintPrice * quantity) {
            payable(msg.sender).transfer(msg.value - mintPrice * quantity);
        }
    }

    /**
     * @notice Mint NFTs during whitelist phase
     * @param quantity Number of NFTs to mint
     * @param merkleProof Merkle proof for whitelist
     */
    function whitelistMint(
        uint256 quantity,
        bytes32[] calldata merkleProof
    ) external payable whenNotPaused nonReentrant {
        require(mintPhase == Phase.Whitelist, "Whitelist mint not active");
        require(quantity > 0, "Invalid quantity");
        require(maxSupply == 0 || totalMinted + quantity <= maxSupply, "Exceeds max supply");
        require(mintedPerWallet[msg.sender] + quantity <= maxPerWallet, "Exceeds wallet limit");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        // Verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(merkleProof, merkleRoot, leaf), "Invalid proof");

        _mintTokens(msg.sender, quantity);

        // Refund excess payment
        if (msg.value > mintPrice * quantity) {
            payable(msg.sender).transfer(msg.value - mintPrice * quantity);
        }
    }

    /**
     * @notice Owner mint (no payment required)
     * @param to Recipient address
     * @param quantity Number of NFTs to mint
     */
    function ownerMint(address to, uint256 quantity) external onlyOwner {
        require(quantity > 0, "Invalid quantity");
        require(maxSupply == 0 || totalMinted + quantity <= maxSupply, "Exceeds max supply");

        _mintTokens(to, quantity);
    }

    /**
     * @dev Internal mint function
     */
    function _mintTokens(address to, uint256 quantity) internal {
        uint256 startId = totalMinted;

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = startId + i;
            _safeMint(to, tokenId);
            emit TokenMinted(to, tokenId);
        }

        totalMinted += quantity;
        mintedPerWallet[to] += quantity;
    }

    // ============ Collection Management ============

    /**
     * @notice Set mint phase
     * @param newPhase The new minting phase
     */
    function setMintPhase(Phase newPhase) external onlyOwner {
        mintPhase = newPhase;
        emit PhaseChanged(newPhase);
    }

    /**
     * @notice Set merkle root for whitelist
     * @param _merkleRoot The new merkle root
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    /**
     * @notice Update mint price
     * @param _mintPrice New mint price in AVAX
     */
    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    /**
     * @notice Update max per wallet
     * @param _maxPerWallet New maximum per wallet
     */
    function setMaxPerWallet(uint256 _maxPerWallet) external onlyOwner {
        maxPerWallet = _maxPerWallet;
    }

    /**
     * @notice Update base URI
     * @param _baseURI New base URI
     */
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    /**
     * @notice Set custom URI for a specific token
     * @param tokenId The token ID
     * @param tokenURI The custom URI
     */
    function setTokenURI(uint256 tokenId, string memory tokenURI) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        _tokenURIs[tokenId] = tokenURI;
    }

    /**
     * @notice Freeze metadata for a token (permanent)
     * @param tokenId The token to freeze
     */
    function freezeMetadata(uint256 tokenId) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        frozen[tokenId] = true;
        emit TokenFrozen(tokenId);
    }

    /**
     * @notice Unfreeze metadata (only if not permanently frozen)
     * @param tokenId The token to unfreeze
     */
    function unfreezeMetadata(uint256 tokenId) external onlyOwner {
        frozen[tokenId] = false;
        emit TokenUnfrozen(tokenId);
    }

    /**
     * @notice Update royalty configuration
     * @param receiver New royalty receiver
     * @param bps New royalty basis points
     */
    function setRoyalty(address receiver, uint96 bps) external onlyOwner {
        require(bps <= 1000, "Royalty too high"); // Max 10%
        royaltyReceiver = receiver;
        royaltyBps = bps;
        emit RoyaltyUpdated(receiver, bps);
    }

    /**
     * @notice Withdraw contract balance
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }

    /**
     * @notice Pause minting
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause minting
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ View Functions ============

    /**
     * @notice Get token URI
     * @param tokenId The token ID
     * @return The token URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");

        // Check for custom URI
        string memory customURI = _tokenURIs[tokenId];
        if (bytes(customURI).length > 0) {
            return customURI;
        }

        // Return base URI + token ID
        return string(abi.encodePacked(baseURI, _toString(tokenId), ".json"));
    }

    /**
     * @notice Get all tokens owned by an address
     * @param owner The owner address
     * @return tokenIds Array of token IDs
     */
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](balance);

        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }

        return tokenIds;
    }

    /**
     * @notice Check if an address has already minted
     * @param wallet The wallet address
     * @return hasMinted Whether the wallet has minted
     * @return quantity Number of NFTs minted
     */
    function getMintInfo(address wallet) external view returns (bool hasMinted, uint256 quantity) {
        quantity = mintedPerWallet[wallet];
        hasMinted = quantity > 0;
    }

    // ============ ERC2981 Royalty Implementation ============

    /**
     * @notice Get royalty info (ERC2981)
     * @param tokenId The token ID (unused, same royalty for all)
     * @param salePrice The sale price
     * @return receiver The royalty receiver
     * @return royaltyAmount The royalty amount
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        receiver = royaltyReceiver;
        royaltyAmount = (salePrice * royaltyBps) / 10000;
    }

    // ============ ERC165 ============

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721Upgradeable, ERC721EnumerableUpgradeable, IERC165) returns (bool) {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // ============ Overrides ============

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // ============ Internal Helpers ============

    /**
     * @dev Convert uint256 to string
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Check if a token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}