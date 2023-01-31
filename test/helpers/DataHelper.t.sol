// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {VmSafe} from "forge-std/Vm.sol";
import {EIP191Signer} from "@lukso/lsp-smart-contracts/contracts/Custom/EIP191Signer.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6Constants.sol";

import "../../src/libraries/Utils.sol";

import "./MockContracts.t.sol";

contract DataHelper {
  using ECDSA for bytes32;

  // Construct call data for calling mint on the mockERC20
  function createERC20ExecuteDataForCall(MockERC20 _mockERC20) internal pure returns (bytes memory) {
    // abi encoded call to mint 100 tokens to the caller
    bytes memory mintCall = abi.encodeWithSelector(_mockERC20.mintCaller.selector, 100);
    // abi encoded call to execute mint call
    bytes memory executeCall = abi.encodeWithSignature(
      "execute(uint256,address,uint256,bytes)", // operationType, target, value, data
      0, // CALL
      address(_mockERC20),
      0,
      mintCall
    );

    return executeCall;
  }

  // Construct call data for creating a new contract (minimal proxy)
  function createMockERC20ExecuteData() internal pure returns (bytes memory) {
    // abi encoded call to create a new contract
    return abi.encodeWithSignature(
      "execute(uint256,address,uint256,bytes)", // operationType, target, value, data
      1, // CREATE
      address(0), // ignored for create
      0,
      abi.encodePacked(type(MockERC20).creationCode) // bytecode with constructor
    );
  }

  // Construct call data for creating a new contract (minimal proxy)
  function create2MockERC20ExecuteData() internal pure returns (bytes memory) {
    bytes memory bytecodeWithConstructorAndSalt = abi.encodePacked(
      type(MockERC20).creationCode,
      bytes32(0x0) // salt
    );

    // abi encoded call to create a new contract
    bytes memory executeCall = abi.encodeWithSignature(
      "execute(uint256,address,uint256,bytes)", // operationType, target, value, data
      2, // CREATE
      address(0), // ignored for create
      0,
      bytecodeWithConstructorAndSalt
    );

    return executeCall;
  }

  /**
   * Create permission data for whitelisting all calls to given address.
   * @param addrs The addresses to whitelist.
   * @return allowedCalls The data to set to allow access to given addresses.
   * @notice This method whitelists all interfaces and methods.
   * @dev Include user's existing permissions when constructing this list so they are not overridden.
   */
  function createCallContractWhitelistData(address[] memory addrs) public pure returns (bytes memory allowedCalls) {
    // Create compact bytes array for permission data
    for (uint256 i = 0; i < addrs.length; i++) {
      bytes[] memory newElement = new bytes[](3);
      newElement[0] = abi.encodePacked(bytes4(0xffffffff)); // All interfaces
      newElement[1] = abi.encodePacked(addrs[i]);
      newElement[2] = abi.encodePacked(bytes4(0xffffffff)); // All methods
      bytes memory newAllowedCalls = generateCompactByteArrayElement(newElement);
      allowedCalls = bytes.concat(allowedCalls, newAllowedCalls);
    }
    return allowedCalls;
  }

  // https://github.com/lukso-network/lsp-smart-contracts/blob/5f4b9a7b2e224f1536be8d5164f58b57016cafcd/tests/foundry/GasTests/UniversalProfileTestsHelper.sol#L51
  function generateCompactByteArrayElement(bytes[] memory data)
    public
    pure
    returns (bytes memory)
  {
    uint256 totalLength = 0;
    bytes memory concatenatedBytes = new bytes(0);
    for (uint256 i = 0; i < data.length; i++) {
      totalLength += data[i].length;
      concatenatedBytes = bytes.concat(concatenatedBytes, data[i]);
    }

    //check that the total length is less than 256
    require(totalLength < type(uint16).max, "DataHelper: CBA Element too big");

    return bytes.concat(bytes2(uint16(totalLength)), concatenatedBytes);
  }

  function signForRelayCall(
    bytes memory payload,
    uint256 nonce,
    uint256 msgValue,
    uint256 pk,
    VmSafe vm,
    address validator
  )
    internal
    view
    returns (bytes memory)
  {
    bytes memory encodedMessage = abi.encodePacked(LSP6_VERSION, block.chainid, nonce, msgValue, payload);
    return sign(EIP191Signer.toDataWithIntendedValidator(validator, encodedMessage), pk, vm);
  }

  function sign(bytes32 data, uint256 pk, VmSafe vm) internal pure returns (bytes memory) {
    bytes32 r;
    bytes32 s;
    uint8 v;
    (v, r, s) = vm.sign(pk, data);
    return abi.encodePacked(r, s, v);
  }

  function bytesToAddress(bytes memory bys) public pure returns (address addr) {
    assembly {
      addr := mload(add(bys, 0x14))
    }
  }
}
