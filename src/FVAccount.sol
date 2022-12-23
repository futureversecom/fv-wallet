// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725Account.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManager.sol";

/**
* @dev reverts when address `addr` is already registered
* @param addr the address to register
*/
error AccountAlreadyExists(address addr);

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
  function toBytes(string memory s) public pure returns (bytes memory) {
    bytes memory ss = bytes(s);
    require(ss.length%2 == 0); // length must be even
    bytes memory r = new bytes(ss.length/2);
    for (uint i=0; i<ss.length/2; ++i) {
      r[i] = bytes1(fromHexChar(uint8(ss[2*i])) * 16 + fromHexChar(uint8(ss[2*i+1])));
    }
    return r;
  }

  function permissionsKey(address _addr) public pure returns (bytes32) {
    return bytes32(toBytes(string.concat("4b80742de2bf82acb3630000", toHexStringNoPrefix(_addr))));
  }
}

contract FVAccountRegistry {
  using Utils for address;
  using Utils for string;

  // All Permissions currently exclude REENTRANCY, DELEGATECALL and SUPER_DELEGATECALL for security
  // source: https://github.com/lukso-network/lsp-smart-contracts/blob/b97b186430eb4e4984c6c366356d62119d5930cc/constants.js#L182
  string public constant ALL_PERMISSIONS = "00000000000000000000000000000000000000000000000000000000003f3f7f";
  string public constant NO_PERMISSION = "0000000000000000000000000000000000000000000000000000000000000000";

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
