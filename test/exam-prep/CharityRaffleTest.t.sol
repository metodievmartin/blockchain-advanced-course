// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {
VRFCoordinatorV2_5Mock
} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {DeployCharityRaffle} from "@script/exam-prep/DeployCharityRaffle.s.sol";
import {CharityRaffle} from "@/exam-prep/CharityRaffle.sol";
import {CharityRaffleConfig} from "@script/exam-prep/CharityRaffleConfig.s.sol";

contract CharityRaffleTest is Test {
    /* ============================================================================================== */
    /*                                         STATE_VARIABLES                                        */
    /* ============================================================================================== */
    CharityRaffle public charityRaffle;
    VRFCoordinatorV2_5Mock public vrfCoordinatorMock;
    CharityRaffleConfig public configHelper;

    // Constants for test accounts
    address public constant PLAYER1 =
    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant PLAYER2 =
    0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public constant PLAYER3 =
    0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address public constant PLAYER4 =
    0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant FUND_AMOUNT = 3 ether;
    uint256 public constant TICKET_PRICE = 0.001 ether;

    // Network configuration
    uint256 public subscriptionId;
    bytes32 public gasLane;
    bytes32 public merkleRoot;
    address public owner;
    address public charityWallet;
    address public vrfCoordinator;
    address public deployedProxy;

    // Merkle proofs for players
    bytes32[][] public playerProofs;

    /* ============================================================================================== */
    /*                                             EVENTS                                             */
    /* ============================================================================================== */
    event TicketPurchased(address indexed buyer, uint256 qty);
    event RandomnessRequested(uint256 requestId);
    event WinnersSelected(address[] winners);
    event PrizeClaimed(address indexed winner);
    event CharityWithdrawal(uint256 amount);

    /* ============================================================================================== */
    /*                                           ERROR_CODES                                          */
    /* ============================================================================================== */
    error InvalidProof();
    error InsufficientValue();
    error InsufficientFunds();
    error InvalidQuantity();
    error VRFRequestAlreadyMade();
    error WinnersNotSelected();
    error NotAWinner();
    error AlreadyClaimed();
    error TransferFailed();

    function setUp() external {
        // Deploy the CharityRaffle contract using the deployment script
        DeployCharityRaffle deployer = new DeployCharityRaffle();
        (address proxy, CharityRaffleConfig config) = deployer.run();

        // Store the proxy address and config helper
        deployedProxy = proxy;
        configHelper = config;

        // Get the network configuration for local testing
        CharityRaffleConfig.NetworkConfig memory networkConfig = configHelper
            .getOrCreateAnvilConfig();

        // Store configuration values
        subscriptionId = networkConfig.subscriptionId;
        gasLane = networkConfig.gasLane;
        merkleRoot = networkConfig.merkleRoot;
        owner = networkConfig.owner;
        charityWallet = networkConfig.charityWallet;
        vrfCoordinator = networkConfig.vrfCoordinator;

        // Get the VRF coordinator mock instance
        vrfCoordinatorMock = VRFCoordinatorV2_5Mock(vrfCoordinator);

        // Get the CharityRaffle contract instance
        charityRaffle = CharityRaffle(deployedProxy);

        // Fund test accounts
        vm.deal(PLAYER1, STARTING_USER_BALANCE);
        vm.deal(PLAYER2, STARTING_USER_BALANCE);
        vm.deal(PLAYER3, STARTING_USER_BALANCE);
        vm.deal(PLAYER4, STARTING_USER_BALANCE);

        // Set up merkle proofs for each player
        playerProofs = new bytes32[][](4);

        // Player 1 proof
        playerProofs[0] = new bytes32[](2);
        playerProofs[0][0] = 0x9b0bc27a9e8f6a8a4b2e92b71ac31b44ef9bd5a54f150ed7b7c2668c6b9be039;
        playerProofs[0][1] = 0x166a633689f07198f116bd599dbcfafd186431540ba501bc90f55692742b0374;

        // Player 2 proof
        playerProofs[1] = new bytes32[](2);
        playerProofs[1][0] = 0x32235e7434a20509b8e17860e4d7b9b0a551e3696a7eac2153aad4e6c348bc46;
        playerProofs[1][1] = 0xe3e347f8d89dba0c928b134cfe6492b90cbb217bee7e19c72413681678e22422;

        // Player 3 proof
        playerProofs[2] = new bytes32[](2);
        playerProofs[2][0] = 0xd791b4384f11048b2330e9ec924a5c80226526b5e9d7f65537637981af4d404f;
        playerProofs[2][1] = 0x166a633689f07198f116bd599dbcfafd186431540ba501bc90f55692742b0374;

        // Player 4 proof
        playerProofs[3] = new bytes32[](2);
        playerProofs[3][0] = 0x208697df1b2d4c083944c10909fe1ed6e99c1eaccff33ba129464b28f8245f01;
        playerProofs[3][1] = 0xe3e347f8d89dba0c928b134cfe6492b90cbb217bee7e19c72413681678e22422;
    }

    /* ============================================================================================== */
    /*                                         INITIALIZATION                                         */
    /* ============================================================================================== */

    function test_SetUpState() public view {
        // Verify the contract was initialized correctly
        assertEq(charityRaffle.owner(), owner, "owner");
        assertEq(charityRaffle.charityWallet(), charityWallet, "charityWallet");
        assertEq(
            charityRaffle.vrfSubscriptionId(),
            subscriptionId,
            "subscriptionId"
        );
        assertEq(charityRaffle.vrfKeyHash(), gasLane, "gasLane");
        assertEq(charityRaffle.merkleRoot(), merkleRoot, "merkleRoot");
        assertEq(charityRaffle.ticketPrice(), TICKET_PRICE, "ticketPrice");
        assertEq(charityRaffle.numOfWinners(), 2, "numOfWinners");
        assertEq(
            charityRaffle.prizePercentageBPS(),
            3000,
            "prizePercentageBPS"
        );
    }

    /* ============================================================================================== */
    /*                                       TICKET_PURCHASING                                        */
    /* ============================================================================================== */

    function test_BuyTicket() public {
        // Arrange
        uint256 quantity = 1;
        uint256 expectedCost = quantity * TICKET_PRICE;
        uint256 initialBalance = PLAYER1.balance;

        // Act
        vm.prank(PLAYER1);
        vm.expectEmit(true, false, false, true);
        emit TicketPurchased(PLAYER1, quantity);
        charityRaffle.buyTicket{value: expectedCost}(quantity, playerProofs[0]);

        // Assert
        assertEq(PLAYER1.balance, initialBalance - expectedCost, "balance1");
        assertEq(
            address(charityRaffle).balance,
            expectedCost,
            "contractBalance1"
        );
        assertEq(charityRaffle.participants(0), PLAYER1, "participant0");
    }

    function test_BuyMultipleTickets() public {
        // Arrange
        uint256 quantity = 5;
        uint256 expectedCost = quantity * TICKET_PRICE;
        uint256 initialBalance = PLAYER2.balance;

        // Act
        vm.prank(PLAYER2);
        vm.expectEmit(true, false, false, true);
        emit TicketPurchased(PLAYER2, quantity);
        charityRaffle.buyTicket{value: expectedCost}(quantity, playerProofs[1]);

        // Assert
        assertEq(PLAYER2.balance, initialBalance - expectedCost, "balance2");
        assertEq(
            address(charityRaffle).balance,
            expectedCost,
            "contractBalance2"
        );
        assertEq(charityRaffle.participants(0), PLAYER2, "participant0");
    }

    function test_MultiplePlayers() public {
        // Player 1 buys 2 tickets
        vm.prank(PLAYER1);
        charityRaffle.buyTicket{value: 2 * TICKET_PRICE}(2, playerProofs[0]);

        // Player 2 buys 3 tickets
        vm.prank(PLAYER2);
        charityRaffle.buyTicket{value: 3 * TICKET_PRICE}(3, playerProofs[1]);

        // Player 3 buys 1 ticket
        vm.prank(PLAYER3);
        charityRaffle.buyTicket{value: TICKET_PRICE}(1, playerProofs[2]);

        // Assert
        assertEq(charityRaffle.participants(0), PLAYER1, "participant0");
        assertEq(charityRaffle.participants(1), PLAYER1, "participant1");
        assertEq(charityRaffle.participants(2), PLAYER2, "participant2");
        assertEq(charityRaffle.participants(3), PLAYER2, "participant3");
        assertEq(charityRaffle.participants(4), PLAYER2, "participant4");
        assertEq(charityRaffle.participants(5), PLAYER3, "participant5");
        assertEq(
            address(charityRaffle).balance,
            6 * TICKET_PRICE,
            "totalBalance"
        );
    }

    function test_RevertIf_InvalidProof() public {
        // Arrange
        uint256 quantity = 1;
        uint256 cost = quantity * TICKET_PRICE;

        // Create an invalid proof
        bytes32[] memory invalidProof = new bytes32[](2);
        invalidProof[0] = bytes32(uint256(0x1234));
        invalidProof[1] = bytes32(uint256(0x5678));

        // Act & Assert
        vm.prank(PLAYER1);
        vm.expectRevert(InvalidProof.selector);
        charityRaffle.buyTicket{value: cost}(quantity, invalidProof);
    }

    function test_RevertIf_InsufficientFunds() public {
        // Arrange
        uint256 quantity = 2;
        uint256 insufficientAmount = quantity * TICKET_PRICE - 1; // 1 wei less than required

        // Act & Assert
        vm.prank(PLAYER3);
        vm.expectRevert(InsufficientValue.selector);
        charityRaffle.buyTicket{value: insufficientAmount}(
            quantity,
            playerProofs[2]
        );
    }

    function test_RevertIf_InvalidQuantity() public {
        // Arrange
        uint256 quantity = 0;
        uint256 cost = quantity * TICKET_PRICE;

        // Act & Assert
        vm.prank(PLAYER4);
        vm.expectRevert(InvalidQuantity.selector);
        charityRaffle.buyTicket{value: cost}(quantity, playerProofs[3]);
    }

    /* ============================================================================================== */
    /*                                    RANDOM_WINNERS_SELECTION                                    */
    /* ============================================================================================== */

    function _setupFourPlayersWithOneTicketEach() internal {
        // Each player buys one ticket
        vm.prank(PLAYER1);
        charityRaffle.buyTicket{value: TICKET_PRICE}(1, playerProofs[0]);

        vm.prank(PLAYER2);
        charityRaffle.buyTicket{value: TICKET_PRICE}(1, playerProofs[1]);

        vm.prank(PLAYER3);
        charityRaffle.buyTicket{value: TICKET_PRICE}(1, playerProofs[2]);

        vm.prank(PLAYER4);
        charityRaffle.buyTicket{value: TICKET_PRICE}(1, playerProofs[3]);

        // Verify all players have entered
        assertEq(charityRaffle.participants(0), PLAYER1, "setup_participant0");
        assertEq(charityRaffle.participants(1), PLAYER2, "setup_participant1");
        assertEq(charityRaffle.participants(2), PLAYER3, "setup_participant2");
        assertEq(charityRaffle.participants(3), PLAYER4, "setup_participant3");
    }

    function test_RequestRandomWinners() public {
        // Arrange - Four players buy tickets
        _setupFourPlayersWithOneTicketEach();

        // Act - Owner requests random winners
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit RandomnessRequested(1); // VRF request ID starts at 1
        charityRaffle.requestRandomWinners();

        // Assert - Check funds distribution calculation
        uint256 totalFunds = 4 * TICKET_PRICE;
        uint256 expectedWinnerReward = ((totalFunds * 3000) / 10000) / 2; // 30% split between 2 winners
        uint256 expectedCharityFunds = totalFunds - (expectedWinnerReward * 2);

        assertEq(
            charityRaffle.winnerReward(),
            expectedWinnerReward,
            "winnerReward"
        );
        assertEq(
            charityRaffle.charityFunds(),
            expectedCharityFunds,
            "charityFunds"
        );
    }

    function test_RevertIf_RequestRandomWinnersNotOwner() public {
        // Arrange - Four players buy tickets
        _setupFourPlayersWithOneTicketEach();

        // Act & Assert - Non-owner tries to request random winners
        vm.prank(PLAYER2);
        vm.expectRevert();
        charityRaffle.requestRandomWinners();
    }

    function test_RevertIf_RequestRandomWinnersAlreadyMade() public {
        // Arrange - Four players buy tickets and owner makes first request
        _setupFourPlayersWithOneTicketEach();
        vm.prank(owner);
        charityRaffle.requestRandomWinners();

        // Act & Assert - Owner tries to request again
        vm.prank(owner);
        vm.expectRevert(VRFRequestAlreadyMade.selector);
        charityRaffle.requestRandomWinners();
    }

    function test_FulfillRandomWords() public {
        // Arrange - Four players buy tickets and owner requests winners
        _setupFourPlayersWithOneTicketEach();
        vm.prank(owner);
        charityRaffle.requestRandomWinners();

        // Create random words that will select PLAYER1 and PLAYER3 as winners
        uint256[] memory randomWords = new uint256[](2);
        randomWords[0] = 0; // This will select participants[0] which is PLAYER1
        randomWords[1] = 2; // This will select participants[2] which is PLAYER3

        // Act - VRF Coordinator fulfills the randomness request
        //        vm.prank(owner);
        vrfCoordinatorMock.fulfillRandomWordsWithOverride(
            1, // requestId
            address(charityRaffle),
            randomWords
        );

        // Assert - Check that winners were selected correctly
        assertTrue(charityRaffle.winners(PLAYER1), "player1_winner");
        assertFalse(charityRaffle.winners(PLAYER2), "player2_not_winner");
        assertTrue(charityRaffle.winners(PLAYER3), "player3_winner");
        assertFalse(charityRaffle.winners(PLAYER4), "player4_not_winner");
        assertTrue(charityRaffle.winnersSelected(), "winners_selected_flag");
    }

    /* ============================================================================================== */
    /*                                       PRIZE_CLAIMING                                           */
    /* ============================================================================================== */

    function _setupRaffleWithWinners() internal {
        // Set up four players with one ticket each
        _setupFourPlayersWithOneTicketEach();

        // Request random winners
        vm.prank(owner);
        charityRaffle.requestRandomWinners();

        // Create random words that will select PLAYER1 and PLAYER3 as winners
        uint256[] memory randomWords = new uint256[](2);
        randomWords[0] = 0; // This will select participants[0] which is PLAYER1
        randomWords[1] = 2; // This will select participants[2] which is PLAYER3

        // Fund the VRF coordinator
//        vm.deal(vrfCoordinator, 10 ether);

        // Fulfill the randomness request
//        vm.prank(vrfCoordinator);
        vrfCoordinatorMock.fulfillRandomWordsWithOverride(
            1, // requestId
            address(charityRaffle),
            randomWords
        );

        // Verify winners were selected correctly
        assertTrue(charityRaffle.winners(PLAYER1), "setup_player1_winner");
        assertTrue(charityRaffle.winners(PLAYER3), "setup_player3_winner");
        assertTrue(charityRaffle.winnersSelected(), "setup_winners_selected");
    }

    function test_ClaimPrize() public {
        // Arrange - Set up raffle with winners
        _setupRaffleWithWinners();

        // Get winner's initial balance
        uint256 initialBalance = PLAYER1.balance;
        uint256 expectedReward = charityRaffle.winnerReward();

        // Act - Winner claims prize
        vm.prank(PLAYER1);
        vm.expectEmit(true, false, false, false);
        emit PrizeClaimed(PLAYER1);
        charityRaffle.claimPrize();

        // Assert
        assertEq(PLAYER1.balance, initialBalance + expectedReward, "winner_balance");
        assertFalse(charityRaffle.winners(PLAYER1), "winner_flag_reset");
    }

    function test_RevertIf_ClaimPrizeNotWinner() public {
        // Arrange - Set up raffle with winners
        _setupRaffleWithWinners();

        // Act & Assert - Non-winner tries to claim prize
        vm.prank(PLAYER2);
        vm.expectRevert(NotAWinner.selector);
        charityRaffle.claimPrize();
    }

    function test_RevertIf_ClaimPrizeAlreadyClaimed() public {
        // Arrange - Set up raffle with winners and claim once
        _setupRaffleWithWinners();
        vm.prank(PLAYER1);
        charityRaffle.claimPrize();

        // Act & Assert - Try to claim again
        vm.prank(PLAYER1);
        vm.expectRevert(NotAWinner.selector);
        charityRaffle.claimPrize();
    }

    function test_ClaimCharityFunds() public {
        // Arrange - Set up raffle with winners
        _setupRaffleWithWinners();

        // Get charity wallet's initial balance
        uint256 initialBalance = charityWallet.balance;
        uint256 expectedFunds = charityRaffle.charityFunds();

        // Act - Owner claims charity funds
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit CharityWithdrawal(expectedFunds);
        charityRaffle.claimCharityFunds();

        // Assert
        assertEq(charityWallet.balance, initialBalance + expectedFunds, "charity_balance");
    }

    function test_RevertIf_ClaimCharityFundsNotOwner() public {
        // Arrange - Set up raffle with winners
        _setupRaffleWithWinners();

        // Act & Assert - Non-owner tries to claim charity funds
        vm.prank(PLAYER2);
        vm.expectRevert();
        charityRaffle.claimCharityFunds();
    }

    function test_RevertIf_ClaimCharityFundsWinnersNotSelected() public {
        // Arrange - Set up raffle but don't select winners
        _setupFourPlayersWithOneTicketEach();

        // Act & Assert - Owner tries to claim charity funds before winners are selected
        vm.prank(owner);
        vm.expectRevert(InsufficientFunds.selector);
        charityRaffle.claimCharityFunds();
    }
}
