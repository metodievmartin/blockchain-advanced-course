import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { ethers } from 'hardhat';
import { expect } from 'chai';
import { deployRaffleFixture } from './fixtures';

describe('Raffle', function () {
  it('should deploy with the correct initial state', async function () {
    const { raffle, entranceFee } = await loadFixture(deployRaffleFixture);

    // 1. Check entrance fee is set as expected (for example, 0.1 ether)
    expect(await raffle.entranceFee()).to.equal(entranceFee);

    // 2. Raffle state should be OPEN (typically 0)
    expect(await raffle.raffleState()).to.equal(0);

    // 3. Players array should be empty
    const players = await raffle.getPlayers();
    expect(players.length).to.equal(0);

    // 4. Contract should have zero balance at deployment
    expect(await ethers.provider.getBalance(raffle.target)).to.equal(0);
  });

  it('should enter and pick a winner', async () => {
    const { raffle, raffleAddress, vrfCoordinator, entranceFee, player } =
      await loadFixture(deployRaffleFixture);

    await raffle.connect(player).enterRaffle({ value: entranceFee });

    // Directly request the random winner
    const reqTx = await raffle.requestRandomWinner();
    const reqReceipt = await reqTx.wait();

    // Simulate Chainlink VRF callback
    await expect(vrfCoordinator.fulfillRandomWords(1n, raffleAddress)).to.emit(
      raffle,
      'WinnerPicked',
    );

    // Check the winner is the player
    const winner = await raffle.recentWinner();
    expect(winner).to.equal(await player.getAddress());
  });
  it('should allow multiple players to enter and track them correctly', async function () {
    const { raffle, entranceFee } = await loadFixture(deployRaffleFixture);
    const [player1, player2, player3] = await ethers.getSigners();

    // Player 1 enters
    await raffle.connect(player1).enterRaffle({ value: entranceFee });
    // Player 2 enters
    await raffle.connect(player2).enterRaffle({ value: entranceFee });
    // Player 3 enters
    await raffle.connect(player3).enterRaffle({ value: entranceFee });

    const players = await raffle.getPlayers();

    // Check all players are stored correctly
    expect(players[0]).to.equal(player1.address);
    expect(players[1]).to.equal(player2.address);
    expect(players[2]).to.equal(player3.address);
    expect(players.length).to.equal(3);
  });
});
