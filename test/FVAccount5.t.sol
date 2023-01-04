// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725Account.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManager.sol";

import "./FVAccountBase.t.sol";
import "./helpers/DataHelper.t.sol";
import "../src/LSP0ERC725AccountLateInit.sol";
import {FVAccountRegistry} from "../src/FVAccount5.sol";

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

  function testRegisterOfZeroAddress() public override {
    vm.expectEmit(true, true, false, false, address(fvAccountRegistry)); // ignore 2nd param of event (not deterministic)

    address proxyKeyManager = FVAccountRegistry(address(fvAccountRegistry)).predictProxyWalletKeyManagerAddress(address(0));

    // We emit the event we expect to see.
    emit AccountRegistered(address(0), proxyKeyManager);

    // Perform the actual call (which should emit expected event).
    fvAccountRegistry.register(address(0));
  }

  function testRegisterOfNewAddressSucceeds() public override {
    vm.expectEmit(true, true, false, false, address(fvAccountRegistry)); // ignore 2nd param of event (not deterministic)

    address proxyKeyManager = FVAccountRegistry(address(fvAccountRegistry)).predictProxyWalletKeyManagerAddress(address(this));

    emit AccountRegistered(address(this), proxyKeyManager);

    startMeasuringGas("fvAccountRegistry.register(address(this)) success");
    address userKeyManagerAddr = fvAccountRegistry.register(address(this));
    stopMeasuringGas();
    assertTrue(userKeyManagerAddr != address(0));

    assertEq(fvAccountRegistry.identityOf(address(this)), userKeyManagerAddr); 
  }

  // overridden as `initialize` does not exist on this implementation
  function testFVAccountImplCannotBeInitializedTwice() public override {
    LSP0ERC725AccountLateInit fvAccount = LSP0ERC725AccountLateInit(payable(fvAccountRegistry.fvAccountAddr()));

    vm.expectRevert("Initializable: contract is already initialized");

    fvAccount.initialize(address(this), bytes32(""), bytes(""));
  }

  function testFVAccountRegistryCannotBeInitializedTwice() public {
    address proxyAddress = address(fvAccountRegistry);

    // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/bc50d373e37a6250f931a5dba3847bc88e46797e/contracts/proxy/ERC1967/ERC1967Upgrade.sol#L28
    bytes32 implementationSlot = bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1);
    bytes32 implAddr = vm.load(proxyAddress, implementationSlot); // load impl address from storage

    FVAccountRegistry fvAccountRegistry = FVAccountRegistry(address(uint160(uint256(implAddr))));

    vm.expectRevert("Initializable: contract is already initialized");

    fvAccountRegistry.initialize();
  }

  function testUpgradingKeyManagerImplFailsAsNonAdmin() public {
    // create a clone of the key manager
    address keyManagerv2 = Clones.clone(fvAccountRegistry.fvKeyManagerAddr());

    // update the impl of the beacon fails externally (not owner)
    UpgradeableBeacon keyManagerBeacon = FVAccountRegistry(address(fvAccountRegistry)).fvKeyManagerBeacon();
    vm.expectRevert("Ownable: caller is not the owner");
    keyManagerBeacon.upgradeTo(keyManagerv2);

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    vm.startPrank(userAddr);

    // update the impl of the beacon fails internally (not owner)
    vm.expectRevert("Ownable: caller is not the owner");
    FVAccountRegistry(address(fvAccountRegistry)).upgradeFVKeyManager(keyManagerv2);
  }

  function testUpgradingKeyManagerImplSucceedsAsAdmin() public {
    // register a user
    address userKeyManager = fvAccountRegistry.register(address(this));

    // create a clone of the key manager
    address keyManagerv2 = Clones.clone(fvAccountRegistry.fvKeyManagerAddr());

    // update the impl of the beacon succeeds
    UpgradeableBeacon keyManagerBeacon = FVAccountRegistry(address(fvAccountRegistry)).fvKeyManagerBeacon();
    vm.expectEmit(true, false, false, false, address(keyManagerBeacon));
    emit Upgraded(keyManagerv2);
    FVAccountRegistry(address(fvAccountRegistry)).upgradeFVKeyManager(keyManagerv2);

    // validate user key manager impl is updated
    bytes32 beaconSlot = bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1);
    bytes32 implAddr = vm.load(userKeyManager, beaconSlot); // load beacon address from storage
    assertEq(address(uint160(uint256(implAddr))), address(keyManagerBeacon));

    // validate that the beacon impl address is updated (also implying that the user key manager impl is updated)
    assertEq(keyManagerBeacon.implementation(), keyManagerv2);
  }

  function testUpgradingFVAccountImplFailsAsNonAdmin() public {
    // create a clone of the account
    address fvAccountv2 = Clones.clone(fvAccountRegistry.fvAccountAddr());

    // update the impl of the beacon fails externally (not owner)
    UpgradeableBeacon fvAccountBeacon = FVAccountRegistry(address(fvAccountRegistry)).fvAccountBeacon();
    vm.expectRevert("Ownable: caller is not the owner");
    fvAccountBeacon.upgradeTo(fvAccountv2);

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    vm.startPrank(userAddr);

    // update the impl of the beacon fails internally (not owner)
    vm.expectRevert("Ownable: caller is not the owner");
    FVAccountRegistry(address(fvAccountRegistry)).upgradeFVAccount(fvAccountv2);
  }

  function testUpgradingFVAccountImplSucceedsAsAdmin() public {
    // register a user
    address userFVAccountProxy = address(payable(LSP6KeyManager(fvAccountRegistry.register(address(this))).target()));

    // create a clone of the account
    address fvAccountv2 = Clones.clone(fvAccountRegistry.fvAccountAddr());

    // update the impl of the beacon succeeds
    UpgradeableBeacon fvAccountBeacon = FVAccountRegistry(address(fvAccountRegistry)).fvAccountBeacon();
    vm.expectEmit(true, false, false, false, address(fvAccountBeacon));
    emit Upgraded(fvAccountv2);
    FVAccountRegistry(address(fvAccountRegistry)).upgradeFVAccount(fvAccountv2);

    // validate user account impl is updated
    bytes32 beaconSlot = bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1);
    bytes32 implAddr = vm.load(userFVAccountProxy, beaconSlot); // load beacon address from storage
    assertEq(address(uint160(uint256(implAddr))), address(fvAccountBeacon));

    // validate that the beacon impl address is updated (also implying that the user account impl is updated)
    assertEq(fvAccountBeacon.implementation(), fvAccountv2);
  }

  // TODO: test admin upgradable functionality - by pranking as admin
}
