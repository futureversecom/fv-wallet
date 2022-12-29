// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./FVAccountBase.t.sol";
import {FVAccountRegistry, AccountAlreadyExists} from "../src/FVAccount3.sol";

contract FVAccount3RegistryTest is FVAccountRegistryBaseTest {

  function setUp() public override {
    fvAccountRegistry = new FVAccountRegistry();
    super.setUp();
  }

}
