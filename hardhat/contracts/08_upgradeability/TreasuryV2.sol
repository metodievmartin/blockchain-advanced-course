// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Treasury} from "./Treasury.sol";

// explain contract extending strategies like inheriting and overriding
// if needed to re-initilize logic add details about reinitilizer from OZ
contract TreasuryV2 is Treasury {
    function withdrawSpecial(address to) external onlyOwner {
        (bool ok, ) = payable(to).call{value: address(this).balance}("");
        if (!ok) revert();
    }
}
