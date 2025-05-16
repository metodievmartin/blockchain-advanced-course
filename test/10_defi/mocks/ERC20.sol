// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@/interfaces/IERC20.sol";

contract MockERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;

    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    function approve(
        address spender,
        uint256 amount
    ) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        require(
            allowance[sender][msg.sender] >= amount,
            "ERC20: transfer amount exceeds allowance"
        );

        if (allowance[sender][msg.sender] != type(uint256).max) {
            allowance[sender][msg.sender] -= amount;
        }

        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function burn(address from, uint256 amount) external {
        balanceOf[from] -= amount;
        totalSupply -= amount;
    }
}
