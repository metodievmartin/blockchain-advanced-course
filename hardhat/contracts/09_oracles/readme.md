Smart Contract Lottery

Create a fair and transparent raffle system where participants enter by sending ETH and a random winner is selected using Chainlink VRF (Verifiable Random Function). The contract will collect entrance fees from players and automatically distribute the prize to a randomly selected winner.

Requirements

1. Chainlink VRF Integration

    * Import VRFConsumerBaseV2Plus and VRFV2PlusClient 
    * In your constructor, accept VRF parameters:
      * subscriptionId 
      * gasLane (keyHash)
      * callbackGasLimit 
      * vrfCoordinatorV2 address
    * Implement fulfillRandomWords() to select a winner when random number is received

2. Raffle State Management
   * Define a RaffleState enum with:
     * OPEN (accepting entries)
     * CALCULATING (waiting for random number)
   * Track state in a state variable

3. Player Entry Mechanism 
   * Function enterRaffle() payable:
     * require minimum entrance fee (stored as immutable variable)
     * require raffle is in OPEN state
     * store player address in array
     * emit RaffleEnter event

4. Random Winner Selection
   * Function requestRandomWinner():
     * only callable when checkCanRequestRandomWinner() returns true
     * change state to CALCULATING
     * request random number from Chainlink VRF
     * emit event when random number is requested

5. fulfillRandomWords()
   * Function requestRandomWinner():
     * select winner
     * reset raffle’s state
     * emit event