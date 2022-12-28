// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IFVAccountRegistry {

  /**
  * @notice Emitted when registering a new address
  * @param account The address of the account registered
  */
  event AccountRegistered(address indexed account);

  function fvAccountAddr() external view returns (address);
  function fvKeyManagerAddr() external view returns (address);

  function identityOf(address _addr) external view returns (address);

  function register(address _addr) external returns (address);
}
