// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    ERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title MyToken
 * @dev ERC20 token with ERC2612 permit functionality
 * This contract extends the standard ERC20 with the permit function,
 * allowing approvals to be made via signatures (EIP-712 typed data)
 */
contract MyToken is ERC20, ERC20Permit {
    /**
     * @dev Constructor that sets the name and symbol of the token
     * and initializes the ERC20Permit extension with the same name
     */
    constructor() ERC20("MyToken", "MTK") ERC20Permit("MyToken") {}
    
    /**
     * @dev Mints tokens to a specified address (for testing purposes)
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
