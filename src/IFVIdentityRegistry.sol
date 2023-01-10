// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IFVIdentityRegistry {
  /**
   * @notice Emitted when registering a new address.
   * @param owner The address of the owner registered for the identity.
   * @param keyManager The address of the key manager registered for the owner.
   * @param identity The address of the identity registered.
   */
  event IdentityRegistered(address indexed owner, address indexed keyManager, address indexed identity);

  /**
   * @notice Emitted when registering a new address.
   * @param oldOwner The address of the previous owner registered for the identity.
   * @param newOwner The address of the new owner registered for the identity.
   * @param keyManager The address of the key manager registered for the owner.
   */
  event IdentityChanged(address indexed oldOwner, address indexed newOwner, address indexed keyManager);

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
   * @param nonce A nonce to support addresses that register multiple times (after a transfer).
   * @return keyManager The registered key manager for the user.
   */
  function register(address _addr, uint96 nonce) external returns (address keyManager);

  /**
   * Predict the key manager address for a given address.
   * @param _addr The address to look up.
   * @param nonce A nonce to support addresses that register multiple times (after a transfer).
   * @return keyManager The predicted key manager address.
   */
  function predictProxyKeyManagerAddress(address _addr, uint96 nonce) external returns (address keyManager);

  /**
   * Predict the identity address for a given address.
   * @param _addr The address to look up.
   * @param nonce A nonce to support addresses that register multiple times (after a transfer).
   * @return identity The predicted identity address.
   */
  function predictProxyIdentityAddress(address _addr, uint96 nonce) external returns (address identity);

  /**
   * Update the owner of a key manager.
   * @param owner The current owner.
   * @param newOwner The new owner.
   * @notice This function is called by the key manager.
   */
  function updateKeyManagerOwner(address owner, address newOwner) external;
}
