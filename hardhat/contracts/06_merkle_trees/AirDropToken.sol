// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    MerkleProof
} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title AirDropToken
 * @notice ERC20 token with Merkle-based airdrop claiming functionality.
 * @dev Users must prove eligibility using a Merkle proof to claim tokens.
 */
contract AirDropToken is ERC20, Ownable {
    // The root hash of the Merkle tree containing all valid claim entries.
    bytes32 public immutable rootHash;

    // Tracks whether an address has already claimed its airdrop.
    mapping(address => bool) public claimed;

    /**
     * @dev Emitted when an address claims their airdropped tokens.
     * @param recipient The address that claimed the tokens.
     * @param amount The amount of tokens claimed.
     */
    event AirdropClaimed(address indexed recipient, uint256 amount);

    error InvalidProof();
    error AlreadyClaimed();

    constructor(
        address initialOwner,
        bytes32 _rootHash
    ) ERC20("AirDropToken", "ADT") Ownable(initialOwner) {
        rootHash = _rootHash;
        _mint(initialOwner, 5000000 * 10 ** decimals());
    }

    /**
     * @notice Allows a user to claim their airdropped tokens if eligible.
     * @dev The caller must provide a valid Merkle proof and has not claimed before.
     * @param amount The amount of tokens the user is eligible to claim (must match leaf data).
     * @param proof The Merkle proof showing the user's address and amount are part of the tree.
     */
    function claimAirDrop(uint256 amount, bytes32[] calldata proof) external {
        // Revert if the user already claimed their tokens
        require(!claimed[msg.sender], AlreadyClaimed());

        // Compute the leaf: keccak256 hash of (address, amount), packed encoding
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));

        // Verify the Merkle proof against the root hash
        require(MerkleProof.verify(proof, rootHash, leaf), InvalidProof());

        // Mark this address as having claimed
        claimed[msg.sender] = true;

        // Mint the tokens to the caller
        _mint(msg.sender, amount);

        emit AirdropClaimed(msg.sender, amount);
    }
}
