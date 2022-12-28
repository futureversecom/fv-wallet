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
  using Utils for address;
  using Utils for string;

  LSP0ERC725AccountInit immutable public fvAccount;
  LSP6KeyManagerInit immutable public fvKeyManager;

  mapping(address => address) public accounts;

  constructor() {
    fvAccount = new LSP0ERC725AccountInit();
    fvKeyManager = new LSP6KeyManagerInit();
  }

  function fvAccountAddr() external view returns (address) {
    return address(fvAccount);
  }

  function fvKeyManagerAddr() external view returns (address) {
    return address(fvKeyManager);
  }

  function identityOf(address _addr) public view returns (address) {
    return accounts[_addr];
  }

  // optimized registration using proxies
  // TODO: Note gas costs for previous tests
  // TODO: benchmark/compare gas costs
  function register(address _addr) public returns (address) {
    if (accounts[_addr] != address(0)) revert AccountAlreadyExists(_addr);

    // https://docs.openzeppelin.com/contracts/4.x/api/proxy#Clones
    // address addrKeyManager = Clones.clone(address(fvAccount));
    // address addrKeyManager = Clones.cloneDeterministic(address(fvAccount), keccak256(abi.encodePacked(_addr)));

    address userFVAccountAddr = Clones.clone(address(fvAccount));
    LSP0ERC725AccountInit userFVAccount = LSP0ERC725AccountInit(payable(userFVAccountAddr));

    address userFVKeyManagerAddr = Clones.clone(address(fvKeyManager));
    LSP6KeyManagerInit userFVKeyManager = LSP6KeyManagerInit(userFVKeyManagerAddr);

    userFVAccount.initialize(address(this)); // set owner to this contract
    userFVKeyManager.initialize(userFVAccountAddr); // set target to proxy -> ERC725Account

    // temporarily give SUPER permissions to this contract,
    // required to set the owner of the account
    userFVAccount.setData(address(this).permissionsKey(), ALL_PERMISSIONS.toBytes());

    // give SUPER permissions to user
    userFVAccount.setData(_addr.permissionsKey(), ALL_PERMISSIONS.toBytes());

    // 2 step ownable transfer to LSP6KeyManager proxy
    userFVAccount.transferOwnership(userFVKeyManagerAddr);
    userFVKeyManager.execute(abi.encode(userFVAccount.acceptOwnership.selector));

    // remove permission required to set the owner of the account from this contract
    userFVKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        address(this).permissionsKey(),
        NO_PERMISSION.toBytes()
      )
    );

    accounts[_addr] = userFVKeyManagerAddr;

    emit AccountRegistered(_addr);

    return userFVKeyManagerAddr;
  }
}
