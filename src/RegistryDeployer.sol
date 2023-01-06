// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {LSP6KeyManagerInit} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManagerInit.sol";
import "./FVAccountRegistry.sol";

contract RegistryDeployer {
  event Deployed(address proxy, address registry, address keyManager);

  constructor(address admin) {
    // deploy account registry
    address accountRegistryImpl = address(new FVAccountRegistry());

    // deploy key manager
    address keyManagerImpl = address(new LSP6KeyManagerInit());

    // deploy proxy with proxy admin, initialize upgradable account registry
    address proxy = address(
      new TransparentUpgradeableProxy(
                  accountRegistryImpl,
                  admin,
                  abi.encodeWithSignature("initialize(address)", keyManagerImpl)
                )
    );

    emit Deployed(proxy, accountRegistryImpl, keyManagerImpl);
  }
}
