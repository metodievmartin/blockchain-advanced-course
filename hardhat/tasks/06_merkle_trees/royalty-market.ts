import { task } from 'hardhat/config';

task(
  '06-royalty-market-test',
  'Deploys and tests royalty-enabled NFT with marketplace',
).setAction(async (_, hre) => {
  const [deployer, buyer, royaltyReceiver] = await hre.ethers.getSigners();

  console.log('Deployer:', deployer.address);
  console.log('Buyer:', buyer.address);
  console.log('Royalty Receiver:', royaltyReceiver.address);

  // --- Deploy Royalty Token ---
  const TokenFactory = await hre.ethers.getContractFactory('MyRoyaltyToken');
  const token = await TokenFactory.deploy(deployer.address);
  await token.waitForDeployment();

  const tokenAddress = await token.getAddress();

  console.log('Token deployed at:', tokenAddress);

  // --- Deploy Marketplace ---
  const MarketplaceFactory =
    await hre.ethers.getContractFactory('RoyaltyMarketplace');
  const marketplace = await MarketplaceFactory.deploy();
  await marketplace.waitForDeployment();

  const marketplaceAddress = await marketplace.getAddress();

  console.log('Marketplace deployed at:', marketplaceAddress);

  // --- Mint a Token ---
  const txMint = await token.safeMint(deployer.address);
  const receiptMint = await txMint.wait();
  let tokenId = 0;
  const log = receiptMint?.logs?.[0];

  if (log && 'args' in log) {
    tokenId = log.args[2];
  }
  console.log('Minted Token ID:', tokenId.toString());

  // --- Set 10% Royalty ---
  const royaltyFee = 1000; // 10% (1000 / 10000)
  await (
    await token.setDefaultRoyalty(royaltyReceiver.address, royaltyFee)
  ).wait();
  console.log(
    `Set default royalty to ${royaltyReceiver.address} at ${royaltyFee / 10000}%`,
  );

  // --- Approve Marketplace ---
  await (await token.approve(marketplaceAddress, tokenId)).wait();
  console.log('Approved marketplace to manage token');

  // --- List the Token ---
  const price = hre.ethers.parseEther('1.0');
  await (await marketplace.listToken(tokenAddress, tokenId, price)).wait();
  console.log(`Token listed for sale at ${hre.ethers.formatEther(price)} ETH`);

  // --- Buyer Buys the Token ---
  await (
    await marketplace
      .connect(buyer)
      .buyToken(tokenAddress, tokenId, { value: price })
  ).wait();
  console.log('Buyer purchased the token');

  // --- Check Pending Balances ---
  const sellerEarnings = await marketplace.pendingWithdrawals(deployer.address);
  const royaltyEarnings = await marketplace.pendingWithdrawals(
    royaltyReceiver.address,
  );

  console.log(`Seller earnings: ${hre.ethers.formatEther(sellerEarnings)} ETH`);
  console.log(
    `Royalty earnings: ${hre.ethers.formatEther(royaltyEarnings)} ETH`,
  );

  const expectedRoyalty = (price * BigInt(royaltyFee)) / BigInt(10000);
  const expectedSeller = price - expectedRoyalty;

  if (sellerEarnings !== expectedSeller) {
    console.error('Seller earnings incorrect');
  }

  if (royaltyEarnings !== expectedRoyalty) {
    console.error('Royalty earnings incorrect');
  }

  console.log('All balances verified');
});
