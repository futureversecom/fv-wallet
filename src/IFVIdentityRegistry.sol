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
   * @return keyManager The registered key manager for the user.
   */
  function register(address _addr) external returns (address keyManager);

  /**
   * Update the owner of a key manager.
   * @param owner The current owner.
   * @param newOwner The new owner.
   * @notice This function is called by the key manager.
   */
  function updateKeyManagerOwner(address owner, address newOwner) external;
}
