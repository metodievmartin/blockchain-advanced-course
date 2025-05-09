// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ForceFeed
 * @notice Demonstrates a subtle vulnerability in using `address(this).balance` for application logic.
 * External actors can force ETH into a contract via selfdestruct, bypassing normal deposit mechanisms.
 */
contract ForceFeed {
    /**
     * @notice Vulnerable check that assumes the contract's balance can only be non-zero
     * if deposit() has been called. This assumption is false.
     *
     * VULNERABILITY:
     * - ETH can be sent forcibly to this contract via the `selfdestruct()` opcode,
     *   which does not trigger any fallback function or validation.
     * - This causes `isNotStarted()` to return false even if no deposits occurred.
     *
     * Used in real-world contexts to check "has this contract started or received funds".
     */
    function isNotStarted() public view returns (bool) {
        return address(this).balance == 0;
    }

    // Records the amount of ETH deposited via the deposit() function
    uint256 public deposits;

    /**
     * @notice Only increases `deposits` if ETH is sent via this function.
     * This provides a reliable, application-level indicator of whether deposits occurred.
     */
    function deposit() external payable {
        deposits += msg.value;
    }

    /**
     * @notice Robust version of `isNotStarted` that checks internal state
     * rather than relying on ETH balance alone.
     *
     * This check cannot be fooled by forced ETH sent via selfdestruct.
     */
    function isNotStartedRobust() public view returns (bool) {
        return deposits == 0;
    }
}

/**
 * @title Attacker
 * @notice A malicious contract that can forcibly send ETH to any address,
 * including contracts without a payable fallback function or without calling any function.
 */
contract Attacker {
    /**
     * @notice Transfers all contract balance forcibly to `forceFeed` using selfdestruct.
     * `selfdestruct` immediately removes this contract and sends its balance to the target.
     * The target cannot prevent or react to this forced transfer.
     *
     * This is the core of the "force-feeding" attack.
     */
    function attack(address payable forceFeed) external {
        selfdestruct(forceFeed); // Force ETH into ForceFeed contract
    }

    // Allow this contract to receive ETH so it can build a balance to attack with
    receive() external payable {}
}
