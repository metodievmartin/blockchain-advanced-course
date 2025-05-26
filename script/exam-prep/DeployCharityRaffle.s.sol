// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {CharityRaffle} from "@/exam-prep/CharityRaffle.sol";
import {LinkToken} from "@/exam-prep/mocks/LinkToken.sol";
import {CharityRaffleConfig} from "./CharityRaffleConfig.s.sol";
import {
    VRFCoordinatorV2_5Mock
} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

/*
 * Contracts deployed on Sepolia:
 *  CharityRaffle proxy deployed to: 0x2C52c2b76Cc007089e1FfF016A3dD1bB241FD0F5
 *  CharityRaffle implementation deployed to: 0xCE5E1aC6d06843159671314CF48D42cdFbD4D62a
 */
contract DeployCharityRaffle is Script {
    address public constant FOUNDRY_DEFAULT_SENDER =
        0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    function run() external returns (address, CharityRaffleConfig) {
        // Get network configuration
        CharityRaffleConfig configHelperInstance = new CharityRaffleConfig();
        CharityRaffleConfig.NetworkConfig memory config = configHelperInstance
            .getNetworkConfig();

        console.log(
            "Deploying CharityRaffle with the following configuration:"
        );
        console.log("- Network Chain ID:", block.chainid);
        console.log("- Owner:", config.owner);
        console.log("- Charity Wallet:", config.charityWallet);
        console.log("- VRF Coordinator:", config.vrfCoordinator);
        console.log("- VRF Subscription ID:", config.subscriptionId);

        vm.startBroadcast();

        // Deploy the proxy contract with implementation
        address deployedProxy = Upgrades.deployTransparentProxy(
            "CharityRaffle.sol",
            config.owner,
            abi.encodeCall(
                CharityRaffle.initialize,
                (
                    config.owner,
                    config.charityWallet,
                    config.subscriptionId,
                    config.vrfCoordinator,
                    config.gasLane,
                    config.merkleRoot
                )
            )
        );

        address deployedImplementation = Upgrades.getImplementationAddress(
            deployedProxy
        );

        // If using local network, add the contract as a consumer
        if (block.chainid == configHelperInstance.LOCAL_CHAIN_ID()) {
            VRFCoordinatorV2_5Mock vrfCoordinatorMock = VRFCoordinatorV2_5Mock(
                config.vrfCoordinator
            );

            vrfCoordinatorMock.addConsumer(
                config.subscriptionId,
                deployedProxy
            );

            console.log("Added CharityRaffle as VRF consumer");

            // Need to fund subscription with LINK if requesting random words with native false
            uint256 LINK_BALANCE = 100000000000000000000;
            //            LinkToken link = LinkToken(config.link);
            //            link.mint(FOUNDRY_DEFAULT_SENDER, LINK_BALANCE);
            //            link.approve(config.vrfCoordinator, LINK_BALANCE);

            vrfCoordinatorMock.fundSubscription(
                config.subscriptionId,
                LINK_BALANCE
            );

            // Need to fund subscription with native if requesting random words with native true
            vrfCoordinatorMock.fundSubscriptionWithNative{value: 30 ether}(
                config.subscriptionId
            );
            console.log("Funded VRF subscription");

            (
                uint96 balance,
                uint96 nativeBalance,
                ,
                address subOwner,

            ) = vrfCoordinatorMock.getSubscription(config.subscriptionId);
            console.log("Subscription owner:", subOwner);
            console.log("Subscription balance:", balance);
            console.log("Subscription native balance:", nativeBalance);
        }

        vm.stopBroadcast();

        console.log("CharityRaffle proxy deployed to:", deployedProxy);
        console.log(
            "CharityRaffle implementation deployed to:",
            deployedImplementation
        );

        return (deployedProxy, configHelperInstance);
    }
}
