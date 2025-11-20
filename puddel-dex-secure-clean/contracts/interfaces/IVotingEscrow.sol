// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVotingEscrow {
    struct Lock {
        uint128 amount;
        uint64 start;
        uint64 end;
        uint8 tier;
    }

    event LockCreated(uint256 indexed tokenId, address indexed owner, uint128 amount, uint64 end, uint8 tier);
    event LockIncreased(uint256 indexed tokenId, uint128 amountAdded);
    event LockExtended(uint256 indexed tokenId, uint64 newEnd, uint8 newTier);
    event Withdrawn(uint256 indexed tokenId, address indexed to, uint128 amount);
    event ActivityBonusSet(uint256 indexed tokenId, uint16 bonusBps);

    function createLock(uint128 amount, uint8 tier) external returns (uint256 tokenId);
    function increaseLockAmount(uint256 tokenId, uint128 amount) external;
    function extendLock(uint256 tokenId, uint8 newTier) external;
    function withdraw(uint256 tokenId) external;

    function votingPower(uint256 tokenId) external view returns (uint256);
    function totalVotingPower() external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function locks(uint256 tokenId) external view returns (Lock memory);
}
