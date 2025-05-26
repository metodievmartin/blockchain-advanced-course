// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../src/exam-prep/mocks/LinkToken.sol";
import {
VRFCoordinatorV2_5Mock
} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Script, console} from "forge-std/Script.sol";

contract CharityRaffleConfig is Script {
    struct NetworkConfig {
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        address charityWallet;
        bytes32 merkleRoot;
        address link;
        address owner;
        address deployer;
    }

    NetworkConfig public localNetworkConfig;

    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;

    // Mock VRF parameters
    uint96 public constant MOCK_BASE_FEE = 0.1 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1000000000;
    int256 public constant MOCK_WEI_PER_UINT_LINK = 4e15;
    uint96 public constant FUND_AMOUNT = 3 ether;

    // Sepolia VRF parameters
    address public constant SEPOLIA_VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    address public constant SEPOLIA_LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    bytes32 public constant SEPOLIA_GAS_LANE =
    0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    // First address in Anvil
    address public constant ANVIL_FIRST_ACCOUNT =
    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant ANVIL_SECOND_ACCOUNT =
    0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public constant FOUNDRY_DEFAULT_SENDER =
    0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    function getNetworkConfig() public returns (NetworkConfig memory config) {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            config = getSepoliaConfig();
        } else {
            config = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
            vrfCoordinator: SEPOLIA_VRF_COORDINATOR,
            gasLane: SEPOLIA_GAS_LANE,
            subscriptionId: vm.envUint("VRF_SUBSCRIPTION_ID"),
            charityWallet: vm.envAddress("CHARITY_WALLET_ADDRESS"),
            merkleRoot: 0x695d9edd482b2fa2f7e1c178f3af1908e97e702e5726da5111c49a2cbe428fcf, // Taken from proofs.json
            link: SEPOLIA_LINK_TOKEN,
            owner: vm.envAddress("OWNER_ADDRESS"),
            deployer: vm.envAddress("DEPLOYER_ADDRESS")
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // Deploy mock VRF coordinator
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UINT_LINK
        );

        console.log("Msg sender: ", msg.sender);
        console.log("VRF Coordinator owner: ", vrfCoordinatorMock.owner());

        LinkToken link = new LinkToken();

        // Create subscription
        uint256 subscriptionId = vrfCoordinatorMock.createSubscription();

        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // mock gas lane
            subscriptionId: subscriptionId,
            charityWallet: ANVIL_SECOND_ACCOUNT,
            merkleRoot: 0xdb3e2b3fb628c92842bacf2cb4884b7db3ceacb9eb81c1151d66fbd3efa069fb, // Taken from proofs_local.json
            link: address(link),
            owner: ANVIL_FIRST_ACCOUNT,
            deployer: ANVIL_FIRST_ACCOUNT
        });

        //        vm.deal(localNetworkConfig.deployer, 100 ether);

        return localNetworkConfig;
    }
}
