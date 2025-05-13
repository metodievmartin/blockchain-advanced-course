const { ethers } = require("ethers");
const fs = require("fs");

const contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; // Replace it with the actual contract address
// EIP-712 domain separator
const domain = {
  name: "AIAgentShare",
  version: "1",
  chainId: 31337, // Replace with actual chain ID
  verifyingContract: contractAddress,
};

// EIP-712 types
const types = {
  BuyAuthorization: [
    { name: "buyer", type: "address" },
    { name: "amount", type: "uint256" },
    { name: "deadline", type: "uint256" },
  ],
};

async function generateSignature() {
  // Create a wallet with a private key (for testing purposes)
  const privateKey =
    "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"; // Replace with actual private key
  const wallet = new ethers.Wallet(privateKey);

  const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

  // Create the message to sign
  const message = {
    buyer: wallet.address,
    amount: "100000000000000000000", // Example amount of tokens
    deadline: deadline,
  };

  // Sign the message
  const signature = await wallet.signTypedData(domain, types, message);

  // Create the signature object with stringified BigInt values
  const signatureData = {
    signature,
    message: {
      buyer: message.buyer,
      amount: message.amount.toString(),
      deadline: message.deadline.toString(),
    },
    deadline: deadline.toString(),
  };

  // Save signature to a file
  fs.writeFileSync("signature.json", JSON.stringify(signatureData, null, 2));

  console.log("Signature generated and saved to signature.json");
  console.log("Wallet address:", wallet.address);
  console.log("Signature:", signature);
}

generateSignature().catch(console.error);
