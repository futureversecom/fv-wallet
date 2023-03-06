// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {Deployer} from "../src/Deployer.sol";
import "../src/libraries/Utils.sol";

import "./helpers/GasHelper.t.sol";
import "./helpers/MockContracts.t.sol";

contract DeployerTest is Test, GasHelper {
  address private constant admin = address(0x000000000000000000000000000000000000dEaD);

  // re-declare event for assertions
  event Deployed(address proxy, address registry, address keyManager);

  function testDeployer() public {
    vm.expectEmit(false, false, false, false);
    emit Deployed(admin, admin, admin); // Values unchecked
    startMeasuringGas("Deployer deployment");
    new Deployer(admin);
    stopMeasuringGas();
  }
}
