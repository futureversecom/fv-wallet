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
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IFVIdentityRegistry} from "../src/IFVIdentityRegistry.sol";
import {FVIdentityRegistry} from "../src/FVIdentityRegistry.sol";
import {FVKeyManager} from "../src/FVKeyManager.sol";
import "../src/Utils.sol";

import "./helpers/GasHelper.t.sol";
import "./helpers/DataHelper.t.sol";
import "./helpers/MockContracts.t.sol";

contract FVIdentityRegistryBaseTest is Test, GasHelper, DataHelper {
  address private constant admin = address(0x000000000000000000000000000000000000dEaD);
  address private constant gameAddr = address(0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045);

  IFVIdentityRegistry public fvIdentityRegistry;
  IFVIdentityRegistry private registryImpl;
  FVKeyManager private keyManagerImpl;
  MockERC20 public mockERC20;

  // Random key. DO NOT USE IN A PRODUCTION ENVIRONMENT
  uint256 private pk = 0xabfa816b2d044fca73f609721c7811b3876e69f915a5398bdb88b3ce5bf28a61;
  address private pkAddr;

  // re-declare event for assertions
  event IdentityRegistered(address indexed owner, address indexed keyManager, address indexed identity);
  event IdentityChanged(address indexed oldOwner, address indexed newOwner, address indexed keyManager);
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
    registryImpl = new FVIdentityRegistry();

    // deploy key manager implementation
    keyManagerImpl = new FVKeyManager();

    // deploy proxy with dead address as proxy admin, initialize upgradable identity registry
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(registryImpl),
      admin,
      abi.encodeWithSignature("initialize(address)", address(keyManagerImpl))
    );

    // note: admin can call additional functions on proxy
    fvIdentityRegistry = FVIdentityRegistry(address(proxy)); // set proxy as fvIdentityRegistry
  }

  //
  // Interfaces
  //
  function testIdentityRegistryInterfaces() public {
    IERC165 registry = IERC165(address(fvIdentityRegistry));

    assertTrue(registry.supportsInterface(type(IERC165).interfaceId), "ERC165 support");
    assertTrue(registry.supportsInterface(type(IFVIdentityRegistry).interfaceId), "FVIdentityRegistry support");
  }

  function testKeyManagerInterfaces() public {
    IERC165 userKeyManager = IERC165(fvIdentityRegistry.register(address(0)));

    assertTrue(userKeyManager.supportsInterface(type(IERC165).interfaceId), "ERC165 support");
    assertTrue(userKeyManager.supportsInterface(type(IERC1271).interfaceId), "ERC1271 support");
    assertTrue(userKeyManager.supportsInterface(type(ILSP6KeyManager).interfaceId), "LSP6 support");
  }

  function testIdentityInterfaces() public {
    address userKeyManager = fvIdentityRegistry.register(address(0));
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
  function testFVIdentityImplCannotBeInitializedTwice() public {
    FVIdentity fvIdentity = FVIdentity(payable(fvIdentityRegistry.fvIdentityAddr()));

    vm.expectRevert("Initializable: contract is already initialized");

    fvIdentity.initialize(address(this), bytes32(""), bytes(""));
  }

  function testFVKeyManagerImplCannotBeInitializedTwice() public {
    FVKeyManager fvKeyManager = FVKeyManager(payable(fvIdentityRegistry.fvKeyManagerAddr()));

    vm.expectRevert("Initializable: contract is already initialized");

    fvKeyManager.initialize(address(this));
  }

  function testFVIdentityOwnerIsZeroAddress() public {
    LSP0ERC725Account fvIdentity = LSP0ERC725Account(payable(fvIdentityRegistry.fvIdentityAddr()));
    assertEq(fvIdentity.owner(), address(0));
  }

  function testFVIdentityRegistryIsNotFVIdentityOwner() public {
    LSP0ERC725Account fvIdentity = LSP0ERC725Account(payable(fvIdentityRegistry.fvIdentityAddr()));
    assertFalse(fvIdentity.owner() == address(fvIdentityRegistry));
  }

  function testFVIdentityRegistryHasNoPermissions() public {
    LSP0ERC725Account fvIdentity = LSP0ERC725Account(payable(fvIdentityRegistry.fvIdentityAddr()));
    bytes memory registryPermissions =
      fvIdentity.getData(Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, address(fvIdentityRegistry)));
    assertEq(registryPermissions, bytes(""));
  }

  //
  // Register
  //
  function testUnregistedErrors() public {
    address zero = address(0);
    vm.expectRevert(abi.encodeWithSelector(IdentityNotRegistered.selector, zero));
    fvIdentityRegistry.identityOf(zero);
    vm.expectRevert(abi.encodeWithSelector(IdentityNotRegistered.selector, zero));
    fvIdentityRegistry.keyManagerOf(zero);
  }

  function testRegisterOfZeroAddress() public {
    // We emit the event we expect to see.
    vm.expectEmit(true, false, false, false, address(fvIdentityRegistry));
    emit IdentityRegistered(address(0), address(0), address(0));

    // Perform the actual call (which should emit expected event).
    fvIdentityRegistry.register(address(0));
  }

  function testRegisterOfNewAddressSucceeds() public {
    vm.expectEmit(true, false, false, false, address(fvIdentityRegistry));
    emit IdentityRegistered(address(this), address(0), address(0));

    startMeasuringGas("fvIdentityRegistry.register(address(this)) success");
    address userKeyManagerAddr = fvIdentityRegistry.register(address(this));
    stopMeasuringGas();

    assertTrue(userKeyManagerAddr != address(0));
    assertEq(fvIdentityRegistry.keyManagerOf(address(this)), userKeyManagerAddr);
  }

  function testRegisterFailsForMultipleRegistrations() public {
    fvIdentityRegistry.register(address(this));
    vm.expectRevert(abi.encodeWithSelector(IdentityAlreadyExists.selector, address(this)));
    startMeasuringGas("fvIdentityRegistry.register(address(this)) fail second acc");
    fvIdentityRegistry.register(address(this));
    stopMeasuringGas();
  }

  function testRegisteredUserCanCallExternalContract() public {
    address userKeyManagerAddr = fvIdentityRegistry.register(address(this));

    // abi encoded call to execute mint call
    bytes memory executeCall = createERC20ExecuteDataForCall(mockERC20);
    ILSP6KeyManager(userKeyManagerAddr).execute(executeCall);

    // Caller of mint should be identity of registered address
    address registeredIdentity = fvIdentityRegistry.identityOf(address(this));
    assertEq(ILSP6KeyManager(userKeyManagerAddr).target(), registeredIdentity);
    assertEq(mockERC20.balanceOf(registeredIdentity), 100);
  }

  function testRegisterAfterChangeOwnerSuccess() public {
    FVKeyManager userKeyManager1 = FVKeyManager(fvIdentityRegistry.register(address(this)));
    userKeyManager1.transferOwnership(admin);

    vm.expectEmit(true, false, false, false, address(fvIdentityRegistry));
    emit IdentityRegistered(address(this), address(0), address(0));
    FVKeyManager userKeyManager2 = FVKeyManager(fvIdentityRegistry.register(address(this)));

    assertEq(userKeyManager1.owner(), admin);
    assertEq(userKeyManager2.owner(), address(this));
    assertEq(fvIdentityRegistry.keyManagerOf(admin), address(userKeyManager1));
    assertEq(fvIdentityRegistry.keyManagerOf(address(this)), address(userKeyManager2));
  }

  function testRegisterAfterChangeOwnerFails() public {
    FVKeyManager userKeyManager1 = FVKeyManager(fvIdentityRegistry.register(address(this)));
    userKeyManager1.transferOwnership(admin);

    vm.expectRevert(abi.encodeWithSelector(IdentityAlreadyExists.selector, admin));
    FVKeyManager(fvIdentityRegistry.register(admin));
  }

  //
  // Test setData permissions
  //
  function testNonOwnerUnableToUseRestrictedFunctions() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));

    checkCannotUseRestrictedFunctions(userKeyManager);
  }

  function testNonOwnerPermissionedUnableToUseRestrictedFunctions() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));

    // Give permissions (expect these to be ignored)
    bytes memory execData = abi.encodeWithSelector(
      bytes4(keccak256("setData(bytes32,bytes)")),
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, gameAddr),
      Utils.toBytes(ALL_PERMISSIONS) // All permissions
    );
    startMeasuringGas("userKeyManager.execute() add all permission");
    userKeyManager.execute(execData);
    stopMeasuringGas();

    checkCannotUseRestrictedFunctions(userKeyManager);
  }

  function checkCannotUseRestrictedFunctions(ILSP6KeyManager userKeyManager) private {
    // setData(bytes32,bytes)
    bytes memory execData = abi.encodeWithSelector(
      bytes4(keccak256("setData(bytes32,bytes)")),
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, admin),
      Utils.toBytes(ALL_PERMISSIONS) // All permissions
    );
    vm.prank(gameAddr);
    vm.expectRevert("Ownable: caller is not the owner");
    userKeyManager.execute(execData);

    // setData(bytes32[],bytes[])
    bytes32[] memory keys = new bytes32[](1);
    bytes[] memory values = new bytes[](1);
    keys[0] = Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, admin);
    values[0] = Utils.toBytes(ALL_PERMISSIONS); // All permissions
    execData = abi.encodeWithSelector(bytes4(keccak256("setData(bytes32[],bytes[])")), keys, values);
    vm.prank(gameAddr);
    vm.expectRevert("Ownable: caller is not the owner");
    userKeyManager.execute(execData);

    // transferOwnership
    execData = abi.encodeWithSelector(bytes4(keccak256("transferOwnership(address)")), admin);
    vm.prank(gameAddr);
    vm.expectRevert("Ownable: caller is not the owner");
    userKeyManager.execute(execData);
  }

  function testOwnerAbleToUseRestrictedFunctions() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));

    // setData(bytes32,bytes)
    bytes memory execData = abi.encodeWithSelector(
      bytes4(keccak256("setData(bytes32,bytes)")),
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, admin),
      Utils.toBytes(ALL_PERMISSIONS) // All permissions
    );
    userKeyManager.execute(execData);

    // setData(bytes32[],bytes[])
    bytes32[] memory keys = new bytes32[](1);
    bytes[] memory values = new bytes[](1);
    keys[0] = Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, admin);
    values[0] = Utils.toBytes(ALL_PERMISSIONS); // All permissions
    execData = abi.encodeWithSelector(bytes4(keccak256("setData(bytes32[],bytes[])")), keys, values);
    userKeyManager.execute(execData);

    // transferOwnership
    execData = abi.encodeWithSelector(bytes4(keccak256("transferOwnership(address)")), admin);
    userKeyManager.execute(execData);
  }

  //
  // Test change key manager owner
  //
  function testChangeKeyManagerOwner() public {
    FVKeyManager userKeyManager = FVKeyManager(fvIdentityRegistry.register(address(this)));

    vm.expectEmit(true, false, true, true, address(fvIdentityRegistry));
    emit IdentityChanged(address(this), admin, address(userKeyManager));
    userKeyManager.transferOwnership(admin);

    assertEq(userKeyManager.owner(), admin);
    assertEq(fvIdentityRegistry.keyManagerOf(admin), address(userKeyManager));
    vm.expectRevert(abi.encodeWithSelector(IdentityNotRegistered.selector, address(this)));
    assertEq(fvIdentityRegistry.keyManagerOf(address(this)), address(0));
  }

  function testChangeKeyManagerOwnerFailsNonOwner() public {
    FVKeyManager userKeyManager = FVKeyManager(fvIdentityRegistry.register(address(this)));

    vm.expectRevert("Ownable: caller is not the owner");
    vm.prank(admin);
    userKeyManager.transferOwnership(admin);
  }

  function testChangeKeyManagerOwnerFailsCallingRegistry() public {
    address userKeyManager = fvIdentityRegistry.register(address(this));

    vm.expectRevert(abi.encodeWithSelector(InvalidCaller.selector, gameAddr, userKeyManager));
    vm.prank(gameAddr);
    fvIdentityRegistry.updateKeyManagerOwner(address(this), gameAddr);

    vm.expectRevert(abi.encodeWithSelector(InvalidCaller.selector, address(this), userKeyManager));
    fvIdentityRegistry.updateKeyManagerOwner(address(this), gameAddr);
  }

  function testChangeKeyManagerOwnerFailsAlreadyRegistered() public {
    FVKeyManager userKeyManager = FVKeyManager(fvIdentityRegistry.register(address(this)));
    fvIdentityRegistry.register(admin);

    vm.expectRevert(abi.encodeWithSelector(IdentityAlreadyExists.selector, admin));
    userKeyManager.transferOwnership(admin);
  }

  //
  // Test CALL permissions
  //
  function testCallUnauthedExternalIdentityFails() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));

    vm.prank(gameAddr);
    vm.expectRevert(abi.encodeWithSelector(NoPermissionsSet.selector, gameAddr));
    userKeyManager.execute(createERC20ExecuteDataForCall(mockERC20));
  }

  function testCallAuthedExternalIdentityWrongContractFails() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));

    // Give call permission
    bytes memory execData = abi.encodeWithSelector(
      bytes4(keccak256("setData(bytes32,bytes)")),
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, gameAddr), // AddressPermissions:Permissions
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
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS_PREFIX, gameAddr), // AddressPermissions:AllowedCalls
      createCallContractWhitelistData(allowed)
    );
    startMeasuringGas("userKeyManager.execute() add call contract permission");
    userKeyManager.execute(execData);
    stopMeasuringGas();

    vm.prank(gameAddr);
    vm.expectRevert(
      abi.encodeWithSelector(NotAllowedCall.selector, gameAddr, address(mockERC20), mockERC20.mintCaller.selector)
    );
    userKeyManager.execute(createERC20ExecuteDataForCall(mockERC20));
  }

  function testCallAuthedExternalIdentitySingleContract() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));

    // Give call permission
    bytes memory execData = abi.encodeWithSelector(
      bytes4(keccak256("setData(bytes32,bytes)")),
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, gameAddr), // AddressPermissions:Permissions
      Utils.toBytes(_PERMISSION_CALL) // Call only
    );
    userKeyManager.execute(execData);
    // Give allowed calls permissions to erc20
    address[] memory allowed = new address[](1);
    allowed[0] = address(mockERC20);
    execData = abi.encodeWithSelector(
      bytes4(keccak256("setData(bytes32,bytes)")),
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS_PREFIX, gameAddr), // AddressPermissions:AllowedCalls
      createCallContractWhitelistData(allowed)
    );
    userKeyManager.execute(execData);

    vm.prank(gameAddr);
    startMeasuringGas("userKeyManager.execute() call erc20 mint");
    userKeyManager.execute(createERC20ExecuteDataForCall(mockERC20));
    stopMeasuringGas();

    assertEq(mockERC20.balanceOf(userKeyManager.target()), 100);
  }

  function testCallAuthedExternalIdentityMultipleContract() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));
    MockERC20 mockERC20B = new MockERC20();

    // Give call permission
    bytes memory execData = abi.encodeWithSelector(
      bytes4(keccak256("setData(bytes32,bytes)")),
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, gameAddr), // AddressPermissions:Permissions
      Utils.toBytes(_PERMISSION_CALL) // Call only
    );
    userKeyManager.execute(execData);
    // Give allowed calls permissions
    address[] memory allowed = new address[](1);
    allowed[0] = address(mockERC20);
    execData = abi.encodeWithSelector(
      bytes4(keccak256("setData(bytes32,bytes)")),
      Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS_PREFIX, gameAddr), // AddressPermissions:AllowedCalls
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

    assertEq(mockERC20.balanceOf(userKeyManager.target()), 100);
    assertEq(mockERC20B.balanceOf(userKeyManager.target()), 100);
  }

  //
  // Test CREATE permissions
  //
  function testCreateUnauthedExternalIdentityFails() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    vm.prank(userAddr);

    vm.expectRevert(abi.encodeWithSelector(NoPermissionsSet.selector, userAddr));
    userKeyManager.execute(createMockERC20ExecuteData());
  }

  function testCreateAuthedExternalIdentitySingleContract() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    // Give user CREATE permission
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, userAddr), // AddressPermissions:Permissions
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
  function testCreate2UnauthedExternalIdentityFails() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    vm.prank(userAddr);

    vm.expectRevert(abi.encodeWithSelector(NoPermissionsSet.selector, userAddr));
    userKeyManager.execute(create2MockERC20ExecuteData());
  }

  function testCreate2AuthedExternalIdentitySingleContract() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    // Give user CREATE permission
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, userAddr), // AddressPermissions:Permissions
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
  function testStaticCallUnauthedExternalIdentityFails() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));

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

  function testStaticCallAuthedExternalIdentitySingleContract() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    // Give user STATICCALL permission
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, userAddr), // AddressPermissions:Permissions
        Utils.toBytes(_PERMISSION_STATICCALL) // STATICCALL only
      )
    );

    // Give allowed calls permissions to erc20
    address[] memory allowed = new address[](1);
    allowed[0] = address(mockERC20);
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS_PREFIX, userAddr), // AddressPermissions:AllowedCalls
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
  function testDelegateCallUnauthedExternalIdentityFails() public {
    DelegateAttacker delegated = new DelegateAttacker();

    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));

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
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    // Give user DELEGATECALL permission
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, userAddr), // AddressPermissions:Permissions
        Utils.toBytes(_PERMISSION_DELEGATECALL) // DELEGATECALL only
      )
    );

    // Give allowed calls permissions to erc20
    address[] memory allowed = new address[](1);
    allowed[0] = address(delegated);
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS_PREFIX, userAddr), // AddressPermissions:AllowedCalls
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
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(pkAddr));

    bytes memory payload = createERC20ExecuteDataForCall(mockERC20);
    bytes memory signature = signForRelayCall(payload, 0, 0, pk, vm, address(userKeyManager));

    startMeasuringGas("userKeyManager.execute() call erc20 mint");
    userKeyManager.executeRelayCall(signature, 0, payload);
    stopMeasuringGas();

    assertEq(mockERC20.balanceOf(userKeyManager.target()), 100);
  }

  function testFVIdentityRegistryCannotBeInitializedTwice() public {
    address proxyAddress = address(fvIdentityRegistry);

    // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/bc50d373e37a6250f931a5dba3847bc88e46797e/contracts/proxy/ERC1967/ERC1967Upgrade.sol#L28
    bytes32 implementationSlot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 implAddr = vm.load(proxyAddress, implementationSlot); // load impl address from storage

    FVIdentityRegistry registry = FVIdentityRegistry(address(uint160(uint256(implAddr))));

    vm.expectRevert("Initializable: contract is already initialized");

    registry.initialize(address(keyManagerImpl));
  }

  //
  // FVIdentityRegistry Transparent Proxy tests
  //
  function testNonAdminCannotCallAdminFunctionsOnFVIdentityRegistryTransparentProxy() public {
    // ensure non-admin cannot call TransparentProxy functions
    TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(fvIdentityRegistry)));

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

  function testAdminCanCallAdminFunctionsOnFVIdentityRegistryTransparentProxy() public {
    TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(fvIdentityRegistry)));

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

    // create a copy of the identity registry impl (not the proxy) - for testing upgradability
    address fvIdentityRegistryV2 = Clones.clone(address(registryImpl));
    vm.expectEmit(true, false, false, false, address(proxy));
    emit Upgraded(fvIdentityRegistryV2);
    proxy.upgradeTo(fvIdentityRegistryV2);

    // create a copy of the identity registry impl (not the proxy) - for testing upgradability with call
    address fvIdentityRegistryV3 = Clones.clone(address(registryImpl));
    // re-initialize fails as already initialized (state saved in proxy), future contracts must use
    // `reinitializer(version)` modifier on `initialize` function
    vm.expectRevert("Initializable: contract is already initialized");
    proxy.upgradeToAndCall(
      fvIdentityRegistryV3, abi.encodeWithSignature("initialize(address)", address(keyManagerImpl))
    );

    // can successfully re-initialize if upgraded contract has `reinitializer(version)` modifier on `initialize` function
    address initializableMock = address(new UpgradedMock());
    vm.expectEmit(true, false, false, false, address(proxy));
    emit Upgraded(initializableMock);
    proxy.upgradeToAndCall(initializableMock, abi.encodeWithSignature("initialize()")); // new initialize function without key-manager
  }

  function testRegistrationsRetainAfterProxyUpgrade() public {
    TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(fvIdentityRegistry)));

    // register address
    address expected = fvIdentityRegistry.register(address(this));

    // upgrade
    address fvIdentityRegistryV2 = Clones.clone(address(registryImpl));
    vm.prank(admin);
    proxy.upgradeTo(fvIdentityRegistryV2);

    assertEq(expected, FVIdentityRegistry(address(proxy)).keyManagerOf(address(this)));
  }

  //
  // FVKeyManager upgrade tests
  //
  function testUpgradingKeyManagerImplFailsAsNonAdmin() public {
    // create a clone of the key manager
    address keyManagerv2 = Clones.clone(fvIdentityRegistry.fvKeyManagerAddr());

    // update the impl of the beacon fails externally (not owner)
    UpgradeableBeacon keyManagerBeacon = FVIdentityRegistry(address(fvIdentityRegistry)).fvKeyManagerBeacon();
    vm.expectRevert("Ownable: caller is not the owner");
    keyManagerBeacon.upgradeTo(keyManagerv2);

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    vm.startPrank(userAddr);

    // update the impl of the beacon fails internally (not owner)
    vm.expectRevert("Ownable: caller is not the owner");
    FVIdentityRegistry(address(fvIdentityRegistry)).upgradeFVKeyManager(keyManagerv2);
  }

  function testUpgradingKeyManagerImplSucceedsAsAdmin() public {
    // register a user
    address userKeyManager = fvIdentityRegistry.register(address(this));

    // create a clone of the key manager
    address keyManagerv2 = Clones.clone(fvIdentityRegistry.fvKeyManagerAddr());

    // update the impl of the beacon succeeds
    UpgradeableBeacon keyManagerBeacon = FVIdentityRegistry(address(fvIdentityRegistry)).fvKeyManagerBeacon();
    vm.expectEmit(true, false, false, false, address(keyManagerBeacon));
    emit Upgraded(keyManagerv2);
    FVIdentityRegistry(address(fvIdentityRegistry)).upgradeFVKeyManager(keyManagerv2);

    // validate user key manager impl is updated
    bytes32 beaconSlot = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);
    bytes32 implAddr = vm.load(userKeyManager, beaconSlot); // load beacon address from storage
    assertEq(address(uint160(uint256(implAddr))), address(keyManagerBeacon));

    // validate that the beacon impl address is updated (also implying that the user key manager impl is updated)
    assertEq(keyManagerBeacon.implementation(), keyManagerv2);
  }

  function testFVKeyManagerStorageUpgrading() public {
    // register a user
    address userKeyManager = fvIdentityRegistry.register(address(this));

    address oldTarget = FVKeyManager(userKeyManager).target();

    // upgrade
    address keyManagerv2 = address(new MockKeyManagerUpgraded());
    FVIdentityRegistry(address(fvIdentityRegistry)).upgradeFVKeyManager(keyManagerv2);

    // test old storage
    assertEq(FVKeyManager(userKeyManager).target(), oldTarget);

    // test new storage
    MockKeyManagerUpgraded(userKeyManager).incrementVal();
    assertEq(MockKeyManagerUpgraded(userKeyManager).val(), 1);
  }

  //
  // FVIdentity upgrade tests
  //
  function testUpgradingFVIdentityImplFailsAsNonAdmin() public {
    // create a clone of the identity
    address fvIdentityv2 = Clones.clone(fvIdentityRegistry.fvIdentityAddr());

    // update the impl of the beacon fails externally (not owner)
    UpgradeableBeacon fvIdentityBeacon = FVIdentityRegistry(address(fvIdentityRegistry)).fvIdentityBeacon();
    vm.expectRevert("Ownable: caller is not the owner");
    fvIdentityBeacon.upgradeTo(fvIdentityv2);

    address userAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    vm.startPrank(userAddr);

    // update the impl of the beacon fails internally (not owner)
    vm.expectRevert("Ownable: caller is not the owner");
    FVIdentityRegistry(address(fvIdentityRegistry)).upgradeFVIdentity(fvIdentityv2);
  }

  function testUpgradingFVIdentityImplSucceedsAsAdmin() public {
    // register a user, get the proxy address for user FV identity
    address userFVIdentityProxy = address(payable(FVKeyManager(fvIdentityRegistry.register(address(this))).target()));

    // create a clone of the identity
    address fvIdentityv2 = Clones.clone(fvIdentityRegistry.fvIdentityAddr());

    // update the impl of the beacon succeeds
    UpgradeableBeacon fvIdentityBeacon = FVIdentityRegistry(address(fvIdentityRegistry)).fvIdentityBeacon();
    vm.expectEmit(true, false, false, false, address(fvIdentityBeacon));
    emit Upgraded(fvIdentityv2);
    FVIdentityRegistry(address(fvIdentityRegistry)).upgradeFVIdentity(fvIdentityv2);

    // validate user identity impl is updated
    bytes32 beaconSlot = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);
    bytes32 implAddr = vm.load(userFVIdentityProxy, beaconSlot); // load beacon address from storage
    assertEq(address(uint160(uint256(implAddr))), address(fvIdentityBeacon));

    // validate that the beacon impl address is updated (also implying that the user identity impl is updated)
    assertEq(fvIdentityBeacon.implementation(), fvIdentityv2);
  }

  function testFVIdentityStorageUpgrading() public {
    // register a user
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));

    // give some permissions for storage test
    bytes memory oldData = Utils.toBytes(_PERMISSION_CALL);
    bytes32 dataKey = Utils.permissionsKey(KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, gameAddr);
    bytes memory execData = abi.encodeWithSelector(bytes4(keccak256("setData(bytes32,bytes)")), dataKey, oldData);
    userKeyManager.execute(execData);
    assertEq(IERC725Y(userKeyManager.target()).getData(dataKey), oldData);

    // upgrade
    address fvIdentityv2 = address(new MockIdentityUpgraded());
    FVIdentityRegistry(address(fvIdentityRegistry)).upgradeFVIdentity(fvIdentityv2);

    // test old storage
    assertEq(IERC725Y(userKeyManager.target()).getData(dataKey), oldData);

    // test new storage
    userKeyManager.execute(execData);
    assertEq(MockIdentityUpgraded(payable(address(userKeyManager.target()))).setDataCounter(), 1);
  }
}
