// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./FVAccountBase.t.sol";
import {FVAccountRegistry, AccountAlreadyExists} from "../src/FVAccount1.sol";

contract FVAccountRegistry1Test is FVAccountRegistryBaseTest {

  function setUp() public override {
    fvAccountRegistry = new FVAccountRegistry();
    super.setUp();
  }

  function testFVAccountRegistryHasNoPermissions() public override {
    LSP0ERC725Account fvAccount = LSP0ERC725Account(payable(fvAccountRegistry.fvAccountAddr()));
    bytes memory registryPermissions = fvAccount.getData(
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, address(fvAccountRegistry))
    );
    assertEq(registryPermissions, Utils.toBytes(NO_PERMISSION));
  }

  function testFVAccountOwnerIsKeyManager() public {
    LSP0ERC725Account fvAccount = LSP0ERC725Account(payable(fvAccountRegistry.fvAccountAddr()));
    assertEq(fvAccount.owner(), fvAccountRegistry.fvKeyManagerAddr());
  }

  // not relevant for FVAccount1 - since KeyManager is always account owner
  function testFVAccountOwnerIsZeroAddress() public override {}

  // not relevant for FVAccount1
  function testFVAccountImplCannotBeInitializedTwice() public override {}

  // not relevant for FVAccount1
  function testFVKeyManagerImplCannotBeInitializedTwice() public override {}

}
