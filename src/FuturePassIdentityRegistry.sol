// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {IFuturePassIdentityRegistry} from "./interfaces/IFuturePassIdentityRegistry.sol";
import {FuturePass} from "./FuturePass.sol";
import {FuturePassKeyManager} from "./FuturePassKeyManager.sol";
import "./libraries/Utils.sol";

/**
 * @title FuturePassIdentityRegistry
 * @author Futureverse
 * @notice A manager for user future passes in the Futureverse ecosystem.
 */
contract FuturePassIdentityRegistry is Initializable, OwnableUpgradeable, ERC165, IFuturePassIdentityRegistry {
  UpgradeableBeacon public futurePassBeacon;
  UpgradeableBeacon public keyManagerBeacon;
  mapping(address => address) internal managers;

  constructor() {
    _disableInitializers();
  }

  /**
   * Initialize the Future Pass Identity Registry contract.
   * @param futurePass The future pass implementation to use.
   * @param keyManager The key manager implementation to use.
   * @dev This can only be called once on creation.
   * @dev Deploys beacons for the future pass and key manager implementations.
   */
  function initialize(address futurePass, address keyManager) external virtual initializer {
    // init initializers
    __Ownable_init();

    // Deploy beacons for the contracts (which user wallet proxies will point to)
    futurePassBeacon = new UpgradeableBeacon(futurePass);
    keyManagerBeacon = new UpgradeableBeacon(keyManager);
  }

  //
  // Getters
  //

  /**
   * Get the key manager for a given address.
   * @param _addr The address to look up.
   * @return Key manager of the address.
   */
  function keyManagerOf(address _addr) public view returns (address) {
    return managers[_addr];
  }

  /**
   * Get the future pass a given address.
   * @param _addr The address to look up.
   * @return Future pass of the address.
   */
  function futurePassOf(address _addr) external view returns (address) {
    address keyManager = keyManagerOf(_addr);
    if (keyManager == address(0)) return address(0);
    return FuturePassKeyManager(keyManager).target();
  }

  /**
   * Get the key manager implementation.
   * @return The Key Manager implementation.
   */
  function keyManagerAddr() external view returns (address) {
    return keyManagerBeacon.implementation();
  }

  /**
   * Get the future pass implementation.
   * @return The future pass implementation.
   */
  function futurePassAddr() external view returns (address) {
    return futurePassBeacon.implementation();
  }

  //
  // Admin
  //

  /**
   * Upgrade the key manager implementation.
   * @param _newImplementation The new implementation address.
   * @dev This can only be called by the contract owner.
   */
  function upgradeKeyManager(address _newImplementation) external onlyOwner {
    keyManagerBeacon.upgradeTo(_newImplementation);
  }

  /**
   * Upgrade the future pass implementation.
   * @param _newImplementation The new implementation address.
   * @dev This can only be called by the contract owner.
   */
  function upgradeFuturePass(address _newImplementation) external onlyOwner {
    futurePassBeacon.upgradeTo(_newImplementation);
  }

  //
  // Register
  //

  /**
   * Register a key manager and future pass for a given address.
   * @param _addr The address to create a key manager and future pass for.
   * @return The registered key manager for the user.
   */
  function register(address _addr) public returns (address) {
    if (managers[_addr] != address(0)) revert IdentityAlreadyExists(_addr);

    // deploy ERC725Account proxy
    BeaconProxy userFuturePassProxy = new BeaconProxy(
      address(futurePassBeacon),
      bytes("") // dont `initialize` (done below)
    );

    // deploy KeyManager proxy
    address keyManager = address(
      new BeaconProxy(address(keyManagerBeacon), abi.encodeWithSignature("initialize(address,address,address)", address(userFuturePassProxy), _addr, address(this)))
    );

    FuturePass(payable(address(userFuturePassProxy))).initialize(
      keyManager, Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, _addr), Utils.toBytes(ALL_PERMISSIONS)
    );

    managers[_addr] = keyManager;

    emit FuturePassRegistered(_addr, keyManager, address(userFuturePassProxy));

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
    if (managers[owner] != msg.sender) revert InvalidCaller(msg.sender, managers[owner]);
    if (managers[newOwner] != address(0)) revert IdentityAlreadyExists(newOwner);
    delete managers[owner];
    managers[newOwner] = msg.sender;
    emit FuturePassTransferred(owner, newOwner, msg.sender);
  }

  //
  // Helpers
  //

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == type(IFuturePassIdentityRegistry).interfaceId || super.supportsInterface(interfaceId);
  }
}
