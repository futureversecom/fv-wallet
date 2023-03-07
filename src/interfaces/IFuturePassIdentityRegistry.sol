// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IFuturePassIdentityRegistry {
  /**
   * @notice Emitted when registering a new address.
   * @param owner The address of the owner registered for the future pass.
   * @param keyManager The address of the key manager registered for the owner.
   * @param futurePass The address of the future pass registered.
   */
  event FuturePassRegistered(address indexed owner, address indexed keyManager, address indexed futurePass);

  /**
   * @notice Emitted when transferring future pass to a new address.
   * @param oldOwner The address of the previous owner registered for the future pass.
   * @param newOwner The address of the new owner registered for the future pass.
   * @param keyManager The address of the key manager registered for the owner.
   */
  event FuturePassTransferred(address indexed oldOwner, address indexed newOwner, address indexed keyManager);

  /**
   * Get the key manager for a given address.
   * @param _addr The address to look up.
   * @return The key manager or address(0) if not found.
   */
  function keyManagerOf(address _addr) external view returns (address);

  /**
   * Get the future pass for a given address.
   * @param _addr The address to look up.
   * @return The future pass of address.
   */
  function futurePassOf(address _addr) external view returns (address);

  /**
   * Get the key manager implementation.
   * @return The key manager implementation.
   */
  function keyManagerAddr() external view returns (address);

  /**
   * Get the future pass implementation.
   * @return The future pass implementation.
   */
  function futurePassAddr() external view returns (address);

  /**
   * Register a key manager and future pass for a given address.
   * @param _addr The address to create a key manager and future pass for.
   * @return keyManager The registered key manager for the user.
   */
  function register(address _addr) external returns (address);

  /**
   * Update the owner of a key manager.
   * @param owner The current owner.
   * @param newOwner The new owner.
   * @notice This function is called by the key manager.
   */
  function updateKeyManagerOwner(address owner, address newOwner) external;
}
