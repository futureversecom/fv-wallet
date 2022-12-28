// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6Constants.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6Errors.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/ILSP6KeyManager.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManagerInit.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725Account.sol";
import {IERC725Y} from "@erc725/smart-contracts/contracts/interfaces/IERC725Y.sol";

import {IFVAccountRegistry} from "../src/IFVAccountRegistry.sol";
import "../src/Utils.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MockERC20 is ERC20 {
  constructor() ERC20("MyToken", "MTK") {}
  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }
}

// Wrap an interface so we can make the test suite common.
// We do this because LSP0ERC725Account and LSP0ERC725AccountInit don't have a common interface grr
interface FVAccountWrapper is IERC725Y {
    function owner() external view returns (address);
}

abstract contract FVAccountRegistryBaseTest is Test {
  IFVAccountRegistry public fvAccountRegistry;
  MockERC20 public mockERC20;

  // re-declare event for assertions
  event AccountRegistered(address indexed account);

  function setUp() public virtual {
    mockERC20 = new MockERC20();
  }

  function testFVAccountRegistryIsNotFVAccountOwner() public {
    assertFalse(FVAccountWrapper(fvAccountRegistry.fvAccountAddr()).owner() == address(fvAccountRegistry));
  }

  function testFVAccountRegistryHasNoPermissions() public virtual {
    bytes memory registryPermissions = FVAccountWrapper(fvAccountRegistry.fvAccountAddr()).getData(Utils.permissionsKey(address(fvAccountRegistry)));
    assertEq(registryPermissions, Utils.toBytes(NO_PERMISSION));
  }

  function testFVAccountOwnerIsKeyManager() public virtual {
    assertEq(FVAccountWrapper(fvAccountRegistry.fvAccountAddr()).owner(), fvAccountRegistry.fvKeyManagerAddr());
  }

  function testRegisterOfZeroAddress() public {
    vm.expectEmit(true, false, false, false, address(fvAccountRegistry));

    // We emit the event we expect to see.
    emit AccountRegistered(address(0));

    // Perform the actual call (which should emit expected event).
    fvAccountRegistry.register(address(0));
  }

  function testRegisterOfNewAddressSucceeds() public {
    vm.expectEmit(true, false, false, false, address(fvAccountRegistry));

    emit AccountRegistered(address(this));

    address userKeyManagerAddr = fvAccountRegistry.register(address(this));
    assertTrue(userKeyManagerAddr != address(0));

    assertEq(fvAccountRegistry.identityOf(address(this)), userKeyManagerAddr); 
  }

  function testRegisterFailsForMultipleRegistrations() public {
    fvAccountRegistry.register(address(this));
    vm.expectRevert(abi.encodeWithSelector(AccountAlreadyExists.selector, address(this)));
    fvAccountRegistry.register(address(this));
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

  // Construct call data for calling mint on the mockERC20
  function createTestERC20ExecuteData(MockERC20 _mockERC20) internal view returns (bytes memory) {
    // abi encoded call to mint 100 tokens to address(this)
    bytes memory mintCall = abi.encodeWithSelector(_mockERC20.mint.selector, address(this), 100);
    // abi encoded call to execute mint call
    bytes memory executeCall = abi.encodeWithSignature(
      "execute(uint256,address,uint256,bytes)", // operationType, target, value, data
      0,
      address(_mockERC20),
      0,
      mintCall
    );

    return executeCall;
  }

  function testUnauthedExternalAccountFails() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));
    address gameAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    vm.prank(gameAddr);
    vm.expectRevert(abi.encodeWithSelector(NoPermissionsSet.selector, gameAddr));
    userKeyManager.execute(createTestERC20ExecuteData(mockERC20));
  }

  function testAuthedExternalAccountWrongContractFails() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));
    address gameAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    // Give call permission
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey("4b80742de2bf82acb3630000", gameAddr), // AddressPermissions:Permissions
        Utils.toBytes(_PERMISSION_CALL) // Call only
    ));
    // Give allowed calls permissions to wrong contract
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey("4b80742de2bf393a64c70000", gameAddr), // AddressPermissions:AllowedCalls
        Utils.toBytes(string.concat("1cffffffff", Utils.toHexStringNoPrefix(address(gameAddr)), "ffffffff"))
      ));

    vm.prank(gameAddr);
    vm.expectRevert(abi.encodeWithSelector(NotAllowedCall.selector, gameAddr, address(mockERC20), mockERC20.mint.selector));
    userKeyManager.execute(createTestERC20ExecuteData(mockERC20));
  }

  function testAuthedExternalAccountSingleContract() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));
    address gameAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    // Give call permission
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey("4b80742de2bf82acb3630000", gameAddr), // AddressPermissions:Permissions
        Utils.toBytes(_PERMISSION_CALL) // Call only
    ));
    // Give allowed calls permissions
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey("4b80742de2bf393a64c70000", gameAddr), // AddressPermissions:AllowedCalls
        Utils.toBytes(string.concat("1cffffffff", Utils.toHexStringNoPrefix(address(mockERC20)), "ffffffff"))
      ));


    vm.prank(gameAddr);
    userKeyManager.execute(createTestERC20ExecuteData(mockERC20));

    assertEq(mockERC20.balanceOf(address(this)), 100);
  }

  function testAuthedExternalAccountMultipleContract() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvAccountRegistry.register(address(this)));
    address gameAddr = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    MockERC20 mockERC20B = new MockERC20();

    // Give call permission
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey("4b80742de2bf82acb3630000", gameAddr), // AddressPermissions:Permissions
        Utils.toBytes(_PERMISSION_CALL) // Call only
    ));
    // Give allowed calls permissions
    userKeyManager.execute(
      abi.encodeWithSelector(
        bytes4(keccak256("setData(bytes32,bytes)")),
        Utils.permissionsKey("4b80742de2bf393a64c70000", gameAddr), // AddressPermissions:AllowedCalls
        Utils.toBytes(string.concat("1cffffffff", Utils.toHexStringNoPrefix(address(mockERC20)), "ffffffff", "1cffffffff", Utils.toHexStringNoPrefix(address(mockERC20B)), "ffffffff"))
      ));


    vm.prank(gameAddr);
    userKeyManager.execute(createTestERC20ExecuteData(mockERC20));
    userKeyManager.execute(createTestERC20ExecuteData(mockERC20B));

    assertEq(mockERC20.balanceOf(address(this)), 100);
    assertEq(mockERC20B.balanceOf(address(this)), 100);
  }
}
