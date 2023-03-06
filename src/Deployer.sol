// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {FuturePassIdentityRegistry} from "./FuturePassIdentityRegistry.sol";
import {FuturePass} from "./FuturePass.sol";
import {FuturePassKeyManager} from "./FuturePassKeyManager.sol";

contract Deployer {
  event Deployed(address proxy, address registry, address keyManager);

  constructor(address admin) {
    // deploy registry
    address identityRegistryImpl = address(new FuturePassIdentityRegistry());

    // deploy initializable ERC725Account (LSP0) and LSP6KeyManager contracts
    address fvAccountImpl = address(new FuturePass());
    address keyManagerImpl = address(new FuturePassKeyManager());

    // deploy proxy with proxy admin, initialize upgradable identity registry
    address proxy = address(
      new TransparentUpgradeableProxy(
                  identityRegistryImpl,
                  admin,
                  abi.encodeWithSignature("initialize(address,address)", fvAccountImpl, keyManagerImpl)
                )
    );

    emit Deployed(proxy, identityRegistryImpl, keyManagerImpl);
  }
}
