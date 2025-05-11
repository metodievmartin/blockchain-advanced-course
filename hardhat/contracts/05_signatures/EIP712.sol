// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

// import "hardhat/console.sol";

contract EIP712Verifier is EIP712 {
    // Define the EIP-712 type hash for the structured data
    // This must match the exact structure and type order used off-chain
    bytes32 public MYSTRUCT_TYPEHASH =
    keccak256(
        "VaultApproval(address owner,address operator,uint256 value)"
    );

    // Pass the domain name and version to the EIP712 constructor
    // This defines the signing domain (used to prevent cross-domain signature reuse)
    constructor() EIP712("VaultProtocol", "v1") {}

    /**
     * @notice Verifies an EIP-712 signature
     * @param owner The address that signed the message
     * @param operator The delegate/recipient address
     * @param value The value that was approved
     * @param v, r, s The signature components
     * @return true if signature is valid and from `owner`
     */
    function verify(
        address owner,
        address operator,
        uint256 value,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public view returns (bool) {
        // Recreate the struct hash off-chain: keccak256(abi.encode(...))
        bytes32 structHash = keccak256(
            abi.encode(MYSTRUCT_TYPEHASH, owner, operator, value)
        );

        // Create the EIP-712 compliant digest: includes domain separator and struct hash
        bytes32 digest = _hashTypedDataV4(structHash);

        // Recover the signer from the signature and the digest
        address signer = ECDSA.recover(digest, v, r, s);

        // Return whether the recovered signer matches the claimed `owner`
        return signer == owner;
    }
}