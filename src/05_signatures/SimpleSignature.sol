// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// import "forge-std/console.sol";

contract Vault {
    // The owner of the contract, set once during deployment and cannot be changed
    address public immutable owner;
    uint256 public balance;

    error NotApproved();
    error FailedTransfer();
    error InvalidSignature();

    constructor() payable {
        owner = msg.sender;
        balance = msg.value;
    }

    /**
     * @notice Allows the caller to withdraw a specified `amount` if they present a valid signature
     * @param amount The amount of ether to withdraw
     * @param v Part of the ECDSA signature (recovery ID)
     * @param r Part of the ECDSA signature
     * @param s Part of the ECDSA signature
     */
    function withdrawBalance(
        uint256 amount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        // Encode the sender's address and the amount into a byte array
        // This data is what the original message signer should have signed
        bytes memory data = abi.encodePacked(msg.sender, amount);

        // Ensure that the signature is valid and was created by the contract owner
        require(_verifySignature(data, v, r, s) == owner, NotApproved());

        // Attempt to send the requested amount of ether to the sender
        (bool success, ) = payable(msg.sender).call{value: amount}("");

        // Revert the transaction if the transfer fails
        require(success == true, FailedTransfer());
    }

    /**
     * @dev Verifies the signature off-chain by recovering the signer address from the message and signature
     * @param data The encoded data that was originally signed
     * @param v, r, s Components of the ECDSA signature
     * @return The address that signed the message
     */
    function _verifySignature(
        bytes memory data,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        // Compute the keccak256 hash of the data (mimicking the signed message hash)
        bytes32 hash = keccak256(data);

        // Use ecrecover to retrieve the address that signed the hash
        address signer = ecrecover(hash, v, r, s);

        // Ensure the signature is not malformed or invalid
        require(signer != address(0), InvalidSignature());

        return signer;
    }

    /**
     * @notice Public method to verify any given signature
     * @param data The original signed message
     * @param v, r, s Components of the ECDSA signature
     * @return The address that created the signature
     */
    function verifySignature(
        bytes memory data,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (address) {
        // Compute the hash of the message to match against the signed version
        bytes32 hash = keccak256(
            abi.encodePacked(
                data // This is the raw message that was signed
            )
        );

        // Recover the signer’s address from the signature
        address signer = ecrecover(hash, v, r, s);

        // Ensure the signature is valid
        require(signer != address(0), InvalidSignature());

        return signer;
    }
}
