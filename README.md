# Futureverse Wallet

This repo includes implementation of EIP725 based wallet and an account registry contract (to register wallet for new users).

## Account registry

## Wallet

Consists of 2 contracts - which work together to implement the ERC725Account spec:

- `KeyManager` - based on [LSP6](https://github.com/lukso-network/LIPs/blob/main/LSPs/LSP-6-KeyManager.md)
- `ERC725Account` - based on [LSP0](https://github.com/lukso-network/LIPs/blob/main/LSPs/LSP-0-ERC725Account.md)

### KeyManager

Responsible for permissions ([ERC725Y](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-725.md#erc725y) substandard).
A manager/owner and entrypoint for the ERC725Account (controls the `ERC725Account` contract).

Why do we need this?

- allows the `ERC725Account` contract to be managed by multiple addresses (since `ERC725Account` is only managed by a single address)
- enables de-coupling of the permissions logic of the `ERC725Account` contract
- enables upgradability of the permissions logic (`KeyManager`)

#### KeyManager standards - ERC165 `0xfb437414`

- ERC165
- ERC1271

### ERC725Account

Responsible for execution ([ERC725X](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-725.md#erc725x) substandard - for calls, contract deployments).

Management of the ERC725Y functionality (data key-value store) is provided by the owner `KeyManager` contract.

#### ERC725Account standards - ERC165 `0x66767497`

- ERC165
- [ERC725Y](https://docs.lukso.tech/standards/universal-profile/lsp0-erc725account/#erc725y---generic-key-value-store)
- [ERC725X](https://docs.lukso.tech/standards/universal-profile/lsp0-erc725account/#erc725x---generic-executor)
- [LSP1-UniversalReceiver](https://docs.lukso.tech/standards/universal-profile/lsp0-erc725account/#lsp1---universalreceiver)
- [ERC1271](https://docs.lukso.tech/standards/universal-profile/lsp0-erc725account/#erc1271)
- [LSP14Ownable2Step](https://docs.lukso.tech/standards/universal-profile/lsp0-erc725account/#erc1271)
- LSP17Extendable

note: This bytes4 interface id is calculated as the XOR of the interfaceId of the following standards: ERC725Y, ERC725X, LSP1-UniversalReceiver, ERC1271, LSP14Ownable2Step and LSP17Extendable.

- Additional docs: https://docs.lukso.tech/standards/universal-profile/lsp0-erc725account/#what-does-this-standard-represent-

## Setup

### Pre-requisites

- [foundry](https://book.getfoundry.sh/getting-started/installation) must be installed

### Install, Build, Test

Retrieve git submodules:

```sh
forge install
```

Build contracts:

```sh
forge build
```

Run tests:

```sh
forge test
```

### Deployment

Copy the `.env.example` file to `.env`  and fill in the required values.

```sh
cp .env.example .env
```

Note: Dummy values (private key and public address) for `Alice` have been provided.

#### Deploying to local network

1. Start [local node (e.g. anvil)](https://book.getfoundry.sh/tutorials/solidity-scripting#deploying-locally)
2. Run command:

**Hardhat:**

```sh
yarn deploy:local
```

**Forge:**

```sh
forge script script/RegistryDeployer.s.sol:Deployment --fork-url http://localhost:8545 --broadcast
```

#### Prod deployment

**Hardhat:**

```sh
yarn deploy:porcini
```

**Forge:**

```sh
source .env
forge script script/RegistryDeployer.s.sol:Deployment --rpc-url $GOERLI_RPC_URL --broadcast --verify -vvvv
```

Note: The `--verify` flag will verify the deployed contracts on Etherscan.
Note2: Forge cannot be used to deploy to TRN - due to [issue](https://github.com/foundry-rs/foundry/issues/3868)

---

## Testing

```sh
forge test -vvv
```

### Gas golf

```sh
forge test --gas-report
```

1. Get gas results for unit tests as starting point
2. Make changes
3. Rerun gas tests
4. Compare results

---
