// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./FVAccountBase.t.sol";
import {FVAccountRegistry, AccountAlreadyExists} from "../src/FVAccount3.sol";

contract FVAccount3RegistryTest is FVAccountRegistryBaseTest {

  function setUp() public override {
    fvAccountRegistry = new FVAccountRegistry();
    super.setUp();
  }

  function testFVAccountOwnerIsZeroAddress() public {
    LSP0ERC725Account fvAccount = LSP0ERC725Account(payable(fvAccountRegistry.fvAccountAddr()));
    assertEq(fvAccount.owner(),  address(0));
  }

  function testFVAccountRegistryHasNoPermissions() public {
    LSP0ERC725Account fvAccount = LSP0ERC725Account(payable(fvAccountRegistry.fvAccountAddr()));
    bytes memory registryPermissions = fvAccount.getData(Utils.permissionsKey(
      KEY_ADDRESSPERMISSIONS_PERMISSIONS,
      address(fvAccountRegistry))
    );
    assertEq(registryPermissions, bytes(""));
  }
}
