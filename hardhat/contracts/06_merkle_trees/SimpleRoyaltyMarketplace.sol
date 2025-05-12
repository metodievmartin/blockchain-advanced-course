// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RoyaltyMarketplace is ReentrancyGuard {
    // Stores the seller and price for a listed NFT
    struct Listing {
        address seller;
        uint256 price;
    }

    // --- Custom Errors ---

    error InvalidPrice();
    error NotForSale();
    error InsufficientPayment();
    error NoEarningToWithdraw();
    error WithdrawalFailed();

    // --- Storage ---

    // Mapping: NFT contract => Token ID => Listing
    // Stores all the listings per NFT contract
    mapping(address => mapping(uint256 => Listing)) public listings;

    // Mapping: Address => Pending earnings (both royalties and sales)
    // Stores and aggregates all unclaimed earnings for each user
    mapping(address => uint256) public pendingWithdrawals;

    // --- Events ---

    event TokenListed(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    event TokenBought(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price
    );
    event Withdrawal(address indexed user, uint256 amount);

    /**
     * @notice Aggregates the royalties and earnings for a recipient.
     * @dev Adds the earnings (either royalty or seller earnings) to the recipient's balance.
     * This method is internal to allow both royalty recipients and sellers to pull the earnings.
     * @param recipient Address of the recipient (royalty or seller)
     * @param amount Amount to add to the recipient's balance
     */
    function _aggregateEarnings(address recipient, uint256 amount) internal {
        pendingWithdrawals[recipient] += amount;
    }

    /**
     * @notice List an ERC-721 token for sale
     * @param nft Address of the NFT contract
     * @param tokenId Token ID to list
     * @param price Sale price in wei
     */
    function listToken(address nft, uint256 tokenId, uint256 price) external {
        if (price == 0) revert InvalidPrice();

        // Transfer the NFT to the marketplace
        IERC721(nft).transferFrom(msg.sender, address(this), tokenId);

        // Record listing details
        listings[nft][tokenId] = Listing({seller: msg.sender, price: price});

        emit TokenListed(nft, tokenId, msg.sender, price);
    }

    /**
     * @notice Purchase an NFT listed on the marketplace
     * @param nft Address of the NFT contract
     * @param tokenId Token ID to buy
     */
    function buyToken(
        address nft,
        uint256 tokenId
    ) external payable nonReentrant {
        Listing memory item = listings[nft][tokenId];

        if (item.price == 0) revert NotForSale();
        if (msg.value < item.price) revert InsufficientPayment();

        // Remove the listing before any external calls to prevent reentrancy
        delete listings[nft][tokenId];

        // Determine royalty info if the NFT supports ERC-2981
        uint256 royaltyAmount;
        address royaltyReceiver;

        if (IERC165(nft).supportsInterface(type(IERC2981).interfaceId)) {
            (royaltyReceiver, royaltyAmount) = IERC2981(nft).royaltyInfo(
                tokenId,
                msg.value
            );
        }

        uint256 sellerAmount = msg.value - royaltyAmount;

        // Save the royalty if required
        if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
            _aggregateEarnings(royaltyReceiver, royaltyAmount);
        }

        // Save the seller's earnings from the sale
        _aggregateEarnings(item.seller, sellerAmount);

        // Transfer the NFT to the buyer
        IERC721(nft).transferFrom(address(this), msg.sender, tokenId);

        emit TokenBought(nft, tokenId, msg.sender, msg.value);
    }

    /**
     * @notice Allows users to withdraw their accumulated earnings and royalties
     * @dev Follows the pull payment pattern and clears balance before transfer
     */
    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];

        // Check
        if (amount == 0) revert NoEarningToWithdraw();

        // Effect: reset owed amount before interaction
        pendingWithdrawals[msg.sender] = 0;

        // Interaction: send ETH
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert WithdrawalFailed();

        emit Withdrawal(msg.sender, amount);
    }
}
