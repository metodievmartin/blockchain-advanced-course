const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");

const whitelistData = JSON.parse(
  fs.readFileSync("whitelist_data.json", "utf8"),
);

const values = whitelistData.participants.map((participant) => [
  participant.index,
  participant.address,
]);

const tree = StandardMerkleTree.of(values, ["uint256", "address"]);

// (3)
console.log("Merkle Root:", tree.root);

// (4)
fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));

const proofs = [];
for (const [i, v] of tree.entries()) {
  const proof = tree.getProof(i);
  proofs.push({ address: v[1], proof, index: v[0] });
}

const proofsData = {
  root: tree.root,
  proofs,
};

fs.writeFileSync("proofs.json", JSON.stringify(proofsData, null, 2));
