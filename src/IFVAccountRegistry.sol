// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IFVAccountRegistry {
    /**
     * @notice Emitted when registering a new address
     * @param account The address of the account registered
     * @param wallet The address of the wallet (key manager) registered for the account
     */
    event AccountRegistered(address indexed account, address indexed wallet);

    function register(address _addr) external returns (address);

    function predictProxyWalletKeyManagerAddress(address _addr) external returns (address);

    function identityOf(address _addr) external view returns (address);

    function fvAccountAddr() external view returns (address);

    function fvKeyManagerAddr() external view returns (address);
}
