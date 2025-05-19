# Oracle Contracts

This folder contains two smart contracts that interact with Chainlink oracles:

1. **Raffle** - A decentralised lottery using Chainlink VRF for fair random winner selection.
2. **PricePredictionGame** - A betting game where players predict price movements using Chainlink Price Feeds.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (for script execution)

## Setup

1. Clone the repository:
```bash
cd <projec_root_folder>
```

2. Install dependencies:
```bash
forge install
```

3. Create a `.env` file with the following variables:
```
PRIVATE_KEY=your_private_key
ETHERSCAN_API_KEY=your_etherscan_api_key
SEPOLIA_RPC_URL=your_sepolia_rpc_url
MAINNET_RPC_URL=your_mainnet_rpc_url
CHAINLINK_SUBSCRIPTION_ID=your_chainlink_subscription_id
```

## Contracts

### Raffle Contract

The Raffle contract implements a decentralised lottery where:
- Players enter by paying an entrance fee
- A random winner is selected using Chainlink VRF
- The entire pot is awarded to the winner

#### Key Features

- Fair and verifiable randomness via Chainlink VRF
- Automatic winner selection after a time interval
- Transparent lottery process on-chain

### Price Prediction Game Contract

The Price Prediction Game allows players to bet on price movements:
- Players bet on whether a price will go UP or DOWN
- Price is fetched from Chainlink Price Feeds
- Winners share the entire pot proportionally to their bet

#### Key Features

- Rounds with configurable durations
- Uses real-world price data from Chainlink oracles
- Proportional payout mechanism

## Testing

Run the tests with:

```bash
forge test
```

For more detailed test output:

```bash
forge test -vvv
```

## Deployment

### Local Deployment

Deploy to local Anvil network:

```bash
forge script script/DeployRaffle.s.sol --rpc-url http://localhost:8545 --broadcast
forge script script/DeployPricePredictionGame.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Testnet Deployment

Deploy to Sepolia testnet:

```bash
forge script script/DeployRaffle.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
forge script script/DeployPricePredictionGame.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

## Configuration

### Chainlink VRF Configuration

For the Raffle contract, you need to:
1. Create a VRF subscription on [Chainlink's website](https://vrf.chain.link/)
2. Add your contract as a consumer
3. Fund your subscription with LINK

### Chainlink Price Feeds

The Price Prediction Game uses Chainlink Price Feeds. Here are some available feeds:

#### Sepolia Testnet
- BTC/USD: `0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43`
- ETH/USD: `0x694AA1769357215DE4FAC081bf1f309aDC325306`

#### Mainnet
- BTC/USD: `0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c`
- ETH/USD: `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`

## Security Considerations

- Both contracts have been designed with security best practices
- Reentrancy protection is implemented in the claim function
- All external calls are checked for success
- Input validation is performed for all parameters
- Consider getting a professional audit before deploying to mainnet with real value