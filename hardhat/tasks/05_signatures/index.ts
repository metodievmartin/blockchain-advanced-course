import { task } from 'hardhat/config';

// Custom Hardhat task to sign a message and verify it using the EIP191 contract
task('05-sign', '').setAction(async (taskArgs, { ethers }) => {
  // Get the first signer from Hardhat's default accounts
  const [signer] = await ethers.getSigners();

  // The message to sign (can be any readable string)
  const message = 'Hello, EIP191 0x45';

  // Convert the message to bytes and hash it (this matches the on-chain logic)
  const hashBytes = ethers.getBytes(
    ethers.keccak256(ethers.toUtf8Bytes(message)),
  );

  // Sign the hash using the signer's private key (returns a standard EIP-191 signature)
  // Automatically applies the EIP-191 prefix before signing
  const signature = await signer.signMessage(hashBytes);

  // Parse the signature into r, s, v components for use with ecrecover
  const sig = ethers.Signature.from(signature);

  // Deploy the EIP191 smart contract
  const contractFactory = await ethers.getContractFactory('EIP191');
  const contract = await contractFactory.deploy();
  await contract.waitForDeployment();

  // Call the contract to verify the signature on-chain
  const result = await contract.verifySignature(message, sig.v, sig.r, sig.s);

  console.log('Signer: ', signer.address);
  console.log('Recovered signer: ', result);

  // Extra: verify signature off-chain (mirrors the same logic manually)
  const messageHash = ethers.hashMessage(hashBytes); // Adds Ethereum prefix
  const recoveredAddress = ethers.recoverAddress(messageHash, signature);

  // Compare on-chain recovered address and off-chain for consistency
  console.log(
    'Signatures match:',
    signer.address.toLowerCase() === recoveredAddress.toLowerCase(),
  );
});

task(
  '05-sign712',
  'A task to sign and verify an EIP-712 typed structured message',
).setAction(async (taskArgs, { ethers }) => {
  // Get the signer (wallet/account) that will create the signature
  const [signer] = await ethers.getSigners();

  // Deploy the EIP712Verifier contract
  const contractFactory = await ethers.getContractFactory('EIP712Verifier');
  const contract = await contractFactory.deploy();
  await contract.waitForDeployment();

  // Get deployed contract address for use in domain
  const contractAddress = await contract.getAddress();

  // Sample operator (recipient/delegate) address
  const operator = '0xC4973de5eE925b8219f1E74559FB217A8e355EcF';

  // The amount being approved, represented in ether
  const value = ethers.parseEther('0.5');

  // Retrieve current network info from the connected provider
  const network = await ethers.provider.getNetwork();

  // Define the EIP-712 signing domain (must match contract's domain)
  const domain = {
    name: 'VaultProtocol', // Same as passed to EIP712 constructor
    version: 'v1', // Same version string
    chainId: Number(network.chainId), // Dynamically fetch the current network’s chain ID (31337 for Hardhat local network)
    verifyingContract: contractAddress, // The address of the deployed contract verifying the signature
  };

  // Define the EIP-712 type structure — must match the Solidity hash
  const types = {
    VaultApproval: [
      { name: 'owner', type: 'address' },
      { name: 'operator', type: 'address' },
      { name: 'value', type: 'uint256' },
    ],
  };

  // Create the actual message payload to be signed
  const messageValue = {
    owner: signer.address,
    operator,
    value,
  };

  // Create an EIP-712 compliant signature
  const signature = await signer.signTypedData(domain, types, messageValue);

  // Parse the returned signature into (v, r, s) components
  const sig = ethers.Signature.from(signature);

  // Call the smart contract to verify the EIP-712 signature
  const isValid = await contract.verify(
    signer.address,
    operator,
    value,
    sig.v,
    sig.r,
    sig.s,
  );

  // Log result of on-chain verification
  console.log('Is valid:', isValid); // true if signature matches signer and message
});
