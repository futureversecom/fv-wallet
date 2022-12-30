// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

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

    address proxyFVWallet = DataHelper.predictProxyWalletAddress(
      address(fvAccountRegistry),
      address(FVAccountRegistry(address(fvAccountRegistry)).fvAccountBeacon()),
      address(0)
    );

    // TODO: maybe there is an easier way to get this - via proxy owner?
    address proxyKeyManager = DataHelper.predictProxyWalletKeyManagerAddress(
      address(fvAccountRegistry),
      address(FVAccountRegistry(address(fvAccountRegistry)).fvKeyManagerBeacon()),
      proxyFVWallet,
      address(0)
    );

    // We emit the event we expect to see.
    emit AccountRegistered(address(0), proxyKeyManager);

    // Perform the actual call (which should emit expected event).
    fvAccountRegistry.register(address(0));
  }

  function testRegisterOfNewAddressSucceeds() public override {
    vm.expectEmit(true, true, false, false, address(fvAccountRegistry)); // ignore 2nd param of event (not deterministic)

    address proxyFVWallet = DataHelper.predictProxyWalletAddress(
      address(fvAccountRegistry),
      address(FVAccountRegistry(address(fvAccountRegistry)).fvAccountBeacon()),
      address(this)
    );

    // TODO: maybe there is an easier way to get this - via proxy owner?
    address proxyKeyManager = DataHelper.predictProxyWalletKeyManagerAddress(
      address(fvAccountRegistry),
      address(FVAccountRegistry(address(fvAccountRegistry)).fvKeyManagerBeacon()),
      proxyFVWallet,
      address(this)
    );

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
    bytes32 implAddr = vm.load(proxyAddress, implementationSlot); // load impl address form storage

    FVAccountRegistry fvAccountRegistry = FVAccountRegistry(address(uint160(uint256(implAddr))));

    vm.expectRevert("Initializable: contract is already initialized");

    fvAccountRegistry.initialize();
  }

  // TODO: test admin upgradable functionality - by pranking as admin
}
