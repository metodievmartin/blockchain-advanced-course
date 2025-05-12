import { task } from 'hardhat/config';
import fs from 'fs';

task(
  '06-verify-participant',
  'Deploys ParticipantsVerifier and tests proof validity',
).setAction(async (taskArgs, hre) => {
  const data = JSON.parse(fs.readFileSync('./merkle_data.json', 'utf-8'));
  const [validCase, invalidCase] = [data.proofs[0], data.proofs[2]];

  const ParticipantsVerifier = await hre.ethers.getContractFactory(
    'ParticipantsVerifier',
  );
  const contract = await ParticipantsVerifier.deploy(data.root);
  await contract.waitForDeployment();
  console.log('Contract deployed at:', await contract.getAddress());

  // Valid test
  const validResult = await contract.isParticipant(
    validCase.address,
    validCase.proof,
  );
  console.log(`isParticipant (valid):`, validResult); // Expected: true

  // Invalid test
  const invalidResult = await contract.isParticipant(
    '0x0000000000000000000000000000000000000066',
    invalidCase.proof,
  );
  console.log(`isParticipant (invalid):`, invalidResult); // Expected: false
});
