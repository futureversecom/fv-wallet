// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./FVAccountBase.t.sol";
import {FVAccountRegistry, AccountAlreadyExists} from "../src/FVAccount1.sol";

contract FVAccountRegistry1Test is FVAccountRegistryBaseTest {

  function setUp() public override {
    fvAccountRegistry = new FVAccountRegistry();
    super.setUp();
  }

  function testFVAccountRegistryHasNoPermissions() public virtual {
    LSP0ERC725Account fvAccount = LSP0ERC725Account(payable(fvAccountRegistry.fvAccountAddr()));
    bytes memory registryPermissions = fvAccount.getData(Utils.permissionsKey(address(fvAccountRegistry)));
    assertEq(registryPermissions, Utils.toBytes(NO_PERMISSION));
  }

  function testFVAccountOwnerIsKeyManager() public virtual {
    LSP0ERC725Account fvAccount = LSP0ERC725Account(payable(fvAccountRegistry.fvAccountAddr()));
    assertEq(fvAccount.owner(), fvAccountRegistry.fvKeyManagerAddr());
  }

}
