// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {E2EWalletRegistry} from "./E2EWalletRegistry.sol";
import {E2EWallet} from "./E2EWallet.sol";
import {E2EWalletKeyManager} from "./E2EWalletKeyManager.sol";

contract RegistryDeployer {
  event Deployed(address proxy, address registry, address keyManager);

  constructor(address admin) {
    // deploy identity registry
    address identityRegistryImpl = address(new E2EWalletRegistry());

    // deploy initializable ERC725Account (LSP0) and LSP6KeyManager contracts
    address fvAccountImpl = address(new E2EWallet());
    address keyManagerImpl = address(new E2EWalletKeyManager());

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
