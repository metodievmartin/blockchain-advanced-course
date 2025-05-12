import { MerkleTree } from 'merkletreejs';
import { ethers } from 'ethers';
import fs from 'fs';

const participants = [
  '0x0000000000000000000000000000000000000003',
  '0x0000000000000000000000000000000000000004',
  '0x0000000000000000000000000000000000000005',
];

const leaves = participants.map((x) => ethers.keccak256(x));

console.log('Leaves: ', leaves);

// If we use OpenZeppelin's merkle tree library, we don't need to set these options: duplicateOdd, sortPairs
// It's already configured to work with Solidity's keccak256 function and sort the leaves by default
const tree = new MerkleTree(leaves, ethers.keccak256, {
  duplicateOdd: false,
  sortPairs: true,
});

console.log('Tree: \n', tree.toString());

const root = tree.getHexRoot();
console.log('Root: ', root);

const leaf = ethers.keccak256(participants[0]);
const proof = tree.getProof(leaf);
const isProofValid = tree.verify(proof, leaf, root);
console.log('Is proof valid for correct address: ', isProofValid);

// Testing with an incorrect address
const incorrectAddress = '0x0000000000000000000000000000000000000006';
const incorrectLeaf = ethers.keccak256(incorrectAddress);
const incorrectProof = tree.getProof(incorrectLeaf);
const isIncorrectProofValid = tree.verify(incorrectProof, incorrectLeaf, root);
console.log('Is proof valid for incorrect address: ', isIncorrectProofValid);

// Create an array of proof objects for each participant address
// Each object contains the address and its corresponding Merkle proof
const proofs = participants.map((x, index) => {
  // Get the Merkle proof for the current participant's leaf
  const merkleProof = tree.getProof(leaves[index]);

  // Convert each proof element to a hexadecimal string with '0x' prefix
  const hexProof = merkleProof.map((x) => '0x' + x.data.toString('hex'));

  return {
    address: x, // Original participant address
    proof: hexProof, // Array of hex strings representing the Merkle proof
  };
});

// Create an output object containing the Merkle root and all proofs
const output = {
  root: root, // The Merkle root hash
  proofs: proofs, // Array of address-proof pairs for all participants
};

// Write the Merkle tree data to a JSON file for later use
fs.writeFileSync('merkle_data.json', JSON.stringify(output, null, 2));
