// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {
    AggregatorV3Interface
} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// Enum to represent the direction of a bet: Up or Down
enum Direction {
    Up,
    Down
}

// Struct to store information about each round
struct Round {
    uint256 lockTime; // Timestamp after which no more bets are accepted
    uint256 endTime; // Timestamp when the round ends
    uint256 startPrice; // Price at the start of the round
    uint256 endPrice; // Price at the end of the round
    uint totalUp; // Total amount bet on Up
    uint totalDown; // Total amount bet on Down
    bool resolved; // Whether the round has been resolved
}

// Struct to store information about a user's bet
struct Bet {
    Direction direction; // Direction of the bet
    uint256 bet; // Amount bet
}

// Custom errors for better gas efficiency
error BetLocked();
error AlreadyBet();
error TooLateToStart();
error PreviousNotResolved();
error WaitingNotFinished();
error SomethingWentWrong();

/**
 * @title PricePrediction
 * @notice A simple prediction market where users bet on whether the ETH/USD price will go up or down in the next 5 minutes.
 *         Uses Chainlink price feeds for price data.
 */
contract PricePrediction {
    // Chainlink price feed for ETH/USD on Sepolia
    AggregatorV3Interface internal constant DATA_FEED =
        AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);

    uint256 public currentRoundId; // Tracks the current round
    mapping(uint256 => Round) public rounds; // roundId => Round
    mapping(uint256 => mapping(address => Bet)) public bets; // roundId => user => Bet
    mapping(uint256 => mapping(address => bool)) public rewardsClaimed; // roundId => user => claimed

    /**
     * @notice Start a new prediction round. Can only be called if the previous round is resolved and within the first 2 minutes of a 5-minute window.
     *         The round is locked for bets after 2 minutes, and ends after 5 minutes.
     *         The price at the start is recorded from Chainlink.
     * @dev Prevents starting a new round if previous is unresolved or if too late in the window.
     */
    function startRound() external {
        uint256 secondsAfterHour = block.timestamp % 5 minutes;

        if (secondsAfterHour > 2 minutes) revert TooLateToStart();
        if (!rounds[currentRoundId].resolved) revert PreviousNotResolved();

        currentRoundId++;

        rounds[currentRoundId] = Round({
            lockTime: block.timestamp + 2 minutes, // Lock bets after 2 minutes
            endTime: block.timestamp + (5 minutes - secondsAfterHour), // Round ends at the next 5-minute mark
            startPrice: uint256(getLatestPrice()), // Record starting price
            endPrice: 0,
            totalUp: 0,
            totalDown: 0,
            resolved: false
        });
    }

    /**
     * @notice Place a bet on the current round. Must be before lockTime and cannot bet twice in the same round.
     * @param _direction The direction of the bet: Up or Down
     */
    function bet(Direction _direction) external payable {
        Round storage round = rounds[currentRoundId];

        if (block.timestamp >= round.lockTime) revert BetLocked();
        if (bets[currentRoundId][msg.sender].bet != 0) revert AlreadyBet();

        bets[currentRoundId][msg.sender] = Bet(_direction, msg.value);

        if (_direction == Direction.Up) {
            round.totalUp += msg.value;
        } else {
            round.totalDown += msg.value;
        }
    }

    /**
     * @notice Resolves the current round by setting the end price from Chainlink and marking as resolved.
     *         Can only be called after the round ends. If called late (>2min after end), endPrice is set to the latest price.
     */
    function setWinner() external {
        Round storage round = rounds[currentRoundId];

        if (block.timestamp < round.endTime) revert WaitingNotFinished();
        if (block.timestamp > round.endTime + 2 minutes) {
            round.endPrice = uint256(getLatestPrice());
        }

        round.resolved = true;
    }

    /**
     * @notice Claims the reward for a winning bet. Calculates payout based on direction and total pool.
     * @param roundToClaim The round to claim rewards for
     */
    function claimReward(uint256 roundToClaim) external {
        uint256 startPrice = rounds[roundToClaim].startPrice;
        uint256 endPrice = rounds[roundToClaim].endPrice;
        uint256 userBet = bets[roundToClaim][msg.sender].bet;
        uint256 totalBet = rounds[roundToClaim].totalUp +
            rounds[roundToClaim].totalDown;

        uint256 reward;
        // If price didn't change or round not resolved, refund bet
        if (endPrice == 0 || startPrice == endPrice) {
            reward = userBet;
        } else if (
            rounds[roundToClaim].startPrice > endPrice &&
            bets[roundToClaim][msg.sender].direction == Direction.Down
        ) {
            // If user bet Down and price went down, win proportional to total pool
            reward = (userBet * totalBet) / rounds[roundToClaim].totalDown;
        } else if (
            rounds[roundToClaim].startPrice < endPrice &&
            bets[roundToClaim][msg.sender].direction == Direction.Up
        ) {
            // If user bet Up and price went up, win proportional to total pool
            reward = (userBet * totalBet) / rounds[roundToClaim].totalDown;
        }

        rewardsClaimed[roundToClaim][msg.sender] = true;

        (bool result, ) = payable(msg.sender).call{value: reward}("");
        if (!result) revert SomethingWentWrong();
    }

    /**
     * Network: Sepolia
     * Aggregator: ETH/USD
     * Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
     */

    /**
     * @notice Returns the latest ETH/USD price from Chainlink.
     */
    function getLatestPrice() public view returns (int) {
        // prettier-ignore
        (
        /* uint80 roundId */,
            int256 answer,
        /*uint256 startedAt*/,
        /*uint256 updatedAt*/,
        /*uint80 answeredInRound*/
        ) = DATA_FEED.latestRoundData();
        return answer;
    }
}
