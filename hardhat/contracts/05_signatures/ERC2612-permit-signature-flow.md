# ERC-2612 permit signature flow

This guide explains how the ERC-2612 `permit` mechanism works, 
enabling gasless approvals via off-chain signatures for ERC-20 tokens. 
It builds on EIP-712 and introduces a structured way to authorise token allowances 
without requiring an on-chain transaction from the owner.

## What is ERC-2612?

ERC-2612 is an extension of the ERC-20 standard that allows token holders to approve allowances
via signatures rather than on-chain `approve()` calls.

This enables:

* Gasless approvals (e.g., for use in DeFi)
* Better UX, since the token holder does not need ETH to approve spending

The core function is:

```solidity
function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v, bytes32 r, bytes32 s
) external;
```

## Signature Components

ERC-2612 uses EIP-712 to create a typed message from this struct:

```solidity
Permit(
  address owner,
  address spender,
  uint256 value,
  uint256 nonce,
  uint256 deadline
)
```

This becomes the **typed data** that is signed off-chain.

### PERMIT\_TYPEHASH

Defined as:

```solidity
bytes32 constant PERMIT_TYPEHASH = keccak256(
  "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
);
```

## Domain Separator (EIP-712)

Defined by the `EIP712` base class:

```solidity
constructor(string memory name) EIP712(name, "1") {}
```

This sets up the domain context:

```solidity
EIP712Domain(
  string name,        // Token name (e.g., "MyToken")
  string version = "1",
  uint256 chainId,
  address verifyingContract
)
```

### Domain Separator Hashing

Automatically computed - what essentially happens:

```solidity
bytes32 domainSeparator = keccak256(
  abi.encode(
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
    keccak256(bytes(name)),
    keccak256(bytes("1")),
    chainId,
    address(this)
  )
);
```
>NOTE: In reality this is handled by the `_domainSeparatorV4()` function in the `EIP712` base class.

## Full `permit` Flow Explained

### Step 1: Signer creates a message

The user creates a digest to sign:

```solidity
bytes32 structHash = keccak256(
  abi.encode(
    PERMIT_TYPEHASH,
    owner,
    spender,
    value,
    nonce,
    deadline
  )
);
```

### Step 2: Digest with Domain

```solidity
bytes32 digest = _hashTypedDataV4(structHash);
// = keccak256("\x19\x01" || domainSeparator || structHash)
```

### Step 3: Recover signer

```solidity
address signer = ECDSA.recover(digest, v, r, s);
require(signer == owner);
```

### Step 4: Update allowance

```solidity
_approve(owner, spender, value);
```

...

---

## Nonces

Every call to `permit` must use a fresh nonce:

```solidity
uint256 nonce = nonces[owner];
```

The nonce ensures **replay protection**. It is incremented via:

```solidity
_useNonce(owner);
```

This design ensures that each signature is valid for **one-time use only**.

### Replay Attack Protection

Without nonces, an attacker could reuse the same signature and call `permit` multiple times. 

By including the nonce:

1. The **signed message contains** the expected nonce.
2. The contract gets the **current nonce on-chain**.
3. Uses it to verify the signature and **increments** the nonce.
4. Any future attempt to reuse that signature **fails** because the nonce has changed and the verification fails.

### Example Flow

| Step | Action                                                         |
| --- |----------------------------------------------------------------|
| 1  | Alice queries nonce = `0`                                      |
| 2 | Alice signs a permit message that includes `nonce = 0`         |
| 3 | Bob submits it to the contract                                 |
| ✅ 4 | Contract gets the nonce = `0`, uses it, increments to `1`      |
| ❌ 5 | Reuse attempt fails — current nonce is different, which results in a verification failure |

### Nonce Is in the Signed Data

The nonce is **encoded and hashed** as part of the signed digest:

```solidity
bytes32 structHash = keccak256(
  abi.encode(
    PERMIT_TYPEHASH,
    owner,
    spender,
    value,
    _useNonce(owner),  // ← the current nonce is retrieved here
    deadline
  )
);
```

The off-chain signer (e.g. MetaMask or backend service) must read the **current nonce** and include it in the message before signing.


## Off-chain Signing (MetaMask Example)

Sign with `eth_signTypedData_v4` using this format:

```json
{
  "types": {
    "EIP712Domain": [
      {"name": "name", "type": "string"},
      {"name": "version", "type": "string"},
      {"name": "chainId", "type": "uint256"},
      {"name": "verifyingContract", "type": "address"}
    ],
    "Permit": [
      {"name": "owner", "type": "address"},
      {"name": "spender", "type": "address"},
      {"name": "value", "type": "uint256"},
      {"name": "nonce", "type": "uint256"},
      {"name": "deadline", "type": "uint256"}
    ]
  },
  "domain": {
    "name": "MyToken",
    "version": "1",
    "chainId": 1,
    "verifyingContract": "0x..."
  },
  "primaryType": "Permit",
  "message": {
    "owner": "0x...",
    "spender": "0x...",
    "value": "1000000000000000000",
    "nonce": 0, // the current nonce is included in data the user signs
    "deadline": 1717093025
  }
}
```

## Summary

1. **User signs** a typed Permit struct off-chain.
2. **Contract verifies** that:

    * Signature is valid
    * Deadline not passed
    * Nonce is correct
3. **Allowance is updated** without any ETH needed from user.

This pattern enables seamless UX for DApps and wallets.
