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

---

## TODO (tests)

- [ ] Validate `KeyManager` implements LSP6 (validate ERC165)
- [ ] Validate `ERC725Account` implements LSP0 (validate ERC165)
  - [ ] Validate upgradable security via KeyManager
  - [ ] Validate that it implements [LSP-1](https://github.com/lukso-network/LIPs/blob/main/LSPs/LSP-1-UniversalReceiver.md)
  - [ ] Validate that it implements [ERC1271](https://eips.ethereum.org/EIPS/eip-1271)
- [ ] Ensure upgrading the ERC725Account (impl contract KeyManager points to) works - for all registered accounts
- [ ] Ensure all operation types work for execution
  - 0 for call
  - 1 for create
  - 2 for create2
  - 3 for staticcall
  - 4 for delegatecall
- [ ] Verify storage updates on minimal proxy contract