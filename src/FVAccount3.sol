// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725Account.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManager.sol";

import "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725AccountInit.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManagerInit.sol";

import "./IFVAccountRegistry.sol";
import "./Utils.sol";

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
    LSP0ERC725AccountInit fvAccount = new LSP0ERC725AccountInit();
    LSP6KeyManagerInit fvKeyManager = new LSP6KeyManagerInit();

    // Deploy beacons for the contracts (which user wallet proxies will point to)
    fvAccountBeacon = new UpgradeableBeacon(address(fvAccount));
    fvKeyManagerBeacon = new UpgradeableBeacon(address(fvKeyManager));
  }

  // TODO: Note gas costs for previous tests
  // TODO: benchmark/compare gas costs
  function register(address _addr) public returns (address) {
    if (accounts[_addr] != address(0)) revert AccountAlreadyExists(_addr);

    BeaconProxy userFVAccountProxy = new BeaconProxy(
      address(fvAccountBeacon),
      abi.encodeWithSignature("initialize(address)", address(this)) // set owner to this contract
    );
    BeaconProxy userFVKeyManagerProxy = new BeaconProxy(
      address(fvKeyManagerBeacon),
      abi.encodeWithSignature("initialize(address)", address(userFVAccountProxy)) // set target to proxy -> ERC725Account
    );

    address userFVKeyManagerAddr = address(userFVKeyManagerProxy); // gas savings (repeated access)

    LSP0ERC725Account userFVAccount = LSP0ERC725Account(payable(address(userFVAccountProxy)));
    LSP6KeyManager userFVKeyManager = LSP6KeyManager(userFVKeyManagerAddr);

    // temporarily give SUPER permissions to this contract,
    // required to set the owner of the account
    userFVAccount.setData(
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, address(this)),
      ALL_PERMISSIONS.toBytes()
    );

    // give SUPER permissions to user
    userFVAccount.setData(
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, _addr),
      ALL_PERMISSIONS.toBytes()
    );

    // 2 step ownable transfer to LSP6KeyManager proxy
    userFVAccount.transferOwnership(userFVKeyManagerAddr);
    userFVKeyManager.execute(abi.encode(userFVAccount.acceptOwnership.selector));

    // remove permission required to set the owner of the account from this contract
    userFVKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, address(this)),
        NO_PERMISSION.toBytes()
      )
    );

    accounts[_addr] = userFVKeyManagerAddr;

    emit AccountRegistered(_addr);

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
