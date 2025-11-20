// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title PuddelErrors
 * @dev Comprehensive error definitions for the Puddel DEX system
 * @notice Using custom errors for gas efficiency and better error handling
 */
library PuddelErrors {
    // ============ General Errors ============
    
    /// @notice Thrown when a zero address is provided where a valid address is required
    /// @param addr The invalid address
    error InvalidAddress(address addr);
    
    /// @notice Thrown when an invalid amount is provided (zero or exceeds limits)
    /// @param provided The invalid amount that was provided
    /// @param minimum The minimum allowed amount
    /// @param maximum The maximum allowed amount
    error InvalidAmount(uint256 provided, uint256 minimum, uint256 maximum);
    
    /// @notice Thrown when deadline has passed
    /// @param deadline The provided deadline
    /// @param currentTime The current block timestamp
    error DeadlineExpired(uint256 deadline, uint256 currentTime);
    
    /// @notice Thrown when caller is not authorized for the operation
    /// @param caller The address that attempted the operation
    /// @param required The address that is authorized
    error Unauthorized(address caller, address required);
    
    // ============ Liquidity Errors ============
    
    /// @notice Thrown when insufficient liquidity exists for an operation
    /// @param available The available liquidity
    /// @param required The required liquidity
    error InsufficientLiquidity(uint256 available, uint256 required);
    
    /// @notice Thrown when liquidity amounts don't meet minimum requirements
    /// @param amountA The amount of token A
    /// @param amountB The amount of token B
    /// @param minA The minimum required amount of token A
    /// @param minB The minimum required amount of token B
    error InsufficientLiquidityAmounts(uint256 amountA, uint256 amountB, uint256 minA, uint256 minB);
    
    /// @notice Thrown when attempting to mint liquidity but insufficient amounts provided
    /// @param liquidity The calculated liquidity amount
    /// @param minimum The minimum required liquidity
    error InsufficientLiquidityMinted(uint256 liquidity, uint256 minimum);
    
    /// @notice Thrown when attempting to burn more liquidity than available
    /// @param requested The requested amount to burn
    /// @param available The available amount to burn
    error InsufficientLiquidityToBurn(uint256 requested, uint256 available);
    
    // ============ Swap Errors ============
    
    /// @notice Thrown when swap input amount is invalid
    /// @param provided The provided input amount
    /// @param minimum The minimum required input amount
    error InsufficientInputAmount(uint256 provided, uint256 minimum);
    
    /// @notice Thrown when swap output amount is below minimum
    /// @param received The received output amount
    /// @param minimum The minimum required output amount
    error InsufficientOutputAmount(uint256 received, uint256 minimum);
    
    /// @notice Thrown when swap input amount exceeds maximum allowed
    /// @param provided The provided input amount
    /// @param maximum The maximum allowed input amount
    error ExcessiveInputAmount(uint256 provided, uint256 maximum);
    
    /// @notice Thrown when swap path is invalid
    /// @param pathLength The length of the provided path
    /// @param minLength The minimum required path length
    /// @param maxLength The maximum allowed path length
    error InvalidPath(uint256 pathLength, uint256 minLength, uint256 maxLength);
    
    /// @notice Thrown when swap path contains duplicate addresses
    /// @param duplicateAddress The address that appears multiple times
    /// @param position1 First position of the duplicate
    /// @param position2 Second position of the duplicate
    error DuplicateAddressInPath(address duplicateAddress, uint256 position1, uint256 position2);
    
    // ============ Pair Errors ============
    
    /// @notice Thrown when pair doesn't exist
    /// @param tokenA First token address
    /// @param tokenB Second token address
    error PairNotFound(address tokenA, address tokenB);
    
    /// @notice Thrown when attempting to create a pair that already exists
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @param existingPair The address of the existing pair
    error PairAlreadyExists(address tokenA, address tokenB, address existingPair);
    
    /// @notice Thrown when pair is locked (reentrancy protection)
    error PairLocked();
    
    /// @notice Thrown when K invariant is violated
    /// @param currentK The current K value
    /// @param requiredK The required minimum K value
    error KInvariantViolated(uint256 currentK, uint256 requiredK);
    
    // ============ Access Control Errors ============
    
    /// @notice Thrown when operation is forbidden for the caller
    /// @param caller The address that attempted the operation
    error Forbidden(address caller);
    
    /// @notice Thrown when contract is paused
    error ContractPaused();
    
    /// @notice Thrown when trying to pause an already paused contract
    error AlreadyPaused();
    
    /// @notice Thrown when trying to unpause a non-paused contract
    error NotPaused();
    
    // ============ Security Errors ============
    
    /// @notice Thrown when reentrancy is detected
    error ReentrancyDetected();
    
    /// @notice Thrown when operation would cause integer overflow
    /// @param value The value that would cause overflow
    /// @param maxValue The maximum allowed value
    error IntegerOverflow(uint256 value, uint256 maxValue);
    
    /// @notice Thrown when operation would cause integer underflow
    /// @param value The value that would cause underflow
    /// @param minValue The minimum allowed value
    error IntegerUnderflow(uint256 value, uint256 minValue);
    
    // ============ Configuration Errors ============
    
    /// @notice Thrown when slippage tolerance is invalid
    /// @param provided The provided slippage value
    /// @param maximum The maximum allowed slippage
    error InvalidSlippage(uint256 provided, uint256 maximum);
    
    /// @notice Thrown when network configuration is invalid
    /// @param chainId The chain ID that has invalid configuration
    error InvalidNetworkConfiguration(uint256 chainId);
    
    /// @notice Thrown when WAVAX address doesn't match configuration
    /// @param provided The provided WAVAX address
    /// @param expected The expected WAVAX address
    error WAVAXMismatch(address provided, address expected);
    
    // ============ Transfer Errors ============
    
    /// @notice Thrown when token transfer fails
    /// @param token The token address
    /// @param from The sender address
    /// @param to The recipient address
    /// @param amount The transfer amount
    error TransferFailed(address token, address from, address to, uint256 amount);
    
    /// @notice Thrown when insufficient token balance for operation
    /// @param available The available balance  
    /// @param required The required balance
    error InsufficientBalance(uint256 available, uint256 required);
    
    /// @notice Thrown when insufficient allowance for operation
    /// @param available The available allowance
    /// @param required The required allowance
    error InsufficientAllowance(uint256 available, uint256 required);
    
    // ============ Factory Errors ============
    
    /// @notice Thrown when factory operation is not supported
    /// @param operation The operation that was attempted
    error UnsupportedFactoryOperation(string operation);
    
    /// @notice Thrown when trying to set fee recipient to zero address
    error InvalidFeeRecipient();
    
    // ============ Emergency Errors ============
    
    /// @notice Thrown when emergency withdrawal fails
    /// @param token The token address
    /// @param amount The withdrawal amount
    error EmergencyWithdrawalFailed(address token, uint256 amount);
    
    /// @notice Thrown when emergency mode is active and operation is blocked
    error EmergencyModeActive();
    
    // ============ Signature Errors ============
    
    /// @notice Thrown when signature is invalid
    /// @param signer The expected signer
    /// @param recovered The recovered address from signature
    error InvalidSignature(address signer, address recovered);
    
    /// @notice Thrown when signature nonce is invalid
    /// @param provided The provided nonce
    /// @param expected The expected nonce
    error InvalidNonce(uint256 provided, uint256 expected);
    
    // ============ Math Errors ============
    
    /// @notice Thrown when division by zero is attempted
    error DivisionByZero();
    
    /// @notice Thrown when square root calculation fails
    /// @param value The value for which square root was attempted
    error SquareRootFailed(uint256 value);
    
    // ============ Array Errors ============
    
    /// @notice Thrown when array lengths don't match
    /// @param length1 Length of first array
    /// @param length2 Length of second array
    error ArrayLengthMismatch(uint256 length1, uint256 length2);
    
    /// @notice Thrown when array is empty when it shouldn't be
    error EmptyArray();
    
    /// @notice Thrown when array index is out of bounds
    /// @param index The attempted index
    /// @param arrayLength The actual array length
    error IndexOutOfBounds(uint256 index, uint256 arrayLength);
    
    /// @notice Thrown when array length is invalid
    /// @param length The invalid array length
    error InvalidArrayLength(uint256 length);
    
    // ============ Governance Errors ============
    
    /// @notice Thrown when voting power is insufficient
    /// @param current Current voting power
    /// @param required Required voting power
    error InsufficientVotingPower(uint256 current, uint256 required);
    
    /// @notice Thrown when proposal ID is invalid
    /// @param proposalId The invalid proposal ID
    error InvalidProposalId(uint256 proposalId);
    
    /// @notice Thrown when vote type is invalid
    /// @param voteType The invalid vote type
    error InvalidVoteType(uint8 voteType);
    
    /// @notice Thrown when voting hasn't started yet
    /// @param currentTime Current timestamp
    /// @param startTime Voting start time
    error VotingNotStarted(uint256 currentTime, uint256 startTime);
    
    /// @notice Thrown when voting has ended
    /// @param currentTime Current timestamp
    /// @param endTime Voting end time
    error VotingEnded(uint256 currentTime, uint256 endTime);
    
    /// @notice Thrown when user has already voted
    /// @param voter The voter address
    error AlreadyVoted(address voter);
    
    /// @notice Thrown when proposal is already executed
    /// @param proposalId The proposal ID
    error ProposalAlreadyExecuted(uint256 proposalId);
    
    /// @notice Thrown when proposal is canceled
    /// @param proposalId The proposal ID
    error ProposalCanceled(uint256 proposalId);
    
    /// @notice Thrown when voting hasn't ended yet
    /// @param currentTime Current timestamp
    /// @param endTime Voting end time
    error VotingNotEnded(uint256 currentTime, uint256 endTime);
    
    /// @notice Thrown when quorum is not reached
    /// @param votes Total votes cast
    /// @param required Required quorum
    error QuorumNotReached(uint256 votes, uint256 required);
    
    /// @notice Thrown when proposal doesn't pass
    /// @param forVotes Votes for the proposal
    /// @param againstVotes Votes against the proposal
    error ProposalNotPassed(uint256 forVotes, uint256 againstVotes);
    
    /// @notice Thrown when execution fails
    /// @param index The index of the failed operation
    error ExecutionFailed(uint256 index);
    
    /// @notice Thrown when proposal is already canceled
    /// @param proposalId The proposal ID
    error ProposalAlreadyCanceled(uint256 proposalId);
    
    // ============ Emissions Errors ============
    
    /// @notice Thrown when time range is invalid
    /// @param startTime Start time
    /// @param endTime End time
    error InvalidTimeRange(uint256 startTime, uint256 endTime);
    
    /// @notice Thrown when timestamp is invalid
    /// @param timestamp The invalid timestamp
    error InvalidTimestamp(uint256 timestamp);
    
    /// @notice Thrown when schedule ID is invalid
    /// @param scheduleId The invalid schedule ID
    error InvalidScheduleId(uint256 scheduleId);
    
    /// @notice Thrown when pool already exists
    /// @param pool The pool address
    error PoolAlreadyExists(address pool);
    
    /// @notice Thrown when pool is not found
    /// @param pool The pool address
    error PoolNotFound(address pool);
    
}