// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Chainlink VRF imports (V2 Plus)
import {
    VRFConsumerBaseV2Plus
} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {
    VRFV2PlusClient
} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle (Lottery) Contract
 * @notice This contract implements a fair and transparent raffle system using Chainlink VRF for randomness
 * @dev Follows best practices for gas, custom errors, and event logging
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* ========== ENUMS ========== */
    enum RaffleState {
        OPEN, // Accepting entries
        CALCULATING // Waiting for random number
    }

    /* ========== STATE VARIABLES ========== */
    uint256 public immutable entranceFee; // Minimum ETH required to enter
    address[] private players; // Array of player addresses
    RaffleState public raffleState; // Current state of the raffle

    // Chainlink VRF variables
    uint256 private immutable subscriptionId; // Chainlink subscription ID
    bytes32 private immutable gasLane; // Chainlink gas lane (keyHash)
    uint32 private immutable callbackGasLimit; // Chainlink callback gas limit
    address private immutable vrfCoordinator; // Chainlink VRF Coordinator address
    uint256 private latestRequestId; // Last VRF request ID

    address public recentWinner; // Most recent winner

    /* ========== EVENTS ========== */
    event RaffleEnter(address indexed player);
    event RandomWinnerRequested(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    /* ========== CUSTOM ERRORS ========== */
    error Raffle__NotEnoughETH();
    error Raffle__NotOpen();
    error Raffle__UpkeepNotNeeded();
    error Raffle__TransferFailed();
    error Raffle__OnlyCoordinator();

    /* ========== CONSTRUCTOR ========== */
    /**
     * @param _entranceFee Minimum ETH required to enter
     * @param _subscriptionId Chainlink subscription ID
     * @param _gasLane Chainlink gas lane (keyHash)
     * @param _callbackGasLimit Chainlink callback gas limit
     * @param _vrfCoordinator Chainlink VRF Coordinator address
     */
    constructor(
        uint256 _entranceFee,
        uint256 _subscriptionId,
        bytes32 _gasLane,
        uint32 _callbackGasLimit,
        address _vrfCoordinator
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        entranceFee = _entranceFee;
        subscriptionId = _subscriptionId;
        gasLane = _gasLane;
        callbackGasLimit = _callbackGasLimit;
        vrfCoordinator = _vrfCoordinator;
        raffleState = RaffleState.OPEN;
    }

    /* ========== PLAYER ENTRY ========== */
    /**
     * @notice Enter the raffle by paying the entrance fee
     */
    function enterRaffle() external payable {
        if (msg.value < entranceFee) revert Raffle__NotEnoughETH();
        if (raffleState != RaffleState.OPEN) revert Raffle__NotOpen();
        players.push(msg.sender);
        emit RaffleEnter(msg.sender);
    }

    /* ========== WINNER SELECTION ========== */
    /**
     * @notice Checks if random winner can be requested
     * @dev Returns true if raffle is open and there are players
     */
    function checkCanRequestRandomWinner() public view returns (bool) {
        return (raffleState == RaffleState.OPEN &&
            players.length > 0 &&
            address(this).balance >= entranceFee);
    }

    /**
     * @notice Request a random winner from Chainlink VRF
     * @dev Only callable if checkCanRequestRandomWinner() returns true
     */
    function requestRandomWinner() external {
        if (!checkCanRequestRandomWinner()) revert Raffle__UpkeepNotNeeded();
        raffleState = RaffleState.CALCULATING;

        // Request random number from Chainlink VRF
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: gasLane,
                subId: subscriptionId,
                requestConfirmations: 3,
                callbackGasLimit: callbackGasLimit,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                )
            })
        );

        latestRequestId = requestId;
        emit RandomWinnerRequested(requestId);
    }

    /* ========== CHAINLINK VRF CALLBACK ========== */
    /**
     * @notice Callback function used by Chainlink VRF Coordinator
     * @dev Selects a winner, resets the raffle, and emits event
     * @param requestId The VRF request ID
     * @param randomWords Array of random numbers provided by Chainlink
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        if (msg.sender != vrfCoordinator) revert Raffle__OnlyCoordinator();

        uint256 winnerIndex = randomWords[0] % players.length;
        address winner = players[winnerIndex];
        recentWinner = winner;
        // Reset state before transfer to prevent reentrancy
        delete players;
        raffleState = RaffleState.OPEN;

        emit WinnerPicked(winner);

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) revert Raffle__TransferFailed();
    }

    /* ========== VIEW FUNCTIONS ========== */
    /**
     * @notice Returns current players in the raffle
     */
    function getPlayers() external view returns (address[] memory) {
        return players;
    }
}
