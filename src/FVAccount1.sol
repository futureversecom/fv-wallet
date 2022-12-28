// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725Account.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManager.sol";

import "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725AccountInit.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManagerInit.sol";

import "./Utils.sol";

contract FVAccountRegistry {
  using Utils for address;
  using Utils for string;

  // All Permissions currently exclude REENTRANCY, DELEGATECALL and SUPER_DELEGATECALL for security
  // source: https://github.com/lukso-network/lsp-smart-contracts/blob/b97b186430eb4e4984c6c366356d62119d5930cc/constants.js#L182
  string public constant ALL_PERMISSIONS = "00000000000000000000000000000000000000000000000000000000003f3f7f";
  string public constant NO_PERMISSION = "0000000000000000000000000000000000000000000000000000000000000000";
  string public constant ADDRESS_PERMISSION_KEY = "4b80742de2bfc6dd6b3c0000";

  LSP0ERC725Account immutable public fvAccount;
  LSP6KeyManager immutable public fvKeyManager;

  mapping(address => address) public accounts;

  /**
  * @notice Emitted when registering a new address
  * @param account The address of the account registered
  */
  event AccountRegistered(address indexed account);

  constructor() {
    fvAccount = new LSP0ERC725Account(address(this));
    fvKeyManager = new LSP6KeyManager(address(fvAccount));
    
    // add permission to set the owner of the account
    fvAccount.setData(
      address(this).permissionsKey(),
      ALL_PERMISSIONS.toBytes()
    );

    fvAccount.transferOwnership(address(fvKeyManager));
    fvKeyManager.execute(abi.encode(fvAccount.acceptOwnership.selector));

    // remove permission required to set the owner of the account from this contract
    fvKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        address(this).permissionsKey(),
        NO_PERMISSION.toBytes()
      )
    );
  }

  function identityOf(address _addr) public view returns (address) {
    return accounts[_addr];
  }

  function register(address _addr) public returns (address) {
    if (accounts[_addr] != address(0)) revert AccountAlreadyExists(_addr);

    // https://docs.openzeppelin.com/contracts/4.x/api/proxy#Clones
    // address addrKeyManager = Clones.clone(address(fvAccount));
    // address addrKeyManager = Clones.cloneDeterministic(address(fvAccount), keccak256(abi.encodePacked(_addr)));    

    LSP0ERC725Account acc = new LSP0ERC725Account(address(this));
    LSP6KeyManager kmgr = new LSP6KeyManager(address(acc));

    // temporarily give SUPER permissions to self
    acc.setData(address(this).permissionsKey(), ALL_PERMISSIONS.toBytes());

    // give SUPER permissions to user
    acc.setData(_addr.permissionsKey(), ALL_PERMISSIONS.toBytes());

    acc.transferOwnership(address(kmgr));
    kmgr.execute(abi.encode(acc.acceptOwnership.selector));

    // remove SUPER permissions from self
    kmgr.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        address(this).permissionsKey(),
        NO_PERMISSION.toBytes()
      )
    );

    accounts[_addr] = address(kmgr);

    emit AccountRegistered(_addr);

    return address(kmgr);
  }
}
