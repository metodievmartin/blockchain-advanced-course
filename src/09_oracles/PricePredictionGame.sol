// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

    error PricePredictionGame__InvalidDuration();
    error PricePredictionGame__BettingClosed();
    error PricePredictionGame__ZeroBetAmount();
    error PricePredictionGame__AlreadyBet();
    error PricePredictionGame__RoundNotEnded();
    error PricePredictionGame__AlreadyResolved();
    error PricePredictionGame__RoundNotResolved();
    error PricePredictionGame__NoBetPlaced();
    error PricePredictionGame__AlreadyClaimed();
    error PricePredictionGame__NoWinners();
    error PricePredictionGame__TransferFailed();

/**
 * @notice A price prediction game where players bet on price movements
 */
contract PricePredictionGame is Ownable {
    /* ============================================================================================== */
    /*                                              TYPES                                             */
    /* ============================================================================================== */
    enum Direction {
        Up,
        Down
    }

    struct Bet {
        Direction direction;
        uint256 amount;
        bool claimed;
    }

    struct Round {
        /// @notice Timestamp when bets close
        uint256 lockTime;
        /// @notice Timestamp when price is checked
        uint256 endTime;
        /// @notice Price at lock
        int256 startPrice;
        /// @notice Price at resolve
        int256 endPrice;
        /// @notice Total ETH bet on Up
        uint256 totalUp;
        /// @notice Total ETH bet on Down
        uint256 totalDown;
        /// @notice Whether the round has been resolved
        bool resolved;
    }

    /* ============================================================================================== */
    /*                                         STATE VARIABLES                                        */
    /* ============================================================================================== */

    AggregatorV3Interface private immutable PRICE_FEED;

    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(address => Bet)) public bets;

    uint256 public roundId;

    /* ============================================================================================== */
    /*                                             EVENTS                                             */
    /* ============================================================================================== */

    event RoundStarted(
        uint256 indexed roundId,
        uint256 lockTime,
        uint256 endTime,
        int256 startPrice
    );
    event BetPlaced(
        uint256 indexed roundId,
        address indexed bettor,
        Direction direction,
        uint256 amount
    );
    event RoundResolved(
        uint256 indexed roundId,
        int256 endPrice,
        Direction outcome
    );
    event PayoutClaimed(
        uint256 indexed roundId,
        address indexed bettor,
        uint256 amount
    );

    /* ============================================================================================== */
    /*                                            FUNCTIONS                                           */
    /* ============================================================================================== */

    constructor(address priceFeedAddress) Ownable(msg.sender) {
        PRICE_FEED = AggregatorV3Interface(priceFeedAddress);
    }

    /**
     * @notice Start a new betting round
     */
    function startRound(
        uint256 duration,
        uint256 lockDelay
    ) external onlyOwner {
        if (lockDelay >= duration) {
            revert PricePredictionGame__InvalidDuration();
        }

        roundId++;
        Round storage round = rounds[roundId];

        round.lockTime = block.timestamp + lockDelay;
        round.endTime = block.timestamp + duration;
        round.startPrice = getPrice();

        emit RoundStarted(
            roundId,
            round.lockTime,
            round.endTime,
            round.startPrice
        );
    }

    /**
     * @notice Place a bet on price direction
     */
    function placeBet(uint256 id, Direction direction) external payable {
        Round storage round = rounds[id];

        if (block.timestamp >= round.lockTime) {
            revert PricePredictionGame__BettingClosed();
        }

        if (msg.value == 0) {
            revert PricePredictionGame__ZeroBetAmount();
        }

        if (bets[id][msg.sender].amount > 0) {
            revert PricePredictionGame__AlreadyBet();
        }

        // 1. Store bet
        bets[id][msg.sender] = Bet({
            direction: direction,
            amount: msg.value,
            claimed: false
        });

        // 2. Update totals
        if (direction == Direction.Up) {
            round.totalUp += msg.value;
        } else {
            round.totalDown += msg.value;
        }

        emit BetPlaced(id, msg.sender, direction, msg.value);
    }

    /**
     * @notice Resolve a round by checking final price
     */
    function resolveRound(uint256 id) external onlyOwner {
        Round storage round = rounds[id];

        if (block.timestamp < round.endTime) {
            revert PricePredictionGame__RoundNotEnded();
        }

        if (round.resolved) {
            revert PricePredictionGame__AlreadyResolved();
        }

        round.endPrice = getPrice();
        round.resolved = true;

        Direction outcome = round.endPrice > round.startPrice
            ? Direction.Up
            : Direction.Down;
        emit RoundResolved(id, round.endPrice, outcome);
    }

    /**
     * @notice Claim winnings from a resolved round
     */
    function claim(uint256 _id) external {
        Round storage round = rounds[_id];
        Bet storage userBet = bets[_id][msg.sender];

        if (!round.resolved) {
            revert PricePredictionGame__RoundNotResolved();
        }

        if (userBet.amount == 0) {
            revert PricePredictionGame__NoBetPlaced();
        }

        if (userBet.claimed) {
            revert PricePredictionGame__AlreadyClaimed();
        }

        // 1. Mark as claimed immediately to prevent reentrancy
        userBet.claimed = true;

        Direction outcome = round.endPrice > round.startPrice
            ? Direction.Up
            : Direction.Down;

        // 2. If price didn't change, refund everyone
        if (round.endPrice == round.startPrice) {
            (bool refundSuccess,) = msg.sender.call{value: userBet.amount}("");
            if (!refundSuccess) {
                revert PricePredictionGame__TransferFailed();
            }
            emit PayoutClaimed(_id, msg.sender, userBet.amount);
            return;
        }

        // 3. If user didn't bet on the winning side, they get nothing
        if (userBet.direction != outcome) {
            emit PayoutClaimed(_id, msg.sender, 0);
            return;
        }

        // 4. Calculate payout
        uint256 totalPool = round.totalUp + round.totalDown;
        uint256 winningPool = outcome == Direction.Up
            ? round.totalUp
            : round.totalDown;

        // 5. Prevent division by zero
        if (winningPool == 0) {
            revert PricePredictionGame__NoWinners();
        }

        uint256 payout = (userBet.amount * totalPool) / winningPool;

        (bool success,) = msg.sender.call{value: payout}("");
        if (!success) {
            revert PricePredictionGame__TransferFailed();
        }

        emit PayoutClaimed(_id, msg.sender, payout);
    }

    /* ============================================================================================== */
    /*                                         VIEW FUNCTIONS                                         */
    /* ============================================================================================== */

    /* View functions */
    /**
     * @notice Get the latest price from the price feed
     * @return Latest price
     */
    function getLatestPrice() external view returns (int256) {
        return getPrice();
    }

    /**
     * @notice Get the price feed address
     * @return Price feed address
     */
    function getPriceFeed() external view returns (address) {
        return address(PRICE_FEED);
    }

    /* ============================================================================================== */
    /*                                       INTERNAL FUNCTIONS                                       */
    /* ============================================================================================== */

    /**
     * @notice Get the latest price from the price feed
     * @return Latest price
     */
    function getPrice() internal view returns (int256) {
        (, int256 price, , ,) = PRICE_FEED.latestRoundData();
        return price;
    }
}