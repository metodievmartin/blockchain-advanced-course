// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Denial, DoSAttack} from "@/02_security/DoS.sol";

/**
 * @title DoSTest
 * @notice Forge test for demonstrating the Denial-of-Service via a malicious withdrawal partner.
 */
contract DoSTest is Test {
    Denial denial;
    address userAttacker;
    address owner;

    /**
     * @notice Sets up a clean test state:
     * - Creates `owner` and `userAttacker` addresses
     * - Funds them with 1 ether each
     * - Deploys a fresh Denial contract with the `owner` set
     */
    function setUp() public {
        owner = makeAddr("owner");
        userAttacker = makeAddr("userAttacker");

        vm.deal(userAttacker, 1 ether); // Give attacker funds to deploy and interact
        vm.deal(owner, 1 ether); // Give owner funds for gas and contract interaction

        denial = new Denial(owner); // Deploy vulnerable Denial contract
    }

    /**
     * @notice Full test demonstrating the Denial-of-Service attack
     * 1. Attacker deploys the malicious DoSAttack contract
     * 2. Owner sets this contract as the withdrawal partner
     * 3. Attacker triggers an initial call to `withdraw()`
     * 4. Owner then tries to withdraw — this will **fail** due to gas exhaustion
     */
    function test_DenialOfService() public {
        // Step 1: Attacker deploys malicious contract
        vm.prank(userAttacker); // Simulate call from attacker address
        DoSAttack attackerContract = new DoSAttack(address(denial));

        // Step 2: Owner sets the attacker contract as the withdrawal partner
        vm.prank(owner);
        denial.setWithdrawPartner(address(attackerContract));

        // Step 3: Attacker triggers a withdraw to engage fallback logic
        vm.prank(userAttacker);
        attackerContract.withdraw();

        // Step 4: Owner attempts to withdraw again
        // This will hang or fail because the attacker's fallback function
        // enters an infinite loop, consuming all gas when `partner.call{value: x}` is used
        vm.prank(owner);

        // This reverts or runs out of gas — the DoS is successful
        denial.withdraw();
    }
}
