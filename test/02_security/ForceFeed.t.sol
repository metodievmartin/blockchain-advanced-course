// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ForceFeed, Attacker} from "@/02_security/ForceFeed.sol";

/**
 * @title ForceFeedTest
 * @notice Demonstrates that ETH can be force-sent to a contract without calling any of its functions,
 * and highlights the difference between unsafe and robust balance-checking logic
 */
contract ForceFeedTest is Test {
    ForceFeed forceFeed;
    address userAttacker;

    /**
     * @notice Setup the test environment:
     * - Create an attacker address
     * - Fund it with ether
     * - Deploy the vulnerable ForceFeed contract
     */
    function setUp() public {
        userAttacker = makeAddr("userAttacker");

        vm.deal(userAttacker, 10 ether); // Provide attacker with ETH for the attack

        forceFeed = new ForceFeed(); // Deploy target contract
    }

    /**
     * @notice Executes the force-feeding attack and shows how balance-based logic can be fooled
     */
    function test_ForceFeed() public {
        // Step 1: Attacker deploys the malicious Attacker contract
        vm.prank(userAttacker);
        Attacker attackerContract = new Attacker();

        // Step 2: Check initial state of the contract before any funds are received
        console.log(
            "Unsafe isNotStarted method call: ",
            forceFeed.isNotStarted()
        ); // ✅ Expect: true (contract has 0 ETH)
        console.log(
            "Safe isNotStartedRobust method call: ",
            forceFeed.isNotStartedRobust()
        ); // ✅ Expect: true (no deposit made)

        // Step 3: Attacker loads their malicious contract with ether
        vm.startPrank(userAttacker);
        payable(attackerContract).transfer(5 ether); // Send ETH to attack contract

        // Step 4: Attacker calls selfdestruct, forcing ether into the ForceFeed contract
        attackerContract.attack(payable(address(forceFeed)));
        vm.stopPrank();

        // Step 5: Check contract's logic again — one check is now fooled
        console.log(
            "Unsafe isNotStarted method call: ",
            forceFeed.isNotStarted()
        ); // ❌ Expect: false (contract *has* ETH now)
        console.log(
            "Safe isNotStartedRobust method call: ",
            forceFeed.isNotStartedRobust()
        ); // ✅ Expect: true (no deposit was recorded)
    }
}
