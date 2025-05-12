import { MerkleTree } from 'merkletreejs';
import { ethers } from 'hardhat';
import fs from 'fs';

/**
 * Main function to generate a Merkle tree for airdrop data using Hardhat signers.
 * The Merkle root and individual proofs are written to `merkle_data_airdrop.json`.
 */
async function main() {
  // Get the list of signers provided by the Hardhat network
  const [firstSigner] = await ethers.getSigners();
  console.log('Using first Hardhat signer:', firstSigner.address);

  /**
   * This list represents recipients of an airdrop.
   * Each entry contains an Ethereum address and a number of tokens (in wei).
   */
  const recipients = [
    {
      address: firstSigner.address, // First signer from Hardhat test accounts
      amount: ethers.parseEther('100'), // 100 tokens
    },
    {
      address: '0x0000000000000000000000000000000000000004',
      amount: ethers.parseEther('200'),
    },
    {
      address: '0x0000000000000000000000000000000000000005',
      amount: ethers.parseEther('300'),
    },
    {
      address: '0x0000000000000000000000000000000000000006',
      amount: ethers.parseEther('400'),
    },
    {
      address: '0x0000000000000000000000000000000000000007',
      amount: ethers.parseEther('500'),
    },
  ];

  /**
   * Convert each recipient into a Merkle leaf using keccak256 hash.
   * We pack the address and amount using `solidityPacked` to match Solidity's `abi.encodePacked(...)`.
   */
  const leaves = recipients.map((x) =>
    ethers.keccak256(
      ethers.solidityPacked(['address', 'uint256'], [x.address, x.amount]),
    ),
  );

  /**
   * Create a Merkle Tree from the leaves using keccak256 as the hash function
   * `sortPairs: true` ensures consistent ordering for reliable root generation
   */
  const tree = new MerkleTree(leaves, ethers.keccak256, {
    sortPairs: true,
  });

  // Display the tree for debugging/visualisation
  console.log('Merkle Tree:\n', tree.toString());

  // Get the Merkle root (to be stored in the smart contract)
  const root = tree.getHexRoot();

  /**
   * Generate proofs for each recipient.
   * Each proof allows an address to prove they are in the Merkle tree using their data.
   */
  const proofs = recipients.map((x, index) => {
    return {
      address: x.address,
      amount: x.amount.toString(), // Convert BigInt to string for JSON storage
      proof: tree
        .getProof(leaves[index])
        .map((x) => '0x' + x.data.toString('hex')), // Convert Buffer to hex string
    };
  });

  // Output structure containing the root and all address proofs
  const output = {
    root: root,
    proofs: proofs,
  };

  // Save the output to a JSON file for use in deployment or testing
  fs.writeFileSync('merkle_data_airdrop.json', JSON.stringify(output, null, 2));

  console.log('Merkle data saved to merkle_data_airdrop.json');
}

main().catch((error) => {
  console.error('Error generating Merkle tree:', error);
  process.exitCode = 1;
});
