// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/**
 * @dev reverts when address `addr` is already registered
 * @param addr the address to register
 */
error IdentityAlreadyExists(address addr);

/**
 * @dev Thrown when an identity is not found for the given address.
 * @param addr The address that does not have a registered identity.
 */
error IdentityNotRegistered(address addr);

/**
 * @dev Thrown when the caller is invalid.
 * @param actual The actual caller.
 * @param expected The expected caller.
 */
error InvalidCaller(address actual, address expected);

// All Permissions currently exclude REENTRANCY, DELEGATECALL and SUPER_DELEGATECALL for security
// source: https://github.com/lukso-network/lsp-smart-contracts/blob/b97b186430eb4e4984c6c366356d62119d5930cc/constants.js#L182
bytes32 constant ALL_PERMISSIONS = 0x00000000000000000000000000000000000000000000000000000000003f3f7f;
bytes32 constant NO_PERMISSION = 0x0000000000000000000000000000000000000000000000000000000000000000;
bytes12 constant KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX = 0x4b80742de2bf82acb3630000;
bytes12 constant KEY_ADDRESSPERMISSIONS_ALLOWEDADDRESSES_PREFIX = 0x4b80742de2bfc6dd6b3c0000;
bytes12 constant KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS_PREFIX = 0x4b80742de2bf393a64c70000;

library Utils {
  bytes16 private constant SYMBOLS = "0123456789abcdef";
  uint8 private constant ADDRESS_LENGTH = 20;

  function toHexStringNoPrefix(uint256 value, uint256 length) internal pure returns (string memory) {
    bytes memory buffer = new bytes(2 * length);
    for (uint256 i = 2 * length + 1; i > 1; i = _uncheckedDecr(i)) {
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
    if (c > 47 && c < 58) { // 0-9
      return c - 48;
    }
    if (c > 96 && c < 103) { // a-f
      return c - 87;
    }
    if (c > 64 && c < 71) { // A-F
      return c - 55;
    }
    revert("fail");
  }

  // Convert an hexadecimal string to raw bytes
  function toBytes(string memory s) public pure returns (bytes memory) {
    bytes memory ss = bytes(s);
    require(ss.length % 2 == 0); // length must be even
    bytes memory r = new bytes(ss.length/2);
    for (uint256 i = 0; i < ss.length / 2; i = _uncheckedInc(i)) {
      r[i] = bytes1(fromHexChar(uint8(ss[2 * i])) * 16 + fromHexChar(uint8(ss[2 * i + 1])));
    }
    return r;
  }

  /**
   * Concat the permission key prefix and address.
   * @param permissionPrefix The permission key prefix.
   * @param addr The address.
   * @return bytes32 The combined permissions key.
   */
  function permissionsKey(bytes12 permissionPrefix, address addr) public pure returns (bytes32) {
    return bytes32(bytes.concat(permissionPrefix, bytes20(addr)));
  }

  function _uncheckedInc(uint256 i) internal pure returns (uint256) {
    unchecked {
      return i + 1;
    }
  }

  function _uncheckedDecr(uint256 i) internal pure returns (uint256) {
    unchecked {
      return i - 1;
    }
  }
}
