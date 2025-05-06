// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {StakeX} from "./StakeX.sol";

error ZeroAmountError();
error InsufficientBalanceError();
error NoRewardsError();

/**
 * @notice A staking pool contract that allows users to stake tokens and earn rewards.
 */
contract StakingPool {
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);

    uint256 public constant ANNUAL_REWARD_RATE = 5;
    uint256 public constant REWARD_RATE_DIVISOR = 100;
    uint256 public constant SECONDS_IN_YEAR = 365 days;

    StakeX public immutable STAKING_TOKEN;

    mapping(address user => uint256) public userStakes;
    mapping(address user => uint256) public userStakeStartTime;
    mapping(address user => uint256) public userRewards;

    /**
     * @notice Modifier that calculates and accumulates rewards before executing the function.
     */
    modifier accrueRewards() {
        if (userStakes[msg.sender] > 0) {
            uint256 stakedAmount = userStakes[msg.sender];
            uint256 stakeDuration = block.timestamp -
                userStakeStartTime[msg.sender];

            // Calculate reward: principal * rate * time / base / timeUnit
            uint256 newReward = (stakedAmount *
                ANNUAL_REWARD_RATE *
                stakeDuration) /
                REWARD_RATE_DIVISOR /
                SECONDS_IN_YEAR;

            userRewards[msg.sender] += newReward;
        }

        userStakeStartTime[msg.sender] = block.timestamp;
        _;
    }

    constructor(address _stakingToken) {
        STAKING_TOKEN = StakeX(_stakingToken);
    }

    /**
     * @notice Stake tokens to earn rewards.
     * @param amount Amount of tokens to stake.
     */
    function stake(uint256 amount) public accrueRewards {
        if (amount <= 0) {
            revert ZeroAmountError();
        }

        STAKING_TOKEN.transferFrom(msg.sender, address(this), amount);
        userStakes[msg.sender] += amount;

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstake tokens from the pool.
     * @param amount Amount of tokens to unstake.
     */
    function unstake(uint256 amount) public accrueRewards {
        if (amount <= 0) {
            revert ZeroAmountError();
        }

        if (amount > userStakes[msg.sender]) {
            revert InsufficientBalanceError();
        }

        STAKING_TOKEN.transfer(msg.sender, amount);
        userStakes[msg.sender] -= amount;

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @notice Claim accumulated rewards.
     */
    function claimRewards() public accrueRewards {
        uint256 reward = userRewards[msg.sender];

        if (reward <= 0) {
            revert NoRewardsError();
        }

        userRewards[msg.sender] = 0;
        STAKING_TOKEN.mint(msg.sender, reward);

        emit RewardsClaimed(msg.sender, reward);
    }

    /**
     * @notice Calculate pending rewards for a user without claiming.
     * @param userAddress Address of the user.
     * @return pendingRewards Pending rewards amount.
     */
    function getPendingRewards(
        address userAddress
    ) public view returns (uint256 pendingRewards) {
        if (userStakes[userAddress] == 0) {
            return userRewards[userAddress];
        }

        uint256 stakedAmount = userStakes[userAddress];
        uint256 stakeDuration = block.timestamp -
            userStakeStartTime[userAddress];

        uint256 pendingReward = (stakedAmount *
            ANNUAL_REWARD_RATE *
            stakeDuration) /
            REWARD_RATE_DIVISOR /
            SECONDS_IN_YEAR;

        pendingRewards = userRewards[userAddress] + pendingReward;
    }
}
