// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725Account.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManager.sol";

import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManagerInit.sol";

import "./LSP0ERC725AccountLateInit.sol";
import "./IFVAccountRegistry.sol";
import "./Utils.sol";

// v3 base

contract FVAccountRegistry is IFVAccountRegistry {
  using Utils for string;

  // TODO: make FVAccountRegistry contract upgradable (Transparent vs UUPS proxy)
  // TODO: remember to inherit from Initializable and correct proxies
  // TODO: should have initializer instead of constructor - initialize every base contract (including ownable)
  // TODO: use initializer modifiers
  // TODO: https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable

  UpgradeableBeacon immutable public fvAccountBeacon;
  UpgradeableBeacon immutable public fvKeyManagerBeacon;

  mapping(address => address) public accounts;

  constructor() {
    // Deploy initializable ERC725Account (LSP0) and LSP6KeyManager contracts
    LSP0ERC725AccountLateInit fvAccount = new LSP0ERC725AccountLateInit();
    LSP6KeyManagerInit fvKeyManager = new LSP6KeyManagerInit();

    // Deploy beacons for the contracts (which user wallet proxies will point to)
    fvAccountBeacon = new UpgradeableBeacon(address(fvAccount));
    fvKeyManagerBeacon = new UpgradeableBeacon(address(fvKeyManager));

    fvAccount.disableInitializers();
  }

  // TODO: Note gas costs for previous tests
  // TODO: benchmark/compare gas costs
  function register(address _addr) public returns (address) {
    if (accounts[_addr] != address(0)) revert AccountAlreadyExists(_addr);

    BeaconProxy userFVAccountProxy = new BeaconProxy(
      address(fvAccountBeacon), bytes("")
    );
    BeaconProxy userFVKeyManagerProxy = new BeaconProxy(
      address(fvKeyManagerBeacon),
      abi.encodeWithSignature("initialize(address)", address(userFVAccountProxy)) // set target to proxy -> ERC725Account
    );

    address userFVKeyManagerAddr = address(userFVKeyManagerProxy); // gas savings (repeated access)

    // Initialise key manager as owner and SUPER permissions to user
    LSP0ERC725AccountLateInit(payable(address(userFVAccountProxy))).initializeWithData(
      userFVKeyManagerAddr,
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, _addr),
      ALL_PERMISSIONS.toBytes()
    );

    accounts[_addr] = userFVKeyManagerAddr;

    emit AccountRegistered(_addr, userFVKeyManagerAddr);

    return userFVKeyManagerAddr;
  }

  function identityOf(address _addr) public view returns (address) {
    return accounts[_addr];
  }

  function fvAccountAddr() external view returns (address) {
    return address(fvAccountBeacon.implementation());
  }

  function fvKeyManagerAddr() external view returns (address) {
    return address(fvKeyManagerBeacon.implementation());
  }
}