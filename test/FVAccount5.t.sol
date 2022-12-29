// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./FVAccountBase.t.sol";
import "../src/LSP0ERC725AccountLateInit.sol";
import {FVAccountRegistry} from "../src/FVAccount5.sol";

contract FVAccount5RegistryTest is FVAccountRegistryBaseTest {

  function setUp() public override {
    fvAccountRegistry = new FVAccountRegistry();
    super.setUp();
  }

  // overridden as `initialize` does not exist on this implementation
  function testFVAccountImplCannotBeInitializedTwice() public override {
    LSP0ERC725AccountLateInit fvAccount = LSP0ERC725AccountLateInit(payable(fvAccountRegistry.fvAccountAddr()));

    vm.expectRevert("Initializable: contract is already initialized");

    fvAccount.initializeWithData(address(this), bytes32(""), bytes(""));
  }
}
