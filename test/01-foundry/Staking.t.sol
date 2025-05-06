// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {StakeX} from "01-foundry/StakeX.sol";
import {StakingPool, ZeroAmountError} from "01-foundry/Staking.sol";
import {console} from "forge-std/console.sol";

contract StakingInitializationTest is Test {
    StakeX token;

    function setUp() public {
        token = new StakeX(address(this));
    }

    function test_Initialization() public {
        StakingPool staking = new StakingPool(address(token));

        assertEq(address(token), address(staking.STAKING_TOKEN()));
    }
}

contract StakingTest is Test {
    StakeX token;
    StakingPool staking;
    address userOne;
    uint256 stake;

    event Staked(address indexed user, uint256 amount);

    function setUp() public {
        stake = 5 * 10 ** 8;
        token = new StakeX(address(this));
        staking = new StakingPool(address(token));

        userOne = makeAddr("User 1");
        console.log(userOne.balance);
        vm.deal(userOne, 5 ether);
        console.log(userOne.balance);

        token.grantRole(token.MINTER_ROLE(), address(staking));
        deal(address(token), userOne, 50 * 10 ** token.decimals());
        vm.prank(userOne);
        token.approve(address(staking), 5000 ether);
    }

    function test_RevertIf_ZeroAmountOnStake() public {
        vm.expectRevert(ZeroAmountError.selector);
        staking.stake(0);
    }

    function test_InitialStake() public {
        vm.startPrank(userOne);

        vm.expectEmit(true, false, false, true);
        emit Staked(userOne, stake);
        staking.stake(stake);

        assertNotEq(staking.userStakeStartTime(address(userOne)), 0);
        assertEq(staking.userStakes(address(userOne)), stake);

        vm.stopPrank();
    }

    function test_RewardsAccrual() public {
        vm.startPrank(userOne);
        staking.stake(stake);

        vm.warp(block.timestamp + 365 days);

        uint256 pendingRewards = staking.getPendingRewards(userOne);
        uint256 expectedPendingRewards = (stake * 5) / 100;
        assertEq(pendingRewards, expectedPendingRewards);
    }

    function testFuzz_CompleteStakingCycle(
        uint256 stakeAmount,
        uint256 timeElapsed
    ) public {
        // Bound the stake amount to reasonable values (between 1 and 1000 tokens)
        stakeAmount = bound(stakeAmount, 1, 1000 * 10 ** 8);

        // Bound time elapsed to ensure we get rewards (at least 1 day)
        timeElapsed = bound(timeElapsed, 1 days, 2 * 365 days);

        vm.startPrank(userOne);

        // Ensure user has enough tokens
        deal(address(token), userOne, stakeAmount * 2); // Double the amount to ensure enough for fees/etc

        // Approve and stake
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Fast forward time
        vm.warp(block.timestamp + timeElapsed);

        // Calculate expected rewards
        uint256 expectedReward = (stakeAmount * 5 * timeElapsed) /
            (100 * 365 days);
        uint256 pendingRewards = staking.getPendingRewards(userOne);

        // Skip test if no rewards would be generated
        if (expectedReward == 0) {
            vm.stopPrank();
            return;
        }

        // Verify rewards are approximately correct
        assertApproxEqAbs(
            pendingRewards,
            expectedReward,
            1000,
            "Rewards should be approximately correct"
        );

        // Claim rewards
        uint256 balanceBefore = token.balanceOf(userOne);
        staking.claimRewards();
        uint256 balanceAfter = token.balanceOf(userOne);

        // Verify rewards were received
        assertApproxEqAbs(
            balanceAfter - balanceBefore,
            pendingRewards,
            1000,
            "User should receive correct reward amount"
        );

        // Unstake
        staking.unstake(stakeAmount);

        // Verify final state
        assertEq(
            staking.userStakes(userOne),
            0,
            "Stake should be zero after unstaking"
        );
        assertEq(
            staking.userRewards(userOne),
            0,
            "Rewards should be zero after claiming"
        );

        vm.stopPrank();
    }
}
