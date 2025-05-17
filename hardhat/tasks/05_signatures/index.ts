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

task(
  '05-permit',
  'A task to demonstrate ERC2612 permit functionality using off-chain signatures',
).setAction(async (taskArgs, { ethers }) => {
  // Get the signer (wallet/account) that will create the permit signature
  const [owner, spender] = await ethers.getSigners();

  console.log('Owner address:', owner.address);
  console.log('Spender address:', spender.address);

  // Deploy the ERC2612 token contract
  console.log('Deploying MyToken (ERC20 with permit)...');
  const contractFactory = await ethers.getContractFactory('MyToken');
  const token = await contractFactory.deploy();
  await token.waitForDeployment();

  const tokenAddress = await token.getAddress();
  console.log('Token deployed at:', tokenAddress);

  // Mint some tokens to the owner for testing
  const mintAmount = ethers.parseEther('1000');
  await token.connect(owner).mint(owner.address, mintAmount);
  console.log(`Minted ${ethers.formatEther(mintAmount)} tokens to owner`);

  // Amount to approve via permit
  const approvalAmount = ethers.parseEther('100');
  console.log(`Approval amount: ${ethers.formatEther(approvalAmount)} tokens`);

  // Get current block timestamp for deadline calculation
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);

  if (!blockBefore) {
    throw new Error('Failed to fetch the block');
  }

  const currentTimestamp = blockBefore.timestamp;

  // Set the deadline to 1 hour from now
  const deadline = currentTimestamp + 60 * 60;
  console.log(`Permit deadline: ${new Date(deadline * 1000).toISOString()}`);

  // Get the current nonce for the owner
  const nonce = await token.nonces(owner.address);
  console.log(`Current nonce for owner: ${nonce}`);

  // Get the chain ID for the current network
  const network = await ethers.provider.getNetwork();
  const chainId = Number(network.chainId);
  console.log(`Chain ID: ${chainId}`);

  // Define the EIP-712 domain separator (must match the contract's domain)
  const domain = {
    name: 'MyToken', // Must match the token name
    version: '1', // Version is typically "1" for ERC2612
    chainId,
    verifyingContract: tokenAddress,
  };

  // Define the EIP-712 permit type structure
  const types = {
    Permit: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
      { name: 'value', type: 'uint256' },
      { name: 'nonce', type: 'uint256' },
      { name: 'deadline', type: 'uint256' },
    ],
  };

  // Create the permit message payload to be signed
  const permitMessage = {
    owner: owner.address,
    spender: spender.address,
    value: approvalAmount,
    nonce,
    deadline,
  };

  console.log('Creating permit signature...');

  // Sign the permit message using EIP-712 typed data
  const signature = await owner.signTypedData(domain, types, permitMessage);

  // Parse the signature into v, r, s components for use with permit
  const sig = ethers.Signature.from(signature);
  console.log('Signature created:', {
    v: sig.v,
    r: sig.r,
    s: sig.s,
  });

  // Check the initial allowance (should be 0)
  const initialAllowance = await token.allowance(
    owner.address,
    spender.address,
  );
  console.log(
    `Initial allowance: ${ethers.formatEther(initialAllowance)} tokens`,
  );

  // Submit the permit transaction using the spender account
  // (demonstrating that the spender can submit the permit, not the owner)
  console.log('Submitting permit transaction...');
  const permitTx = await token
    .connect(spender)
    .permit(
      owner.address,
      spender.address,
      approvalAmount,
      deadline,
      sig.v,
      sig.r,
      sig.s,
    );

  // Wait for the transaction to be mined
  await permitTx.wait();
  console.log('Permit transaction confirmed!');

  // Check the new allowance (should match the approved amount)
  const newAllowance = await token.allowance(owner.address, spender.address);
  console.log(`New allowance: ${ethers.formatEther(newAllowance)} tokens`);

  // Demonstrate a transfer using the approved allowance
  console.log('Transferring tokens using the approved allowance...');
  const transferAmount = ethers.parseEther('50');
  const transferTx = await token
    .connect(spender)
    .transferFrom(owner.address, spender.address, transferAmount);

  await transferTx.wait();
  console.log(
    `Transferred ${ethers.formatEther(transferAmount)} tokens from owner to spender`,
  );

  // Check final balances
  const ownerBalance = await token.balanceOf(owner.address);
  const spenderBalance = await token.balanceOf(spender.address);

  console.log(`Owner balance: ${ethers.formatEther(ownerBalance)} tokens`);
  console.log(`Spender balance: ${ethers.formatEther(spenderBalance)} tokens`);

  // Check the remaining allowance
  const remainingAllowance = await token.allowance(
    owner.address,
    spender.address,
  );
  console.log(
    `Remaining allowance: ${ethers.formatEther(remainingAllowance)} tokens`,
  );
});
