// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/**
 * @dev reverts when address `addr` is already registered
 * @param addr the address to register
 */
error AccountAlreadyExists(address addr);

// All Permissions currently exclude REENTRANCY, DELEGATECALL and SUPER_DELEGATECALL for security
// source: https://github.com/lukso-network/lsp-smart-contracts/blob/b97b186430eb4e4984c6c366356d62119d5930cc/constants.js#L182
string constant ALL_PERMISSIONS = "00000000000000000000000000000000000000000000000000000000003f3f7f";
string constant NO_PERMISSION = "0000000000000000000000000000000000000000000000000000000000000000";
string constant KEY_ADDRESSPERMISSIONS_PERMISSIONS = "4b80742de2bf82acb3630000";
string constant KEY_ADDRESSPERMISSIONS_ALLOWEDADDRESSES = "4b80742de2bfc6dd6b3c0000";
string constant KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS = "4b80742de2bf393a64c70000";

library Utils {
  bytes16 private constant SYMBOLS = "0123456789abcdef";
  uint8 private constant ADDRESS_LENGTH = 20;

  function toHexStringNoPrefix(uint256 value, uint256 length) internal pure returns (string memory) {
    bytes memory buffer = new bytes(2 * length);
    for (uint256 i = 2 * length + 1; i > 1; --i) {
      buffer[i - 2] = SYMBOLS[value & 0xf];
      value >>= 4;
    }
    require(value == 0, "Strings: hex length insufficient");
    return string(buffer);
  }

  function toHexStringNoPrefix(address addr) internal pure returns (string memory) {
    return toHexStringNoPrefix(uint256(uint160(addr)), ADDRESS_LENGTH);
  }

  function stringToBytes32(string memory source) internal pure returns (bytes32 result) {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) {
      return 0x0;
    }
    assembly {
      result := mload(add(source, 32))
    }
  }

  function toBytes(bytes32 data) internal pure returns (bytes memory) {
    return bytes.concat(data);
  }

  function fromHexChar(uint8 c) internal pure returns (uint8) {
    if (bytes1(c) >= bytes1("0") && bytes1(c) <= bytes1("9")) {
      return c - uint8(bytes1("0"));
    }
    if (bytes1(c) >= bytes1("a") && bytes1(c) <= bytes1("f")) {
      return 10 + c - uint8(bytes1("a"));
    }
    if (bytes1(c) >= bytes1("A") && bytes1(c) <= bytes1("F")) {
      return 10 + c - uint8(bytes1("A"));
    }
    revert("fail");
  }

  // Convert an hexadecimal string to raw bytes
  function toBytes(string memory s) public pure returns (bytes memory) {
    bytes memory ss = bytes(s);
    require(ss.length % 2 == 0); // length must be even
    bytes memory r = new bytes(ss.length/2);
    for (uint256 i = 0; i < ss.length / 2; ++i) {
      r[i] = bytes1(fromHexChar(uint8(ss[2 * i])) * 16 + fromHexChar(uint8(ss[2 * i + 1])));
    }
    return r;
  }

  function permissionsKey(string memory permissionKey, address _addr) public pure returns (bytes32) {
    return bytes32(toBytes(string.concat(permissionKey, toHexStringNoPrefix(_addr))));
  }
}
