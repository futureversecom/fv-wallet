// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IFVAccountRegistry {
  /**
   * @notice Emitted when registering a new address
   * @param account The address of the account registered
   * @param wallet The address of the wallet (key manager) registered for the account
   */
  event AccountRegistered(address indexed account, address indexed wallet);

  /**
   * Get the account for a given address.
   * @param _addr The address to look up.
   * @return account The account.
   */
  function identityOf(address _addr) external view returns (address account);

  /**
   * Get the key manager implementation.
   * @return keyManager The key manager implementation.
   */
  function fvKeyManagerAddr() external view returns (address keyManager);

  /**
   * Get the account implementation.
   * @return account The account implementation.
   */
  function fvAccountAddr() external view returns (address account);

  /**
   * Register a key manager and account for a given address.
   * @param _addr The address to create a key manager and account for.
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
   * Predict the account address for a given address.
   * @param _addr The address to look up.
   * @return account The predicted account address.
   */
  function predictProxyAccountAddress(address _addr) external returns (address account);
}
