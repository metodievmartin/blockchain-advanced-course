// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {Vault} from "@/05_signatures/SimpleSignature.sol";

contract SimpleSignatureTest is Test {
    Vault simpleSignatureContract;
    uint256 privateKeySigner;
    address signer;

    function setUp() public {
        // Use a dummy private key for testing
        privateKeySigner = 0x11;
        // Get the address that corresponds to the private key
        signer = vm.addr(privateKeySigner);

        // Give the signer 2 ether to work with
        vm.deal(signer, 2 ether);
        // Set the context so the next tx is sent from `signer`
        vm.prank(signer);

        simpleSignatureContract = new Vault{value: 1 ether}();
    }

    function testSignatureVerification() public view {
        // Sign a piece of arbitrary data to test signature recovery
        bytes memory data = abi.encode("secret value");

        // Hash the data (as done in the contract)
        bytes32 hash = keccak256(data);

        // Sign the hash with our test private key (simulating an off-chain signature)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeySigner, hash);

        // Attempt to recover the signer address from the hash and signature
        address recovered = simpleSignatureContract.verifySignature(
            data,
            v,
            r,
            s
        );

        // Check that the recovered address matches the expected signer
        assertEq(recovered, signer, "Signature verification failed");
    }

    function testSignatureVerificationFalse() public view {
        // Sign a piece of arbitrary data to test signature recovery
        bytes memory data = abi.encode("secret value");

        // Hash the data (as done in the contract)
        bytes32 hash = keccak256(data);

        // Sign the hash with our test private key (simulating an off-chain signature)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeySigner, hash);

        // Use different data to simulate a tampered or mismatched message
        bytes memory dataTwo = abi.encode("tampered secret value");

        // Attempt to recover the address using mismatched data
        address recovered = simpleSignatureContract.verifySignature(
            dataTwo,
            v,
            r,
            s
        );

        // The recovery should fail because the data does not match what was signed
        assertNotEq(recovered, signer, "Signature verification is successful");
    }

    function testVault() public {
        // Amount we want to withdraw from the contract
        uint256 value = 0.5 ether;

        // Construct the same payload that the Vault contract expects:
        // (address to withdraw to, amount)
        bytes memory data = abi.encodePacked(address(this), value);

        // Hash the data (as done in the contract)
        bytes32 hash = keccak256(data);

        // Sign the hashed data wih the simulated signer’s private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeySigner, hash);

        // Save the current contract's ether balance before the withdrawal
        uint256 balanceBefore = address(this).balance;

        // Call withdrawBalance with the signed data to trigger the transfer
        simpleSignatureContract.withdrawBalance(value, v, r, s);

        // Check the balance after withdrawal
        uint256 balanceAfter = address(this).balance;

        // Ensure the correct amount was received by this contract
        assertEq(
            balanceAfter,
            balanceBefore + value,
            "Signature verification failed"
        );
    }

    receive() external payable {}
}
