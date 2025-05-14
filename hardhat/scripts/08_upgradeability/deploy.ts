import { ethers, upgrades } from 'hardhat';
import { saveDeploymentData } from './helpers';

/**
 * DEPLOY SCRIPT — UPGRADEABLE PROXY (TRANSPARENT PATTERN)
 *
 * This script deploys an upgradeable smart contract using OpenZeppelin's `@openzeppelin/hardhat-upgrades` plugin.
 * It follows the Transparent Proxy pattern, where logic and storage are separated.
 *
 * `TransparentUpgradeableProxy.sol` => https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/transparent/TransparentUpgradeableProxy.sol
 * `ProxyAdmin.sol` => https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/transparent/ProxyAdmin.sol
 * `Implementation Contract` => `hardhat/contracts/08_upgradeability/Treasury.sol`
 *
 * What happens under the hood:
 *
 * 1. A new `Implementation Contract` is deployed.
 *    - Contains the actual function logic (`Treasury` in this case).
 *    - Does not hold any state directly.
 *
 * 2. A `ProxyAdmin Contract` is deployed (if not already).
 *    - A special contract that manages proxy upgrades.
 *    - Only this admin can change the implementation address of the proxy.
 *
 * 3. A `Transparent Proxy Contract` is deployed.
 *    - This is the contract users interact with.
 *    - It holds all the contract state and forwards function calls to the implementation via `delegatecall`.
 *
 * 4. The proxy runs the `initialize(owner)` function.
 *    - Since constructors are not used in upgradeable contracts, initialization is done through an initializer.
 *    - Ensures the contract is correctly set up with ownership and initial state.
 *
 * Result: A fully functioning upgradeable contract, with logic in the implementation and storage in the proxy.
 */

// 1. Run `npx hardhat node` to start the local network
// 2. Run `npx hardhat run scripts/08_upgradeability/deploy.ts --network localhost` to deploy the contract on the local network
async function main() {
  const TreasuryFactory = await ethers.getContractFactory('Treasury');
  const owner = (await ethers.getSigners())[0];
  console.log('Deploying Treasury with account:', owner.address);

  // Deploys a proxy and sets up the initial implementation
  // Also calls `initialize(owner)` after deployment to mimic constructor behaviour
  const treasury = await upgrades.deployProxy(TreasuryFactory, [owner.address]);
  await treasury.waitForDeployment();

  const proxyAddress = await treasury.getAddress();
  console.log('Treasury deployed to:', proxyAddress);

  saveDeploymentData({ proxyAddress, owner: owner.address });
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
