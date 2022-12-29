// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {LSP0ERC725Account} from "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725Account.sol";
import {LSP6KeyManager} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManager.sol";
import {LSP0ERC725AccountInit} from "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725AccountInit.sol";
import {LSP6KeyManagerInit} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManagerInit.sol";

import {IFVAccountRegistry} from "./IFVAccountRegistry.sol";
import "./Utils.sol";
import "./LSP0ERC725AccountLateInit.sol";

// v4 base

contract FVAccountRegistry is Initializable, OwnableUpgradeable, ERC165, IFVAccountRegistry {
  using Utils for string;

  UpgradeableBeacon public fvAccountBeacon;
  UpgradeableBeacon public fvKeyManagerBeacon;
  mapping(address => address) public accounts;

  constructor() {
    _disableInitializers();
  }

  function initialize() external virtual initializer {
    // init initializers
    __Ownable_init();

    // Deploy initializable ERC725Account (LSP0) and LSP6KeyManager contracts
    LSP0ERC725AccountLateInit fvAccount = new LSP0ERC725AccountLateInit();
    LSP6KeyManagerInit fvKeyManager = new LSP6KeyManagerInit();

    // Deploy beacons for the contracts (which user wallet proxies will point to)
    fvAccountBeacon = new UpgradeableBeacon(address(fvAccount));
    fvKeyManagerBeacon = new UpgradeableBeacon(address(fvKeyManager));
  }

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

    LSP0ERC725AccountLateInit(payable(address(userFVAccountProxy))).initialize(
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
