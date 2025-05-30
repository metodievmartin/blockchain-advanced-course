# Blockchain Advanced Course Labs

This repository contains practical labs and implementations completed during the SoftUni Blockchain Advanced Course. Each directory represents a different topic covered in the course, demonstrating implementations of advanced blockchain development concepts.

The corresponding exercises for this course can be found in this repository: [blockchain-advanced-course-exercises](https://github.com/metodievmartin/blockchain-advanced-course-exercises)

> **Disclaimer**: These implementations are primarily for educational purposes. Many contracts are intentionally simplified to focus on specific learning objectives and concepts being taught in each module. They may not include all the security features or optimizations that would be required in production-ready code. 

## Course Topics

### 01. Foundry Toolchain
- Implementation of smart contracts using Foundry's development environment
- Practical exercises with Forge, Cast, Anvil, and Chisel

### 02. Security in Smart Contract Development
- Common Vulnerabilities in Smart Contracts
- Security Best Practices for Smart Contract Development
- Tools for Static and Dynamic Analysis (Slither and MythX)
- Examples of DoS, Force Feed, and Reentrancy attacks

### 03. Gas Optimization Techniques
- Implementation of gas-efficient smart contracts
- Practical examples of optimization patterns and techniques

### 04. Exercise: Secure and Gas Optimised Contracts with Foundry
- Practical application of security principles and gas optimisation techniques
- Implementation of secure and efficient contract patterns

### 05. Signatures and Advanced ERC-20 Standards
- Implementation of cryptographic signatures
- Demonstration of structured data signing (EIP-712)
- Advanced token functionalities beyond the basic ERC-20 standard
- Hardhat examples: EIP191, EIP712, and ERC2612 permit signature implementations

### 06. Merkle Trees and Advanced NFT Standards
- Implementation of Merkle tree verification for allowlists
- JavaScript utilities for Merkle tree generation and proof validation
- Hardhat examples: Merkle tree-based airdrop and verification contracts
- Implementation of ERC-2981 NFT Royalty Standard

### 07. Exercise: Advanced Token Contracts
- Implementation of tokens with advanced functionality
- Extensions of standard token interfaces with additional features

### 08. Upgradeability
- Implementation of various upgradeability patterns:
  - Transparent Proxy Pattern for contract upgradeability
  - Initializable contracts with OpenZeppelin's upgradeable contracts
  - Factory with Minimal Proxy Pattern (EIP-1167 Clones)
- Foundry implementation of upgradeable contracts
- Hardhat examples: `BasicProxy`, `NFTFactory`, and `Treasury`/`TreasuryV2` upgrade pattern
- Deployment and upgrade scripts for both Foundry and Hardhat implementations

### 09. Oracles and External Data Feeds
- Integration with Chainlink VRF for verifiable randomness
- Implementation of price-feed oracles for financial applications
- `Raffle.sol`: Decentralized lottery using Chainlink VRF
- `PricePredictionGame.sol`: Betting game using Chainlink Price Feeds

### 10. DeFi Applications
- Implementation of DeFi primitives and protocols
- `CPAMM.sol`: Constant Product Automated Market Maker implementation
- Liquidity provision and token swapping mechanisms

### Exam Preparation
- `CharityRaffle.sol`: A decentralized charity raffle system
- Implementation of Merkle tree allowlists for participant verification
- Integration with Chainlink VRF for fair winner selection
- Transparent proxy pattern for contract upgradeability

## Setup and Usage

### Prerequisites
- Node.js v22 or above and npm
- Foundry tools (forge, cast, anvil)

### Installation
```bash
# Clone the repository
git clone https://github.com/metodievmartin/blockchain-advanced-course.git

# Change to the project directory
cd blockchain-advanced-course

# Install dependencies
npm install

# Install Foundry submodules
forge install
```

### Environment Setup
Copy the example environment file and configure your variables:
```bash
cp .env.example .env
```

Required environment variables:
- `PRIVATE_KEY`: Your wallet's private key for deployments
- `SEPOLIA_RPC_URL`: RPC endpoint for Sepolia testnet
- `ETHERSCAN_API_KEY`: For contract verification
- `CHAINLINK_SUBSCRIPTION_ID`: For VRF-based contracts

### Running Tests
```bash
# Run all tests
forge test

# Run tests with more verbosity
forge test -vvv

# Run specific test file
forge test --match-path test/exam-prep/CharityRaffleTest.t.sol
```

### Deployment Examples

#### Local Deployment
```bash
# Deploy to local Anvil network
forge script script/exam-prep/DeployCharityRaffle.s.sol --broadcast --network anvil --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

#### Testnet Deployment
```bash
# Deploy to Sepolia testnet
forge script script/exam-prep/DeployCharityRaffle.s.sol --broadcast --network sepolia --verify --private-key ${PRIVATE_KEY}
```

## Project Structure

```
blockchain-advanced-course/
├── script/                 # Foundry deployment scripts
├── src/                    # Foundry smart contract source code
│   ├── 01-foundry/           # Foundry basics
│   ├── 02_security/          # Security patterns
│   ├── 03_gas_optimisation/  # Gas optimization techniques
│   ├── 05_signatures/        # Cryptographic signatures
│   ├── 09_oracles/           # Oracle integrations
│   ├── 10_defi/              # DeFi implementations
│   └── exam-prep/            # Exam preparation project
├── test/                   # Foundry test files
├── js_scripts/             # JavaScript utilities
└── hardhat/                # Hardhat project examples
    ├── contracts/            # Hardhat smart contracts
    │   ├── 05_signatures/      # EIP191, EIP712, and ERC2612 implementations
    │   ├── 06_merkle_trees/    # Merkle tree verification contracts
    │   ├── 08_upgradeability/  # Proxy patterns and upgradeable contracts
    │   └── 09_oracles/         # Oracle integration examples
    ├── scripts/              # Hardhat deployment scripts
    └── test/                 # Hardhat test files
