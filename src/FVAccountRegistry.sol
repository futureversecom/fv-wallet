// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {LSP6KeyManagerInit} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManagerInit.sol";

import {IFVAccountRegistry} from "./IFVAccountRegistry.sol";
import {LSP0ERC725AccountLateInit} from "./LSP0ERC725AccountLateInit.sol";
import "./Utils.sol";

// v4 base

contract FVAccountRegistry is Initializable, OwnableUpgradeable, ERC165, IFVAccountRegistry {
  using Utils for string;

  UpgradeableBeacon public fvAccountBeacon;
  UpgradeableBeacon public fvKeyManagerBeacon;
  mapping(address => address) internal accounts;

  constructor() {
    _disableInitializers();
  }

  function initialize(LSP6KeyManagerInit fvKeyManager) external virtual initializer {
    // init initializers
    __Ownable_init();

    // Deploy initializable ERC725Account (LSP0) and LSP6KeyManager contracts
    LSP0ERC725AccountLateInit fvAccount = new LSP0ERC725AccountLateInit();

    // Deploy beacons for the contracts (which user wallet proxies will point to)
    fvAccountBeacon = new UpgradeableBeacon(address(fvAccount));
    fvKeyManagerBeacon = new UpgradeableBeacon(address(fvKeyManager));
  }

  function register(address _addr) public returns (address) {
    if (accounts[_addr] != address(0)) {
      revert AccountAlreadyExists(_addr);
    }

    // deploy ERC725Account proxy - using Create2
    BeaconProxy userFVAccountProxy = new BeaconProxy{
            salt: keccak256(abi.encodePacked(_addr))
        }(
            address(fvAccountBeacon),
            bytes("") // dont `initialize` (done below)
        );

    // deploy KeyManager proxy - using Create2
    BeaconProxy userFVKeyManagerProxy = new BeaconProxy{
            salt: keccak256(abi.encodePacked(_addr))
        }(
            address(fvKeyManagerBeacon),
            abi.encodeWithSignature(
                "initialize(address)",
                address(userFVAccountProxy)
            )
        );

    LSP0ERC725AccountLateInit(payable(address(userFVAccountProxy))).initialize(
      address(userFVKeyManagerProxy),
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, _addr),
      ALL_PERMISSIONS.toBytes()
    );

    accounts[_addr] = address(userFVKeyManagerProxy);

    emit AccountRegistered(_addr, address(userFVKeyManagerProxy));

    return address(userFVKeyManagerProxy);
  }

  function identityOf(address _addr) public view returns (address) {
    return accounts[_addr];
  }

  function fvAccountAddr() external view returns (address) {
    return fvAccountBeacon.implementation();
  }

  function fvKeyManagerAddr() external view returns (address) {
    return fvKeyManagerBeacon.implementation();
  }

  function predictProxyWalletAddress(address userAddr) public view returns (address) {
    bytes memory bytecodeWithConstructor =
      abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(fvAccountBeacon, bytes("")));
    return predictAddress(userAddr, bytecodeWithConstructor);
  }

  function predictProxyWalletKeyManagerAddress(address userAddr) public view returns (address) {
    address proxyWalletAddress = predictProxyWalletAddress(userAddr);
    bytes memory bytecodeWithConstructor = abi.encodePacked(
      type(BeaconProxy).creationCode,
      abi.encode(fvKeyManagerBeacon, abi.encodeWithSignature("initialize(address)", address(proxyWalletAddress)))
    );
    return predictAddress(userAddr, bytecodeWithConstructor);
  }

  function upgradeFVAccount(address _newImplementation) external onlyOwner {
    fvAccountBeacon.upgradeTo(_newImplementation);
  }

  function upgradeFVKeyManager(address _newImplementation) external onlyOwner {
    fvKeyManagerBeacon.upgradeTo(_newImplementation);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == type(IFVAccountRegistry).interfaceId || super.supportsInterface(interfaceId);
  }

  function predictAddress(address saltAddr, bytes memory bytecodeWithConstructor) internal view returns (address addr) {
    bytes32 salt = keccak256(abi.encodePacked(saltAddr));
    bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecodeWithConstructor)));
    return address(uint160(uint256(hash)));
  }
}
