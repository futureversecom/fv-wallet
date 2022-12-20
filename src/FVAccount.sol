// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725Account.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManager.sol";

contract FVAccount is LSP0ERC725Account {
  constructor(address _newOwner) LSP0ERC725Account(_newOwner) {
  }
}

contract FVKeyManager is LSP6KeyManager {
  constructor(address target) LSP6KeyManager(target) {
  }
}

contract FVAccountRegistry {
  FVAccount immutable public fvAccount;
  FVKeyManager immutable public fvKeyManager;

  mapping(address => address) public accounts;

  event AccountRegistered(address indexed account);

  constructor() {
    fvAccount = new FVAccount(address(this));
    fvKeyManager = new FVKeyManager(address(fvAccount));
  }

  function identityOf(address addr) public view returns (address) {
    return accounts[addr];
  }

  // TODO - move to library
  bytes16 private constant _SYMBOLS = "0123456789abcdef";
  uint8 private constant _ADDRESS_LENGTH = 20;
  function toHexStringNoPrefix(uint256 value, uint256 length) public pure returns (string memory) {
    bytes memory buffer = new bytes(2 * length);
    for (uint256 i = 2 * length + 1; i > 1; --i) {
      buffer[i - 2] = _SYMBOLS[value & 0xf];
      value >>= 4;
    }
    require(value == 0, "Strings: hex length insufficient");
    return string(buffer);
  }
  function toHexStringNoPrefix(address addr) public pure returns (string memory) {
    return toHexStringNoPrefix(uint256(uint160(addr)), _ADDRESS_LENGTH);
  }
  function stringToBytes32(string memory source) public pure returns (bytes32 result) {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) {
        return 0x0;
    }

    assembly {
        result := mload(add(source, 32))
    }
  }
  function toBytes(bytes32 data) public pure returns (bytes memory) {
    return bytes.concat(data);
  }
  function fromHexChar(uint8 c) public pure returns (uint8) {
    if (bytes1(c) >= bytes1('0') && bytes1(c) <= bytes1('9')) {
      return c - uint8(bytes1('0'));
    }
    if (bytes1(c) >= bytes1('a') && bytes1(c) <= bytes1('f')) {
      return 10 + c - uint8(bytes1('a'));
    }
    if (bytes1(c) >= bytes1('A') && bytes1(c) <= bytes1('F')) {
      return 10 + c - uint8(bytes1('A'));
    }
    revert("fail");
  }
  // Convert an hexadecimal string to raw bytes
  function fromHex(string memory s) public pure returns (bytes memory) {
    bytes memory ss = bytes(s);
    require(ss.length%2 == 0); // length must be even
    bytes memory r = new bytes(ss.length/2);
    for (uint i=0; i<ss.length/2; ++i) {
      r[i] = bytes1(fromHexChar(uint8(ss[2*i])) * 16 + fromHexChar(uint8(ss[2*i+1])));
    }
    return r;
  }

  function register(address addr) public {
    if (accounts[addr] != address(0)) return;
    FVAccount acc = new FVAccount(address(this));
    FVKeyManager kmgr = new FVKeyManager(address(acc));

    // temporarily give SUPER permissions to self
    acc.setData(
      bytes32(fromHex(string.concat("4b80742de2bf82acb3630000", toHexStringNoPrefix(address(this))))),
      fromHex("00000000000000000000000000000000000000000000000000000000003f3f7f")
    );
    // give SUPER permissions to user
    acc.setData(
      bytes32(fromHex(string.concat("4b80742de2bf82acb3630000", toHexStringNoPrefix(addr)))),
      fromHex("00000000000000000000000000000000000000000000000000000000003f3f7f")
    );
    acc.transferOwnership(address(kmgr));
    kmgr.execute(abi.encode(acc.acceptOwnership.selector));
    // remove SUPER permissions from self
    kmgr.execute(abi.encodeWithSelector(bytes4(keccak256("setData(bytes32,bytes)")),
      bytes32(fromHex(string.concat("4b80742de2bf82acb3630000", toHexStringNoPrefix(address(this))))),
      fromHex("0000000000000000000000000000000000000000000000000000000000000000")
    ));
    accounts[addr] = address(kmgr);
  }
}