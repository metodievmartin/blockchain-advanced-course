// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;


import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "@test/09_oracles/mocks/MockV3Aggregator.sol";
import {PricePredictionGame} from "@/09_oracles/PricePredictionGame.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @dev Deployment script for `PricePredictionGame` contract
 */
contract DeployPricePredictionGame is Script {
    function run() external returns (PricePredictionGame, HelperConfig) {
        return run(msg.sender);
    }

    function run(
        address owner
    ) public returns (PricePredictionGame, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        // 1. Create and deploy a MockV3Aggregator for local testing
        address priceFeedAddress;

        if (block.chainid == 31337) {
            vm.startBroadcast();
            MockV3Aggregator mockPriceFeed = new MockV3Aggregator(8, 2000e8);
            vm.stopBroadcast();

            priceFeedAddress = address(mockPriceFeed);
        } else {
            // @custom:todo
            priceFeedAddress = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43; // BTC/USD on Sepolia
        }

        // 2. Store the owner to be used in the contract creation
        address initialOwner = owner;

        vm.startBroadcast();
        // 3. Pass the owner as the constructor argument for Ownable
        PricePredictionGame game = new PricePredictionGame(priceFeedAddress);

        // 4. If the owner is different from msg.sender, transfer ownership
        if (initialOwner != msg.sender) {
            game.transferOwnership(initialOwner);
        }

        vm.stopBroadcast();

        return (game, helperConfig);
    }
}
