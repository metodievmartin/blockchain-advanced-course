// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/* -------------------------------------------------------------------------
STORAGE CONTRACT — PACKING VARIABLES TO REDUCE GAS
- Uses deliberate type ordering to fit multiple variables into fewer slots.
- Smaller types (uint128, uint64, etc.) are packed into the same 32-byte slot.
- Goal: reduce SSTORE operations and storage footprint.
------------------------------------------------------------------------- */
contract Storage {
    uint256 a; // slot 0 — full 32 bytes
    uint256 b; // slot 1 — full 32 bytes

    // slot 2 — all packed together (uint128 + uint64 + uint32 = 224 bits)
    uint128 c;
    uint64 d;
    uint32 e;

    uint64 f; // slot 3 — fits in unused bits but declared later, so new slot
    uint256 x; // slot 4

    function saveA() external {
        a = 1;
    }

    function saveF() external {
        f = 1;
    }

    function saveBC() external {
        b = 1;
        c = 1;
    }

    function saveDE() external {
        d = 1;
        e = 1;
    }

    function saveX(uint256 _x) external {
        x = _x;
    }

    // Accepts calldata array — cheap and efficient
    function getData(uint256[] calldata _arr) external returns (uint256) {
        return _arr.length;
    }
}

/* -------------------------------------------------------------------------
UNOPTIMIZED CONTRACT — WASTED STORAGE AND COSTLY MEMORY USAGE
- Demonstrates poor variable ordering and suboptimal storage layout.
- Small types are not packed.
- Dynamic and fixed arrays illustrate inefficient design if not accessed properly.
------------------------------------------------------------------------- */
contract UnOptimized {
    uint256 a = 1; // slot 0 — full 32 bytes
    uint128 c = 1; // slot 1 — wastes 16 bytes
    uint256 b; // slot 2
    uint128 d; // slot 3 — again isolated

    mapping(uint256 => uint256) public map; // slot 4 - keccak256(slot . key) => value for the slot
    uint256[] public test; // slot 5 — dynamic array, starts at keccak(5)
    uint256 neww; // slot 6
    uint256[3] public fixedArr; // slots 7, 8, 9

    function getA() external view returns (uint256) {
        return a;
    }

    function getC() external view returns (uint256) {
        return c;
    }

    // Creates dynamic array in memory — gas cost scales with `length`
    function alocateMemory(uint256 length) external pure returns (uint256) {
        uint256[] memory newArr = new uint256[](length);
        return newArr.length;
    }
}

// 830 - 1
// 836 - 2
// 842 - 3
// new allocation = 6 gas
// 945 - 20
// 1445 - 100
// 8800 - 1000 // average cost 8 gas

/* -------------------------------------------------------------------------
STUDENT CONTRACT — DYNAMIC STRUCTURE AND NESTED STORAGE
- Demonstrates how complex structures like strings, arrays, and structs
  are laid out in dynamic storage using keccak256 hashing.
- Useful for understanding low-level storage slot computation.
------------------------------------------------------------------------- */
contract StudentContract {
    struct Student {
        string name; // stored at dynamic location (keccak(slot))
        uint256 age; // fixed slot
        uint256 numberInClass; // fixed slot
        uint256[] grades; // dynamic - stored like arrays
    }

    string test = "Hellodsadasdadsjadjsadhashdhashdashdhashdhasdhashda";
    // Stored as a pointer in a slot; content at keccak(slot)

    Student public firstStudent; // slot 0 => 1,2,3 for fixed parts; dynamic via keccak

    Student[] public students; // slot 4 => dynamic array of structs, same rules apply
    // students[0].name => stored at keccak256(...)
    // students[0].grades => nested dynamic via hashing again
}

/* -------------------------------------------------------------------------
CALLDATA VS MEMORY — DATA LOCATION IMPACT ON GAS COST
- `memory` creates a new in-memory copy; good for modification, costly.
- `calldata` reads input directly without copying; best for read-only external data.
------------------------------------------------------------------------- */
contract CalldataVsMemory {
    // Gas inefficient: copies data into memory
    function processWithMemory(
        string memory data
    ) external pure returns (uint256) {
        return bytes(data).length;
    }

    // Gas efficient: directly uses input from calldata
    function processWithCalldata(
        string calldata data
    ) external pure returns (uint256) {
        return bytes(data).length;
    }
}
