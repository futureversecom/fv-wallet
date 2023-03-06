// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {Deployer} from "../src/Deployer.sol";

contract Deployment is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address admin = vm.envAddress("PUBLIC_ADDRESS");

    vm.startBroadcast(deployerPrivateKey);

    new Deployer(admin);

    vm.stopBroadcast();
  }
}
