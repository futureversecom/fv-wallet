// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./FVAccountBase.t.sol";
import {FVAccountRegistry, AccountAlreadyExists} from "../src/FVAccount2.sol";

contract FVAccountRegistry2Test is FVAccountRegistryBaseTest {

  function setUp() public override {
    fvAccountRegistry = new FVAccountRegistry();
    super.setUp();
  }

  // NOT CONSISTENT

  function testFVAccountRegistryHasNoPermissions() public override {
    bytes memory registryPermissions = FVAccountWrapper(fvAccountRegistry.fvAccountAddr()).getData(Utils.permissionsKey(address(fvAccountRegistry)));
    assertEq(registryPermissions, bytes(""));
  }

  function testFVAccountOwnerIsKeyManager() public override {
    assertEq(FVAccountWrapper(fvAccountRegistry.fvAccountAddr()).owner(), address(0));
  }

}
