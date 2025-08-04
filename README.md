# Account Abstraction

This repository provides a deep dive into smart-contract account abstraction with two fully featured, side-by-side implementations:

- **Ethereum**: a multisig `MinimalAccount` contract integrating with the ERC-4337 EntryPoint
- **zkSync Era**: a minimal `ZkMinimalAccount` contract using a single ECDSA owner signature

## Table of Contents

1. [Project Overview](#project-overview)
2. [Key Features](#key-features)
3. [Prerequisites](#prerequisites)
4. [Installation & Setup](#installation--setup)
5. [Foundry Configuration](#foundry-configuration)
6. [Deployment Scripts](#deployment-scripts)
7. [Contracts](#contracts)
   - [Ethereum](#ethereum)
   - [zkSync Era](#zksync-era)
8. [Security Considerations](#security-considerations)
9. [Testing](#testing)
10. [Future Enhancements](#future-enhancement-ideas)
11. [License](#license)

## Project Overview

This repository showcases a comprehensive exploration of smart-contract account abstraction through two distinct, production-grade implementations tailored for different execution environments:

- **Ethereum (ERC-4337)**:  
  I implement a fully featured multisignature smart-contract wallet (`MinimalAccount`) that conforms to the ERC-4337 “EntryPoint” paradigm. Owners can propose, confirm, and execute arbitrary transactions via off-chain coordination, while the EntryPoint contract orchestrates gas payments and user-operation bundling. The design emphasizes modular security by separating multisig logic (`MultiSigGuardianship`) from account-abstraction mechanics, enabling threshold-based transaction approval, dynamic owner replacement, and seamless integration into existing Ethereum infrastructure.

- **zkSync Era**:  
  I present a minimalistic account contract (`ZkMinimalAccount`) optimized for the zkSync Era execution model. Leveraging the zkSync Bootloader and on-chain NonceHolder, this implementation supports a single ECDSA-signed owner signature and native gas management within the zkSync system-contracts framework. The contract demonstrates how to validate, execute, and pay for transactions entirely within the layer-2 environment, highlighting performance and cost advantages of zero-knowledge rollups while preserving key principles of account abstraction.

Together, these two implementations provide a side-by-side comparison of account-abstraction strategies on Ethereum mainnet/testnets versus zkSync Era, illustrating design trade-offs in security, complexity, and operational costs. Whether you’re building highly secure multisig wallets or streamlined L2 accounts, this project offers battle-tested patterns, Foundry deployment scripts, and complete test suites to accelerate your own account-abstraction journey.

## Key Features

- **Threshold Multisig** (Ethereum): propose, confirm, and execute transactions only when ≥ `minConfirmations` owners have signed.
- **Dynamic Owner Replacement**: initiate and finalize owner swaps via multisig votes.
- **ERC-4337 EntryPoint Integration**: offloads gas management, bundling, and paymaster support.
- **zkSync Bootloader Flow**: native Layer-2 execution with minimal overhead and a single ECDSA signature.
- **Comprehensive Test Suites**: full coverage with Forge tests, including edge cases and failure modes.
- **Foundry Scripts**: `DeployMinimal` and `SendPackedUserOp` automate deployment and UserOperation submission.

## Prerequisites

- **Foundry** (`forge`, `cast`)
- Submodules in `lib/`:
  - `account-abstraction`
  - `forge-std`
  - `foundry-devops` (for zkSync tests)
  - `foundry-era-contracts`
  - `openzeppelin-contracts`

## Installation & Setup

```bash
# Clone the repository
git clone https://github.com/WhatFate/account-abstraction
cd account-abstraction

# Install library dependencies
make install
```

## Foundry Configuration

Ensure `foundry.toml` contains:

```bash
[profile.default]
src = "src"
out = "out"
libs = ["lib"]

remappings = [
"@account-abstraction=lib/account-abstraction",
"@openzeppelin-contracts=lib/openzeppelin-contracts",
"@foundry-era-contracts=lib/foundry-era-contracts",
]
is-system = true
via-ir = true
optimizer = true
optimizer_runs = 200
```

> **Note:** Accurate remappings are required for zkSync tests to compile and run.

## Deployment Scripts

`DeployMinimal.s.sol`

```bash
function deployMinimalAccount(
  address[] memory owners,
  uint256 minConfirmations
) public returns (HelperConfig, MinimalAccount)
```

- **Local (Anvil):** deploys a mock EntryPoint and uses a default account.
- **Sepolia:** references the real EntryPoint address and a burner wallet.

`SendPackedUserOp.s.sol`

```bash
function generatedSignedUserOperation(
  bytes memory callData,
  HelperConfig.NetworkConfig memory config,
  address minimalAccount
) external view returns (PackedUserOperation)
```

- Builds, signs, and returns a `PackedUserOperation` ready for `EntryPoint.handleOps`.

## Contracts

### Ethereum

- **MinimalAccount.sol**

  - Implements `IAccount` (ERC-4337)

  - Validates UserOperation signatures via `MultiSigGuardianship`

  - Prefunds EntryPoint as needed

- **MultiSigGuardianship.sol**

  - Propose / confirm / execute transactions

  - Owner replacement flows

  - Confirmation threshold (`minConfirmations`)

### **zkSync Era**

- **ZkMinimalAccount.sol**

  - Implements `IAccount` for zkSync Era

  - Uses Bootloader and NonceHolder system contracts

  - Single-owner ECDSA validation

  - Methods: `validateTransaction`, `executeTransaction`, `payForTransaction`

## Security Considerations

- **Reentrancy:** `MultiSigGuardianship` uses OpenZeppelin’s `ReentrancyGuard` on confirmation paths.

- **Signature Validation:** strictly checks that recovered ECDSA signer is a registered owner.

- **Nonce Management:**

  - Ethereum: uses minimal-account nonce via EntryPoint’s `getUserOpHash`.

  - zkSync: increments nonce via `INonceHolder` system contract only if matches expected.

- **Gas Limits:** default limits set conservatively; adjust `verificationGasLimit` and `callGasLimit` as needed.

## Testing

Run all tests with:

```bash
forge test
```

- **Ethereum tests:**

  - `MinimalAccountTest.t.sol`

  - `MultiSigGuardianshipTest.t.sol`

- **zkSync Era tests:**

  - `ZkMinimalAccountTest.t.sol` (requires `foundry-devops` for chain checking)

## Future Enhancement Ideas

I welcome contributions and suggestions for improving and extending this project. Below are both your ideas and a few of my own:

- **Add multisig guardianship to zkSync**  
  Integrate the `MultiSigGuardianship` logic into `ZkMinimalAccount.sol`, enabling threshold-based approvals on zkSync Era as well as single-owner flows.

- **Enable proposal removal in Ethereum multisig**  
  Update `MultiSigGuardianship.sol` to allow owners to cancel or remove pending transaction and replacement proposals before they reach the confirmation threshold.

- **Make contracts upgradeable**  
  Refactor both `MinimalAccount` and `ZkMinimalAccount` into proxy/implementation patterns (e.g. OpenZeppelin’s UUPS or Transparent proxies) so that the account logic can be safely upgraded in future.

- **Gas- and fee-optimizations**  
  • Analyze and reduce on-chain gas usage in `validateUserOp`, `executeTransaction`, and multisig loops.  
  • Consider batching techniques or meta-transactions to further lower per-operation costs.

- **Paymaster support**  
  • Extend both implementations to integrate a paymaster mechanism, allowing sponsored gas or ERC-20 token payments via ERC-4337’s `paymasterAndData` field.  
  • Add testing and example paymaster contracts.

- **EIP-1271 signature support**  
  Allow smart-contract signatures (e.g. EIP-1271) in addition to ECDSA, so that other contract-based wallets can act as owners.

- **Gasless meta-transactions front end**  
  Build a lightweight web UI that uses these contracts to send gasless transactions (via a relayer or bundler), demonstrating a full dApp integration.

- **Detailed security audits and fuzz tests**  
  • Add property-based tests and fuzzing for edge cases in multisig confirmation and replacement flows.  
  • Integrate with a security-analysis pipeline (e.g. Slither, Manticore) to catch potential vulnerabilities.

Feel free to open issues or pull requests with additional ideas or detailed proposals!

## License

[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

