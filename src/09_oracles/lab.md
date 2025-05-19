## Lab: Oracles

### Smart Contract Lottery (Raffle)

Create a fair and transparent raffle system where participants enter by sending ETH and a random winner is selected using **Chainlink VRF (Verifiable Random Function)**. The contract will collect entrance fees from players and automatically distribute the prize to a randomly selected winner.

### Requirements

#### Chainlink VRF Integration

* Import `VRFConsumerBaseV2Plus` and `VRFV2PlusClient`
* In the constructor, accept VRF parameters:

    * `subscriptionId`
    * `gasLane` (keyHash)
    * `callbackGasLimit`
    * `vrfCoordinatorV2` address
* Implement `fulfillRandomWords()` to select a winner when the random number is received

#### Raffle State Management

* Define a `RaffleState` enum with:

    * `OPEN` (accepting entries)
    * `CALCULATING` (waiting for random number)
* Track the state in a state variable

#### Player Entry Mechanism

* Function `enterRaffle()` (payable):

    * Require a minimum entrance fee (stored as immutable variable)
    * Require raffle is in `OPEN` state
    * Store player address in an array
    * Emit `RaffleEnter` event

#### Random Winner Selection

* Function `requestRandomWinner()`:

    * Only callable when `checkCanRequestRandomWinner()` returns true
    * Change state to `CALCULATING`
    * Request random number from Chainlink VRF
    * Emit event when random number is requested

* `fulfillRandomWords()`:

    * Select winner
    * Reset raffle’s state
    * Emit event

---

### Price Prediction Game

Create a "price prediction" game where players wager ETH on whether an asset's price will go up or down over a fixed interval (e.g. one hour). Your contract will fetch the price at round start (lock) and again at round end (resolve), then distribute the pooled bets to winning players.

### Requirements

#### 1. Chainlink Data Feed Integration

* Import `AggregatorV3Interface`

#### 2. Round Lifecycle

* Define a `Round` struct with:

    * `lockTime` (timestamp when bets close)
    * `endTime` (timestamp when price is checked)
    * `startPrice` (price at lock)
    * `endPrice` (price at resolve)
    * `totalUp` & `totalDown` (ETH totals per direction)
    * `resolved` (bool)
* Store the rounds

#### 3. Betting Mechanism

* Enum `Direction { Up, Down }`
* Store the bets
* Add to `totalUp` or `totalDown`

#### 4. Resolution & Payouts

* Implement guard checks:

    * Require round is resolved
    * User has a bet
    * Not yet claimed
* Compute winning side:

    * `Up` if `endPrice > startPrice`, else `Down`
* Transfer payout if user bet correctly
* Mark `claimed = true`
