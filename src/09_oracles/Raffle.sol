// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

    error Raffle__NotEnoughTimePassed(uint256 timeRemaining);
    error Raffle__TransferFailed();
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__RaffleNotOpen();

/**
 * @notice A raffle contract that uses Chainlink VRF to pick a winner
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* ============================================================================================== */
    /*                                              TYPES                                             */
    /* ============================================================================================== */

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* ============================================================================================== */
    /*                                         STATE VARIABLES                                        */
    /* ============================================================================================== */

    // Chainlink VRF Variables
    uint256 private immutable SUBSCRIPTION_ID;
    bytes32 private immutable GAS_LANE;
    uint32 private immutable CALLBACK_GAS_LIMIT;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // Lottery Variables
    uint256 private immutable INTERVAL;
    uint256 private immutable ENTRANCE_FEE;

    RaffleState public raffleState;
    uint256 public lastTimeStamp;
    address public recentWinner;

    address payable[] private players;

    /* ============================================================================================== */
    /*                                             EVENTS                                             */
    /* ============================================================================================== */

    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    /* ============================================================================================== */
    /*                                            FUNCTIONS                                           */
    /* ============================================================================================== */

    constructor(
        uint256 subscriptionId,
        bytes32 gasLane,
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        GAS_LANE = gasLane;
        INTERVAL = interval;
        SUBSCRIPTION_ID = subscriptionId;
        ENTRANCE_FEE = entranceFee;
        raffleState = RaffleState.OPEN;
        lastTimeStamp = block.timestamp;
        CALLBACK_GAS_LIMIT = callbackGasLimit;
    }

    function enterRaffle() public payable {
        if (msg.value < ENTRANCE_FEE) revert Raffle__SendMoreToEnterRaffle();
        if (raffleState != RaffleState.OPEN) revert Raffle__RaffleNotOpen();

        players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    /**
     * @notice This function allows anyone to pick a winner if the following conditions are met:
     * 1. The time interval has passed between raffle runs;
     * 2. The lottery is open;
     * 3. The contract has ETH;
     * 4. The contract has players;
     * 5. Implicitly, your subscription is funded with LINK.
     */
    function pickWinner() external {
        // 1. Check if enough time has passed
        if ((block.timestamp - lastTimeStamp) < INTERVAL) {
            uint256 timeRemaining = INTERVAL -
                (block.timestamp - lastTimeStamp);
            revert Raffle__NotEnoughTimePassed(timeRemaining);
        }

        // 2. Check if raffle is open
        if (raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        // 3. Check if there are players and contract has balance
        if (players.length == 0 || address(this).balance == 0) {
            revert("Raffle__NoPlayersOrBalance");
        }

        // 4. Set raffle state to calculating
        raffleState = RaffleState.CALCULATING;

        // 5. Request random words
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: GAS_LANE,
                subId: SUBSCRIPTION_ID,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
            // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        emit RequestedRaffleWinner(requestId);
    }

    /**
     * @dev This is the function that Chainlink VRF node
     * calls to send the money to the random winner
     */
    function fulfillRandomWords(
        uint256,
    /* requestId */ uint256[] calldata randomWords
    ) internal override {
        // 1. Get the index of the winner
        uint256 indexOfWinner = randomWords[0] % players.length;
        address payable _recentWinner = players[indexOfWinner];
        recentWinner = _recentWinner;

        // 2. Reset the players and raffle state
        players = new address payable[](0);
        raffleState = RaffleState.OPEN;
        lastTimeStamp = block.timestamp;

        // 3. Emit the winner picked event
        emit WinnerPicked(_recentWinner);

        // 4. Send the balance to the winner
        (bool ok,) = recentWinner.call{value: address(this).balance}("");
        if (!ok) {
            revert Raffle__TransferFailed();
        }
    }

    /* ============================================================================================== */
    /*                                         VIEW FUNCTIONS                                         */
    /* ============================================================================================== */

    function getPlayer(uint256 _index) public view returns (address) {
        return players[_index];
    }
}