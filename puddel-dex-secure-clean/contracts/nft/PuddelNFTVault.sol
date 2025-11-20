// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../security/ReentrancyGuard.sol";
import "../security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PuddelNFTVault
 * @notice Advanced NFT-Fi features: loans, fractionalization, staking, and liquidations
 * @dev Integrates with veNFT system for enhanced benefits and PeL rewards
 */
contract PuddelNFTVault is ReentrancyGuard, Pausable, ERC721Holder, Ownable {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant MAX_LTV = 5000; // 50% max loan-to-value
    uint256 public constant LIQUIDATION_THRESHOLD = 8000; // 80% LTV triggers liquidation
    uint256 public constant LIQUIDATION_PENALTY = 500; // 5% liquidation penalty
    uint256 public constant MIN_LOAN_DURATION = 1 days;
    uint256 public constant MAX_LOAN_DURATION = 90 days;
    uint256 public constant PLATFORM_FEE_BPS = 100; // 1% platform fee
    uint256 public constant FRACTION_DECIMALS = 18;
    uint256 public constant TOTAL_FRACTIONS = 10000 * 10**FRACTION_DECIMALS; // 10,000 shares

    // Core contracts
    address public immutable VOTING_ESCROW;
    address public immutable PEL_TOKEN;
    address public treasury;

    // Loan structure
    struct Loan {
        address borrower;
        address nftContract;
        uint256 tokenId;
        address lendingToken; // Token borrowed (AVAX if address(0))
        uint256 principal;
        uint256 interestRate; // Annual rate in BPS
        uint256 startTime;
        uint256 duration;
        uint256 floorPrice; // Floor price at loan creation
        bool active;
        bool liquidated;
    }

    // Fractional NFT structure
    struct FractionalNFT {
        address nftContract;
        uint256 tokenId;
        address fractionalToken; // ERC20 representing shares
        address curator; // Original owner/curator
        uint256 reservePrice; // Buyout reserve price
        uint256 auctionEndTime; // Buyout auction end time
        address highestBidder;
        uint256 highestBid;
        bool redeemed;
    }

    // NFT Staking structure
    struct StakedNFT {
        address owner;
        address nftContract;
        uint256 tokenId;
        uint256 stakedAt;
        uint256 lastRewardClaim;
        uint256 accumulatedRewards;
    }

    // State mappings
    mapping(bytes32 => Loan) public loans;
    mapping(bytes32 => FractionalNFT) public fractionalNFTs;
    mapping(bytes32 => StakedNFT) public stakedNFTs;

    // Lending pools
    mapping(address => uint256) public lendingPools; // Token => available liquidity
    mapping(address => mapping(address => uint256)) public lenderDeposits; // Token => lender => amount

    // Floor price oracles (simplified - in production use Chainlink)
    mapping(address => uint256) public collectionFloorPrices;

    // veNFT benefits
    mapping(uint8 => uint256) public ltvBonus; // Tier => additional LTV in BPS
    mapping(uint8 => uint256) public interestDiscount; // Tier => discount in BPS

    // Staking rewards configuration
    mapping(address => uint256) public stakingRewardRates; // Collection => PeL per second
    mapping(address => uint256) public collectionMultipliers; // Collection => reward multiplier

    // Fractional token factory
    mapping(bytes32 => address) public fractionTokens; // NFT ID => ERC20 token

    // Events
    event LoanCreated(
        bytes32 indexed loanId,
        address indexed borrower,
        address nftContract,
        uint256 tokenId,
        uint256 principal,
        uint256 interestRate
    );

    event LoanRepaid(bytes32 indexed loanId, uint256 totalPaid);
    event LoanLiquidated(bytes32 indexed loanId, address liquidator, uint256 penalty);

    event NFTFractionalized(
        bytes32 indexed nftId,
        address indexed curator,
        address nftContract,
        uint256 tokenId,
        address fractionalToken
    );

    event FractionalBuyout(bytes32 indexed nftId, address buyer, uint256 price);

    event NFTStaked(bytes32 indexed stakeId, address owner, address nftContract, uint256 tokenId);
    event NFTUnstaked(bytes32 indexed stakeId, uint256 rewardsClaimed);
    event RewardsClaimed(bytes32 indexed stakeId, uint256 amount);

    event LiquidityDeposited(address indexed lender, address token, uint256 amount);
    event LiquidityWithdrawn(address indexed lender, address token, uint256 amount);
    event FloorPriceUpdated(address indexed collection, uint256 newFloor);

    constructor(
        address _votingEscrow,
        address _pelToken,
        address _treasury
    ) {
        VOTING_ESCROW = _votingEscrow;
        PEL_TOKEN = _pelToken;
        treasury = _treasury;

        // Initialize veNFT benefits
        ltvBonus[0] = 200; // Tier 0: +2% LTV
        ltvBonus[1] = 400; // Tier 1: +4% LTV
        ltvBonus[2] = 600; // Tier 2: +6% LTV
        ltvBonus[3] = 800; // Tier 3: +8% LTV
        ltvBonus[4] = 1000; // Tier 4: +10% LTV

        interestDiscount[0] = 50;  // Tier 0: 0.5% discount
        interestDiscount[1] = 100; // Tier 1: 1% discount
        interestDiscount[2] = 150; // Tier 2: 1.5% discount
        interestDiscount[3] = 200; // Tier 3: 2% discount
        interestDiscount[4] = 300; // Tier 4: 3% discount
    }

    // ============ Lending Functions ============

    /**
     * @notice Deposit liquidity to lending pool
     * @param token Token to deposit (address(0) for AVAX)
     * @param amount Amount to deposit
     */
    function depositLiquidity(address token, uint256 amount) external payable nonReentrant {
        if (token == address(0)) {
            require(msg.value == amount, "Incorrect AVAX amount");
            lendingPools[token] += amount;
            lenderDeposits[token][msg.sender] += amount;
        } else {
            require(msg.value == 0, "No AVAX needed");
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            lendingPools[token] += amount;
            lenderDeposits[token][msg.sender] += amount;
        }

        emit LiquidityDeposited(msg.sender, token, amount);
    }

    /**
     * @notice Withdraw liquidity from lending pool
     * @param token Token to withdraw
     * @param amount Amount to withdraw
     */
    function withdrawLiquidity(address token, uint256 amount) external nonReentrant {
        require(lenderDeposits[token][msg.sender] >= amount, "Insufficient deposit");
        require(lendingPools[token] >= amount, "Insufficient liquidity");

        lenderDeposits[token][msg.sender] -= amount;
        lendingPools[token] -= amount;

        if (token == address(0)) {
            payable(msg.sender).transfer(amount);
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }

        emit LiquidityWithdrawn(msg.sender, token, amount);
    }

    /**
     * @notice Borrow against an NFT
     * @param nftContract NFT contract address
     * @param tokenId Token ID
     * @param lendingToken Token to borrow
     * @param amount Amount to borrow
     * @param duration Loan duration in seconds
     */
    function borrowAgainstNFT(
        address nftContract,
        uint256 tokenId,
        address lendingToken,
        uint256 amount,
        uint256 duration
    ) external whenNotPaused nonReentrant returns (bytes32 loanId) {
        require(duration >= MIN_LOAN_DURATION && duration <= MAX_LOAN_DURATION, "Invalid duration");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");
        require(lendingPools[lendingToken] >= amount, "Insufficient liquidity");

        // Calculate max LTV based on floor price and veNFT tier
        uint256 floorPrice = collectionFloorPrices[nftContract];
        require(floorPrice > 0, "No floor price");

        uint256 maxLTV = MAX_LTV + _getUserLTVBonus(msg.sender);
        uint256 maxLoan = (floorPrice * maxLTV) / 10000;
        require(amount <= maxLoan, "Exceeds max LTV");

        // Transfer NFT to vault
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        // Calculate interest rate with veNFT discount
        uint256 baseRate = 1000; // 10% annual base rate
        uint256 discount = _getUserInterestDiscount(msg.sender);
        uint256 interestRate = baseRate > discount ? baseRate - discount : 100; // Min 1%

        // Create loan
        loanId = keccak256(abi.encodePacked(msg.sender, nftContract, tokenId, block.timestamp));
        loans[loanId] = Loan({
            borrower: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            lendingToken: lendingToken,
            principal: amount,
            interestRate: interestRate,
            startTime: block.timestamp,
            duration: duration,
            floorPrice: floorPrice,
            active: true,
            liquidated: false
        });

        // Transfer funds to borrower
        lendingPools[lendingToken] -= amount;
        if (lendingToken == address(0)) {
            payable(msg.sender).transfer(amount);
        } else {
            IERC20(lendingToken).safeTransfer(msg.sender, amount);
        }

        emit LoanCreated(loanId, msg.sender, nftContract, tokenId, amount, interestRate);
    }

    /**
     * @notice Repay a loan and retrieve NFT
     * @param loanId Loan identifier
     */
    function repayLoan(bytes32 loanId) external payable nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.active, "Loan not active");
        require(loan.borrower == msg.sender, "Not borrower");

        // Calculate total repayment
        uint256 timeElapsed = block.timestamp - loan.startTime;
        uint256 interest = (loan.principal * loan.interestRate * timeElapsed) / (365 days * 10000);
        uint256 totalRepayment = loan.principal + interest;

        // Platform fee
        uint256 platformFee = (interest * PLATFORM_FEE_BPS) / 10000;

        // Handle repayment
        if (loan.lendingToken == address(0)) {
            require(msg.value >= totalRepayment, "Insufficient payment");

            // Return funds to pool
            lendingPools[loan.lendingToken] += loan.principal + interest - platformFee;

            // Send platform fee to treasury
            if (platformFee > 0) {
                payable(treasury).transfer(platformFee);
            }

            // Refund excess
            if (msg.value > totalRepayment) {
                payable(msg.sender).transfer(msg.value - totalRepayment);
            }
        } else {
            IERC20(loan.lendingToken).safeTransferFrom(msg.sender, address(this), totalRepayment);
            lendingPools[loan.lendingToken] += loan.principal + interest - platformFee;

            if (platformFee > 0) {
                IERC20(loan.lendingToken).safeTransfer(treasury, platformFee);
            }
        }

        // Return NFT
        IERC721(loan.nftContract).safeTransferFrom(address(this), msg.sender, loan.tokenId);

        // Mark loan as repaid
        loan.active = false;

        emit LoanRepaid(loanId, totalRepayment);
    }

    /**
     * @notice Liquidate an underwater loan
     * @param loanId Loan to liquidate
     */
    function liquidateLoan(bytes32 loanId) external payable nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.active, "Loan not active");
        require(block.timestamp > loan.startTime + loan.duration, "Loan not expired");

        // Calculate current LTV
        uint256 currentFloor = collectionFloorPrices[loan.nftContract];
        uint256 currentLTV = (loan.principal * 10000) / currentFloor;

        // Check if liquidatable
        require(
            currentLTV >= LIQUIDATION_THRESHOLD ||
            block.timestamp > loan.startTime + loan.duration,
            "Not liquidatable"
        );

        // Calculate liquidation price (principal + penalty)
        uint256 liquidationPrice = loan.principal + (loan.principal * LIQUIDATION_PENALTY) / 10000;

        // Handle payment from liquidator
        if (loan.lendingToken == address(0)) {
            require(msg.value >= liquidationPrice, "Insufficient payment");

            // Return principal to pool
            lendingPools[loan.lendingToken] += loan.principal;

            // Penalty to treasury
            uint256 penalty = liquidationPrice - loan.principal;
            if (penalty > 0) {
                payable(treasury).transfer(penalty);
            }

            // Refund excess
            if (msg.value > liquidationPrice) {
                payable(msg.sender).transfer(msg.value - liquidationPrice);
            }
        } else {
            IERC20(loan.lendingToken).safeTransferFrom(msg.sender, address(this), liquidationPrice);
            lendingPools[loan.lendingToken] += loan.principal;

            uint256 penalty = liquidationPrice - loan.principal;
            if (penalty > 0) {
                IERC20(loan.lendingToken).safeTransfer(treasury, penalty);
            }
        }

        // Transfer NFT to liquidator
        IERC721(loan.nftContract).safeTransferFrom(address(this), msg.sender, loan.tokenId);

        // Mark as liquidated
        loan.active = false;
        loan.liquidated = true;

        emit LoanLiquidated(loanId, msg.sender, liquidationPrice - loan.principal);
    }

    // ============ Fractionalization Functions ============

    /**
     * @notice Fractionalize an NFT into ERC20 shares
     * @param nftContract NFT contract address
     * @param tokenId Token ID
     * @param name Token name
     * @param symbol Token symbol
     * @param reservePrice Buyout reserve price
     */
    function fractionalizeNFT(
        address nftContract,
        uint256 tokenId,
        string memory name,
        string memory symbol,
        uint256 reservePrice
    ) external whenNotPaused nonReentrant returns (address fractionalToken) {
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");
        require(reservePrice > 0, "Invalid reserve price");

        // Transfer NFT to vault
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        // Deploy fractional token
        fractionalToken = address(new FractionalToken(name, symbol, TOTAL_FRACTIONS, msg.sender));

        // Store fractional NFT data
        bytes32 nftId = keccak256(abi.encodePacked(nftContract, tokenId));
        fractionalNFTs[nftId] = FractionalNFT({
            nftContract: nftContract,
            tokenId: tokenId,
            fractionalToken: fractionalToken,
            curator: msg.sender,
            reservePrice: reservePrice,
            auctionEndTime: 0,
            highestBidder: address(0),
            highestBid: 0,
            redeemed: false
        });

        fractionTokens[nftId] = fractionalToken;

        emit NFTFractionalized(nftId, msg.sender, nftContract, tokenId, fractionalToken);
    }

    /**
     * @notice Start buyout auction for fractional NFT
     * @param nftContract NFT contract
     * @param tokenId Token ID
     */
    function startBuyoutAuction(
        address nftContract,
        uint256 tokenId
    ) external payable whenNotPaused nonReentrant {
        bytes32 nftId = keccak256(abi.encodePacked(nftContract, tokenId));
        FractionalNFT storage fractional = fractionalNFTs[nftId];

        require(fractional.curator != address(0), "Not fractionalized");
        require(!fractional.redeemed, "Already redeemed");
        require(fractional.auctionEndTime == 0, "Auction active");
        require(msg.value >= fractional.reservePrice, "Below reserve");

        // Start 7-day buyout auction
        fractional.auctionEndTime = block.timestamp + 7 days;
        fractional.highestBidder = msg.sender;
        fractional.highestBid = msg.value;
    }

    /**
     * @notice Complete buyout and redeem NFT
     * @param nftContract NFT contract
     * @param tokenId Token ID
     */
    function completeBuyout(
        address nftContract,
        uint256 tokenId
    ) external nonReentrant {
        bytes32 nftId = keccak256(abi.encodePacked(nftContract, tokenId));
        FractionalNFT storage fractional = fractionalNFTs[nftId];

        require(fractional.auctionEndTime > 0, "No auction");
        require(block.timestamp > fractional.auctionEndTime, "Auction not ended");
        require(!fractional.redeemed, "Already redeemed");
        require(fractional.highestBidder == msg.sender, "Not winner");

        // Transfer NFT to winner
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);

        // Mark as redeemed
        fractional.redeemed = true;

        emit FractionalBuyout(nftId, msg.sender, fractional.highestBid);
    }

    /**
     * @notice Claim proceeds from fractional buyout
     * @param nftContract NFT contract
     * @param tokenId Token ID
     */
    function claimFractionalProceeds(
        address nftContract,
        uint256 tokenId
    ) external nonReentrant {
        bytes32 nftId = keccak256(abi.encodePacked(nftContract, tokenId));
        FractionalNFT memory fractional = fractionalNFTs[nftId];

        require(fractional.redeemed, "Not redeemed");

        // Calculate share of proceeds
        FractionalToken token = FractionalToken(fractional.fractionalToken);
        uint256 userBalance = token.balanceOf(msg.sender);
        require(userBalance > 0, "No shares");

        uint256 proceeds = (fractional.highestBid * userBalance) / TOTAL_FRACTIONS;

        // Burn user's tokens
        token.burnFrom(msg.sender, userBalance);

        // Transfer proceeds
        payable(msg.sender).transfer(proceeds);
    }

    // ============ NFT Staking Functions ============

    /**
     * @notice Stake an NFT for PeL rewards
     * @param nftContract NFT contract
     * @param tokenId Token ID
     */
    function stakeNFT(
        address nftContract,
        uint256 tokenId
    ) external whenNotPaused nonReentrant returns (bytes32 stakeId) {
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");
        require(stakingRewardRates[nftContract] > 0, "Staking not enabled");

        // Transfer NFT to vault
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        // Create stake
        stakeId = keccak256(abi.encodePacked(msg.sender, nftContract, tokenId, block.timestamp));
        stakedNFTs[stakeId] = StakedNFT({
            owner: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            stakedAt: block.timestamp,
            lastRewardClaim: block.timestamp,
            accumulatedRewards: 0
        });

        emit NFTStaked(stakeId, msg.sender, nftContract, tokenId);
    }

    /**
     * @notice Unstake NFT and claim rewards
     * @param stakeId Stake identifier
     */
    function unstakeNFT(bytes32 stakeId) external nonReentrant {
        StakedNFT storage stake = stakedNFTs[stakeId];
        require(stake.owner == msg.sender, "Not owner");

        // Calculate and claim rewards
        uint256 rewards = _calculateStakingRewards(stakeId);
        if (rewards > 0) {
            IERC20(PEL_TOKEN).safeTransfer(msg.sender, rewards);
        }

        // Return NFT
        IERC721(stake.nftContract).safeTransferFrom(address(this), msg.sender, stake.tokenId);

        // Delete stake
        delete stakedNFTs[stakeId];

        emit NFTUnstaked(stakeId, rewards);
    }

    /**
     * @notice Claim staking rewards without unstaking
     * @param stakeId Stake identifier
     */
    function claimStakingRewards(bytes32 stakeId) external nonReentrant {
        StakedNFT storage stake = stakedNFTs[stakeId];
        require(stake.owner == msg.sender, "Not owner");

        uint256 rewards = _calculateStakingRewards(stakeId);
        require(rewards > 0, "No rewards");

        stake.lastRewardClaim = block.timestamp;
        stake.accumulatedRewards = 0;

        IERC20(PEL_TOKEN).safeTransfer(msg.sender, rewards);

        emit RewardsClaimed(stakeId, rewards);
    }

    // ============ Internal Functions ============

    function _calculateStakingRewards(bytes32 stakeId) internal view returns (uint256) {
        StakedNFT memory stake = stakedNFTs[stakeId];
        uint256 timeStaked = block.timestamp - stake.lastRewardClaim;
        uint256 baseRate = stakingRewardRates[stake.nftContract];
        uint256 multiplier = collectionMultipliers[stake.nftContract];

        if (multiplier == 0) multiplier = 10000; // 1x default

        uint256 rewards = (baseRate * timeStaked * multiplier) / 10000;
        return rewards + stake.accumulatedRewards;
    }

    function _getUserLTVBonus(address user) internal view returns (uint256) {
        // Simplified - check veNFT ownership
        try IVotingEscrow(VOTING_ESCROW).balanceOf(user) returns (uint256 balance) {
            if (balance > 0) {
                return ltvBonus[2]; // Default tier 2 bonus
            }
        } catch {}
        return 0;
    }

    function _getUserInterestDiscount(address user) internal view returns (uint256) {
        try IVotingEscrow(VOTING_ESCROW).balanceOf(user) returns (uint256 balance) {
            if (balance > 0) {
                return interestDiscount[2]; // Default tier 2 discount
            }
        } catch {}
        return 0;
    }

    // ============ Admin Functions ============

    /**
     * @notice Update collection floor price
     * @param collection NFT collection address
     * @param floorPrice New floor price in wei
     */
    function updateFloorPrice(address collection, uint256 floorPrice) external onlyOwner {
        collectionFloorPrices[collection] = floorPrice;
        emit FloorPriceUpdated(collection, floorPrice);
    }

    /**
     * @notice Set staking reward rate for a collection
     * @param collection NFT collection
     * @param rewardRate PeL per second
     */
    function setStakingRewardRate(address collection, uint256 rewardRate) external onlyOwner {
        stakingRewardRates[collection] = rewardRate;
    }

    /**
     * @notice Set collection staking multiplier
     * @param collection NFT collection
     * @param multiplier Multiplier in BPS (10000 = 1x)
     */
    function setCollectionMultiplier(address collection, uint256 multiplier) external onlyOwner {
        collectionMultipliers[collection] = multiplier;
    }

    /**
     * @notice Update treasury address
     * @param newTreasury New treasury
     */
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid address");
        treasury = newTreasury;
    }

    /**
     * @notice Emergency pause
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ View Functions ============

    /**
     * @notice Get loan details
     * @param loanId Loan identifier
     */
    function getLoan(bytes32 loanId) external view returns (Loan memory) {
        return loans[loanId];
    }

    /**
     * @notice Calculate current interest on a loan
     * @param loanId Loan identifier
     */
    function calculateCurrentInterest(bytes32 loanId) external view returns (uint256) {
        Loan memory loan = loans[loanId];
        if (!loan.active) return 0;

        uint256 timeElapsed = block.timestamp - loan.startTime;
        return (loan.principal * loan.interestRate * timeElapsed) / (365 days * 10000);
    }

    /**
     * @notice Get available liquidity for lending
     * @param token Token address
     */
    function getAvailableLiquidity(address token) external view returns (uint256) {
        return lendingPools[token];
    }

    /**
     * @notice Check if an NFT is fractionalized
     * @param nftContract NFT contract
     * @param tokenId Token ID
     */
    function isFractionalized(address nftContract, uint256 tokenId) external view returns (bool) {
        bytes32 nftId = keccak256(abi.encodePacked(nftContract, tokenId));
        return fractionalNFTs[nftId].curator != address(0) && !fractionalNFTs[nftId].redeemed;
    }

    receive() external payable {}
}

// ============ Fractional Token Contract ============

/**
 * @title FractionalToken
 * @notice ERC20 token representing fractional ownership of an NFT
 */
contract FractionalToken is ERC20 {
    address public immutable vault;
    address public immutable curator;

    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address _curator
    ) ERC20(name, symbol) {
        vault = msg.sender;
        curator = _curator;
        _mint(_curator, totalSupply);
    }

    /**
     * @notice Allow vault to burn tokens during buyout
     */
    function burnFrom(address account, uint256 amount) external {
        require(msg.sender == vault, "Only vault");
        _burn(account, amount);
    }
}

// ============ Interfaces ============

interface IVotingEscrow {
    function balanceOf(address owner) external view returns (uint256);
}