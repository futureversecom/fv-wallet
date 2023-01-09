// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ILSP6KeyManager} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/ILSP6KeyManager.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {IFVAccountRegistry} from "./IFVAccountRegistry.sol";
import {LSP0ERC725AccountLateInit} from "./LSP0ERC725AccountLateInit.sol";
import "./Utils.sol";

/**
 * FV Account Registry
 * A manager for user accounts in the Futureverse ecosystem.
 */
contract FVAccountRegistry is Initializable, OwnableUpgradeable, ERC165, IFVAccountRegistry {
  using Utils for string;

  UpgradeableBeacon public fvAccountBeacon;
  UpgradeableBeacon public fvKeyManagerBeacon;
  mapping(address => address) internal managers;

  constructor() {
    _disableInitializers();
  }

  /**
   * Initialize the Account Registry contract.
   * @param fvKeyManager The key manager implementation to use.
   * @dev This can only be called once on creation.
   * @dev Deploys the account implementation so this contract is the owner.
   * @dev Deploys beacons for these implementations.
   */
  function initialize(address fvKeyManager) external virtual initializer {
    // init initializers
    __Ownable_init();

    // Deploy initializable ERC725Account (LSP0) and LSP6KeyManager contracts
    LSP0ERC725AccountLateInit fvAccount = new LSP0ERC725AccountLateInit();

    // Deploy beacons for the contracts (which user wallet proxies will point to)
    fvAccountBeacon = new UpgradeableBeacon(address(fvAccount));
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
      revert AccountNotRegistered(_addr);
    }
    return keyManager;
  }

  /**
   * Get the account for a given address.
   * @param _addr The address to look up.
   * @return account The account.
   */
  function accountOf(address _addr) external view returns (address account) {
    address keyManager = keyManagerOf(_addr);
    return ILSP6KeyManager(keyManager).target();
  }

  /**
   * Get the key manager implementation.
   * @return keyManager The key manager implementation.
   */
  function fvKeyManagerAddr() external view returns (address keyManager) {
    return fvKeyManagerBeacon.implementation();
  }

  /**
   * Get the account implementation.
   * @return account The account implementation.
   */
  function fvAccountAddr() external view returns (address account) {
    return fvAccountBeacon.implementation();
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
   * Upgrade the account implementation.
   * @param _newImplementation The new implementation address.
   * @dev This can only be called by the contract owner.
   */
  function upgradeFVAccount(address _newImplementation) external onlyOwner {
    fvAccountBeacon.upgradeTo(_newImplementation);
  }

  //
  // Register
  //

  /**
   * Register a key manager and account for a given address.
   * @param _addr The address to create a key manager and account for.
   * @return keyManager The registered key manager for the user.
   */
  function register(address _addr) public returns (address keyManager) {
    if (managers[_addr] != address(0)) {
      revert AccountAlreadyExists(_addr);
    }

    bytes32 salt = keccak256(abi.encodePacked(_addr));

    // deploy ERC725Account proxy - using Create2
    BeaconProxy userFVAccountProxy = new BeaconProxy{salt: salt}(
            address(fvAccountBeacon),
            bytes("") // dont `initialize` (done below)
        );

    // deploy KeyManager proxy - using Create2
    keyManager = address(
      new BeaconProxy{salt: salt}(
                                    address(fvKeyManagerBeacon),
                                    abi.encodeWithSignature(
                                        "initialize(address)",
                                        address(userFVAccountProxy)
                                    )
                                )
    );

    LSP0ERC725AccountLateInit(payable(address(userFVAccountProxy))).initialize(
      keyManager, Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, _addr), ALL_PERMISSIONS.toBytes()
    );

    managers[_addr] = keyManager;

    emit AccountRegistered(_addr, keyManager);

    return keyManager;
  }

  /**
   * Predict the key manager address for a given address.
   * @param _addr The address to look up.
   * @return keyManager The predicted key manager address.
   */
  function predictProxyKeyManagerAddress(address _addr) public view returns (address keyManager) {
    address proxyWalletAddress = predictProxyAccountAddress(_addr);
    bytes memory bytecodeWithConstructor = abi.encodePacked(
      type(BeaconProxy).creationCode,
      abi.encode(fvKeyManagerBeacon, abi.encodeWithSignature("initialize(address)", address(proxyWalletAddress)))
    );
    return predictAddress(_addr, bytecodeWithConstructor);
  }

  /**
   * Predict the account address for a given address.
   * @param _addr The address to look up.
   * @return account The predicted account address.
   */
  function predictProxyAccountAddress(address _addr) public view returns (address account) {
    bytes memory bytecodeWithConstructor =
      abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(fvAccountBeacon, bytes("")));
    return predictAddress(_addr, bytecodeWithConstructor);
  }

  //
  // Helpers
  //

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == type(IFVAccountRegistry).interfaceId || super.supportsInterface(interfaceId);
  }

  /**
   * Predict the address for a contract deployed with CREATE2.
   * @param saltAddr The deployment salt.
   * @param bytecodeWithConstructor The deployed bytecode.
   * @return addr The predicted address.
   */
  function predictAddress(address saltAddr, bytes memory bytecodeWithConstructor) internal view returns (address addr) {
    bytes32 salt = keccak256(abi.encodePacked(saltAddr));
    bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecodeWithConstructor)));
    return address(uint160(uint256(hash)));
  }
}
