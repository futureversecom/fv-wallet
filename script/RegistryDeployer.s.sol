// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {LSP6KeyManagerInit} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManagerInit.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/RegistryDeployer.sol";

contract Deployment is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address admin = vm.envAddress("PUBLIC_ADDRESS");

    vm.startBroadcast(deployerPrivateKey);

    new RegistryDeployer(admin);

    vm.stopBroadcast();
  }
}
