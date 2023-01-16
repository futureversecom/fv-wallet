// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {RegistryDeployer} from "../src/RegistryDeployer.sol";
import "../src/Utils.sol";

import "./helpers/GasHelper.t.sol";
import "./helpers/MockContracts.t.sol";

contract RegistryDeployerTest is Test, GasHelper {
  address private constant admin = address(0x000000000000000000000000000000000000dEaD);

  // re-declare event for assertions
  event Deployed(address proxy, address registry, address keyManager);

  function testDeployer() public {
    vm.expectEmit(false, false, false, false);
    emit Deployed(admin, admin, admin); // Values unchecked
    startMeasuringGas("RegistryDeployer deployment");
    new RegistryDeployer(admin);
    stopMeasuringGas();
  }
}
