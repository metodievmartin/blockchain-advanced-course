// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Implementation contract - contains the logic but does not store data persistently
contract Implementation {
    uint256 public num;
    address public sender;
    uint256 public value;

    // This function sets state variables using values from the calling context (proxy)
    function setVars(uint256 _num) external payable {
        num = _num;
        sender = msg.sender;
        value = msg.value;
    }
}

/**
 * Proxy contract - stores state, and delegates function calls to the implementation.
 * Uses `delegatecall` to execute the implementation's logic in the context of the proxy's storage.
 * This is a basic transparent proxy pattern implementation.
 */
contract Proxy {
    // These storage variables must match the order and types of those in Implementation.
    // This is critical for delegatecall to function correctly and not corrupt storage.
    uint256 public num;
    address public sender;
    uint256 public value;

    /**
     * Calls the `setVars(uint256)` function on the implementation contract.
     * `_contract` is the address of the deployed implementation logic contract.
     * `delegatecall` executes the code of the implementation in the proxy’s context,
     * meaning `msg.sender`, `msg.value`, and all storage writes affect the proxy.
     */
    function setVars(address _contract, uint256 _num) external {
        (bool ok, ) = _contract.delegatecall(
            abi.encodeWithSignature("setVars(uint256)", _num)
        );
        if (!ok) revert();
    }
}
