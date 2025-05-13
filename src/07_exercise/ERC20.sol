// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    ERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    MerkleProof
} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract AIAgentShare is ERC20, Ownable, EIP712, ERC20Permit {
    uint256 public constant MIN_AMOUNT_MINUS_ONE = 99 * 10 ** 18;
    uint256 public constant MAX_AMOUNT_PLUS_ONE = 50001 * 10 ** 18;
    uint256 public constant TOTAL_PARTICIPANTS = 260;
    uint256 public constant BITS_PER_UINT = 256;
    uint256 public constant RELAYER_FEE = 5 * 10 ** 18;
    // EIP-712 typehash for BuyAuthorization
    bytes32 private constant BUY_AUTHORIZATION_TYPEHASH =
        keccak256(
            "BuyAuthorization(address buyer,uint256 amount,uint256 deadline)"
        );

    uint256 public immutable BUY_PERIOD_ENDS = block.timestamp + 10 days;
    bytes32 public immutable root;

    address public relayer;
    uint256 public shareholdersPool = 5_000_000 * 10 ** 18;
    uint256 public price = 0.1 ether;

    error InvalidAmount();
    error InsufficientValue();
    error BuyPeriodEnded();
    error InvalidProof();
    error InvalidIndex();
    error AlreadyClaimed();
    error InvalidRelayer();
    error InvalidSignature();
    error SignatureExpired();

    /**
     * @dev Bitmap storage for tracking claimed whitelist spots
     * We need to track 260 participants, but a uint256 can only store 256 bits
     * Therefore, we use an array of 2 uint256s:
     * - claimedBitmap[0] stores bits 0-255 (participants 0-255)
     * - claimedBitmap[1] stores bits 0-3 (participants 256-259)
     * Each bit represents whether a participant has claimed their whitelist spot:
     * - 0 = not claimed
     * - 1 = claimed
     *
     * Bit positions in claimedBitmap[1]: [0] => 00000000000000000000000000001001; [1] =>0000000000000000000000000000101
     * - bit 0: participant 256
     * - bit 1: participant 257
     * - bit 2: participant 258
     * - bit 3: participant 259
     *
     * Visual representation of the bitmap:
     * claimedBitmap[0]: [bit255 ... bit5 bit4 bit3 bit2 bit1 bit0]  // participants 0-255
     * claimedBitmap[1]: [bit255 ... bit3 bit2 bit1 bit0]             // participants 256-259
     */
    uint256[2] private claimedBitmap;

    constructor(
        bytes32 _root,
        address _relayer
    )
        ERC20("AIAgentShare", "AIS")
        Ownable(msg.sender)
        ERC20Permit("AIAgentShare")
    {
        _mint(msg.sender, 5_000_000 * 10 ** 18);
        root = _root;
        relayer = _relayer;
    }

    function setRelayer(address _relayer) external onlyOwner {
        relayer = _relayer;
    }

    function buy(
        uint256 amount,
        uint256 index,
        bytes32[] memory proof
    ) external payable {
        require(msg.value == (amount * price) / 10 ** 18, InsufficientValue());
        _buy(msg.sender, amount, amount, index, proof);
    }

    function buyWithSignature(
        address buyer,
        uint256 amount,
        uint256 index,
        uint256 deadline,
        bytes32[] memory proof,
        bytes memory signature
    ) external payable {
        require(msg.sender == relayer, InvalidRelayer());
        require(
            verifySignature(buyer, amount, deadline, signature),
            InvalidSignature()
        );

        _mint(msg.sender, RELAYER_FEE);
        _buy(buyer, amount, amount - RELAYER_FEE, index, proof);
    }

    function _buy(
        address buyer,
        uint256 amount,
        uint256 amountToMint,
        uint256 index,
        bytes32[] memory proof
    ) private {
        require(
            amount > MIN_AMOUNT_MINUS_ONE && amount < MAX_AMOUNT_PLUS_ONE,
            InvalidAmount()
        );
        require(block.timestamp < BUY_PERIOD_ENDS, BuyPeriodEnded());
        require(isValidProof(index, buyer, proof), InvalidProof());
        require(!isClaimed(index), AlreadyClaimed());

        _setClaimed(index);
        shareholdersPool -= amount;

        _mint(buyer, amountToMint);
    }

    function claimLeftShares() external onlyOwner {
        _mint(msg.sender, shareholdersPool);
    }

    function verifySignature(
        address buyer,
        uint256 amount,
        uint256 deadline,
        bytes memory signature
    ) public view returns (bool) {
        // Check if signature is expired
        if (block.timestamp > deadline) {
            revert SignatureExpired();
        }

        // Create the hash of the typed data
        bytes32 structHash = keccak256(
            abi.encode(BUY_AUTHORIZATION_TYPEHASH, buyer, amount, deadline)
        );

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);

        // Verify the signer is the owner
        return signer == buyer;
    }

    function isValidProof(
        uint256 index,
        address buyer,
        bytes32[] memory proof
    ) public view returns (bool) {
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(index, buyer)))
        );

        return MerkleProof.verify(proof, root, leaf);
    }

    /**
     * @dev Checks if a participant at the given index has claimed their whitelist spot
     * @param index The participant's index (0-259)
     * @return bool True if the participant has claimed their spot
     *
     * Example for index 5:
     * 1. Calculate positions:
     *    - bitmapIndex = 5 / 256 = 0 (first uint256)
     *    - bitIndex = 5 % 256 = 5 (6th bit)
     *
     * 2. Create mask:
     *    - mask = 1 << 5 = 32
     *    - Binary: 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00100000
     *    - Visual: [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 1 0 0 0 0 0]
     *
     * 3. Check if bit is set:
     *    claimedBitmap[0] & mask
     *    If result != 0, then bit 5 is set
     *
     * Example for index 257:
     * 1. Calculate positions:
     *    - bitmapIndex = 257 / 256 = 1 (second uint256)
     *    - bitIndex = 257 % 256 = 1 (2nd bit)
     *
     * 2. Create mask:
     *    - mask = 1 << 1 = 2
     *    - Binary: 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000010
     *    - Visual: [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 1 0]
     *
     * 3. Check if bit is set:
     *    claimedBitmap[1] & mask
     *    If result != 0, then bit 1 is set
     */
    function isClaimed(uint256 index) public view returns (bool) {
        if (index >= TOTAL_PARTICIPANTS) revert InvalidIndex();

        // Calculate which uint256 in the array to use (0 or 1)
        uint256 bitmapIndex = index / BITS_PER_UINT;
        // Calculate which bit within the uint256 to check (0-255) 000000000 00000000
        uint256 bitIndex = index % BITS_PER_UINT;

        // Create a mask with a 1 at the bit position we want to check
        // Index:        7 6 5 4 3 2 1 0
        // Mask:         0 0 1 0 0 0 0 0   ← This is 1 << 5 = 32 = 00100000
        uint256 mask = 1 << bitIndex;

        // Check if the bit is set by ANDing with the mask
        // claimedBitmap[0] & mask
        // → 00000000
        //   &
        //   00100000
        //   --------
        //   00000000 = 0 → not claimed
        return (claimedBitmap[bitmapIndex] & mask) != 0;
    }

    /**
     * @dev Marks a participant's index as claimed in the bitmap
     * @param index The participant's index (0-259)
     *
     * Example for index 5:
     * 1. Calculate positions:
     *    - bitmapIndex = 5 / 256 = 0 (first uint256)
     *    - bitIndex = 5 % 256 = 5 (6th bit)
     *
     * 2. Create mask:
     *    - mask = 1 << 5 = 32
     *    - Binary: 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00100000
     *    - Visual: [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 1 0 0 0 0 0]
     *
     * 3. Set the bit:
     *    claimedBitmap[0] |= mask
     *    This sets the 6th bit to 1 while preserving all other bits
     *
     * Example for index 257:
     * 1. Calculate positions:
     *    - bitmapIndex = 257 / 256 = 1 (second uint256)
     *    - bitIndex = 257 % 256 = 1 (2nd bit)
     *
     * 2. Create mask:
     *    - mask = 1 << 1 = 2
     *    - Binary: 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000010
     *    - Visual: [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 0 0] [0 0 0 0 0 0 1 0]
     *
     * 3. Set the bit:
     *    claimedBitmap[1] |= mask
     *    This sets the 2nd bit to 1 while preserving all other bits
     */
    function _setClaimed(uint256 index) private {
        if (index >= TOTAL_PARTICIPANTS) revert InvalidIndex();

        // Calculate which uint256 in the array to use (0 or 1)
        uint256 bitmapIndex = index / BITS_PER_UINT;
        // Calculate which bit within the uint256 to set (0-255)
        uint256 bitIndex = index % BITS_PER_UINT;

        // Create a mask with a 1 at the bit position we want to set
        //Index:        7 6 5 4 3 2 1 0
        //Mask:         0 0 1 0 0 0 0 0   ← This is 1 << 5 = 32 = 00100000
        uint256 mask = 1 << bitIndex;

        // Set the bit by ORing with the mask
        // claimedBitmap[0] |= mask
        // → 00000000
        //   |
        //   00100000
        //   --------
        //   00100000 ← Now bit 5 is marked as claimed
        claimedBitmap[bitmapIndex] = claimedBitmap[bitmapIndex] | mask;
    }
}
