import { ethers } from 'hardhat';
import { EventArgs, getEventArgs } from '../../utils';
import { VRFCoordinatorV2_5Mock } from '../../typechain-types';

export async function deployRaffleFixture() {
  const BASE_FEE = ethers.parseEther('0.25');
  const GAS_PRICE_LINK = 1e9;
  const WEI_PER_UNIT_LINK = ethers.parseUnits('0.001', 'ether'); // 0.001 ETH

  const [deployer, player] = await ethers.getSigners();

  // Deploy mock VRFCoordinatorV2
  const vrfCoordinatorV25MockFactory = await ethers.getContractFactory(
    'VRFCoordinatorV2_5Mock',
  );
  const vrfCoordinator = await vrfCoordinatorV25MockFactory.deploy(
    BASE_FEE,
    GAS_PRICE_LINK,
    WEI_PER_UNIT_LINK,
  );
  await vrfCoordinator.waitForDeployment();
  const vrfCoordinatorAddress = await vrfCoordinator.getAddress();

  // Create subscription
  const tx = await vrfCoordinator.createSubscription();
  const receipt = await tx.wait();
  const SUBSCRIPTION_CREATED_EVENT = 'SubscriptionCreated';
  const iface = vrfCoordinator.interface;

  // Extract the specific event type
  type SubscriptionCreatedArgs = EventArgs<
    VRFCoordinatorV2_5Mock['filters'][typeof SUBSCRIPTION_CREATED_EVENT]
  >;

  const { subId } = getEventArgs<SubscriptionCreatedArgs>(
    receipt?.logs ?? [],
    iface,
    SUBSCRIPTION_CREATED_EVENT,
  );

  // Fund it
  await vrfCoordinator.fundSubscriptionWithNative(subId, {
    value: ethers.parseEther('10'),
  });

  // Deploy Raffle
  const entranceFee = ethers.parseEther('0.1');
  const gasLane =
    '0x0000000000000000000000000000000000000000000000000000000000000000';
  const callbackGasLimit = 100000;

  const Raffle = await ethers.getContractFactory('Raffle');
  const raffle = await Raffle.deploy(
    entranceFee,
    subId,
    gasLane,
    callbackGasLimit,
    vrfCoordinatorAddress,
  );

  await raffle.waitForDeployment();
  const raffleAddress = await raffle.getAddress();

  // Authorise raffle as consumer
  await vrfCoordinator.addConsumer(subId, raffleAddress);

  return {
    raffle,
    raffleAddress,
    vrfCoordinator,
    vrfCoordinatorAddress,
    entranceFee,
    deployer,
    player,
  };
}
