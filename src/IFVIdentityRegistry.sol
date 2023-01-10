// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IFVIdentityRegistry {
  /**
   * @notice Emitted when registering a new address.
   * @param identity The address of the identity registered.
   * @param wallet The address of the wallet (key manager) registered for the identity.
   */
  event IdentityRegistered(address indexed identity, address indexed wallet);

  /**
   * Get the key manager for a given address.
   * @param _addr The address to look up.
   * @return keyManager The key manager.
   */
  function keyManagerOf(address _addr) external view returns (address keyManager);

  /**
   * Get the identity for a given address.
   * @param _addr The address to look up.
   * @return identity The identity.
   */
  function identityOf(address _addr) external view returns (address identity);

  /**
   * Get the key manager implementation.
   * @return keyManager The key manager implementation.
   */
  function fvKeyManagerAddr() external view returns (address keyManager);

  /**
   * Get the identity implementation.
   * @return identity The identity implementation.
   */
  function fvIdentityAddr() external view returns (address identity);

  /**
   * Register a key manager and identity for a given address.
   * @param _addr The address to create a key manager and identity for.
   * @return keyManager The registered key manager for the user.
   */
  function register(address _addr) external returns (address keyManager);

  /**
   * Predict the key manager address for a given address.
   * @param _addr The address to look up.
   * @return keyManager The predicted key manager address.
   */
  function predictProxyKeyManagerAddress(address _addr) external returns (address keyManager);

  /**
   * Predict the identity address for a given address.
   * @param _addr The address to look up.
   * @return identity The predicted identity address.
   */
  function predictProxyIdentityAddress(address _addr) external returns (address identity);
}
