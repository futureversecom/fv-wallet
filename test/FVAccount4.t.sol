// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./FVAccountBase.t.sol";
import {FVAccountRegistry, AccountAlreadyExists} from "../src/FVAccount4.sol";

contract FVAccount4RegistryTest is FVAccountRegistryBaseTest {

  address private constant admin = address(0x000000000000000000000000000000000000dEaD);

  function setUp() public override {
    // deploy upgradable contract
    FVAccountRegistry upgradableFVAccountRegistry = new FVAccountRegistry();

    // deploy proxy with dead address as proxy admin, initialize upgradable account registry
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(upgradableFVAccountRegistry),
      admin,
      abi.encodeWithSignature("initialize()")
    );

    // note: admin can call additional functions on proxy
    fvAccountRegistry = FVAccountRegistry(address(proxy)); // set proxy as fvAccountRegistry

    super.setUp();
  }

  function testFVAccountRegistryCannotBeInitializedTwice() public {
    address proxyAddress = address(fvAccountRegistry);

    // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/bc50d373e37a6250f931a5dba3847bc88e46797e/contracts/proxy/ERC1967/ERC1967Upgrade.sol#L28
    bytes32 implementationSlot = bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1);
    bytes32 implAddr = vm.load(proxyAddress, implementationSlot); // load impl address form storage

    FVAccountRegistry fvAccountRegistry = FVAccountRegistry(address(uint160(uint256(implAddr))));

    vm.expectRevert("Initializable: contract is already initialized");

    fvAccountRegistry.initialize();
  }

  // TODO: test admin upgradable functionality - by pranking as admin
}
