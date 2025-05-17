# Components that form an EIP-712 signature

This guide explains the components and process involved in generating an EIP-712 signature, 
showing how different parts are encoded, hashed, and finally signed. 
Each step includes structure, purpose, and transformation into hashed formats, 
helping to build a solid mental model.

## 1. Domain Separator

Define the **context** of the message (prevents cross-domain signature reuse).

```solidity
EIP712Domain(
  string name,
  string version,
  uint256 chainId,
  address verifyingContract
)
```

**Hash Process:**

```solidity
// 1. Create the type hash for the domain (the schema fingerprint)
bytes32 typeHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

// 2. Hash individual string fields
bytes32 nameHash = keccak256(bytes(name));
bytes32 versionHash = keccak256(bytes(version));

// 3. Hash the full domain separator
bytes32 domainSeparator = keccak256(
  abi.encode(
    typeHash,
    nameHash,
    versionHash,
    chainId,
    verifyingContract
  )
);
```

This domain separator is constant for a given deployment (contract + chain).

## 2. Message Type & Data

This is the **structured data** you want to sign.

### Example Struct

```solidity
struct VaultApproval {
  address owner;
  address operator;
  uint256 value;
}
```

### Hash Process:

```solidity
// 1. Compute type hash (the schema fingerprint)
bytes32 typeHash = keccak256("VaultApproval(address owner,address operator,uint256 value)");

// 2. Compute struct hash using field values
bytes32 structHash = keccak256(
  abi.encode(
    typeHash,
    owner,
    operator,
    value
  )
);
```

The `typeHash` acts like a schema identifier and ensures structure integrity.

> Note: If a struct includes dynamic types like `string` or `bytes`, you must hash them before including them in `abi.encode()`.

### Example with Dynamic Types:

```solidity
struct Person {
  string name;
  uint256 age;
}

bytes32 typeHash = keccak256("Person(string name,uint256 age)");

bytes32 structHash = keccak256(
  abi.encode(
    typeHash,
    keccak256(bytes(name)), // hash the dynamic string before encoding
    age
  )
);
```

## 3. Final Digest (To Be Signed)

Follows the EIP-191 format for typed data:

```solidity
bytes32 digest = keccak256(
  abi.encodePacked(
    "\x19\x01",
    domainSeparator,
    structHash
  )
);
```

This `digest` is the actual data that will be signed by a wallet using `eth_signTypedData_v4`.

## NOTE: `typeHash` as a Schema Identifier

The `typeHash` is like a fingerprint of the struct's schema:

```solidity
bytes32 typeHash = keccak256("VaultApproval(address owner,address operator,uint256 value)");
```

This captures:

* Struct name
* Exact types
* Exact field order and names

If this schema changes (order, name, or types), the `typeHash` changes. 
It's used to distinguish between different data structures even if the field values are similar.

### Why it's important

* Prevents collisions between different message types.
* Ensures that both the signer and verifier are referencing the **same struct definition**.
* Used to prefix field data before hashing into a `structHash`.

## ✅ SIGNATURE FLOW SUMMARY

Below is a clear step-by-step illustration of how all the components come together:

### 1. Inputs

```
User-provided:
  - Domain: name, version, chainId, verifyingContract
  - Data:   field values for the struct (e.g., owner, operator, value)
```

### 2. Domain Separator

```
1. Create a type string: "EIP712Domain(...)"
2. Compute typeHash = keccak256(type string)
3. Encode and hash domain fields:
   domainSeparator = keccak256(abi.encode(...))
```

### 3. Struct Hash

```
1. Create a type string: "VaultApproval(...)"
2. Compute typeHash = keccak256(type string)
3. Encode and hash field values:
   structHash = keccak256(abi.encode(...))
```

### 4. Final Digest (Message to Sign)

```
1. Combine with EIP-191 prefix:
   digest = keccak256("\x19\x01" + domainSeparator + structHash)
```

### 5. Signature

```
Sign digest using user's private key
→ (v, r, s)
```