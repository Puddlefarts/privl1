//! # Simple AMM Pallet
//!
//! A simple Automated Market Maker (AMM) pallet for PRIVL1.
//! Ports the constant product formula from PuddelSwap (x * y = k).
//!
//! ## Overview
//!
//! This pallet implements a basic AMM with:
//! - Liquidity pools (pairs of tokens)
//! - Constant product formula (Uniswap V2 style)
//! - 0.25% swap fee (matching PuddelSwap)
//! - Add/remove liquidity
//!
//! This is the PUBLIC version (no privacy yet). Privacy layer comes in Phase 2.

#![cfg_attr(not(feature = "std"), no_std)]

pub use pallet::*;

#[frame_support::pallet]
pub mod pallet {
    use frame_support::pallet_prelude::*;
    use frame_system::pallet_prelude::*;
    use sp_runtime::traits::{CheckedAdd, CheckedDiv, CheckedMul, CheckedSub, One, Zero, AtLeast32BitUnsigned};

    /// The pallet's configuration trait
    #[pallet::config]
    pub trait Config: frame_system::Config {
        /// The overarching event type
        type RuntimeEvent: From<Event<Self>> + IsType<<Self as frame_system::Config>::RuntimeEvent>;

        /// Asset ID type (for now we'll use u32, can be generic later)
        type AssetId: Parameter + Member + Copy + Default + MaxEncodedLen;

        /// Balance type for token amounts
        type Balance: Parameter + Member + Copy + Default + MaxEncodedLen
            + AtLeast32BitUnsigned
            + CheckedAdd + CheckedSub + CheckedMul + CheckedDiv + Zero + One + PartialOrd;
    }

    #[pallet::pallet]
    pub struct Pallet<T>(_);

    /// Liquidity pool data structure
    /// Represents a single AMM pool (token0 <-> token1)
    #[derive(Clone, Encode, Decode, Eq, PartialEq, RuntimeDebug, TypeInfo, MaxEncodedLen)]
    pub struct Pool<AssetId, Balance> {
        /// First token in the pair
        pub token0: AssetId,
        /// Second token in the pair
        pub token1: AssetId,
        /// Reserve of token0
        pub reserve0: Balance,
        /// Reserve of token1
        pub reserve1: Balance,
        /// Total LP token supply for this pool
        pub total_supply: Balance,
    }

    /// Storage: Pools by ID
    /// Maps pool_id -> Pool data
    #[pallet::storage]
    #[pallet::getter(fn pools)]
    pub type Pools<T: Config> = StorageMap<
        _,
        Blake2_128Concat,
        u32, // pool_id
        Pool<T::AssetId, T::Balance>,
    >;

    /// Storage: LP token balances
    /// Maps (pool_id, account) -> LP token balance
    #[pallet::storage]
    #[pallet::getter(fn lp_balances)]
    pub type LpBalances<T: Config> = StorageDoubleMap<
        _,
        Blake2_128Concat,
        u32, // pool_id
        Blake2_128Concat,
        T::AccountId,
        T::Balance,
        ValueQuery,
    >;

    /// Storage: Pool ID counter
    #[pallet::storage]
    #[pallet::getter(fn next_pool_id)]
    pub type NextPoolId<T: Config> = StorageValue<_, u32, ValueQuery>;

    /// Events emitted by this pallet
    #[pallet::event]
    #[pallet::generate_deposit(pub(super) fn deposit_event)]
    pub enum Event<T: Config> {
        /// Pool created [pool_id, token0, token1]
        PoolCreated {
            pool_id: u32,
            token0: T::AssetId,
            token1: T::AssetId,
        },
        /// Liquidity added [pool_id, provider, amount0, amount1, lp_tokens]
        LiquidityAdded {
            pool_id: u32,
            provider: T::AccountId,
            amount0: T::Balance,
            amount1: T::Balance,
            lp_tokens: T::Balance,
        },
        /// Liquidity removed [pool_id, provider, amount0, amount1, lp_tokens_burned]
        LiquidityRemoved {
            pool_id: u32,
            provider: T::AccountId,
            amount0: T::Balance,
            amount1: T::Balance,
            lp_tokens_burned: T::Balance,
        },
        /// Swap executed [pool_id, trader, amount_in, amount_out, token_in, token_out]
        Swapped {
            pool_id: u32,
            trader: T::AccountId,
            amount_in: T::Balance,
            amount_out: T::Balance,
            token_in: T::AssetId,
            token_out: T::AssetId,
        },
    }

    /// Errors that can be returned by this pallet
    #[pallet::error]
    pub enum Error<T> {
        /// Pool does not exist
        PoolNotFound,
        /// Pool already exists for this token pair
        PoolAlreadyExists,
        /// Insufficient liquidity in pool
        InsufficientLiquidity,
        /// Insufficient LP tokens
        InsufficientLpTokens,
        /// Amount is zero
        ZeroAmount,
        /// Slippage tolerance exceeded
        SlippageExceeded,
        /// Math overflow
        Overflow,
        /// Invariant violated (x * y < k)
        InvariantViolated,
    }

    #[pallet::call]
    impl<T: Config> Pallet<T> {
        /// Create a new liquidity pool
        ///
        /// # Arguments
        /// * `token0` - First token ID
        /// * `token1` - Second token ID
        #[pallet::call_index(0)]
        #[pallet::weight(10_000)]
        pub fn create_pool(
            origin: OriginFor<T>,
            token0: T::AssetId,
            token1: T::AssetId,
        ) -> DispatchResult {
            let _who = ensure_signed(origin)?;

            // Get next pool ID
            let pool_id = NextPoolId::<T>::get();

            // Check if pool already exists (we'd need a lookup map in production)
            // For now, skip this check for simplicity

            // Create new pool with zero reserves
            let pool = Pool {
                token0,
                token1,
                reserve0: T::Balance::zero(),
                reserve1: T::Balance::zero(),
                total_supply: T::Balance::zero(),
            };

            // Store pool
            Pools::<T>::insert(pool_id, pool);

            // Increment pool ID counter
            NextPoolId::<T>::put(pool_id.saturating_add(1));

            // Emit event
            Self::deposit_event(Event::PoolCreated {
                pool_id,
                token0,
                token1,
            });

            Ok(())
        }

        /// Add liquidity to a pool
        ///
        /// # Arguments
        /// * `pool_id` - ID of the pool
        /// * `amount0_desired` - Desired amount of token0
        /// * `amount1_desired` - Desired amount of token1
        /// * `amount0_min` - Minimum amount of token0 (slippage protection)
        /// * `amount1_min` - Minimum amount of token1 (slippage protection)
        #[pallet::call_index(1)]
        #[pallet::weight(10_000)]
        pub fn add_liquidity(
            origin: OriginFor<T>,
            pool_id: u32,
            amount0_desired: T::Balance,
            amount1_desired: T::Balance,
            amount0_min: T::Balance,
            amount1_min: T::Balance,
        ) -> DispatchResult {
            let who = ensure_signed(origin)?;

            // Ensure amounts are non-zero
            ensure!(!amount0_desired.is_zero(), Error::<T>::ZeroAmount);
            ensure!(!amount1_desired.is_zero(), Error::<T>::ZeroAmount);

            // Get pool
            let mut pool = Pools::<T>::get(pool_id).ok_or(Error::<T>::PoolNotFound)?;

            // Calculate actual amounts to add based on current reserves
            let (amount0, amount1) = if pool.reserve0.is_zero() || pool.reserve1.is_zero() {
                // First liquidity provider sets the ratio
                (amount0_desired, amount1_desired)
            } else {
                // Subsequent providers must match the ratio
                // amount1_optimal = (amount0_desired * reserve1) / reserve0
                let amount1_optimal = Self::quote(amount0_desired, pool.reserve0, pool.reserve1)?;

                if amount1_optimal <= amount1_desired {
                    ensure!(amount1_optimal >= amount1_min, Error::<T>::SlippageExceeded);
                    (amount0_desired, amount1_optimal)
                } else {
                    let amount0_optimal = Self::quote(amount1_desired, pool.reserve1, pool.reserve0)?;
                    ensure!(amount0_optimal <= amount0_desired, Error::<T>::Overflow);
                    ensure!(amount0_optimal >= amount0_min, Error::<T>::SlippageExceeded);
                    (amount0_optimal, amount1_desired)
                }
            };

            // Calculate LP tokens to mint
            let lp_tokens = if pool.total_supply.is_zero() {
                // First liquidity: sqrt(amount0 * amount1)
                // For simplicity, use geometric mean: (amount0 + amount1) / 2
                // In production, use proper sqrt
                amount0.checked_add(&amount1)
                    .ok_or(Error::<T>::Overflow)?
                    .checked_div(&2u32.into())
                    .ok_or(Error::<T>::Overflow)?
            } else {
                // Subsequent liquidity: min(amount0/reserve0, amount1/reserve1) * totalSupply
                let lp0 = amount0.checked_mul(&pool.total_supply)
                    .ok_or(Error::<T>::Overflow)?
                    .checked_div(&pool.reserve0)
                    .ok_or(Error::<T>::Overflow)?;
                let lp1 = amount1.checked_mul(&pool.total_supply)
                    .ok_or(Error::<T>::Overflow)?
                    .checked_div(&pool.reserve1)
                    .ok_or(Error::<T>::Overflow)?;

                if lp0 < lp1 { lp0 } else { lp1 }
            };

            // Update pool reserves
            pool.reserve0 = pool.reserve0.checked_add(&amount0).ok_or(Error::<T>::Overflow)?;
            pool.reserve1 = pool.reserve1.checked_add(&amount1).ok_or(Error::<T>::Overflow)?;
            pool.total_supply = pool.total_supply.checked_add(&lp_tokens).ok_or(Error::<T>::Overflow)?;

            // Update LP balance
            LpBalances::<T>::mutate(pool_id, &who, |balance| {
                if let Some(new_balance) = balance.checked_add(&lp_tokens) {
                    *balance = new_balance;
                }
            });

            // Store updated pool
            Pools::<T>::insert(pool_id, pool);

            // Emit event
            Self::deposit_event(Event::LiquidityAdded {
                pool_id,
                provider: who,
                amount0,
                amount1,
                lp_tokens,
            });

            Ok(())
        }

        /// Remove liquidity from a pool
        ///
        /// # Arguments
        /// * `pool_id` - ID of the pool
        /// * `lp_tokens` - Amount of LP tokens to burn
        /// * `amount0_min` - Minimum amount of token0 to receive
        /// * `amount1_min` - Minimum amount of token1 to receive
        #[pallet::call_index(2)]
        #[pallet::weight(10_000)]
        pub fn remove_liquidity(
            origin: OriginFor<T>,
            pool_id: u32,
            lp_tokens: T::Balance,
            amount0_min: T::Balance,
            amount1_min: T::Balance,
        ) -> DispatchResult {
            let who = ensure_signed(origin)?;

            // Ensure amount is non-zero
            ensure!(!lp_tokens.is_zero(), Error::<T>::ZeroAmount);

            // Get pool
            let mut pool = Pools::<T>::get(pool_id).ok_or(Error::<T>::PoolNotFound)?;

            // Check LP balance
            let lp_balance = LpBalances::<T>::get(pool_id, &who);
            ensure!(lp_balance >= lp_tokens, Error::<T>::InsufficientLpTokens);

            // Calculate amounts to withdraw
            // amount0 = (lp_tokens * reserve0) / total_supply
            let amount0 = lp_tokens.checked_mul(&pool.reserve0)
                .ok_or(Error::<T>::Overflow)?
                .checked_div(&pool.total_supply)
                .ok_or(Error::<T>::Overflow)?;

            let amount1 = lp_tokens.checked_mul(&pool.reserve1)
                .ok_or(Error::<T>::Overflow)?
                .checked_div(&pool.total_supply)
                .ok_or(Error::<T>::Overflow)?;

            // Check slippage
            ensure!(amount0 >= amount0_min, Error::<T>::SlippageExceeded);
            ensure!(amount1 >= amount1_min, Error::<T>::SlippageExceeded);

            // Update pool reserves
            pool.reserve0 = pool.reserve0.checked_sub(&amount0).ok_or(Error::<T>::Overflow)?;
            pool.reserve1 = pool.reserve1.checked_sub(&amount1).ok_or(Error::<T>::Overflow)?;
            pool.total_supply = pool.total_supply.checked_sub(&lp_tokens).ok_or(Error::<T>::Overflow)?;

            // Update LP balance
            LpBalances::<T>::mutate(pool_id, &who, |balance| {
                if let Some(new_balance) = balance.checked_sub(&lp_tokens) {
                    *balance = new_balance;
                }
            });

            // Store updated pool
            Pools::<T>::insert(pool_id, pool);

            // Emit event
            Self::deposit_event(Event::LiquidityRemoved {
                pool_id,
                provider: who,
                amount0,
                amount1,
                lp_tokens_burned: lp_tokens,
            });

            Ok(())
        }

        /// Execute a swap
        ///
        /// # Arguments
        /// * `pool_id` - ID of the pool
        /// * `token_in` - Token to swap from
        /// * `amount_in` - Amount of token_in to swap
        /// * `amount_out_min` - Minimum amount of token_out to receive (slippage protection)
        ///
        /// This implements the constant product formula from PuddelPair.sol
        #[pallet::call_index(3)]
        #[pallet::weight(10_000)]
        pub fn swap(
            origin: OriginFor<T>,
            pool_id: u32,
            token_in: T::AssetId,
            amount_in: T::Balance,
            amount_out_min: T::Balance,
        ) -> DispatchResult {
            let who = ensure_signed(origin)?;

            // Ensure amount is non-zero
            ensure!(!amount_in.is_zero(), Error::<T>::ZeroAmount);

            // Get pool
            let mut pool = Pools::<T>::get(pool_id).ok_or(Error::<T>::PoolNotFound)?;

            // Determine which direction we're swapping
            let (reserve_in, reserve_out, token_out) = if token_in == pool.token0 {
                (pool.reserve0, pool.reserve1, pool.token1)
            } else if token_in == pool.token1 {
                (pool.reserve1, pool.reserve0, pool.token0)
            } else {
                return Err(Error::<T>::PoolNotFound.into());
            };

            // Calculate amount out using constant product formula
            // From PuddelPair.sol:
            // amount_out = (amount_in * 0.9975 * reserve_out) / (reserve_in + amount_in * 0.9975)
            // 0.9975 = (10000 - 25) / 10000 (0.25% fee)
            let amount_out = Self::get_amount_out(amount_in, reserve_in, reserve_out)?;

            // Check slippage
            ensure!(amount_out >= amount_out_min, Error::<T>::SlippageExceeded);

            // Update reserves
            if token_in == pool.token0 {
                pool.reserve0 = pool.reserve0.checked_add(&amount_in).ok_or(Error::<T>::Overflow)?;
                pool.reserve1 = pool.reserve1.checked_sub(&amount_out).ok_or(Error::<T>::Overflow)?;
            } else {
                pool.reserve1 = pool.reserve1.checked_add(&amount_in).ok_or(Error::<T>::Overflow)?;
                pool.reserve0 = pool.reserve0.checked_sub(&amount_out).ok_or(Error::<T>::Overflow)?;
            }

            // Verify constant product formula (k check)
            // From PuddelPair.sol: balance0Adjusted * balance1Adjusted >= reserve0 * reserve1 * (10000^2)
            Self::verify_invariant(&pool, reserve_in, reserve_out)?;

            // Store updated pool
            Pools::<T>::insert(pool_id, pool);

            // Emit event
            Self::deposit_event(Event::Swapped {
                pool_id,
                trader: who,
                amount_in,
                amount_out,
                token_in,
                token_out,
            });

            Ok(())
        }
    }

    impl<T: Config> Pallet<T> {
        /// Quote function: given some amount of token0 and pool reserves, return equivalent amount of token1
        /// From PuddelLibrary.sol: quote(amountA, reserveA, reserveB) = (amountA * reserveB) / reserveA
        fn quote(
            amount_a: T::Balance,
            reserve_a: T::Balance,
            reserve_b: T::Balance,
        ) -> Result<T::Balance, Error<T>> {
            ensure!(!amount_a.is_zero(), Error::<T>::ZeroAmount);
            ensure!(!reserve_a.is_zero(), Error::<T>::InsufficientLiquidity);
            ensure!(!reserve_b.is_zero(), Error::<T>::InsufficientLiquidity);

            let amount_b = amount_a.checked_mul(&reserve_b)
                .ok_or(Error::<T>::Overflow)?
                .checked_div(&reserve_a)
                .ok_or(Error::<T>::Overflow)?;

            Ok(amount_b)
        }

        /// Calculate amount out for a swap (constant product formula with 0.25% fee)
        /// From PuddelPair.sol:
        /// uint amountInWithFee = amountIn.mul(9975);
        /// uint numerator = amountInWithFee.mul(reserveOut);
        /// uint denominator = reserveIn.mul(10000).add(amountInWithFee);
        /// amountOut = numerator / denominator;
        fn get_amount_out(
            amount_in: T::Balance,
            reserve_in: T::Balance,
            reserve_out: T::Balance,
        ) -> Result<T::Balance, Error<T>> {
            ensure!(!amount_in.is_zero(), Error::<T>::ZeroAmount);
            ensure!(!reserve_in.is_zero(), Error::<T>::InsufficientLiquidity);
            ensure!(!reserve_out.is_zero(), Error::<T>::InsufficientLiquidity);

            // amount_in_with_fee = amount_in * 9975 (0.25% fee = 25 basis points)
            let amount_in_with_fee = amount_in.checked_mul(&9975u32.into())
                .ok_or(Error::<T>::Overflow)?;

            // numerator = amount_in_with_fee * reserve_out
            let numerator = amount_in_with_fee.checked_mul(&reserve_out)
                .ok_or(Error::<T>::Overflow)?;

            // denominator = reserve_in * 10000 + amount_in_with_fee
            let denominator = reserve_in.checked_mul(&10000u32.into())
                .ok_or(Error::<T>::Overflow)?
                .checked_add(&amount_in_with_fee)
                .ok_or(Error::<T>::Overflow)?;

            // amount_out = numerator / denominator
            let amount_out = numerator.checked_div(&denominator)
                .ok_or(Error::<T>::Overflow)?;

            Ok(amount_out)
        }

        /// Verify the constant product invariant (x * y >= k)
        /// From PuddelPair.sol:
        /// uint balance0Adjusted = balance0.mul(10000).sub(amount0In.mul(25));
        /// uint balance1Adjusted = balance1.mul(10000).sub(amount1In.mul(25));
        /// require(balance0Adjusted.mul(balance1Adjusted) >= reserve0.mul(reserve1).mul(10000**2));
        fn verify_invariant(
            pool: &Pool<T::AssetId, T::Balance>,
            old_reserve0: T::Balance,
            old_reserve1: T::Balance,
        ) -> Result<(), Error<T>> {
            // Simplified check: new_reserve0 * new_reserve1 >= old_reserve0 * old_reserve1
            let old_k = old_reserve0.checked_mul(&old_reserve1).ok_or(Error::<T>::Overflow)?;
            let new_k = pool.reserve0.checked_mul(&pool.reserve1).ok_or(Error::<T>::Overflow)?;

            ensure!(new_k >= old_k, Error::<T>::InvariantViolated);

            Ok(())
        }
    }
}
