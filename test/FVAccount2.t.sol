// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManager.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManagerInit.sol";

import {FVAccountRegistry, AccountAlreadyExists, Utils} from "../src/FVAccount2.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MockERC20 is ERC20 {
  constructor() ERC20("MyToken", "MTK") {}
  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }
}

contract FVAccount2RegistryTest is Test {
  FVAccountRegistry public fvAccountRegistry;
  MockERC20 public mockERC20;

  // re-declare event for assertions
  event AccountRegistered(address indexed account);

  function setUp() public {
    fvAccountRegistry = new FVAccountRegistry();
    mockERC20 = new MockERC20();
  }

  function testFVAccountRegistryIsNotFVAccountOwner() public {
    assertFalse(fvAccountRegistry.fvAccount().owner() == address(fvAccountRegistry));
  }

  function testFVAccountRegistryHasNoPermissions() public {
    bytes memory registryPermissions = fvAccountRegistry.fvAccount().getData(Utils.permissionsKey(address(fvAccountRegistry)));
    assertEq(registryPermissions, bytes(""));
  }

  function testFVAccountOwnerIsKeyManager() public {
    assertEq(fvAccountRegistry.fvAccount().owner(), address(0));
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
    LSP6KeyManager(userKeyManagerAddr).execute(executeCall);

    assertEq(mockERC20.balanceOf(address(this)), 100);
  }
}
