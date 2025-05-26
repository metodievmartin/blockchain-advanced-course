const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");

// Parse command line arguments
const args = process.argv.slice(2);
const network = args[0] || "sepolia"; // Default to sepolia if no argument provided

// Set file paths based on network
const inputFile = network === "local" ? "whitelist_data_local.json" : "whitelist_data.json";
const outputProofsFile = network === "local" ? "proofs_local.json" : "proofs.json";
const outputTreeFile = network === "local" ? "tree_local.json" : "tree.json";

console.log(`Generating Merkle tree for ${network} network...`);
console.log(`Using whitelist data from: ${inputFile}`);

// Read whitelist data
try {
  const whitelistData = JSON.parse(
    fs.readFileSync(inputFile, "utf8"),
  );

  const values = whitelistData.participants.map((participantAddress) => [
    participantAddress,
  ]);

  const tree = StandardMerkleTree.of(values, ["address"]);

  console.log("Merkle Root:", tree.root);

  // Write tree data
  fs.writeFileSync(outputTreeFile, JSON.stringify(tree.dump()));
  console.log(`Tree data written to: ${outputTreeFile}`);

  // Generate proofs
  const proofs = [];
  for (const [i, v] of tree.entries()) {
    const proof = tree.getProof(i);
    proofs.push({ address: v[0], proof });
  }

  const proofsData = {
    root: tree.root,
    proofs,
  };

  // Write proofs data
  fs.writeFileSync(outputProofsFile, JSON.stringify(proofsData, null, 2));
  console.log(`Proofs data written to: ${outputProofsFile}`);
  console.log("Done!");
} catch (error) {
  console.error(`Error: ${error.message}`);
  console.error(`Make sure ${inputFile} exists in the current directory.`);
  process.exit(1);
}
