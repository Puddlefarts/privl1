// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IVotingEscrow.sol";
import "../interfaces/IERC20.sol";
import "../security/ReentrancyGuard.sol";

/**
 * @title VotingEscrow - vePeL (veNFT)
 * @notice Lock PeL tokens to receive veNFT with voting power
 * @dev Constant Duration Multiplier model - power = amount * tierMultiplier * (1 + activityBonus)
 *      Power drops to 0 when lock expires (no linear decay)
 */
contract VotingEscrow is IVotingEscrow, ReentrancyGuard {
    // ERC721 metadata
    string public constant name = "vePeL";
    string public constant symbol = "vePeL";

    IERC20 public immutable PEL;

    mapping(uint256 => Lock) internal _locks;
    mapping(uint256 => address) public override ownerOf;

    function locks(uint256 tokenId) external view override returns (Lock memory) {
        return _locks[tokenId];
    }
    mapping(address => uint256) public balanceOf; // number of NFTs owned
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    // Tier configuration: tier => multiplier in basis points (10000 = 1x)
    mapping(uint8 => uint16) public multiplierBps;
    // Tier configuration: tier => duration in seconds
    mapping(uint8 => uint32) public tierDuration;
    // Activity bonus per tokenId (basis points, e.g., 1000 = +10%)
    mapping(uint256 => uint16) public activityBonusBps;

    uint256 public nextId = 1;
    uint256 public totalPower;

    // Access control
    bytes32 public constant OPS_ROLE = keccak256("OPS_ROLE");
    mapping(bytes32 => mapping(address => bool)) private _roles;
    address public admin;

    uint16 public constant MAX_ACTIVITY_BONUS = 1000; // Max +10% bonus
    uint8 public constant MAX_TIER = 5;

    // ERC721 events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    modifier onlyRole(bytes32 role) {
        require(_roles[role][msg.sender], "VotingEscrow: unauthorized");
        _;
    }

    modifier onlyOwner(uint256 tokenId) {
        require(ownerOf[tokenId] == msg.sender, "VotingEscrow: not owner");
        _;
    }

    constructor(IERC20 pel, address _admin) {
        PEL = pel;
        admin = _admin;
        _roles[OPS_ROLE][_admin] = true;

        // Initialize tier durations and multipliers
        // Tier 0: 1 month (30 days)
        tierDuration[0] = 30 days;
        multiplierBps[0] = 10000; // 1x

        // Tier 1: 3 months
        tierDuration[1] = 90 days;
        multiplierBps[1] = 15000; // 1.5x

        // Tier 2: 6 months
        tierDuration[2] = 180 days;
        multiplierBps[2] = 20000; // 2x

        // Tier 3: 1 year
        tierDuration[3] = 365 days;
        multiplierBps[3] = 30000; // 3x

        // Tier 4: 2 years
        tierDuration[4] = 730 days;
        multiplierBps[4] = 50000; // 5x
    }

    /**
     * @notice Calculate voting power for a token
     * @dev power = amount * (multiplierBps + activityBonusBps) / 10000
     *      Returns 0 if lock has expired
     */
    function votingPower(uint256 tokenId) public view override returns (uint256) {
        Lock memory L = _locks[tokenId];
        if (block.timestamp >= L.end || L.amount == 0) return 0;

        uint256 bps = uint256(multiplierBps[L.tier]) + uint256(activityBonusBps[tokenId]);
        return (uint256(L.amount) * bps) / 10000;
    }

    function totalVotingPower() external view override returns (uint256) {
        return totalPower;
    }

    /**
     * @notice Create a new lock and mint veNFT
     * @param amount Amount of PeL to lock
     * @param tier Lock duration tier (0-4)
     * @return tokenId The ID of the newly minted veNFT
     */
    function createLock(uint128 amount, uint8 tier) external override nonReentrant returns (uint256 tokenId) {
        require(amount > 0, "VotingEscrow: zero amount");
        require(tier <= MAX_TIER, "VotingEscrow: invalid tier");
        require(tierDuration[tier] > 0, "VotingEscrow: tier not configured");

        tokenId = nextId++;
        uint64 end = uint64(block.timestamp + tierDuration[tier]);

        _locks[tokenId] = Lock({
            amount: amount,
            start: uint64(block.timestamp),
            end: end,
            tier: tier
        });

        // Transfer PeL from user to escrow
        require(PEL.transferFrom(msg.sender, address(this), amount), "VotingEscrow: transfer failed");

        // Mint NFT
        ownerOf[tokenId] = msg.sender;
        balanceOf[msg.sender]++;

        // Update total power
        totalPower += votingPower(tokenId);

        emit Transfer(address(0), msg.sender, tokenId);
        emit LockCreated(tokenId, msg.sender, amount, end, tier);
    }

    /**
     * @notice Increase the amount of an existing lock
     * @param tokenId The veNFT to increase
     * @param amount Additional PeL to lock
     */
    function increaseLockAmount(uint256 tokenId, uint128 amount) external override nonReentrant onlyOwner(tokenId) {
        require(amount > 0, "VotingEscrow: zero amount");
        Lock storage lock = _locks[tokenId];
        require(lock.end > block.timestamp, "VotingEscrow: lock expired");

        // Remove old power
        totalPower -= votingPower(tokenId);

        // Update amount
        lock.amount += amount;

        // Add new power
        totalPower += votingPower(tokenId);

        // Transfer additional PeL
        require(PEL.transferFrom(msg.sender, address(this), amount), "VotingEscrow: transfer failed");

        emit LockIncreased(tokenId, amount);
    }

    /**
     * @notice Extend lock duration to a higher tier
     * @param tokenId The veNFT to extend
     * @param newTier New tier (must be >= current tier for longer duration)
     */
    function extendLock(uint256 tokenId, uint8 newTier) external override nonReentrant onlyOwner(tokenId) {
        require(newTier <= MAX_TIER, "VotingEscrow: invalid tier");
        require(tierDuration[newTier] > 0, "VotingEscrow: tier not configured");

        Lock storage lock = _locks[tokenId];
        require(lock.end > block.timestamp, "VotingEscrow: lock expired");

        uint64 newEnd = uint64(block.timestamp + tierDuration[newTier]);
        require(newEnd >= lock.end, "VotingEscrow: can only extend");

        // Remove old power
        totalPower -= votingPower(tokenId);

        // Update lock
        lock.end = newEnd;
        lock.tier = newTier;

        // Add new power
        totalPower += votingPower(tokenId);

        emit LockExtended(tokenId, newEnd, newTier);
    }

    /**
     * @notice Withdraw PeL after lock expires
     * @param tokenId The veNFT to withdraw
     */
    function withdraw(uint256 tokenId) external override nonReentrant onlyOwner(tokenId) {
        Lock memory lock = _locks[tokenId];
        require(block.timestamp >= lock.end, "VotingEscrow: lock not expired");
        require(lock.amount > 0, "VotingEscrow: already withdrawn");

        uint128 amount = lock.amount;

        // Remove power (should be 0 already since expired)
        totalPower -= votingPower(tokenId);

        // Clear lock
        delete _locks[tokenId];

        // Transfer PeL back to owner
        require(PEL.transfer(msg.sender, amount), "VotingEscrow: transfer failed");

        emit Withdrawn(tokenId, msg.sender, amount);
    }

    /**
     * @notice Set activity bonus for a tokenId (OPS only)
     * @param tokenId The veNFT to update
     * @param bonusBps Bonus in basis points (max 1000 = +10%)
     */
    function setActivityBonus(uint256 tokenId, uint16 bonusBps) external onlyRole(OPS_ROLE) {
        require(bonusBps <= MAX_ACTIVITY_BONUS, "VotingEscrow: bonus too high");
        require(ownerOf[tokenId] != address(0), "VotingEscrow: token doesn't exist");

        // Remove old power
        totalPower -= votingPower(tokenId);

        // Update bonus
        activityBonusBps[tokenId] = bonusBps;

        // Add new power
        totalPower += votingPower(tokenId);

        emit ActivityBonusSet(tokenId, bonusBps);
    }

    /**
     * @notice Update tier multiplier (OPS only)
     * @param tier Tier to update
     * @param bps New multiplier in basis points
     */
    function setTierMultiplier(uint8 tier, uint16 bps) external onlyRole(OPS_ROLE) {
        require(tier <= MAX_TIER, "VotingEscrow: invalid tier");
        require(bps >= 10000 && bps <= 100000, "VotingEscrow: multiplier out of range"); // 1x to 10x
        multiplierBps[tier] = bps;
    }

    // ========== ERC721 Basic Functions ==========

    function transferFrom(address from, address to, uint256 tokenId) external {
        require(ownerOf[tokenId] == from, "VotingEscrow: not owner");
        require(
            msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[tokenId],
            "VotingEscrow: not authorized"
        );
        require(to != address(0), "VotingEscrow: zero address");

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        this.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata) external {
        this.transferFrom(from, to, tokenId);
    }

    function approve(address approved, uint256 tokenId) external {
        address owner = ownerOf[tokenId];
        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "VotingEscrow: not authorized");
        getApproved[tokenId] = approved;
        emit Approval(owner, approved, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        delete getApproved[tokenId];
        balanceOf[from]--;
        balanceOf[to]++;
        ownerOf[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    // ERC165 support
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == 0x80ac58cd || // ERC721
            interfaceId == 0x01ffc9a7; // ERC165
    }
}
