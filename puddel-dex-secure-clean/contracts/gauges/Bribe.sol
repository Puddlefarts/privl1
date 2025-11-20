// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBribe.sol";
import "../interfaces/IVoter.sol";
import "../interfaces/IVotingEscrow.sol";
import "../security/ReentrancyGuard.sol";

/**
 * @title Bribe - Per-Gauge Bribe Vault
 * @notice Protocols deposit bribes per epoch, voters claim pro-rata by vote weight
 * @dev One Bribe contract per Gauge, epoch-scoped incentives
 */
contract Bribe is IBribe, ReentrancyGuard {
    address public immutable gauge;
    IVoter public immutable voter;
    IVotingEscrow public immutable ve;

    // epoch => token => total bribe amount
    mapping(uint256 => mapping(IERC20 => uint256)) public bribeAmount;
    // epoch => token => tokenId => claimed amount
    mapping(uint256 => mapping(IERC20 => mapping(uint256 => uint256))) public claimed;

    constructor(address _gauge, IVoter _voter, IVotingEscrow _ve) {
        require(_gauge != address(0), "Bribe: zero gauge");
        gauge = _gauge;
        voter = _voter;
        ve = _ve;
    }

    /**
     * @notice Deposit bribe for an epoch
     * @param token The ERC20 token to deposit
     * @param amount Amount to deposit
     * @param epoch Target epoch for the bribe
     */
    function depositBribe(
        IERC20 token,
        uint256 amount,
        uint256 epoch
    ) external override nonReentrant {
        require(amount > 0, "Bribe: zero amount");
        require(epoch >= voter.currentEpoch(), "Bribe: past epoch");

        require(token.transferFrom(msg.sender, address(this), amount), "Bribe: transfer failed");

        bribeAmount[epoch][token] += amount;

        emit BribeDeposited(epoch, address(token), amount, msg.sender);
    }

    /**
     * @notice Claim bribes for a veNFT across multiple tokens and epochs
     * @param tokenId The veNFT that voted
     * @param tokens Array of bribe tokens to claim
     * @param epochs Array of epochs to claim from
     */
    function claim(
        uint256 tokenId,
        address[] calldata tokens,
        uint256[] calldata epochs
    ) external override nonReentrant {
        require(ve.ownerOf(tokenId) == msg.sender, "Bribe: not owner");
        require(tokens.length == epochs.length, "Bribe: length mismatch");

        for (uint i = 0; i < tokens.length; i++) {
            _claimBribe(tokenId, IERC20(tokens[i]), epochs[i]);
        }
    }

    /**
     * @dev Internal claim logic
     */
    function _claimBribe(uint256 tokenId, IERC20 token, uint256 epoch) internal {
        require(epoch < voter.currentEpoch(), "Bribe: epoch not ended");

        uint256 amount = claimable(tokenId, token, epoch);
        if (amount == 0) return;

        claimed[epoch][token][tokenId] = amount;
        require(token.transfer(msg.sender, amount), "Bribe: transfer failed");

        emit BribeClaimed(epoch, address(token), msg.sender, amount);
    }

    /**
     * @notice Calculate claimable bribe for a veNFT
     * @param tokenId The veNFT that voted
     * @param token The bribe token
     * @param epoch The epoch to check
     * @return Claimable amount
     */
    function claimable(
        uint256 tokenId,
        IERC20 token,
        uint256 epoch
    ) public view override returns (uint256) {
        // Already claimed?
        if (claimed[epoch][token][tokenId] > 0) return 0;

        // Get total bribe for this epoch/token
        uint256 totalBribe = bribeAmount[epoch][token];
        if (totalBribe == 0) return 0;

        // Get vote weight for this token on this gauge in this epoch
        uint256 userVote = voter.votes(tokenId, gauge);
        if (userVote == 0) return 0;

        // Get total gauge weight for this epoch
        uint256 totalGaugeWeight = voter.epochGaugeWeight(epoch, gauge);
        if (totalGaugeWeight == 0) return 0;

        // Pro-rata share: (userVote / totalGaugeWeight) * totalBribe
        return (totalBribe * userVote) / totalGaugeWeight;
    }
}
