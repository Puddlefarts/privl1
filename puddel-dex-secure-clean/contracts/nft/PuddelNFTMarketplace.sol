// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../security/ReentrancyGuard.sol";
import "../security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

/**
 * @title PuddelNFTMarketplace
 * @notice Comprehensive NFT marketplace supporting ERC721/1155, royalties, offers, and atomic swaps
 * @dev Integrates with veNFT system for fee discounts and enhanced features
 */
contract PuddelNFTMarketplace is ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using ERC165Checker for address;

    // Constants
    uint256 public constant MAX_ROYALTY_BPS = 1000; // 10% max royalty
    uint256 public constant BASE_FEE_BPS = 250; // 2.5% base platform fee
    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;
    bytes4 private constant INTERFACE_ID_ERC2981 = 0x2a55205a;

    // Contracts
    address public immutable VOTING_ESCROW; // veNFT contract for fee discounts
    address public immutable PEL_TOKEN;
    address public treasury;

    // Listing structure
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 amount; // For ERC1155
        address paymentToken; // address(0) for AVAX
        uint256 price;
        uint256 expiresAt;
        bool isERC1155;
    }

    // Offer structure
    struct Offer {
        address offeror;
        address nftContract;
        uint256 tokenId;
        address paymentToken;
        uint256 price;
        uint256 expiresAt;
    }

    // NFT Swap structure
    struct Swap {
        address initiator;
        address nftContract1;
        uint256 tokenId1;
        uint256 amount1; // For ERC1155
        address counterparty;
        address nftContract2;
        uint256 tokenId2;
        uint256 amount2; // For ERC1155
        uint256 expiresAt;
        bool isERC1155_1;
        bool isERC1155_2;
    }

    // State mappings
    mapping(bytes32 => Listing) public listings;
    mapping(bytes32 => Offer[]) public offers;
    mapping(bytes32 => Swap) public swaps;

    // Royalty registry (can be overridden by ERC2981)
    mapping(address => RoyaltyInfo) public royaltyRegistry;

    // veNFT tier discounts (in basis points reduction from BASE_FEE_BPS)
    mapping(uint8 => uint256) public tierDiscounts;

    // Whitelisted payment tokens
    mapping(address => bool) public paymentTokens;

    // User stats for achievements/rewards
    mapping(address => UserStats) public userStats;

    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyBps;
    }

    struct UserStats {
        uint256 totalSold;
        uint256 totalBought;
        uint256 totalVolume;
        uint256 offersAccepted;
    }

    // Events
    event Listed(
        bytes32 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price,
        address paymentToken
    );

    event Sold(
        bytes32 indexed listingId,
        address indexed buyer,
        address indexed seller,
        uint256 price,
        uint256 royaltyPaid
    );

    event ListingCancelled(bytes32 indexed listingId);

    event OfferMade(
        bytes32 indexed listingId,
        address indexed offeror,
        uint256 price,
        uint256 offerIndex
    );

    event OfferAccepted(
        bytes32 indexed listingId,
        address indexed offeror,
        uint256 offerIndex
    );

    event OfferCancelled(
        bytes32 indexed listingId,
        uint256 offerIndex
    );

    event SwapCreated(
        bytes32 indexed swapId,
        address indexed initiator,
        address indexed counterparty
    );

    event SwapExecuted(bytes32 indexed swapId);
    event SwapCancelled(bytes32 indexed swapId);

    event RoyaltySet(address indexed collection, address receiver, uint96 royaltyBps);
    event PaymentTokenUpdated(address token, bool enabled);

    modifier onlyAdmin() {
        require(msg.sender == treasury, "Not admin");
        _;
    }

    constructor(
        address _votingEscrow,
        address _pelToken,
        address _treasury
    ) {
        VOTING_ESCROW = _votingEscrow;
        PEL_TOKEN = _pelToken;
        treasury = _treasury;

        // Initialize payment tokens
        paymentTokens[address(0)] = true; // AVAX
        paymentTokens[_pelToken] = true; // PEL

        // Initialize veNFT tier discounts (in bps)
        tierDiscounts[0] = 25;  // Tier 0: 0.25% discount
        tierDiscounts[1] = 50;  // Tier 1: 0.50% discount
        tierDiscounts[2] = 75;  // Tier 2: 0.75% discount
        tierDiscounts[3] = 100; // Tier 3: 1.00% discount
        tierDiscounts[4] = 125; // Tier 4: 1.25% discount (Oasis tier)
    }

    // ============ Listing Functions ============

    /**
     * @notice List an NFT for sale
     * @param nftContract The NFT contract address
     * @param tokenId The token ID
     * @param amount Amount for ERC1155 (1 for ERC721)
     * @param paymentToken Payment token address (address(0) for AVAX)
     * @param price Sale price in payment token
     * @param duration Listing duration in seconds
     */
    function listNFT(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        address paymentToken,
        uint256 price,
        uint256 duration
    ) external whenNotPaused nonReentrant {
        require(price > 0, "Invalid price");
        require(paymentTokens[paymentToken], "Payment token not allowed");
        require(duration > 0 && duration <= 180 days, "Invalid duration");

        bool isERC1155 = nftContract.supportsInterface(INTERFACE_ID_ERC1155);
        bool isERC721 = nftContract.supportsInterface(INTERFACE_ID_ERC721);
        require(isERC721 || isERC1155, "Invalid NFT contract");

        if (isERC721) {
            require(amount == 1, "Invalid amount for ERC721");
            require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");
            require(
                IERC721(nftContract).isApprovedForAll(msg.sender, address(this)) ||
                IERC721(nftContract).getApproved(tokenId) == address(this),
                "Not approved"
            );
        } else {
            require(amount > 0, "Invalid amount");
            require(IERC1155(nftContract).balanceOf(msg.sender, tokenId) >= amount, "Insufficient balance");
            require(IERC1155(nftContract).isApprovedForAll(msg.sender, address(this)), "Not approved");
        }

        bytes32 listingId = keccak256(abi.encodePacked(msg.sender, nftContract, tokenId, block.timestamp));

        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            amount: amount,
            paymentToken: paymentToken,
            price: price,
            expiresAt: block.timestamp + duration,
            isERC1155: isERC1155
        });

        emit Listed(listingId, msg.sender, nftContract, tokenId, price, paymentToken);
    }

    /**
     * @notice Buy a listed NFT
     * @param listingId The listing identifier
     */
    function buyNFT(bytes32 listingId) external payable whenNotPaused nonReentrant {
        Listing memory listing = listings[listingId];
        require(listing.seller != address(0), "Listing not found");
        require(block.timestamp < listing.expiresAt, "Listing expired");
        require(listing.seller != msg.sender, "Cannot buy own listing");

        // Calculate fees and royalties
        (uint256 platformFee, uint256 royaltyAmount, address royaltyReceiver) = _calculateFees(
            listing.nftContract,
            listing.tokenId,
            listing.price,
            msg.sender
        );

        uint256 sellerProceeds = listing.price - platformFee - royaltyAmount;

        // Handle payment
        if (listing.paymentToken == address(0)) {
            require(msg.value == listing.price, "Incorrect payment");

            // Transfer fees and royalties
            if (platformFee > 0) {
                payable(treasury).transfer(platformFee);
            }
            if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
                payable(royaltyReceiver).transfer(royaltyAmount);
            }
            // Transfer to seller
            payable(listing.seller).transfer(sellerProceeds);
        } else {
            IERC20(listing.paymentToken).safeTransferFrom(msg.sender, address(this), listing.price);

            // Distribute tokens
            if (platformFee > 0) {
                IERC20(listing.paymentToken).safeTransfer(treasury, platformFee);
            }
            if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
                IERC20(listing.paymentToken).safeTransfer(royaltyReceiver, royaltyAmount);
            }
            IERC20(listing.paymentToken).safeTransfer(listing.seller, sellerProceeds);
        }

        // Transfer NFT
        if (listing.isERC1155) {
            IERC1155(listing.nftContract).safeTransferFrom(
                listing.seller,
                msg.sender,
                listing.tokenId,
                listing.amount,
                ""
            );
        } else {
            IERC721(listing.nftContract).safeTransferFrom(
                listing.seller,
                msg.sender,
                listing.tokenId
            );
        }

        // Update stats
        userStats[msg.sender].totalBought++;
        userStats[msg.sender].totalVolume += listing.price;
        userStats[listing.seller].totalSold++;
        userStats[listing.seller].totalVolume += listing.price;

        // Remove listing
        delete listings[listingId];

        emit Sold(listingId, msg.sender, listing.seller, listing.price, royaltyAmount);
    }

    /**
     * @notice Cancel a listing
     * @param listingId The listing to cancel
     */
    function cancelListing(bytes32 listingId) external nonReentrant {
        Listing memory listing = listings[listingId];
        require(listing.seller == msg.sender, "Not seller");

        delete listings[listingId];
        emit ListingCancelled(listingId);
    }

    // ============ Offer Functions ============

    /**
     * @notice Make an offer on an NFT (listed or unlisted)
     * @param nftContract The NFT contract
     * @param tokenId The token ID
     * @param paymentToken The payment token for the offer
     * @param price The offer price
     * @param duration Offer duration in seconds
     */
    function makeOffer(
        address nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price,
        uint256 duration
    ) external payable whenNotPaused nonReentrant {
        require(paymentTokens[paymentToken], "Payment token not allowed");
        require(price > 0, "Invalid price");
        require(duration > 0 && duration <= 30 days, "Invalid duration");

        bytes32 offerId = keccak256(abi.encodePacked(nftContract, tokenId));

        // Escrow payment
        if (paymentToken == address(0)) {
            require(msg.value == price, "Incorrect payment");
        } else {
            IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), price);
        }

        offers[offerId].push(Offer({
            offeror: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            paymentToken: paymentToken,
            price: price,
            expiresAt: block.timestamp + duration
        }));

        emit OfferMade(offerId, msg.sender, price, offers[offerId].length - 1);
    }

    /**
     * @notice Accept an offer
     * @param nftContract The NFT contract
     * @param tokenId The token ID
     * @param offerIndex The offer index to accept
     * @param amount Amount for ERC1155
     */
    function acceptOffer(
        address nftContract,
        uint256 tokenId,
        uint256 offerIndex,
        uint256 amount
    ) external whenNotPaused nonReentrant {
        bytes32 offerId = keccak256(abi.encodePacked(nftContract, tokenId));
        require(offerIndex < offers[offerId].length, "Invalid offer");

        Offer memory offer = offers[offerId][offerIndex];
        require(offer.offeror != address(0), "Offer not found");
        require(block.timestamp < offer.expiresAt, "Offer expired");

        // Verify ownership and approval
        bool isERC1155 = nftContract.supportsInterface(INTERFACE_ID_ERC1155);
        if (isERC1155) {
            require(amount > 0, "Invalid amount");
            require(IERC1155(nftContract).balanceOf(msg.sender, tokenId) >= amount, "Insufficient balance");
            require(IERC1155(nftContract).isApprovedForAll(msg.sender, address(this)), "Not approved");
        } else {
            require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");
            require(
                IERC721(nftContract).isApprovedForAll(msg.sender, address(this)) ||
                IERC721(nftContract).getApproved(tokenId) == address(this),
                "Not approved"
            );
        }

        // Calculate fees
        (uint256 platformFee, uint256 royaltyAmount, address royaltyReceiver) = _calculateFees(
            nftContract,
            tokenId,
            offer.price,
            offer.offeror
        );

        uint256 sellerProceeds = offer.price - platformFee - royaltyAmount;

        // Distribute payment from escrow
        if (offer.paymentToken == address(0)) {
            if (platformFee > 0) {
                payable(treasury).transfer(platformFee);
            }
            if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
                payable(royaltyReceiver).transfer(royaltyAmount);
            }
            payable(msg.sender).transfer(sellerProceeds);
        } else {
            if (platformFee > 0) {
                IERC20(offer.paymentToken).safeTransfer(treasury, platformFee);
            }
            if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
                IERC20(offer.paymentToken).safeTransfer(royaltyReceiver, royaltyAmount);
            }
            IERC20(offer.paymentToken).safeTransfer(msg.sender, sellerProceeds);
        }

        // Transfer NFT
        if (isERC1155) {
            IERC1155(nftContract).safeTransferFrom(msg.sender, offer.offeror, tokenId, amount, "");
        } else {
            IERC721(nftContract).safeTransferFrom(msg.sender, offer.offeror, tokenId);
        }

        // Update stats
        userStats[msg.sender].offersAccepted++;
        userStats[msg.sender].totalSold++;
        userStats[offer.offeror].totalBought++;

        // Remove offer
        delete offers[offerId][offerIndex];

        emit OfferAccepted(offerId, offer.offeror, offerIndex);
    }

    /**
     * @notice Cancel an offer and refund
     * @param nftContract The NFT contract
     * @param tokenId The token ID
     * @param offerIndex The offer to cancel
     */
    function cancelOffer(
        address nftContract,
        uint256 tokenId,
        uint256 offerIndex
    ) external nonReentrant {
        bytes32 offerId = keccak256(abi.encodePacked(nftContract, tokenId));
        require(offerIndex < offers[offerId].length, "Invalid offer");

        Offer memory offer = offers[offerId][offerIndex];
        require(offer.offeror == msg.sender, "Not offeror");

        // Refund escrowed payment
        if (offer.paymentToken == address(0)) {
            payable(msg.sender).transfer(offer.price);
        } else {
            IERC20(offer.paymentToken).safeTransfer(msg.sender, offer.price);
        }

        delete offers[offerId][offerIndex];
        emit OfferCancelled(offerId, offerIndex);
    }

    // ============ NFT Swap Functions ============

    /**
     * @notice Create an NFT-for-NFT swap proposal
     */
    function createSwap(
        address nftContract1,
        uint256 tokenId1,
        uint256 amount1,
        address counterparty,
        address nftContract2,
        uint256 tokenId2,
        uint256 amount2,
        uint256 duration
    ) external whenNotPaused nonReentrant {
        require(counterparty != address(0) && counterparty != msg.sender, "Invalid counterparty");
        require(duration > 0 && duration <= 7 days, "Invalid duration");

        // Verify contracts and ownership
        bool isERC1155_1 = nftContract1.supportsInterface(INTERFACE_ID_ERC1155);
        bool isERC1155_2 = nftContract2.supportsInterface(INTERFACE_ID_ERC1155);

        if (isERC1155_1) {
            require(IERC1155(nftContract1).balanceOf(msg.sender, tokenId1) >= amount1, "Insufficient balance");
            require(IERC1155(nftContract1).isApprovedForAll(msg.sender, address(this)), "Not approved");
        } else {
            require(IERC721(nftContract1).ownerOf(tokenId1) == msg.sender, "Not owner");
            require(
                IERC721(nftContract1).isApprovedForAll(msg.sender, address(this)) ||
                IERC721(nftContract1).getApproved(tokenId1) == address(this),
                "Not approved"
            );
        }

        bytes32 swapId = keccak256(
            abi.encodePacked(msg.sender, counterparty, nftContract1, tokenId1, block.timestamp)
        );

        swaps[swapId] = Swap({
            initiator: msg.sender,
            nftContract1: nftContract1,
            tokenId1: tokenId1,
            amount1: amount1,
            counterparty: counterparty,
            nftContract2: nftContract2,
            tokenId2: tokenId2,
            amount2: amount2,
            expiresAt: block.timestamp + duration,
            isERC1155_1: isERC1155_1,
            isERC1155_2: isERC1155_2
        });

        emit SwapCreated(swapId, msg.sender, counterparty);
    }

    /**
     * @notice Execute an NFT swap
     * @param swapId The swap identifier
     */
    function executeSwap(bytes32 swapId) external whenNotPaused nonReentrant {
        Swap memory swap = swaps[swapId];
        require(swap.initiator != address(0), "Swap not found");
        require(msg.sender == swap.counterparty, "Not counterparty");
        require(block.timestamp < swap.expiresAt, "Swap expired");

        // Verify counterparty ownership and approval
        if (swap.isERC1155_2) {
            require(
                IERC1155(swap.nftContract2).balanceOf(msg.sender, swap.tokenId2) >= swap.amount2,
                "Insufficient balance"
            );
            require(IERC1155(swap.nftContract2).isApprovedForAll(msg.sender, address(this)), "Not approved");
        } else {
            require(IERC721(swap.nftContract2).ownerOf(swap.tokenId2) == msg.sender, "Not owner");
            require(
                IERC721(swap.nftContract2).isApprovedForAll(msg.sender, address(this)) ||
                IERC721(swap.nftContract2).getApproved(swap.tokenId2) == address(this),
                "Not approved"
            );
        }

        // Execute atomic swap
        if (swap.isERC1155_1) {
            IERC1155(swap.nftContract1).safeTransferFrom(
                swap.initiator,
                msg.sender,
                swap.tokenId1,
                swap.amount1,
                ""
            );
        } else {
            IERC721(swap.nftContract1).safeTransferFrom(swap.initiator, msg.sender, swap.tokenId1);
        }

        if (swap.isERC1155_2) {
            IERC1155(swap.nftContract2).safeTransferFrom(
                msg.sender,
                swap.initiator,
                swap.tokenId2,
                swap.amount2,
                ""
            );
        } else {
            IERC721(swap.nftContract2).safeTransferFrom(msg.sender, swap.initiator, swap.tokenId2);
        }

        delete swaps[swapId];
        emit SwapExecuted(swapId);
    }

    /**
     * @notice Cancel a swap proposal
     * @param swapId The swap to cancel
     */
    function cancelSwap(bytes32 swapId) external nonReentrant {
        Swap memory swap = swaps[swapId];
        require(swap.initiator == msg.sender, "Not initiator");

        delete swaps[swapId];
        emit SwapCancelled(swapId);
    }

    // ============ Admin Functions ============

    /**
     * @notice Set royalty info for a collection (admin only)
     * @param collection The NFT collection address
     * @param receiver The royalty receiver
     * @param royaltyBps Royalty in basis points
     */
    function setRoyalty(
        address collection,
        address receiver,
        uint96 royaltyBps
    ) external onlyAdmin {
        require(royaltyBps <= MAX_ROYALTY_BPS, "Royalty too high");
        royaltyRegistry[collection] = RoyaltyInfo(receiver, royaltyBps);
        emit RoyaltySet(collection, receiver, royaltyBps);
    }

    /**
     * @notice Update payment token whitelist
     * @param token The token address
     * @param enabled Whether the token is enabled
     */
    function setPaymentToken(address token, bool enabled) external onlyAdmin {
        paymentTokens[token] = enabled;
        emit PaymentTokenUpdated(token, enabled);
    }

    /**
     * @notice Update veNFT tier discounts
     * @param tier The veNFT tier
     * @param discountBps Discount in basis points
     */
    function setTierDiscount(uint8 tier, uint256 discountBps) external onlyAdmin {
        require(discountBps <= BASE_FEE_BPS, "Discount too high");
        tierDiscounts[tier] = discountBps;
    }

    /**
     * @notice Update treasury address
     * @param newTreasury The new treasury address
     */
    function setTreasury(address newTreasury) external onlyAdmin {
        require(newTreasury != address(0), "Invalid address");
        treasury = newTreasury;
    }

    /**
     * @notice Emergency pause
     */
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @notice Unpause
     */
    function unpause() external onlyAdmin {
        _unpause();
    }

    // ============ Internal Functions ============

    /**
     * @dev Calculate platform fees and royalties
     * @param nftContract The NFT contract
     * @param tokenId The token ID
     * @param salePrice The sale price
     * @param buyer The buyer address (for veNFT discount)
     * @return platformFee The platform fee amount
     * @return royaltyAmount The royalty amount
     * @return royaltyReceiver The royalty receiver address
     */
    function _calculateFees(
        address nftContract,
        uint256 tokenId,
        uint256 salePrice,
        address buyer
    ) internal view returns (uint256 platformFee, uint256 royaltyAmount, address royaltyReceiver) {
        // Calculate platform fee with veNFT discount
        uint256 effectiveFee = BASE_FEE_BPS;

        // Check if buyer holds veNFT for discount
        if (VOTING_ESCROW != address(0)) {
            try IVotingEscrow(VOTING_ESCROW).balanceOf(buyer) returns (uint256 balance) {
                if (balance > 0) {
                    // Get highest tier veNFT for maximum discount
                    uint8 maxTier = _getUserMaxTier(buyer);
                    uint256 discount = tierDiscounts[maxTier];
                    effectiveFee = effectiveFee > discount ? effectiveFee - discount : 0;
                }
            } catch {}
        }

        platformFee = (salePrice * effectiveFee) / 10000;

        // Check for ERC2981 royalty support
        if (nftContract.supportsInterface(INTERFACE_ID_ERC2981)) {
            try IERC2981(nftContract).royaltyInfo(tokenId, salePrice) returns (
                address receiver,
                uint256 amount
            ) {
                royaltyReceiver = receiver;
                royaltyAmount = amount;

                // Cap royalty at maximum
                if (royaltyAmount > (salePrice * MAX_ROYALTY_BPS) / 10000) {
                    royaltyAmount = (salePrice * MAX_ROYALTY_BPS) / 10000;
                }
            } catch {
                // Fall back to registry
                _getRoyaltyFromRegistry(nftContract, salePrice, royaltyAmount, royaltyReceiver);
            }
        } else {
            // Use royalty registry
            _getRoyaltyFromRegistry(nftContract, salePrice, royaltyAmount, royaltyReceiver);
        }
    }

    /**
     * @dev Get royalty info from registry
     */
    function _getRoyaltyFromRegistry(
        address nftContract,
        uint256 salePrice,
        uint256 royaltyAmount,
        address royaltyReceiver
    ) private view {
        RoyaltyInfo memory info = royaltyRegistry[nftContract];
        if (info.receiver != address(0)) {
            royaltyReceiver = info.receiver;
            royaltyAmount = (salePrice * info.royaltyBps) / 10000;
        }
    }

    /**
     * @dev Get user's maximum veNFT tier
     * @param user The user address
     * @return maxTier The highest tier veNFT owned
     */
    function _getUserMaxTier(address user) internal view returns (uint8 maxTier) {
        // This is a simplified version - in production, would iterate through user's veNFTs
        // and check each one's tier from the VotingEscrow contract
        try IVotingEscrow(VOTING_ESCROW).balanceOf(user) returns (uint256 balance) {
            if (balance > 0) {
                // For simplicity, return tier 2 if user has any veNFT
                // In production, would check actual tier of each veNFT
                return 2;
            }
        } catch {}
        return 0;
    }

    // ============ View Functions ============

    /**
     * @notice Get all active offers for an NFT
     * @param nftContract The NFT contract
     * @param tokenId The token ID
     * @return activeOffers Array of active offers
     */
    function getActiveOffers(
        address nftContract,
        uint256 tokenId
    ) external view returns (Offer[] memory activeOffers) {
        bytes32 offerId = keccak256(abi.encodePacked(nftContract, tokenId));
        Offer[] memory allOffers = offers[offerId];

        // Count active offers
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allOffers.length; i++) {
            if (allOffers[i].offeror != address(0) && block.timestamp < allOffers[i].expiresAt) {
                activeCount++;
            }
        }

        // Create array of active offers
        activeOffers = new Offer[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allOffers.length; i++) {
            if (allOffers[i].offeror != address(0) && block.timestamp < allOffers[i].expiresAt) {
                activeOffers[index] = allOffers[i];
                index++;
            }
        }
    }

    /**
     * @notice Calculate fee for a potential sale
     * @param salePrice The sale price
     * @param buyer The buyer address
     * @return platformFee The platform fee that would be charged
     */
    function calculatePlatformFee(
        uint256 salePrice,
        address buyer
    ) external view returns (uint256 platformFee) {
        uint256 effectiveFee = BASE_FEE_BPS;

        if (VOTING_ESCROW != address(0)) {
            try IVotingEscrow(VOTING_ESCROW).balanceOf(buyer) returns (uint256 balance) {
                if (balance > 0) {
                    uint8 maxTier = _getUserMaxTier(buyer);
                    uint256 discount = tierDiscounts[maxTier];
                    effectiveFee = effectiveFee > discount ? effectiveFee - discount : 0;
                }
            } catch {}
        }

        platformFee = (salePrice * effectiveFee) / 10000;
    }

    receive() external payable {}
}

// Minimal interface for VotingEscrow integration
interface IVotingEscrow {
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function locks(uint256 tokenId) external view returns (
        uint128 amount,
        uint64 start,
        uint64 end,
        uint8 tier
    );
}