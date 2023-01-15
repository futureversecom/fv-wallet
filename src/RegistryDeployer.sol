// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {FVIdentityRegistry} from "./FVIdentityRegistry.sol";
import {FVAccount} from "./FVAccount.sol";
import {FVKeyManager} from "./FVKeyManager.sol";

contract RegistryDeployer {
  event Deployed(address proxy, address registry, address keyManager);

  constructor(address admin) {
    // deploy identity registry
    address identityRegistryImpl = address(new FVIdentityRegistry());

    // deploy initializable ERC725Account (LSP0) and LSP6KeyManager contracts
    address fvAccountImpl = address(new FVAccount());
    address keyManagerImpl = address(new FVKeyManager());

    // deploy proxy with proxy admin, initialize upgradable identity registry
    address proxy = address(
      new TransparentUpgradeableProxy(
                  accountRegistryImpl,
                  admin,
                  abi.encodeWithSignature("initialize(address,address)", fvAccountImpl, keyManagerImpl)
                )
    );

    emit Deployed(proxy, identityRegistryImpl, keyManagerImpl);
  }
}
