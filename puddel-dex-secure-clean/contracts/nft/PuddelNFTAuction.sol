// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../security/ReentrancyGuard.sol";
import "../security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

/**
 * @title PuddelNFTAuction
 * @notice Advanced auction system supporting English and Dutch auctions with veNFT benefits
 * @dev Integrates with PUDDeL ecosystem for enhanced auction mechanics
 */
contract PuddelNFTAuction is ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant MIN_BID_INCREMENT_BPS = 100; // 1% minimum bid increment
    uint256 public constant MAX_ROYALTY_BPS = 1000; // 10% max royalty
    uint256 public constant PLATFORM_FEE_BPS = 250; // 2.5% platform fee
    uint256 public constant MAX_AUCTION_DURATION = 30 days;
    uint256 public constant AUCTION_EXTENSION_TIME = 10 minutes; // Time extension on last-minute bids

    // Contracts
    address public immutable VOTING_ESCROW;
    address public immutable PEL_TOKEN;
    address public treasury;
    address public marketplace;

    // Auction types
    enum AuctionType {
        English, // Ascending bid auction
        Dutch    // Descending price auction
    }

    // Auction struct
    struct Auction {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 amount; // For ERC1155
        bool isERC1155;
        AuctionType auctionType;
        address paymentToken; // address(0) for AVAX
        uint256 startPrice;
        uint256 endPrice; // For Dutch auction (final price)
        uint256 reservePrice; // For English auction
        uint256 startTime;
        uint256 endTime;
        address highestBidder;
        uint256 highestBid;
        bool settled;
        uint256 bidCount;
    }

    // Bid struct
    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
        bool refunded;
    }

    // State mappings
    mapping(bytes32 => Auction) public auctions;
    mapping(bytes32 => Bid[]) public auctionBids;
    mapping(bytes32 => mapping(address => uint256)) public pendingReturns;

    // veNFT bid multipliers (in basis points, 10000 = 1x)
    mapping(uint8 => uint256) public tierMultipliers;

    // Statistics
    mapping(address => uint256) public totalAuctionsCreated;
    mapping(address => uint256) public totalBidsMade;
    mapping(address => uint256) public totalAuctionsWon;

    // Events
    event AuctionCreated(
        bytes32 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        AuctionType auctionType,
        uint256 startPrice,
        uint256 endTime
    );

    event BidPlaced(
        bytes32 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        uint256 newEndTime
    );

    event AuctionSettled(
        bytes32 indexed auctionId,
        address indexed winner,
        uint256 finalPrice
    );

    event AuctionCancelled(bytes32 indexed auctionId);

    event BidRefunded(
        bytes32 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );

    modifier onlyAdmin() {
        require(msg.sender == treasury, "Not admin");
        _;
    }

    constructor(
        address _votingEscrow,
        address _pelToken,
        address _treasury,
        address _marketplace
    ) {
        VOTING_ESCROW = _votingEscrow;
        PEL_TOKEN = _pelToken;
        treasury = _treasury;
        marketplace = _marketplace;

        // Initialize veNFT tier multipliers for bids
        tierMultipliers[0] = 10100; // Tier 0: 1.01x multiplier
        tierMultipliers[1] = 10200; // Tier 1: 1.02x multiplier
        tierMultipliers[2] = 10300; // Tier 2: 1.03x multiplier
        tierMultipliers[3] = 10500; // Tier 3: 1.05x multiplier
        tierMultipliers[4] = 11000; // Tier 4: 1.10x multiplier (Oasis)
    }

    // ============ Create Auction Functions ============

    /**
     * @notice Create an English auction
     * @param nftContract NFT contract address
     * @param tokenId Token ID
     * @param amount Amount for ERC1155
     * @param paymentToken Payment token (address(0) for AVAX)
     * @param startPrice Starting bid price
     * @param reservePrice Minimum acceptable price
     * @param duration Auction duration in seconds
     */
    function createEnglishAuction(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        address paymentToken,
        uint256 startPrice,
        uint256 reservePrice,
        uint256 duration
    ) external whenNotPaused nonReentrant returns (bytes32 auctionId) {
        require(startPrice > 0, "Invalid start price");
        require(reservePrice >= startPrice, "Reserve below start");
        require(duration > 0 && duration <= MAX_AUCTION_DURATION, "Invalid duration");

        // Verify NFT ownership and approval
        bool isERC1155 = _isERC1155(nftContract);
        _verifyNFTOwnership(nftContract, tokenId, amount, isERC1155);

        auctionId = _generateAuctionId(msg.sender, nftContract, tokenId);
        require(auctions[auctionId].seller == address(0), "Auction exists");

        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            amount: amount,
            isERC1155: isERC1155,
            auctionType: AuctionType.English,
            paymentToken: paymentToken,
            startPrice: startPrice,
            endPrice: 0,
            reservePrice: reservePrice,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            highestBidder: address(0),
            highestBid: 0,
            settled: false,
            bidCount: 0
        });

        totalAuctionsCreated[msg.sender]++;

        emit AuctionCreated(
            auctionId,
            msg.sender,
            nftContract,
            tokenId,
            AuctionType.English,
            startPrice,
            block.timestamp + duration
        );
    }

    /**
     * @notice Create a Dutch auction
     * @param nftContract NFT contract address
     * @param tokenId Token ID
     * @param amount Amount for ERC1155
     * @param paymentToken Payment token
     * @param startPrice Starting price (highest)
     * @param endPrice Ending price (lowest)
     * @param duration Auction duration
     */
    function createDutchAuction(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        address paymentToken,
        uint256 startPrice,
        uint256 endPrice,
        uint256 duration
    ) external whenNotPaused nonReentrant returns (bytes32 auctionId) {
        require(startPrice > endPrice, "Invalid price range");
        require(endPrice > 0, "Invalid end price");
        require(duration > 0 && duration <= MAX_AUCTION_DURATION, "Invalid duration");

        // Verify NFT ownership and approval
        bool isERC1155 = _isERC1155(nftContract);
        _verifyNFTOwnership(nftContract, tokenId, amount, isERC1155);

        auctionId = _generateAuctionId(msg.sender, nftContract, tokenId);
        require(auctions[auctionId].seller == address(0), "Auction exists");

        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            amount: amount,
            isERC1155: isERC1155,
            auctionType: AuctionType.Dutch,
            paymentToken: paymentToken,
            startPrice: startPrice,
            endPrice: endPrice,
            reservePrice: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            highestBidder: address(0),
            highestBid: 0,
            settled: false,
            bidCount: 0
        });

        totalAuctionsCreated[msg.sender]++;

        emit AuctionCreated(
            auctionId,
            msg.sender,
            nftContract,
            tokenId,
            AuctionType.Dutch,
            startPrice,
            block.timestamp + duration
        );
    }

    // ============ Bidding Functions ============

    /**
     * @notice Place bid on English auction
     * @param auctionId Auction identifier
     * @param bidAmount Bid amount (for ERC20 tokens)
     */
    function placeBid(bytes32 auctionId, uint256 bidAmount) external payable whenNotPaused nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction not found");
        require(auction.auctionType == AuctionType.English, "Not English auction");
        require(!auction.settled, "Auction settled");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(msg.sender != auction.seller, "Seller cannot bid");

        // Calculate effective bid with veNFT multiplier
        uint256 effectiveBid = _getEffectiveBid(msg.sender, bidAmount);

        // Validate bid amount
        uint256 minBid = auction.highestBid > 0
            ? auction.highestBid + (auction.highestBid * MIN_BID_INCREMENT_BPS) / 10000
            : auction.startPrice;
        require(effectiveBid >= minBid, "Bid too low");

        // Handle payment
        if (auction.paymentToken == address(0)) {
            require(msg.value == bidAmount, "Incorrect payment");
        } else {
            require(msg.value == 0, "No AVAX needed");
            IERC20(auction.paymentToken).safeTransferFrom(msg.sender, address(this), bidAmount);
        }

        // Record previous highest bidder for refund
        if (auction.highestBidder != address(0)) {
            pendingReturns[auctionId][auction.highestBidder] += auction.highestBid;
        }

        // Update auction state
        auction.highestBidder = msg.sender;
        auction.highestBid = bidAmount; // Store actual bid, not effective
        auction.bidCount++;

        // Record bid
        auctionBids[auctionId].push(Bid({
            bidder: msg.sender,
            amount: bidAmount,
            timestamp: block.timestamp,
            refunded: false
        }));

        // Extend auction if bid placed near end
        if (auction.endTime - block.timestamp <= AUCTION_EXTENSION_TIME) {
            auction.endTime = block.timestamp + AUCTION_EXTENSION_TIME;
        }

        totalBidsMade[msg.sender]++;

        emit BidPlaced(auctionId, msg.sender, bidAmount, auction.endTime);
    }

    /**
     * @notice Buy now in Dutch auction at current price
     * @param auctionId Auction identifier
     */
    function buyDutchAuction(bytes32 auctionId) external payable whenNotPaused nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction not found");
        require(auction.auctionType == AuctionType.Dutch, "Not Dutch auction");
        require(!auction.settled, "Auction settled");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(msg.sender != auction.seller, "Seller cannot buy");

        // Calculate current price
        uint256 currentPrice = getCurrentDutchPrice(auctionId);

        // Handle payment
        if (auction.paymentToken == address(0)) {
            require(msg.value >= currentPrice, "Insufficient payment");
            // Refund excess
            if (msg.value > currentPrice) {
                payable(msg.sender).transfer(msg.value - currentPrice);
            }
        } else {
            require(msg.value == 0, "No AVAX needed");
            IERC20(auction.paymentToken).safeTransferFrom(msg.sender, address(this), currentPrice);
        }

        // Update auction
        auction.highestBidder = msg.sender;
        auction.highestBid = currentPrice;
        auction.settled = true;

        // Transfer NFT and distribute payments
        _settleAuction(auctionId);

        totalAuctionsWon[msg.sender]++;

        emit AuctionSettled(auctionId, msg.sender, currentPrice);
    }

    // ============ Settlement Functions ============

    /**
     * @notice Settle an ended English auction
     * @param auctionId Auction identifier
     */
    function settleAuction(bytes32 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction not found");
        require(!auction.settled, "Already settled");
        require(block.timestamp >= auction.endTime, "Auction not ended");

        if (auction.auctionType == AuctionType.English) {
            if (auction.highestBid >= auction.reservePrice && auction.highestBidder != address(0)) {
                auction.settled = true;
                _settleAuction(auctionId);
                totalAuctionsWon[auction.highestBidder]++;
                emit AuctionSettled(auctionId, auction.highestBidder, auction.highestBid);
            } else {
                // Reserve not met or no bids - cancel auction
                auction.settled = true;
                // Refund highest bidder if any
                if (auction.highestBidder != address(0)) {
                    pendingReturns[auctionId][auction.highestBidder] += auction.highestBid;
                }
                emit AuctionCancelled(auctionId);
            }
        } else {
            // Dutch auction with no buyer - mark as settled/cancelled
            auction.settled = true;
            emit AuctionCancelled(auctionId);
        }
    }

    /**
     * @notice Cancel an auction (only before first bid)
     * @param auctionId Auction to cancel
     */
    function cancelAuction(bytes32 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.seller == msg.sender, "Not seller");
        require(!auction.settled, "Already settled");
        require(auction.bidCount == 0, "Has bids");

        auction.settled = true;
        emit AuctionCancelled(auctionId);
    }

    /**
     * @notice Withdraw pending returns
     * @param auctionId Auction identifier
     */
    function withdrawPendingReturns(bytes32 auctionId) external nonReentrant {
        uint256 amount = pendingReturns[auctionId][msg.sender];
        require(amount > 0, "No pending returns");

        pendingReturns[auctionId][msg.sender] = 0;

        Auction memory auction = auctions[auctionId];
        if (auction.paymentToken == address(0)) {
            payable(msg.sender).transfer(amount);
        } else {
            IERC20(auction.paymentToken).safeTransfer(msg.sender, amount);
        }

        emit BidRefunded(auctionId, msg.sender, amount);
    }

    // ============ Internal Functions ============

    /**
     * @dev Settle auction by transferring NFT and distributing payments
     */
    function _settleAuction(bytes32 auctionId) internal {
        Auction memory auction = auctions[auctionId];

        // Calculate fees and royalties
        (uint256 platformFee, uint256 royaltyAmount, address royaltyReceiver) = _calculateFees(
            auction.nftContract,
            auction.tokenId,
            auction.highestBid
        );

        uint256 sellerProceeds = auction.highestBid - platformFee - royaltyAmount;

        // Distribute payments
        if (auction.paymentToken == address(0)) {
            // AVAX payments
            if (platformFee > 0) {
                payable(treasury).transfer(platformFee);
            }
            if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
                payable(royaltyReceiver).transfer(royaltyAmount);
            }
            payable(auction.seller).transfer(sellerProceeds);
        } else {
            // ERC20 payments
            if (platformFee > 0) {
                IERC20(auction.paymentToken).safeTransfer(treasury, platformFee);
            }
            if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
                IERC20(auction.paymentToken).safeTransfer(royaltyReceiver, royaltyAmount);
            }
            IERC20(auction.paymentToken).safeTransfer(auction.seller, sellerProceeds);
        }

        // Transfer NFT
        if (auction.isERC1155) {
            IERC1155(auction.nftContract).safeTransferFrom(
                auction.seller,
                auction.highestBidder,
                auction.tokenId,
                auction.amount,
                ""
            );
        } else {
            IERC721(auction.nftContract).safeTransferFrom(
                auction.seller,
                auction.highestBidder,
                auction.tokenId
            );
        }
    }

    /**
     * @dev Calculate platform fees and royalties
     */
    function _calculateFees(
        address nftContract,
        uint256 tokenId,
        uint256 salePrice
    ) internal view returns (uint256 platformFee, uint256 royaltyAmount, address royaltyReceiver) {
        // Platform fee
        platformFee = (salePrice * PLATFORM_FEE_BPS) / 10000;

        // Check for ERC2981 royalty
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
            // No royalty or error
            royaltyAmount = 0;
            royaltyReceiver = address(0);
        }
    }

    /**
     * @dev Get effective bid amount with veNFT multiplier
     */
    function _getEffectiveBid(address bidder, uint256 bidAmount) internal view returns (uint256) {
        if (VOTING_ESCROW == address(0)) {
            return bidAmount;
        }

        try IVotingEscrow(VOTING_ESCROW).balanceOf(bidder) returns (uint256 balance) {
            if (balance > 0) {
                // Get highest tier for maximum multiplier
                uint8 maxTier = _getUserMaxTier(bidder);
                uint256 multiplier = tierMultipliers[maxTier];
                return (bidAmount * multiplier) / 10000;
            }
        } catch {}

        return bidAmount;
    }

    /**
     * @dev Get user's maximum veNFT tier
     */
    function _getUserMaxTier(address user) internal view returns (uint8) {
        // Simplified - in production would check actual tiers
        return 2; // Default tier 2 for any veNFT holder
    }

    /**
     * @dev Verify NFT ownership and approval
     */
    function _verifyNFTOwnership(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        bool isERC1155
    ) internal view {
        if (isERC1155) {
            require(amount > 0, "Invalid amount");
            require(
                IERC1155(nftContract).balanceOf(msg.sender, tokenId) >= amount,
                "Insufficient balance"
            );
            require(
                IERC1155(nftContract).isApprovedForAll(msg.sender, address(this)),
                "Not approved"
            );
        } else {
            require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");
            require(
                IERC721(nftContract).isApprovedForAll(msg.sender, address(this)) ||
                IERC721(nftContract).getApproved(tokenId) == address(this),
                "Not approved"
            );
        }
    }

    /**
     * @dev Check if contract is ERC1155
     */
    function _isERC1155(address nftContract) internal view returns (bool) {
        try IERC165(nftContract).supportsInterface(0xd9b67a26) returns (bool result) {
            return result;
        } catch {
            return false;
        }
    }

    /**
     * @dev Generate auction ID
     */
    function _generateAuctionId(
        address seller,
        address nftContract,
        uint256 tokenId
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(seller, nftContract, tokenId, block.timestamp));
    }

    // ============ View Functions ============

    /**
     * @notice Get current price for Dutch auction
     * @param auctionId Auction identifier
     * @return Current price
     */
    function getCurrentDutchPrice(bytes32 auctionId) public view returns (uint256) {
        Auction memory auction = auctions[auctionId];
        require(auction.auctionType == AuctionType.Dutch, "Not Dutch auction");

        if (block.timestamp >= auction.endTime) {
            return auction.endPrice;
        }

        uint256 elapsed = block.timestamp - auction.startTime;
        uint256 duration = auction.endTime - auction.startTime;
        uint256 priceDrop = auction.startPrice - auction.endPrice;

        uint256 currentDrop = (priceDrop * elapsed) / duration;
        return auction.startPrice - currentDrop;
    }

    /**
     * @notice Get bid history for an auction
     * @param auctionId Auction identifier
     * @return Bid history
     */
    function getBidHistory(bytes32 auctionId) external view returns (Bid[] memory) {
        return auctionBids[auctionId];
    }

    /**
     * @notice Get user's pending returns across all auctions
     * @param user User address
     * @param auctionIds Array of auction IDs to check
     * @return total Total pending returns
     */
    function getUserPendingReturns(
        address user,
        bytes32[] calldata auctionIds
    ) external view returns (uint256 total) {
        for (uint256 i = 0; i < auctionIds.length; i++) {
            total += pendingReturns[auctionIds[i]][user];
        }
    }

    // ============ Admin Functions ============

    /**
     * @notice Update tier multipliers
     * @param tier Tier number
     * @param multiplier Multiplier in basis points
     */
    function setTierMultiplier(uint8 tier, uint256 multiplier) external onlyAdmin {
        require(multiplier >= 10000 && multiplier <= 20000, "Invalid multiplier");
        tierMultipliers[tier] = multiplier;
    }

    /**
     * @notice Update treasury
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyAdmin {
        require(newTreasury != address(0), "Invalid address");
        treasury = newTreasury;
    }

    /**
     * @notice Pause auctions
     */
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @notice Unpause auctions
     */
    function unpause() external onlyAdmin {
        _unpause();
    }

    receive() external payable {}
}

// Interfaces
interface IVotingEscrow {
    function balanceOf(address owner) external view returns (uint256);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}