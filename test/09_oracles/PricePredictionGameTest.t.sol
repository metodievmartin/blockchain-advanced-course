// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {
PricePredictionGame,
PricePredictionGame__InvalidDuration,
PricePredictionGame__BettingClosed,
PricePredictionGame__ZeroBetAmount,
PricePredictionGame__AlreadyBet,
PricePredictionGame__RoundNotEnded,
PricePredictionGame__AlreadyResolved,
PricePredictionGame__AlreadyClaimed
} from "@/09_oracles/PricePredictionGame.sol";
import {DeployPricePredictionGame} from "@script/09_oracles/DeployPricePredictionGame.s.sol";
import {HelperConfig} from "@script/09_oracles/HelperConfig.s.sol";

import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

contract PricePredictionGameTest is Test {
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
        PricePredictionGame.Direction direction,
        uint256 amount
    );
    event RoundResolved(
        uint256 indexed roundId,
        int256 endPrice,
        PricePredictionGame.Direction outcome
    );
    event PayoutClaimed(
        uint256 indexed roundId,
        address indexed bettor,
        uint256 amount
    );

    /* ============================================================================================== */
    /*                                         STATE VARIABLES                                        */
    /* ============================================================================================== */

    PricePredictionGame game;
    HelperConfig helperConfig;
    MockV3Aggregator mockPriceFeed;

    address public OWNER = makeAddr("owner");
    address public USER1 = makeAddr("user1");
    address public USER2 = makeAddr("user2");
    address public USER3 = makeAddr("user3");

    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant BET_AMOUNT = 1 ether;

    uint256 public constant ROUND_DURATION = 3600; // 1 hour
    uint256 public constant LOCK_DELAY = 60; // 1 minute

    /* ============================================================================================== */
    /*                                              SETUP                                             */
    /* ============================================================================================== */

    function setUp() external {
        DeployPricePredictionGame deployer = new DeployPricePredictionGame();
        (game, helperConfig) = deployer.run(OWNER);

        address priceFeedAddress = game.getPriceFeed();
        mockPriceFeed = MockV3Aggregator(priceFeedAddress);

        vm.deal(USER1, STARTING_BALANCE);
        vm.deal(USER2, STARTING_BALANCE);
        vm.deal(USER3, STARTING_BALANCE);
    }

    function testGameInitialization() public view {
        assert(game.getPriceFeed() == address(mockPriceFeed));
        assert(game.roundId() == 0);
    }

    function testOnlyOwnerCanStartRound() public {
        vm.expectRevert();
        game.startRound(ROUND_DURATION, LOCK_DELAY);

        vm.prank(OWNER);
        vm.expectEmit(true, false, false, false);
        emit RoundStarted(1, 0, 0, 0);
        game.startRound(ROUND_DURATION, LOCK_DELAY);

        assert(game.roundId() == 1);
    }

    function testCannotStartRoundWithInvalidDuration() public {
        vm.prank(OWNER);
        vm.expectRevert(PricePredictionGame__InvalidDuration.selector);
        game.startRound(60, 60);

        vm.prank(OWNER);
        vm.expectRevert(PricePredictionGame__InvalidDuration.selector);
        game.startRound(60, 120); // Lock delay > duration
    }

    function testCanPlaceBet() public {
        // 1. Start a round
        vm.prank(OWNER);
        game.startRound(ROUND_DURATION, LOCK_DELAY);

        // 2. Place a bet
        vm.prank(USER1);
        vm.expectEmit(true, true, false, false);
        emit BetPlaced(1, USER1, PricePredictionGame.Direction.Up, BET_AMOUNT);
        game.placeBet{value: BET_AMOUNT}(1, PricePredictionGame.Direction.Up);

        // 3. Check bet was recorded
        (PricePredictionGame.Direction dir, uint256 amount, bool claimed) = game
            .bets(1, USER1);
        assert(dir == PricePredictionGame.Direction.Up);
        assert(amount == BET_AMOUNT);
        assert(claimed == false);

        // 4. Check totals
        (, , , , uint256 totalUp, ,) = game.rounds(1);
        assert(totalUp == BET_AMOUNT);
    }

    function testCannotBetAfterLockTime() public {
        // 1. Start a round
        vm.prank(OWNER);
        game.startRound(ROUND_DURATION, LOCK_DELAY);

        // 2. Warp time to after lock
        vm.warp(block.timestamp + LOCK_DELAY + 1);

        // 3. Try to place a bet
        vm.prank(USER1);
        vm.expectRevert(PricePredictionGame__BettingClosed.selector);
        game.placeBet{value: BET_AMOUNT}(1, PricePredictionGame.Direction.Up);
    }

    function testCannotBetZeroAmount() public {
        // 1. Start a round
        vm.prank(OWNER);
        game.startRound(ROUND_DURATION, LOCK_DELAY);

        // 2. Try to place a bet with zero amount
        vm.prank(USER1);
        vm.expectRevert(PricePredictionGame__ZeroBetAmount.selector);
        game.placeBet{value: 0}(1, PricePredictionGame.Direction.Up);
    }

    function testCannotBetTwice() public {
        // 1. Start a round
        vm.prank(OWNER);
        game.startRound(ROUND_DURATION, LOCK_DELAY);

        // 2. Place a bet
        vm.prank(USER1);
        game.placeBet{value: BET_AMOUNT}(1, PricePredictionGame.Direction.Up);

        // 3. Try to bet again
        vm.prank(USER1);
        vm.expectRevert(PricePredictionGame__AlreadyBet.selector);
        game.placeBet{value: BET_AMOUNT}(1, PricePredictionGame.Direction.Down);
    }

    function testCanResolveRound() public {
        // 1. Start a round
        vm.prank(OWNER);
        game.startRound(ROUND_DURATION, LOCK_DELAY);

        // 2. Warp time to after end
        vm.warp(block.timestamp + ROUND_DURATION + 1);

        // 3. Resolve round
        vm.prank(OWNER);
        vm.expectEmit(true, false, false, false);
        emit RoundResolved(1, 0, PricePredictionGame.Direction.Down);
        game.resolveRound(1);

        // 4. Check round was resolved
        (, , , , , , bool resolved) = game.rounds(1);
        assert(resolved == true);
    }

    function testCannotResolveBeforeEndTime() public {
        // 1. Start a round
        vm.prank(OWNER);
        game.startRound(ROUND_DURATION, LOCK_DELAY);

        // 2. Try to resolve before end time
        vm.prank(OWNER);
        vm.expectRevert(PricePredictionGame__RoundNotEnded.selector);
        game.resolveRound(1);
    }

    function testCannotResolveAlreadyResolvedRound() public {
        // 1. Start a round
        vm.prank(OWNER);
        game.startRound(ROUND_DURATION, LOCK_DELAY);

        // 2. Warp time to after end
        vm.warp(block.timestamp + ROUND_DURATION + 1);

        // 3. Resolve round
        vm.prank(OWNER);
        game.resolveRound(1);

        // 4. Try to resolve again
        vm.prank(OWNER);
        vm.expectRevert(PricePredictionGame__AlreadyResolved.selector);
        game.resolveRound(1);
    }

    function testFullGameFlowAllBetUp() public {
        // 1. Start a round
        vm.prank(OWNER);
        game.startRound(ROUND_DURATION, LOCK_DELAY);

        // 2. Place bets (all Up)
        vm.prank(USER1);
        game.placeBet{value: BET_AMOUNT}(1, PricePredictionGame.Direction.Up);

        vm.prank(USER2);
        game.placeBet{value: BET_AMOUNT}(1, PricePredictionGame.Direction.Up);

        // 3. Warp time to after end
        vm.warp(block.timestamp + ROUND_DURATION + 1);

        // 4. Set price higher
        int256 endPrice = 2500e8;
        mockPriceFeed.updateAnswer(endPrice);

        // 5. Resolve round
        vm.prank(OWNER);
        game.resolveRound(1);

        // 6. Users claim
        uint256 user1BalanceBefore = USER1.balance;

        vm.prank(USER1);
        game.claim(1);

        // 7. Each user gets their bet back since both bet on the winning side
        assert(USER1.balance == user1BalanceBefore + BET_AMOUNT);

        vm.prank(USER2);
        game.claim(1);
    }

    function testFullGameFlowMixedBets() public {
        // 1. Start a round
        vm.prank(OWNER);
        game.startRound(ROUND_DURATION, LOCK_DELAY);

        // 2. Place bets
        vm.prank(USER1);
        game.placeBet{value: BET_AMOUNT}(1, PricePredictionGame.Direction.Up);

        vm.prank(USER2);
        game.placeBet{value: BET_AMOUNT}(1, PricePredictionGame.Direction.Down);

        vm.prank(USER3);
        game.placeBet{value: BET_AMOUNT}(1, PricePredictionGame.Direction.Down);

        // 3. Warp time to after end
        vm.warp(block.timestamp + ROUND_DURATION + 1);

        // 4. Set price lower
        int256 endPrice = 1800e8;
        mockPriceFeed.updateAnswer(endPrice);

        // 5. Resolve round
        vm.prank(OWNER);
        game.resolveRound(1);

        // 6. Check balances before
        uint256 user1BalanceBefore = USER1.balance;
        console.log("user1BalanceBefore", user1BalanceBefore);
        uint256 user2BalanceBefore = USER2.balance;
        console.log("user2BalanceBefore", user2BalanceBefore);

        // 7. Losers get nothing
        vm.prank(USER1);
        game.claim(1);
        assert(USER1.balance == user1BalanceBefore);
        console.log("user1BalanceAfter", USER1.balance);
        // 8. Winners split the pool proportionally
        vm.prank(USER2);
        game.claim(1);
        // USER2 bet 1 ETH, total 3 ETH in pool, 2 ETH bet on DOWN, so gets 3/2 ETH = 1.5 ETH
        assert(USER2.balance == user2BalanceBefore + 1.5 ether);
        console.log("user2BalanceAfter", USER2.balance);

        // 9. Verify can't claim again
        vm.prank(USER2);
        vm.expectRevert(PricePredictionGame__AlreadyClaimed.selector);
        game.claim(1);
    }

    function testPriceDidNotChange() public {
        // 1. Start a round
        vm.prank(OWNER);
        game.startRound(ROUND_DURATION, LOCK_DELAY);

        // 2. Place bets
        vm.prank(USER1);
        game.placeBet{value: BET_AMOUNT}(1, PricePredictionGame.Direction.Up);

        vm.prank(USER2);
        game.placeBet{value: BET_AMOUNT}(1, PricePredictionGame.Direction.Down);

        // 3. Warp time to after end
        vm.warp(block.timestamp + ROUND_DURATION + 1);

        // 4. Set same price (no change)
        mockPriceFeed.updateAnswer(2000e8); // Same as initial value

        // 5. Resolve round
        vm.prank(OWNER);
        game.resolveRound(1);

        // 6. Check balances before
        uint256 user1BalanceBefore = USER1.balance;
        uint256 user2BalanceBefore = USER2.balance;

        // 7. Everyone gets refunded
        vm.prank(USER1);
        game.claim(1);
        assert(USER1.balance == user1BalanceBefore + BET_AMOUNT);

        vm.prank(USER2);
        game.claim(1);
        assert(USER2.balance == user2BalanceBefore + BET_AMOUNT);
    }
}