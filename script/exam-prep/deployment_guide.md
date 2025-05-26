# CharityRaffle Deployment Guide

This guide provides step-by-step instructions for deploying the CharityRaffle smart contract to both local Anvil and Sepolia networks.

## Overview

The CharityRaffle contract is a transparent upgradeable proxy contract that implements a raffle system with the following features:
- Ticket purchase with Merkle proof verification for whitelisting
- Chainlink VRF for random winner selection
- Prize distribution between winners and a charity wallet
- Owner-controlled raffle management

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- [Node.js](https://nodejs.org/) and npm installed
- Basic understanding of Solidity and Ethereum
- For Sepolia deployment: ETH in your wallet and a Chainlink VRF subscription

## Environment Setup

1. Clone the repository and navigate to the project directory
2. Install dependencies:
   ```bash
   forge install
   ```

3. Create a `.env` file based on `.env.example`:
   ```bash
   cp .env.example .env
   ```

4. Configure your `.env` file with the following variables:

```
# Required for all deployments
PRIVATE_KEY=your_private_key

# Required for Sepolia deployment
SEPOLIA_RPC_URL=your_sepolia_rpc_url
ETHERSCAN_API_KEY=your_etherscan_api_key

# Required for CharityRaffle deployment on Sepolia
VRF_SUBSCRIPTION_ID=your_vrf_subscription_id
OWNER_ADDRESS=your_owner_address
CHARITY_WALLET_ADDRESS=your_charity_wallet_address
DEPLOYER_ADDRESS=your_deployer_address
```
## IMPORTANT

> If you make changes to the files, make sure you run:
> ```bash
> forge clean && forge build
>```
> Otherwise, may get errors. That's because of how the upgrade package works

## Local Deployment (Anvil)

For local testing, the deployment script automatically:
- Deploys a mock VRF coordinator
- Creates and funds a VRF subscription
- Uses predefined Anvil accounts for owner and charity wallet
- Uses a fixed merkle root for whitelisting

### Steps:

1. Start Anvil in a separate terminal:
   ```bash
   anvil
   ```

2. Deploy the CharityRaffle contract with the private key of the first Anvil account:
   ```bash
   forge script script/exam-prep/DeployCharityRaffle.s.sol:DeployCharityRaffle --broadcast --network anvil --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
   ```

3. The deployment script will:
   - Deploy the CharityRaffle implementation and proxy contracts
   - Add the CharityRaffle contract as a consumer to the VRF subscription
   - Fund the VRF subscription with both LINK tokens and native ETH

4. After successful deployment, you'll see the proxy and implementation addresses in the console output.

## Sepolia Deployment

For Sepolia deployment, you need to:
- Have a funded Chainlink VRF subscription on Sepolia
- Set all required environment variables in your `.env` file

### Steps:

1. Make sure your `.env` file is properly configured with all required variables.

2. Deploy the CharityRaffle contract to Sepolia:
   ```bash
   forge script script/exam-prep/DeployCharityRaffle.s.sol:DeployCharityRaffle --broadcast --network sepolia --verify --private-key $PRIVATE_KEY
   ```

3. The deployment script will:
   - Deploy the CharityRaffle implementation and proxy contracts
   - Initialize the contract with the parameters from your `.env` file
   - Verify the contract on Etherscan if `--verify` flag is used

4. After successful deployment, you'll see the proxy and implementation addresses in the console output.

## Contract Verification

The contract will be automatically verified on Etherscan when using the `--verify` flag during Sepolia deployment. If verification fails, you can manually verify the contract:

```bash
forge verify-contract <IMPLEMENTATION_ADDRESS> src/exam-prep/CharityRaffle.sol:CharityRaffle --chain-id 11155111 --watch --etherscan-api-key ${ETHERSCAN_API_KEY}
```

## Post-Deployment

After deploying the contract, you'll need to:

1. **For Sepolia**: 
   - Ensure your VRF subscription has enough LINK tokens
   - Add the deployed proxy contract as a consumer to your VRF subscription through the Chainlink VRF UI

2. **For both networks**:
   - Interact with the contract through a frontend or directly using Foundry's `cast` command
   - Test the raffle functionality by buying tickets, requesting random winners, and claiming prizes

## Running Tests

The CharityRaffle contract includes a test suite that verifies all functionality. 
The tests use Foundry's testing framework and mock the Chainlink VRF coordinator for deterministic testing.

### Running All Tests

To run all tests for the CharityRaffle contract:

```bash
forge test --match-path test/exam-prep/CharityRaffleTest.t.sol -v
```

The `-v` flag increases verbosity. You can use different verbosity levels:
- `-v`: Shows test names and pass/fail status
- `-vv`: Also shows logs and emitted events
- `-vvv`: Shows even more detailed information including gas usage
- `-vvvv`: Shows step-by-step execution trace

### Running Specific Tests

To run a specific test or group of tests, use the `--match-test` flag:

```bash
# Run only ticket purchasing tests
forge test --match-path test/exam-prep/CharityRaffleTest.t.sol --match-test "test_Buy" -v

# Run only winner selection tests
forge test --match-path test/exam-prep/CharityRaffleTest.t.sol --match-test "test_RequestRandomWinners" -v

# Run only prize claiming tests
forge test --match-path test/exam-prep/CharityRaffleTest.t.sol --match-test "test_ClaimPrize" -v
```

## Environment Variables Explained

| Variable | Description | Required For |
|----------|-------------|-------------|
| `PRIVATE_KEY` | Your Ethereum wallet private key | All deployments |
| `SEPOLIA_RPC_URL` | RPC URL for the Sepolia network | Sepolia deployment |
| `ETHERSCAN_API_KEY` | API key for Etherscan verification | Sepolia verification |
| `VRF_SUBSCRIPTION_ID` | Your Chainlink VRF subscription ID | Sepolia deployment |
| `OWNER_ADDRESS` | Address that will be the owner of the contract | Sepolia deployment |
| `CHARITY_WALLET_ADDRESS` | Address that will receive charity funds | Sepolia deployment |
| `DEPLOYER_ADDRESS` | Address that will deploy the contract | Sepolia deployment |

## Troubleshooting

1. **VRF Subscription Issues**:
   - Ensure your VRF subscription is properly funded with LINK tokens
   - Verify that the deployed contract is added as a consumer to your subscription

2. **Deployment Failures**:
   - Check that all environment variables are correctly set
   - Ensure you have enough ETH in your wallet for deployment gas fees

3. **Verification Failures**:
   - Make sure your Etherscan API key is valid
   - Try manual verification with the correct contract parameters
