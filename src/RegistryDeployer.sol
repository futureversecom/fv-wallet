// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./FVAccountRegistry.sol";

contract RegistryDeployer {

  event Deployed(address indexed proxy, address indexed registry, address indexed keyManager);

  constructor(address admin) {

    // deploy account registry
    FVAccountRegistry accountRegistryImpl = new FVAccountRegistry();

    // deploy key manager
    LSP6KeyManagerInit keyManagerImpl = new LSP6KeyManagerInit();

    // deploy proxy with proxy admin, initialize upgradable account registry
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(accountRegistryImpl),
      admin,
      abi.encodeWithSignature("initialize(address)", address(keyManagerImpl))
    );

    emit Deployed(address(proxy), address(accountRegistryImpl), address(keyManagerImpl));
  }
}