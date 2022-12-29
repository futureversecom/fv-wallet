// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725Account.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManager.sol";

import "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725AccountInit.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManagerInit.sol";

import "./IFVAccountRegistry.sol";
import "./Utils.sol";

contract FVAccountRegistry is IFVAccountRegistry {
  using Utils for string;

  LSP0ERC725Account immutable public fvAccount;
  LSP6KeyManager immutable public fvKeyManager;

  mapping(address => address) public accounts;

  constructor() {
    fvAccount = new LSP0ERC725Account(address(this));
    fvKeyManager = new LSP6KeyManager(address(fvAccount));
    
    // add permission to set the owner of the account
    fvAccount.setData(
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, address(this)),
      ALL_PERMISSIONS.toBytes()
    );

    fvAccount.transferOwnership(address(fvKeyManager));
    fvKeyManager.execute(abi.encode(fvAccount.acceptOwnership.selector));

    // remove permission required to set the owner of the account from this contract
    fvKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, address(this)),
        NO_PERMISSION.toBytes()
      )
    );
  }

  function register(address _addr) public returns (address) {
    if (accounts[_addr] != address(0)) revert AccountAlreadyExists(_addr);

    // https://docs.openzeppelin.com/contracts/4.x/api/proxy#Clones
    // address addrKeyManager = Clones.clone(address(fvAccount));
    // address addrKeyManager = Clones.cloneDeterministic(address(fvAccount), keccak256(abi.encodePacked(_addr)));    

    LSP0ERC725Account acc = new LSP0ERC725Account(address(this));
    LSP6KeyManager kmgr = new LSP6KeyManager(address(acc));

    // temporarily give SUPER permissions to self
    acc.setData(
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, address(this)),
      ALL_PERMISSIONS.toBytes()
    );

    // give SUPER permissions to user
    acc.setData(
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, _addr),
      ALL_PERMISSIONS.toBytes()
    );

    acc.transferOwnership(address(kmgr));
    kmgr.execute(abi.encode(acc.acceptOwnership.selector));

    // remove SUPER permissions from self
    kmgr.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, address(this)),
        NO_PERMISSION.toBytes()
      )
    );

    accounts[_addr] = address(kmgr);

    emit AccountRegistered(_addr, address(kmgr));

    return address(kmgr);
  }

  function identityOf(address _addr) public view returns (address) {
    return accounts[_addr];
  }

  function fvAccountAddr() external view returns (address) {
    return address(fvAccount);
  }

  function fvKeyManagerAddr() external view returns (address) {
    return address(fvKeyManager);
  }
}
