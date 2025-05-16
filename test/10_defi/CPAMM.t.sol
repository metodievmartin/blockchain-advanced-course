// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../src/10_defi/CPAMM.sol";

import "forge-std/Test.sol";
import {
    CPAMM,
    InvalidLiquidityRatio,
    InvalidToken,
    InsufficientAmount
} from "@/10_defi/CPAMM.sol";
import {MockERC20} from "./mocks/ERC20.sol";

contract CPAMMTest is Test {
    uint256 public constant INITIAL_LIQUIDITY_TOKEN0 = 1000 ether;
    uint256 public constant INITIAL_LIQUIDITY_TOKEN1 = 500 ether;

    CPAMM public cpamm;
    MockERC20 public token0;
    MockERC20 public token1;

    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        // 1. Deploy mock tokens
        token0 = new MockERC20("Token0", "TK0", 18);
        token1 = new MockERC20("Token1", "TK1", 18);

        // 2. Ensure tokens are sorted by address (required by many AMMs)
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // 3. Deploy CPAMM
        cpamm = new CPAMM(address(token0), address(token1));

        // 4. Mint tokens to users
        token0.mint(user1, 2000 ether);
        token1.mint(user1, 1000 ether);
        token0.mint(user2, 1000 ether);
        token1.mint(user2, 2000 ether);

        // 5. Give allowance for the test contract
        vm.startPrank(user1);
        token0.approve(address(cpamm), type(uint256).max);
        token1.approve(address(cpamm), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        token0.approve(address(cpamm), type(uint256).max);
        token1.approve(address(cpamm), type(uint256).max);
        vm.stopPrank();
    }

    function testInitialState() public view {
        assertEq(address(cpamm.token0()), address(token0));
        assertEq(address(cpamm.token1()), address(token1));
        assertEq(cpamm.reserve0(), 0);
        assertEq(cpamm.reserve1(), 0);
        assertEq(cpamm.totalSupply(), 0);
    }

    function testAddInitialLiquidity() public {
        vm.startPrank(user1);

        uint256 shares = cpamm.addLiquidity(
            INITIAL_LIQUIDITY_TOKEN0,
            INITIAL_LIQUIDITY_TOKEN1
        );

        // 1. Check LP tokens minted
        assertEq(
            shares,
            _sqrt(INITIAL_LIQUIDITY_TOKEN0 * INITIAL_LIQUIDITY_TOKEN1)
        );
        assertEq(cpamm.balanceOf(user1), shares);
        assertEq(cpamm.totalSupply(), shares);

        // 2. Check reserves updated
        assertEq(cpamm.reserve0(), INITIAL_LIQUIDITY_TOKEN0);
        assertEq(cpamm.reserve1(), INITIAL_LIQUIDITY_TOKEN1);

        // 3. Check token balances
        assertEq(token0.balanceOf(address(cpamm)), INITIAL_LIQUIDITY_TOKEN0);
        assertEq(token1.balanceOf(address(cpamm)), INITIAL_LIQUIDITY_TOKEN1);

        vm.stopPrank();
    }

    function testAddMoreLiquidity() public {
        // 1. First add initial liquidity
        vm.startPrank(user1);
        uint256 initialShares = cpamm.addLiquidity(
            INITIAL_LIQUIDITY_TOKEN0,
            INITIAL_LIQUIDITY_TOKEN1
        );
        vm.stopPrank();

        uint256 addToken0 = 500 ether;
        uint256 addToken1 = 250 ether; // Must maintain the ratio

        vm.startPrank(user2);
        uint256 newShares = cpamm.addLiquidity(addToken0, addToken1);
        vm.stopPrank();

        // 2. Check new shares calculation
        uint256 expectedShares = (addToken0 * initialShares) /
            INITIAL_LIQUIDITY_TOKEN0;
        assertEq(newShares, expectedShares);

        // 3. Check LP tokens
        assertEq(cpamm.balanceOf(user2), newShares);
        assertEq(cpamm.totalSupply(), initialShares + newShares);

        // 4. Check reserves
        assertEq(cpamm.reserve0(), INITIAL_LIQUIDITY_TOKEN0 + addToken0);
        assertEq(cpamm.reserve1(), INITIAL_LIQUIDITY_TOKEN1 + addToken1);
    }

    function test_RevertIfAddLiquidityWrongRatio() public {
        // 1. First add initial liquidity
        vm.startPrank(user1);
        cpamm.addLiquidity(INITIAL_LIQUIDITY_TOKEN0, INITIAL_LIQUIDITY_TOKEN1);
        vm.stopPrank();

        // 2. Try to add liquidity with incorrect ratio
        vm.startPrank(user2);
        vm.expectRevert(InvalidLiquidityRatio.selector);
        cpamm.addLiquidity(500 ether, 300 ether); // Wrong ratio, should revert
        vm.stopPrank();
    }

    function testSwapToken0ForToken1() public {
        // 1. First add liquidity
        vm.startPrank(user1);
        cpamm.addLiquidity(INITIAL_LIQUIDITY_TOKEN0, INITIAL_LIQUIDITY_TOKEN1);

        uint256 swapAmount = 100 ether;
        uint256 user1BalanceBefore = token1.balanceOf(user1);

        // 2. Calculate expected output amount (based on the formula used in the contract)
        uint256 amountInWithFee = (swapAmount * 997) / 1000;
        uint256 expectedOut = (INITIAL_LIQUIDITY_TOKEN1 * amountInWithFee) /
            (INITIAL_LIQUIDITY_TOKEN0 + amountInWithFee);

        // 3. Perform swap
        cpamm.swap(address(token0), swapAmount);
        vm.stopPrank();

        // 4. Check balances
        assertEq(token1.balanceOf(user1), user1BalanceBefore + expectedOut);
        assertEq(cpamm.reserve0(), INITIAL_LIQUIDITY_TOKEN0 + swapAmount);
        assertEq(cpamm.reserve1(), INITIAL_LIQUIDITY_TOKEN1 - expectedOut);

        // 5. Verify constant product formula
        uint256 k1 = INITIAL_LIQUIDITY_TOKEN0 * INITIAL_LIQUIDITY_TOKEN1;
        uint256 k2 = cpamm.reserve0() * cpamm.reserve1();

        // Due to fees, k2 can be greater than k1
        // This is because the fee is kept in the pool, which increases the product
        assertGe(k2, (k1 * 997) / 1000); // Should be at least 99.7% of original k value
    }

    function testSwapToken1ForToken0() public {
        // 1. First add liquidity
        vm.startPrank(user1);
        cpamm.addLiquidity(INITIAL_LIQUIDITY_TOKEN0, INITIAL_LIQUIDITY_TOKEN1);
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 swapAmount = 50 ether;
        uint256 user2BalanceBefore = token0.balanceOf(user2);

        // 2. Calculate expected output amount
        uint256 amountInWithFee = (swapAmount * 997) / 1000;
        uint256 expectedOut = (INITIAL_LIQUIDITY_TOKEN0 * amountInWithFee) /
            (INITIAL_LIQUIDITY_TOKEN1 + amountInWithFee);

        // 3. Perform swap
        cpamm.swap(address(token1), swapAmount);
        vm.stopPrank();

        // 4. Check balances
        assertEq(token0.balanceOf(user2), user2BalanceBefore + expectedOut);
        assertEq(cpamm.reserve0(), INITIAL_LIQUIDITY_TOKEN0 - expectedOut);
        assertEq(cpamm.reserve1(), INITIAL_LIQUIDITY_TOKEN1 + swapAmount);
    }

    function test_RevertIfSwapInvalidToken() public {
        address fakeToken = makeAddr("fakeToken");
        vm.expectRevert(InvalidToken.selector);
        cpamm.swap(fakeToken, 100 ether);
    }

    function test_RevertIfSwapZeroAmount() public {
        vm.expectRevert(InsufficientAmount.selector);
        cpamm.swap(address(token0), 0);
    }

    function testRemoveLiquidity() public {
        // 1. First add liquidity
        vm.startPrank(user1);
        uint256 shares = cpamm.addLiquidity(
            INITIAL_LIQUIDITY_TOKEN0,
            INITIAL_LIQUIDITY_TOKEN1
        );

        uint256 token0Before = token0.balanceOf(user1);
        uint256 token1Before = token1.balanceOf(user1);

        // 2. Remove half of the liquidity
        uint256 sharesToRemove = shares / 2;
        (uint256 amount0, uint256 amount1) = cpamm.removeLiquidity(
            sharesToRemove
        );
        vm.stopPrank();

        // 3. Check tokens returned
        assertEq(amount0, INITIAL_LIQUIDITY_TOKEN0 / 2);
        assertEq(amount1, INITIAL_LIQUIDITY_TOKEN1 / 2);

        // 4. Verify user received tokens
        assertEq(token0.balanceOf(user1), token0Before + amount0);
        assertEq(token1.balanceOf(user1), token1Before + amount1);

        // 5. Verify LP tokens burned
        assertEq(cpamm.balanceOf(user1), shares - sharesToRemove);
        assertEq(cpamm.totalSupply(), shares - sharesToRemove);

        // 6. Verify reserves updated
        assertEq(cpamm.reserve0(), INITIAL_LIQUIDITY_TOKEN0 - amount0);
        assertEq(cpamm.reserve1(), INITIAL_LIQUIDITY_TOKEN1 - amount1);
    }

    function test_RevertIfRemoveTooMuchLiquidity() public {
        // 1. Add liquidity
        vm.startPrank(user1);
        uint256 shares = cpamm.addLiquidity(
            INITIAL_LIQUIDITY_TOKEN0,
            INITIAL_LIQUIDITY_TOKEN1
        );

        // 2. Try to remove more shares than owned
        vm.expectRevert();
        cpamm.removeLiquidity(shares + 1);
        vm.stopPrank();
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
