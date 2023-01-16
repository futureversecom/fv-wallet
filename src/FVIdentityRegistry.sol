// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {IFVIdentityRegistry} from "./IFVIdentityRegistry.sol";
import {FVIdentity} from "./FVIdentity.sol";
import {FVKeyManager} from "./FVKeyManager.sol";
import "./Utils.sol";

/**
 * FV Identity Registry
 * A manager for user identities in the Futureverse ecosystem.
 */
contract FVIdentityRegistry is Initializable, OwnableUpgradeable, ERC165, IFVIdentityRegistry {
  UpgradeableBeacon public fvIdentityBeacon;
  UpgradeableBeacon public fvKeyManagerBeacon;
  mapping(address => address) internal managers;

  constructor() {
    _disableInitializers();
  }

  /**
   * Initialize the Identity Registry contract.
   * @param fvKeyManager The key manager implementation to use.
   * @dev This can only be called once on creation.
   * @dev Deploys the identity implementation so this contract is the owner.
   * @dev Deploys beacons for these implementations.
   */
  function initialize(address fvKeyManager) external virtual initializer {
    // init initializers
    __Ownable_init();

    // Deploy initializable ERC725Account (LSP0) and LSP6KeyManager contracts
    FVIdentity fvIdentity = new FVIdentity();

    // Deploy beacons for the contracts (which user wallet proxies will point to)
    fvIdentityBeacon = new UpgradeableBeacon(address(fvIdentity));
    fvKeyManagerBeacon = new UpgradeableBeacon(fvKeyManager);
  }

  //
  // Getters
  //

  /**
   * Get the key manager for a given address.
   * @param _addr The address to look up.
   * @return keyManager The key manager.
   */
  function keyManagerOf(address _addr) public view returns (address keyManager) {
    keyManager = managers[_addr];
    if (keyManager == address(0)) {
      revert IdentityNotRegistered(_addr);
    }
    return keyManager;
  }

  /**
   * Get the identity for a given address.
   * @param _addr The address to look up.
   * @return identity The identity.
   */
  function identityOf(address _addr) external view returns (address identity) {
    address keyManager = keyManagerOf(_addr);
    return FVKeyManager(keyManager).target();
  }

  /**
   * Get the key manager implementation.
   * @return keyManager The key manager implementation.
   */
  function fvKeyManagerAddr() external view returns (address keyManager) {
    return fvKeyManagerBeacon.implementation();
  }

  /**
   * Get the identity implementation.
   * @return identity The identity implementation.
   */
  function fvIdentityAddr() external view returns (address identity) {
    return fvIdentityBeacon.implementation();
  }

  //
  // Admin
  //

  /**
   * Upgrade the key manager implementation.
   * @param _newImplementation The new implementation address.
   * @dev This can only be called by the contract owner.
   */
  function upgradeFVKeyManager(address _newImplementation) external onlyOwner {
    fvKeyManagerBeacon.upgradeTo(_newImplementation);
  }

  /**
   * Upgrade the identity implementation.
   * @param _newImplementation The new implementation address.
   * @dev This can only be called by the contract owner.
   */
  function upgradeFVIdentity(address _newImplementation) external onlyOwner {
    fvIdentityBeacon.upgradeTo(_newImplementation);
  }

  //
  // Register
  //

  /**
   * Register a key manager and identity for a given address.
   * @param _addr The address to create a key manager and identity for.
   * @return keyManager The registered key manager for the user.
   */
  function register(address _addr) public returns (address keyManager) {
    if (managers[_addr] != address(0)) {
      revert IdentityAlreadyExists(_addr);
    }

    // deploy ERC725Account proxy
    BeaconProxy userFVIdentityProxy = new BeaconProxy(
      address(fvIdentityBeacon),
      bytes("") // dont `initialize` (done below)
    );

    // deploy KeyManager proxy
    keyManager = address(
      new BeaconProxy(address(fvKeyManagerBeacon), abi.encodeWithSignature("initialize(address,address,address)", address(userFVIdentityProxy), _addr, address(this)))
    );

    FVIdentity(payable(address(userFVIdentityProxy))).initialize(
      keyManager, Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, _addr), Utils.toBytes(ALL_PERMISSIONS)
    );

    managers[_addr] = keyManager;

    emit IdentityRegistered(_addr, keyManager, address(userFVIdentityProxy));

    return keyManager;
  }

  /**
   * Update the owner of a key manager.
   * @param owner The current owner.
   * @param newOwner The new owner.
   * @notice This function is called by the key manager.
   * @notice newOwner must not already have a key manager.
   */
  function updateKeyManagerOwner(address owner, address newOwner) external {
    if (managers[owner] != msg.sender) {
      revert InvalidCaller(msg.sender, managers[owner]);
    }
    if (managers[newOwner] != address(0)) {
      revert IdentityAlreadyExists(newOwner);
    }
    delete managers[owner];
    managers[newOwner] = msg.sender;
    emit IdentityChanged(owner, newOwner, msg.sender);
  }

  //
  // Helpers
  //

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == type(IFVIdentityRegistry).interfaceId || super.supportsInterface(interfaceId);
  }
}
