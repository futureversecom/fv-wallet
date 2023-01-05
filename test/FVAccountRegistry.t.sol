// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {IERC725X} from "@erc725/smart-contracts/contracts/interfaces/IERC725X.sol";
import {IERC725Y} from "@erc725/smart-contracts/contracts/interfaces/IERC725Y.sol";
import {LSP0ERC725Account} from "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725Account.sol";
import {LSP0ERC725AccountInit} from "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725AccountInit.sol";
import {ILSP1UniversalReceiver} from
  "@lukso/lsp-smart-contracts/contracts/LSP1UniversalReceiver/ILSP1UniversalReceiver.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6Constants.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6Errors.sol";
import {ILSP6KeyManager} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/ILSP6KeyManager.sol";
import {LSP6KeyManagerInit} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManagerInit.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IFVAccountRegistry} from "../src/IFVAccountRegistry.sol";
import {FVAccountRegistry} from "../src/FVAccountRegistry.sol";
import "../src/Utils.sol";

import "./helpers/GasHelper.t.sol";
import "./helpers/DataHelper.t.sol";
import "./helpers/MockContracts.t.sol";

contract FVAccountRegistryBaseTest is Test, GasHelper, DataHelper {
  address private constant admin = address(0x000000000000000000000000000000000000dEaD);
  address private constant gameAddr = address(0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045);

  IFVAccountRegistry public fvAccountRegistry;
  IFVAccountRegistry private registryImpl;
  LSP6KeyManagerInit private keyManagerImpl;
  MockERC20 public mockERC20;

  // Random key. DO NOT USE IN A PRODUCTION ENVIRONMENT
  uint256 private pk = 0xabfa816b2d044fca73f609721c7811b3876e69f915a5398bdb88b3ce5bf28a61;
  address private pkAddr;

  // re-declare event for assertions
  event AccountRegistered(address indexed account, address indexed wallet);
  event ContractCreated(
    uint256 indexed operationType, address indexed contractAddress, uint256 indexed value, bytes32 salt
  );
  event Upgraded(address indexed implementation);
  event AdminChanged(address previousAdmin, address newAdmin);

  constructor() {
    pkAddr = vm.addr(pk);
  }

  function setUp() public {
    mockERC20 = new MockERC20();

    // deploy upgradable contract
    registryImpl = new FVAccountRegistry();

    // deploy key manager implementation
    keyManagerImpl = new LSP6KeyManagerInit();

    // deploy proxy with dead address as proxy admin, initialize upgradable account registry
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(registryImpl),
      admin,
      abi.encodeWithSignature("initialize(address)", address(keyManagerImpl))
    );

    // note: admin can call additional functions on proxy
    fvAccountRegistry = FVAccountRegistry(address(proxy)); // set proxy as fvAccountRegistry
  }

  //
  // Interfaces
  //
  function testKeyManagerInterfaces() public {
    IERC165 userKeyManager = IERC165(fvAccountRegistry.register(address(0)));

    assertTrue(userKeyManager.supportsInterface(type(IERC165).interfaceId), "ERC165 support");
    assertTrue(userKeyManager.supportsInterface(type(IERC1271).interfaceId), "ERC1271 support");
    assertTrue(userKeyManager.supportsInterface(type(ILSP6KeyManager).interfaceId), "LSP6 support");
  }

  function testAccountInterfaces() public {
    address userKeyManager = fvAccountRegistry.register(address(0));
    IERC165 userFVWalletProxy = IERC165(ILSP6KeyManager(userKeyManager).target());

    assertTrue(userFVWalletProxy.supportsInterface(type(IERC165).interfaceId), "ERC165 support");
    assertTrue(userFVWalletProxy.supportsInterface(type(IERC1271).interfaceId), "ERC1271 support");
    assertTrue(userFVWalletProxy.supportsInterface(type(ILSP1UniversalReceiver).interfaceId), "LSP1 support");
    assertTrue(userFVWalletProxy.supportsInterface(type(IERC725X).interfaceId), "ERC725X support");
    assertTrue(userFVWalletProxy.supportsInterface(type(IERC725Y).interfaceId), "ERC725Y support");
  }

  //
  // Initialising
  //
  function testFVAccountImplCannotBeInitializedTwice() public {
    LSP0ERC725AccountLateInit fvAccount = LSP0ERC725AccountLateInit(payable(fvAccountRegistry.fvAccountAddr()));

    vm.expectRevert("Initializable: contract is already initialized");

    fvAccount.initialize(address(this), bytes32(""), bytes(""));
  }

  function testFVKeyManagerImplCannotBeInitializedTwice() public {
    LSP6KeyManagerInit fvKeyManager = LSP6KeyManagerInit(payable(fvAccountRegistry.fvKeyManagerAddr()));

    vm.expectRevert("Initializable: contract is already initialized");

    fvKeyManager.initialize(address(this));
  }

  function testFVAccountOwnerIsZeroAddress() public {
    LSP0ERC725Account fvAccount = LSP0ERC725Account(payable(fvAccountRegistry.fvAccountAddr()));
    assertEq(fvAccount.owner(), address(0));
  }

  function testFVAccountRegistryIsNotFVAccountOwner() public {
    LSP0ERC725Account fvAccount = LSP0ERC725Account(payable(fvAccountRegistry.fvAccountAddr()));
    assertFalse(fvAccount.owner() == address(fvAccountRegistry));
  }

  function testFVAccountRegistryHasNoPermissions() public {
    LSP0ERC725Account fvAccount = LSP0ERC725Account(payable(fvAccountRegistry.fvAccountAddr()));
    bytes memory registryPermissions =
      fvAccount.getData(Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, address(fvAccountRegistry)));
    assertEq(registryPermissions, bytes(""));
  }

  //
  // Register
  //
  function testRegisterOfZeroAddress() public {
    vm.expectEmit(true, true, false, false, address(fvAccountRegistry)); // ignore 2nd param of event (not deterministic)

    address proxyKeyManager =
      IFVAccountRegistry(address(fvAccountRegistry)).predictProxyWalletKeyManagerAddress(address(0));

    // We emit the event we expect to see.
    emit AccountRegistered(address(0), proxyKeyManager);

    // Perform the actual call (which should emit expected event).
    fvAccountRegistry.register(address(0));
  }

  function testRegisterOfNewAddressSucceeds() public {
    vm.expectEmit(true, true, false, false, address(fvAccountRegistry)); // ignore 2nd param of event (not deterministic)

    address proxyKeyManager =
      IFVAccountRegistry(address(fvAccountRegistry)).predictProxyWalletKeyManagerAddress(address(this));

    emit AccountRegistered(address(this), proxyKeyManager);

    startMeasuringGas("fvAccountRegistry.register(address(this)) success");
    address userKeyManagerAddr = fvAccountRegistry.register(address(this));
    stopMeasuringGas();
    assertTrue(userKeyManagerAddr != address(0));

    assertEq(fvAccountRegistry.identityOf(address(this)), userKeyManagerAddr);
  }

  function testRegisterFailsForMultipleRegistrations() public {
    fvAccountRegistry.register(address(this));
    vm.expectRevert(abi.encodeWithSelector(AccountAlreadyExists.selector, address(this)));
    startMeasuringGas("fvAccountRegistry.register(address(this)) fail second acc");
    fvAccountRegistry.register(address(this));
    stopMeasuringGas();
  }

  function testRegisteredUserCanCallExternalContract() public {
    address userKeyManagerAddr = fvAccountRegistry.register(address(this));

    // abi encoded call to mint 100 tokens to address(this)
    bytes memory mintCall = abi.encodeWithSelector(mockERC20.mint.selector, address(this), 100);

    // abi encoded call to execute mint call
    bytes memory executeCall = abi.encodeWithSignature(
      "execute(uint256,address,uint256,bytes)", // operationType, target, value, data
      0,
      address(mockERC20),
      0,
      mintCall
    );
    ILSP6KeyManager(userKeyManagerAddr).execute(executeCall);

    assertEq(mockERC20.balanceOf(address(this)), 100);
  }

  //
  // Test CALL permissions
  //
  function testCallUnauthedExternalAccountFails() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));

    vm.prank(gameAddr);
    vm.expectRevert(abi.encodeWithSelector(NoPermissionsSet.selector, gameAddr));
    userKeyManager.execute(createERC20ExecuteDataForCall(mockERC20));
  }

  function testCallAuthedExternalAccounWrongContractFails() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));

    // Give call permission
    bytes memory execData = abi.encodeWithSelector(
      bytes4(keccak256("setData(bytes32,bytes)")),
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, gameAddr), // AddressPermissions:Permissions
      Utils.toBytes(_PERMISSION_CALL) // Call only
    );
    startMeasuringGas("userKeyManager.execute() add call permission");
    userKeyManager.execute(execData);
    stopMeasuringGas();
    // Give allowed calls permissions to wrong contract
    address[] memory allowed = new address[](1);
    allowed[0] = gameAddr;
    execData = abi.encodeWithSelector(
      bytes4(keccak256("setData(bytes32,bytes)")),
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS, gameAddr), // AddressPermissions:AllowedCalls
      createCallContractWhitelistData(allowed)
    );
    startMeasuringGas("userKeyManager.execute() add call contract permission");
    userKeyManager.execute(execData);
    stopMeasuringGas();

    vm.prank(gameAddr);
    vm.expectRevert(
      abi.encodeWithSelector(NotAllowedCall.selector, gameAddr, address(mockERC20), mockERC20.mint.selector)
    );
    userKeyManager.execute(createERC20ExecuteDataForCall(mockERC20));
  }

  function testCallAuthedExternalAccountSingleContract() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));

    // Give call permission
    bytes memory execData = abi.encodeWithSelector(
      bytes4(keccak256("setData(bytes32,bytes)")),
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, gameAddr), // AddressPermissions:Permissions
      Utils.toBytes(_PERMISSION_CALL) // Call only
    );
    userKeyManager.execute(execData);
    // Give allowed calls permissions to erc20
    address[] memory allowed = new address[](1);
    allowed[0] = address(mockERC20);
    execData = abi.encodeWithSelector(
      bytes4(keccak256("setData(bytes32,bytes)")),
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS, gameAddr), // AddressPermissions:AllowedCalls
      createCallContractWhitelistData(allowed)
    );
    userKeyManager.execute(execData);

    vm.prank(gameAddr);
    startMeasuringGas("userKeyManager.execute() call erc20 mint");
    userKeyManager.execute(createERC20ExecuteDataForCall(mockERC20));
    stopMeasuringGas();

    assertEq(mockERC20.balanceOf(address(this)), 100);
  }

  function testCallAuthedExternalAccountMultipleContract() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));
    MockERC20 mockERC20B = new MockERC20();

    // Give call permission
    bytes memory execData = abi.encodeWithSelector(
      bytes4(keccak256("setData(bytes32,bytes)")),
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, gameAddr), // AddressPermissions:Permissions
      Utils.toBytes(_PERMISSION_CALL) // Call only
    );
    userKeyManager.execute(execData);
    // Give allowed calls permissions
    address[] memory allowed = new address[](1);
    allowed[0] = address(mockERC20);
    execData = abi.encodeWithSelector(
      bytes4(keccak256("setData(bytes32,bytes)")),
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS, gameAddr), // AddressPermissions:AllowedCalls
      createCallContractWhitelistData(allowed)
    );
    userKeyManager.execute(execData);

    vm.prank(gameAddr);
    startMeasuringGas("userKeyManager.execute() call erc20 mint");
    userKeyManager.execute(createERC20ExecuteDataForCall(mockERC20));
    stopMeasuringGas();
    startMeasuringGas("userKeyManager.execute() call erc20 mint b");
    userKeyManager.execute(createERC20ExecuteDataForCall(mockERC20B));
    stopMeasuringGas();

    assertEq(mockERC20.balanceOf(address(this)), 100);
    assertEq(mockERC20B.balanceOf(address(this)), 100);
  }

  //
  // Test CREATE permissions
  //
  function testCreateUnauthedExternalAccountFails() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    vm.prank(userAddr);

    vm.expectRevert(abi.encodeWithSelector(NoPermissionsSet.selector, userAddr));
    userKeyManager.execute(createMockERC20ExecuteData());
  }

  function testCreateAuthedExternalAccountSingleContract() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    // Give user CREATE permission
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, userAddr), // AddressPermissions:Permissions
        Utils.toBytes(_PERMISSION_DEPLOY) // CREATE/CREATE2 only
      )
    );

    // Give allowed calls permissions to erc20
    address userFVWalletProxy = userKeyManager.target();

    vm.prank(userAddr);

    vm.expectEmit(true, false, true, true, userFVWalletProxy);
    emit ContractCreated(1, address(0), 0, bytes32(0));

    bytes memory data = userKeyManager.execute(createMockERC20ExecuteData());

    address addr = bytesToAddress(data);
    assertTrue(addr != address(0));

    // test minting on created address
    MockERC20(addr).mint(address(this), 100);
    assertEq(MockERC20(addr).balanceOf(address(this)), 100);
  }

  //
  // Test CREATE2 permissions
  //
  function testCreate2UnauthedExternalAccountFails() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    vm.prank(userAddr);

    vm.expectRevert(abi.encodeWithSelector(NoPermissionsSet.selector, userAddr));
    userKeyManager.execute(create2MockERC20ExecuteData());
  }

  function testCreate2AuthedExternalAccountSingleContract() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    // Give user CREATE permission
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, userAddr), // AddressPermissions:Permissions
        Utils.toBytes(_PERMISSION_DEPLOY) // CREATE/CREATE2 only
      )
    );

    // Give allowed calls permissions to erc20
    address userFVWalletProxy = userKeyManager.target();

    vm.prank(userAddr);

    vm.expectEmit(true, false, true, true, userFVWalletProxy);
    emit ContractCreated(2, address(0), 0, bytes32(0));

    bytes memory data = userKeyManager.execute(create2MockERC20ExecuteData());

    address addr = bytesToAddress(data);
    assertTrue(addr != address(0));

    // test minting on created address
    MockERC20(addr).mint(address(this), 100);
    assertEq(MockERC20(addr).balanceOf(address(this)), 100);
  }

  //
  // Test STATICCALL permissions
  //
  function testStaticCallUnauthedExternalAccountFails() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    vm.prank(userAddr);

    vm.expectRevert(abi.encodeWithSelector(NoPermissionsSet.selector, userAddr));
    userKeyManager.execute(
      abi.encodeWithSignature(
        "execute(uint256,address,uint256,bytes)", // operationType, target, value, data
        3, // STATICCALL
        address(mockERC20),
        0,
        abi.encodeWithSignature("balanceOf(address)", address(this))
      )
    );
  }

  function testStaticCallAuthedExternalAccountSingleContract() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    // Give user STATICCALL permission
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, userAddr), // AddressPermissions:Permissions
        Utils.toBytes(_PERMISSION_STATICCALL) // STATICCALL only
      )
    );

    // Give allowed calls permissions to erc20
    address[] memory allowed = new address[](1);
    allowed[0] = address(mockERC20);
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS, userAddr), // AddressPermissions:AllowedCalls
        createCallContractWhitelistData(allowed)
      )
    );

    // mint some tokens (for testing)
    mockERC20.mint(address(this), 150);

    vm.prank(userAddr);

    bytes memory data = userKeyManager.execute(
      abi.encodeWithSignature(
        "execute(uint256,address,uint256,bytes)", // operationType, target, value, data
        3, // STATICCALL
        address(mockERC20),
        0,
        abi.encodeWithSignature("balanceOf(address)", address(this))
      )
    );
    uint256 gotAmount = abi.decode(data, (uint256));
    assertEq(gotAmount, 150);
  }

  //
  // Test DELEGATECALL permissions
  //
  function testDelegateCallUnauthedExternalAccountFails() public {
    DelegateAttacker delegated = new DelegateAttacker();

    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    vm.prank(userAddr);

    vm.expectRevert(abi.encodeWithSelector(NoPermissionsSet.selector, userAddr));
    userKeyManager.execute(
      abi.encodeWithSignature(
        "execute(uint256,address,uint256,bytes)", // operationType, target, value, data
        4, // DELEGATECALL
        address(delegated),
        0,
        abi.encodeWithSignature("balance()")
      )
    );
  }

  function testDelegateCallFailsOnKeyManager() public {
    DelegateAttacker delegated = new DelegateAttacker();
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    // Give user DELEGATECALL permission
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, userAddr), // AddressPermissions:Permissions
        Utils.toBytes(_PERMISSION_DELEGATECALL) // DELEGATECALL only
      )
    );

    // Give allowed calls permissions to erc20
    address[] memory allowed = new address[](1);
    allowed[0] = address(delegated);
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS, userAddr), // AddressPermissions:AllowedCalls
        createCallContractWhitelistData(allowed)
      )
    );

    vm.prank(userAddr);

    vm.expectRevert(abi.encodeWithSelector(DelegateCallDisallowedViaKeyManager.selector));
    userKeyManager.execute(
      abi.encodeWithSignature(
        "execute(uint256,address,uint256,bytes)", // operationType, target, value, data
        4, // DELEGATECALL
        address(delegated),
        0,
        abi.encodeWithSignature("balance()")
      )
    );
  }

  //
  // Test CALL permissions using relay
  //
  function testCallRelay() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(pkAddr));

    bytes memory payload = createERC20ExecuteDataForCall(mockERC20);
    bytes memory signature = signForRelayCall(payload, 0, 0, pk, vm, address(userKeyManager));

    startMeasuringGas("userKeyManager.execute() call erc20 mint");
    userKeyManager.executeRelayCall(signature, 0, payload);
    stopMeasuringGas();

    assertEq(mockERC20.balanceOf(address(this)), 100);
  }

  function testFVAccountRegistryCannotBeInitializedTwice() public {
    address proxyAddress = address(fvAccountRegistry);

    // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/bc50d373e37a6250f931a5dba3847bc88e46797e/contracts/proxy/ERC1967/ERC1967Upgrade.sol#L28
    bytes32 implementationSlot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 implAddr = vm.load(proxyAddress, implementationSlot); // load impl address from storage

    FVAccountRegistry registry = FVAccountRegistry(address(uint160(uint256(implAddr))));

    vm.expectRevert("Initializable: contract is already initialized");

    registry.initialize(keyManagerImpl);
  }

  //
  // FVAccountRegistry Transparent Proxy tests
  //
  function testNonAdminCannotCallAdminFunctionsOnFVAccountRegistryTransparentProxy() public {
    // ensure non-admin cannot call TransparentProxy functions
    TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(fvAccountRegistry)));

    vm.expectRevert();
    proxy.admin();

    vm.expectRevert();
    proxy.implementation();

    vm.expectRevert();
    proxy.changeAdmin(address(this));

    vm.expectRevert();
    proxy.upgradeTo(address(this));

    vm.expectRevert();
    proxy.upgradeToAndCall(address(this), "");
  }

  function testAdminCanCallAdminFunctionsOnFVAccountRegistryTransparentProxy() public {
    TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(fvAccountRegistry)));

    vm.startPrank(admin);

    assertEq(proxy.admin(), admin);

    assertEq(proxy.implementation(), address(registryImpl));

    vm.expectEmit(true, true, false, false, address(proxy));
    emit AdminChanged(admin, address(this));
    proxy.changeAdmin(address(this));

    vm.stopPrank(); // admin updated, stop prank

    // upgrade fails if not a contract
    vm.expectRevert("ERC1967: new implementation is not a contract");
    proxy.upgradeTo(address(admin));

    // create a copy of the account registry impl (not the proxy) - for testing upgradability
    address fvAccountRegistryV2 = Clones.clone(address(registryImpl));
    vm.expectEmit(true, false, false, false, address(proxy));
    emit Upgraded(fvAccountRegistryV2);
    proxy.upgradeTo(fvAccountRegistryV2);

    // create a copy of the account registry impl (not the proxy) - for testing upgradability with call
    address fvAccountRegistryV3 = Clones.clone(address(registryImpl));
    // re-initialize fails as already initialized (state saved in proxy), future contracts must use
    // `reinitializer(version)` modifier on `initialize` function
    vm.expectRevert("Initializable: contract is already initialized");
    proxy.upgradeToAndCall(fvAccountRegistryV3, abi.encodeWithSignature("initialize(address)", address(keyManagerImpl)));

    // can successfully re-initialize if upgraded contract has `reinitializer(version)` modifier on `initialize` function
    address initializableMock = address(new UpgradedMock());
    vm.expectEmit(true, false, false, false, address(proxy));
    emit Upgraded(initializableMock);
    proxy.upgradeToAndCall(initializableMock, abi.encodeWithSignature("initialize()")); // new initialize function without key-manager
  }

  function testRegistrationsRetainAfterProxyUpgrade() public {
    TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(fvAccountRegistry)));

    // register address
    address expected = fvAccountRegistry.register(address(this));

    // upgrade
    address fvAccountRegistryV2 = Clones.clone(address(registryImpl));
    vm.prank(admin);
    proxy.upgradeTo(fvAccountRegistryV2);

    assertEq(expected, FVAccountRegistry(address(proxy)).identityOf(address(this)));
  }

  //
  // FVKeyManager upgrade tests
  //
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
    bytes32 beaconSlot = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);
    bytes32 implAddr = vm.load(userKeyManager, beaconSlot); // load beacon address from storage
    assertEq(address(uint160(uint256(implAddr))), address(keyManagerBeacon));

    // validate that the beacon impl address is updated (also implying that the user key manager impl is updated)
    assertEq(keyManagerBeacon.implementation(), keyManagerv2);
  }

  function testFVKeyManagerStorageUpgrading() public {
    // register a user
    address userKeyManager = fvAccountRegistry.register(address(this));

    address oldTarget = LSP6KeyManagerInit(userKeyManager).target();

    // upgrade
    address keyManagerv2 = address(new MockKeyManagerUpgraded());
    FVAccountRegistry(address(fvAccountRegistry)).upgradeFVKeyManager(keyManagerv2);

    // test old storage
    assertEq(oldTarget, LSP6KeyManagerInit(userKeyManager).target());

    // test new storage
    MockKeyManagerUpgraded(userKeyManager).incrementVal();
    assertEq(1, MockKeyManagerUpgraded(userKeyManager).val());
  }

  //
  // FVAccount upgrade tests
  //
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
    // register a user, get the proxy address for user FV account
    address userFVAccountProxy =
      address(payable(LSP6KeyManagerInit(fvAccountRegistry.register(address(this))).target()));

    // create a clone of the account
    address fvAccountv2 = Clones.clone(fvAccountRegistry.fvAccountAddr());

    // update the impl of the beacon succeeds
    UpgradeableBeacon fvAccountBeacon = FVAccountRegistry(address(fvAccountRegistry)).fvAccountBeacon();
    vm.expectEmit(true, false, false, false, address(fvAccountBeacon));
    emit Upgraded(fvAccountv2);
    FVAccountRegistry(address(fvAccountRegistry)).upgradeFVAccount(fvAccountv2);

    // validate user account impl is updated
    bytes32 beaconSlot = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);
    bytes32 implAddr = vm.load(userFVAccountProxy, beaconSlot); // load beacon address from storage
    assertEq(address(uint160(uint256(implAddr))), address(fvAccountBeacon));

    // validate that the beacon impl address is updated (also implying that the user account impl is updated)
    assertEq(fvAccountBeacon.implementation(), fvAccountv2);
  }

  function testFVAccountStorageUpgrading() public {
    // register a user
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));

    // give some permissions for storage test
    bytes memory oldData = Utils.toBytes(_PERMISSION_CALL);
    bytes32 dataKey = Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS, gameAddr);
    bytes memory execData = abi.encodeWithSelector(bytes4(keccak256("setData(bytes32,bytes)")), dataKey, oldData);
    userKeyManager.execute(execData);
    assertEq(IERC725Y(userKeyManager.target()).getData(dataKey), oldData);

    // upgrade
    address fvAccountv2 = address(new MockAccountUpgraded());
    FVAccountRegistry(address(fvAccountRegistry)).upgradeFVAccount(fvAccountv2);

    // test old storage
    assertEq(IERC725Y(userKeyManager.target()).getData(dataKey), oldData);

    // test new storage
    userKeyManager.execute(execData);
    assertEq(MockAccountUpgraded(payable(address(userKeyManager.target()))).setDataCounter(), 1);
  }
}
