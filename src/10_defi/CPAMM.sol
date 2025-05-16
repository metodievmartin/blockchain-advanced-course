// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@/interfaces/IERC20.sol";

error InvalidToken();
error InsufficientAmount();
error InvalidLiquidityRatio();
error InsufficientLiquidityMinted();
error InsufficientLiquidityBurned();

contract CPAMM {
    // Tokens used in the liquidity pool (e.g., token0 could be DAI and token1 could be ETH)
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    // Internal accounting of token reserves held by the contract
    uint256 public reserve0;
    uint256 public reserve1;

    // Total supply of liquidity provider (LP) tokens
    uint256 public totalSupply;

    // Mapping of user addresses to their LP token balances
    mapping(address => uint256) public balanceOf;

    /* ============================================================================================== */
    /*                                            FUNCTIONS                                           */
    /* ============================================================================================== */

    constructor(address _token0, address _token1) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    /**
     * @notice Exchange one token for another
     * @param _tokenIn The token being sent into the pool
     * @param _amountIn The amount of _tokenIn to swap
     *
     * Performs a swap using the constant product formula (x * y = k).
     * A fee of 0.3% is applied to the input amount. The output amount
     * is calculated based on the post-fee input and current reserves.
     */
    function swap(address _tokenIn, uint256 _amountIn) external {
        // Ensure the input token is one of the two supported pool tokens
        if (_tokenIn != address(token0) && _tokenIn != address(token1)) {
            revert InvalidToken();
        }

        // Require a non-zero amount to swap
        if (_amountIn == 0) {
            revert InsufficientAmount();
        }

        // Determine which direction the swap is going and fetch appropriate token/reserve pair
        bool isToken0In = _tokenIn == address(token0);
        (
            IERC20 tokenIn,
            IERC20 tokenOut,
            uint256 reserveIn,
            uint256 reserveOut
        ) = isToken0In
                ? (token0, token1, reserve0, reserve1)
                : (token1, token0, reserve1, reserve0);

        // Transfer the input tokens from the user to this contract
        tokenIn.transferFrom(msg.sender, address(this), _amountIn);

        // Apply a 0.3% fee by multiplying with 997/1000
        uint256 amountInWithFee = (_amountIn * 997) / 1000;

        // Calculate the output amount using the constant product formula:
        // (x + dx) * (y - dy) = k  => dy = (dx * y) / (x + dx)
        uint256 amountOut = (amountInWithFee * reserveOut) /
            (reserveIn + amountInWithFee);

        // Transfer output tokens to the user
        tokenOut.transfer(msg.sender, amountOut);

        // Update internal reserve tracking to match actual balances
        _updateReserves();
    }

    /**
     * @notice Add liquidity to the pool
     * @param amount0 Amount of token0 to deposit
     * @param amount1 Amount of token1 to deposit
     * @return shares Amount of LP tokens minted
     *
     * If the pool is empty, the depositor sets the initial ratio.
     * Otherwise, the deposit must match the current token ratio to
     * avoid arbitrage. LP shares are calculated based on the proportion
     * of added liquidity relative to current reserves.
     */
    function addLiquidity(
        uint256 amount0,
        uint256 amount1
    ) external returns (uint256 shares) {
        // Validate non-zero amounts for both tokens
        if (amount0 == 0 || amount1 == 0) {
            revert InsufficientAmount();
        }

        if (reserve0 == 0 && reserve1 == 0) {
            // If this is the first liquidity, LP shares are the geometric mean of deposited amounts
            shares = sqrt(amount0 * amount1);
        } else {
            // Enforce depositing tokens in the correct ratio to preserve pricing
            uint256 expectedAmount1 = (amount0 * reserve1) / reserve0;
            if (amount1 != expectedAmount1) revert InvalidLiquidityRatio();
            // Shares issued based on the ratio of new liquidity to existing pool
            shares = (amount0 * totalSupply) / reserve0; // Could alternatively use amount1 / reserve1
        }

        // Prevent rounding errors from minting 0 LP tokens
        if (shares == 0) {
            revert InsufficientLiquidityMinted();
        }

        // Transfer tokens from user to pool contract
        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);

        // Mint LP tokens to liquidity provider
        balanceOf[msg.sender] += shares;
        totalSupply += shares;

        // Update internal reserves
        _updateReserves();
    }

    /**
     * @notice Remove liquidity from the pool
     * @param shares Amount of LP tokens to burn
     * @return amount0 Amount of token0 returned
     * @return amount1 Amount of token1 returned
     *
     * Burns the sender's LP tokens and returns the proportional share
     * of the reserves based on the total supply.
     */
    function removeLiquidity(
        uint256 shares
    ) external returns (uint256 amount0, uint256 amount1) {
        // Require a non-zero LP share amount
        if (shares == 0) {
            revert InsufficientLiquidityBurned();
        }

        // Calculate user's share of the pool for each token
        amount0 = (shares * reserve0) / totalSupply;
        amount1 = (shares * reserve1) / totalSupply;

        // Burn LP tokens from user's balance
        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;

        // Send proportional amounts of tokens back to user
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);

        // Sync internal reserves with new balances
        _updateReserves();
    }

    /**
     * @dev Internal function to synchronise reserve values with actual token balances
     * Called after every token movement (swap, add/remove liquidity).
     */
    function _updateReserves() private {
        // Update reserves using actual token balances of the contract
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));
    }

    /**
     * @dev Efficient integer square root function using the Babylonian method
     * Used during initial liquidity provision to calculate LP share value
     */
    function sqrt(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            // Iterative approximation to find square root
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
