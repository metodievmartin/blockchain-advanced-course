import { ethers, upgrades } from 'hardhat';
import { getDeploymentData } from './helpers';

/**
 * UPGRADE SCRIPT — UPGRADE TO NEW IMPLEMENTATION
 *
 * This script upgrades the proxy contract to use a new implementation (`TreasuryV2`) while keeping the existing state.
 *
 * `TransparentUpgradeableProxy.sol` => https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/transparent/TransparentUpgradeableProxy.sol
 * `ProxyAdmin.sol` => https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/transparent/ProxyAdmin.sol
 * `Implementation Contract` => `hardhat/contracts/08_upgradeability/TreasuryV2.sol`
 *
 * What happens under the hood:
 *
 * 1. A new `Implementation Contract` is deployed.
 *    - This contract (`TreasuryV2`) contains extended or modified logic.
 *    - It must maintain a compatible storage layout with the original.
 *
 * 2. The `ProxyAdmin Contract` updates the proxy.
 *    - It changes the proxy’s internal reference to the new implementation contract.
 *    - This is done securely and atomically.
 *
 * 3. Proxy storage remains untouched.
 *    - All balances, state variables, and ownership persist across upgrades.
 *    - Only the logic code is swapped out.
 *
 * NOTE:
 * - `initialize()` is not re-run (it's protected by `initializer`).
 * - If additional setup is required (e.g., for new state vars), define a `reinitializer(version)` function.
 *
 * Result: The proxy now runs the new logic from `TreasuryV2` but keeps its original state.
 */

// 1. Make sure the local network is running and the contract is deployed
// 2. Run `npx hardhat run scripts/08_upgradeability/upgrade.ts --network localhost` to upgrade the contract on the local network
async function main() {
  const { proxyAddress } = getDeploymentData();
  console.log(`Upgrading contract at address: ${proxyAddress}`);

  // Upgrades the proxy to use TreasuryV2 logic
  // The proxy storage remains untouched; only logic is swapped
  const TreasuryV2Factory = await ethers.getContractFactory('TreasuryV2');
  const upgraded = await upgrades.upgradeProxy(proxyAddress, TreasuryV2Factory);

  console.log('Upgrade complete. Address:', await upgraded.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
