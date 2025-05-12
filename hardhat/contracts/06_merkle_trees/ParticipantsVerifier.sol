// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {
    MerkleProof
} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title ParticipantsVerifier
 * @notice Verifies whether an address belongs to a predefined group using a Merkle proof.
 * @dev Utilises OpenZeppelin's MerkleProof library for on-chain Merkle verification.
 */
contract ParticipantsVerifier {
    // The Merkle root hash representing the full set of authorised participants.
    bytes32 public immutable rootHash;

    constructor(bytes32 _rootHash) {
        rootHash = _rootHash;
    }

    /**
     * @notice Verifies whether a given address is a valid participant using a Merkle proof
     * @dev Hashes the address and compares it with the Merkle root using the supplied proof
     * @param participant The address to verify against the Merkle tree
     * @param proof An array of sibling hashes from the leaf to the Merkle root
     * @return isValid A boolean indicating whether the address is included in the tree
     */
    function isParticipant(
        address participant,
        bytes32[] calldata proof
    ) external view returns (bool isValid) {
        bytes32 leaf = keccak256(abi.encodePacked(participant));
        return MerkleProof.verify(proof, rootHash, leaf);
    }
}
