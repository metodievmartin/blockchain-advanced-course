import { task } from 'hardhat/config';
import fs from 'fs';

task('06-test-airdrop', 'Deploys AirDropToken and tests claims').setAction(
  async (_, hre) => {
    // Load signers: 0 = eligible, 1 = deployer, 2 = attacker
    const [eligibleUser, deployer, signer2] = await hre.ethers.getSigners();

    // Load Merkle data from file
    const merkleData = JSON.parse(
      fs.readFileSync('./merkle_data_airdrop.json', 'utf-8'),
    );

    const root = merkleData.root;
    const validEntry = merkleData.proofs.find(
      (p: any) =>
        p.address.toLowerCase() === eligibleUser.address.toLowerCase(),
    );

    if (!validEntry) {
      throw new Error(
        `No proof found for eligible address: ${eligibleUser.address}`,
      );
    }

    const AirDropTokenFactory =
      await hre.ethers.getContractFactory('AirDropToken');
    const airDropToken = await AirDropTokenFactory.deploy(
      deployer.address,
      root,
    );
    await airDropToken.waitForDeployment();
    console.log(`AirDropToken deployed at: ${await airDropToken.getAddress()}`);

    // VALID CLAIM
    try {
      const tx = await airDropToken
        .connect(eligibleUser)
        .claimAirDrop(validEntry.amount, validEntry.proof);

      await tx.wait();

      console.log(`Valid claim by ${eligibleUser.address} succeeded`);
    } catch (err) {
      console.error(`Valid claim failed:`, err);
    }

    // INVALID CLAIM by signer2 (not in the Merkle tree)
    try {
      const fakeAmount = hre.ethers.parseEther('999');
      const fakeProof = merkleData.proofs[0].proof;

      const tokenAsAttacker = airDropToken.connect(signer2);
      const tx = await tokenAsAttacker.claimAirDrop(fakeAmount, fakeProof);

      await tx.wait();

      console.error(`Invalid claim unexpectedly succeeded`);
    } catch {
      console.log(`Invalid claim by ${signer2.address} failed as expected`);
    }
  },
);
