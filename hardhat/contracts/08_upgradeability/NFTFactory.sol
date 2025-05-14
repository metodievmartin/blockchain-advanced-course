// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/*
    ──────────────────────────────────────────────────────────────────────────────
    High-Level Summary: Factory with Minimal Proxy Pattern (EIP-1167 Clones)
    ──────────────────────────────────────────────────────────────────────────────

    This system consists of two contracts:
      1. BaseNFTImplementation – the core logic for an ERC721 token contract.
      2. BaseNFTFactory        – a factory that deploys new NFT collections as clones.

    Pattern Used:
      - This is a `Factory + Clone (EIP-1167) pattern`, using logic that is upgrade-compatible.
      - The factory uses OpenZeppelin’s `Clones` library to deploy minimal proxy contracts.
      - Each clone delegates calls to a shared implementation contract (BaseNFTImplementation),
        but holds its own independent state.
      - The base contract is built using OpenZeppelin’s `*Upgradeable` modules to support initialisation,
        but **upgradeability is not enabled in practice** in this setup.

    Upgradeability Note:
      - The implementation contract address is set once in the factory and marked `immutable`.
      - This means the logic **cannot be changed** after deployment — clones will always point to
        the same version of `BaseNFTImplementation`.
      - Therefore, this system is **not upgradeable** in the traditional proxy sense.
      - If logic upgradeability were required, alternative patterns like **Beacon Proxy** or
        **ProxyAdmin-based upgradable proxies** would be necessary.

    Why this pattern?
      - Clones are highly gas-efficient and reusable.
      - Each clone can be configured at deployment via `initialize()`, enabling per-instance customisation
        like `name`, `symbol`, and `owner`.
      - This pattern is ideal for platforms that allow users to deploy isolated, cheap, and
        fully functional NFT collections.

    Key Benefits:
      - Gas savings: clones avoid redeploying full contract code.
      - Maintainability: logic is centralised in one contract.
      - Isolation: each NFT collection has its own state and access control.

    Tools Used:
      - OpenZeppelin Upgradeable Contracts (for `initialize()`-based logic)
      - OpenZeppelin Clones (EIP-1167 minimal proxy)

    Security Note:
      - `BaseNFTImplementation` disables its initialisers to prevent accidental or malicious use
        of the logic contract directly.
      - All clones are expected to be initialised exactly once after creation via the factory.

    ------------------------------------------------------------------------------
*/

// Importing upgradeable versions of OpenZeppelin contracts
// These replace constructors with initializer functions, enabling safe use with proxies
import {
    ERC721Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol"; // Utility for EIP-1167 minimal proxy cloning

// ----------------------------------------------------------------------------
// BaseNFTImplementation: Core logic contract for ERC721 NFTs.
// Designed to be cloned and initialised via a factory.
// ----------------------------------------------------------------------------

contract BaseNFTImplementation is ERC721Upgradeable, OwnableUpgradeable {
    uint256 private _nextTokenId; // Tracks the next token ID for minting

    constructor() {
        _disableInitializers();
        // Prevents this base contract from being initialised directly
        // Crucial in upgradeable patterns to protect the logic contract
    }

    // Acts as a constructor replacement in upgradeable contracts
    // This function is only callable once, thanks to the `initializer` modifier
    function initialize(
        address initialOwner, // Owner of the new clone instance.
        string calldata name, // ERC721 name
        string calldata symbol // ERC721 symbol
    ) external initializer {
        __ERC721_init(name, symbol); // Internal setup logic from OpenZeppelin
        __Ownable_init(initialOwner); // Sets initial owner
    }

    // Minting function restricted to the contract owner.
    function safeMint(address to) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++; // Incremental token ID generation
        _safeMint(to, tokenId); // Safe minting (checks for ERC721Receiver if `to` is a contract)
        return tokenId;
    }
}

// ----------------------------------------------------------------------------
// BaseNFTFactory: Deploys clone instances of BaseNFTImplementation.
// Each user can create and track their own NFT collections.
// ----------------------------------------------------------------------------

contract BaseNFTFactory {
    address public immutable implementation; // Address of the base NFT logic contract.

    // Maps user addresses to an array of their deployed NFT collections.
    mapping(address => address[]) public collections;

    constructor(address _implementation) {
        implementation = _implementation; // Set the implementation address at factory deployment.
    }

    // Deploys a new NFT collection via a minimal proxy clone.
    function createNFTCollection(
        string calldata name, // ERC721 name for the new collection
        string calldata symbol // ERC721 symbol
    ) external {
        // Deploy a new clone instance pointing to the base implementation.
        address instance = Clones.clone(implementation);

        // Record the new collection under the caller's address.
        collections[msg.sender].push(instance);

        // Initialise the clone with custom metadata and set caller as the owner.
        BaseNFTImplementation(instance).initialize(msg.sender, name, symbol);
    }
}
