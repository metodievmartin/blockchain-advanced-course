// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// EIP-191 compliant contract to verify Ethereum-signed messages
// https://eips.ethereum.org/EIPS/eip-191

contract EIP191 {
    /**
     * @notice Verifies a message signature according to EIP-191
     * @param message The original human-readable string message that was signed
     * @param v, r, s The components of the ECDSA signature
     * @return The address that signed the message
     */
    function verifySignature(
        string calldata message,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (address) {
        // Hash the raw string message (this alone is not safe for signature verification)
        bytes32 rawMessageHash = keccak256(bytes(message));

        // Apply the Ethereum-specific prefix as defined in EIP-191:
        // "\x19Ethereum Signed Message:\n" + message length
        // In this case, 32 is hardcoded since we're signing a bytes32 hash
        bytes32 messageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", rawMessageHash)
        );

        // Recover the address that signed the prefixed message hash
        address signer = ecrecover(messageHash, v, r, s);

        // Ensure signature is valid and signer is not the zero address
        require(signer != address(0), "Invalid signature");

        return signer;
    }
}
