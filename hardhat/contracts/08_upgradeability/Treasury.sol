// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

error InsufficientBalance();
error TransferFailed();

contract Treasury is OwnableUpgradeable {
    uint256 public openTime;
    mapping(address => uint256) public balances;

    // Initializer replaces constructor in upgradeable contracts
    function initialize(address _owner) public initializer {
        // Ownable initializer from OZ, sets ownership
        __Ownable_init(_owner);

        openTime = block.timestamp;
    }

    function deposit() public payable virtual {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) public {
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        balances[msg.sender] -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");

        if (!success) revert TransferFailed();
    }
}
